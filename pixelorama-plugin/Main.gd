## pix-MCP Bridge — Main Extension Entry Point
## This extension runs a local HTTP server inside Pixelorama that accepts
## JSON commands from the pix-MCP server, translating them into
## Pixelorama API calls (drawing, layers, palettes, export, etc.)
extends Node

const PORT: int = 7373
const MAX_REQUEST_SIZE: int = 4194304  # 4 MB max request body
const MAX_RESPONSE_CHUNK: int = 8192   # max bytes written per frame (keeps loop non-blocking)
const CLIENT_TIMEOUT_MS: int = 15000   # drop connections idle longer than this
const MAX_CLIENTS: int = 32

var _server: TCPServer = TCPServer.new()
var _clients: Array = []
var _api: Node = null
var _command_handler: RefCounted = null

## Logging prefix
const LOG_TAG: String = "[pix-MCP] "


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_api = get_node_or_null("/root/ExtensionsApi")
	if _api == null:
		push_error(LOG_TAG + "ExtensionsApi not found! Is this running inside Pixelorama?")
		return

	_command_handler = preload("command_handler.gd").new()
	_command_handler.initialize(_api)

	var err := _server.listen(PORT, "127.0.0.1")
	if err != OK:
		push_error(LOG_TAG + "Failed to start HTTP server on port %d: %s" % [PORT, error_string(err)])
		return
	print(LOG_TAG + "HTTP server listening on 127.0.0.1:%d" % PORT)
	print(LOG_TAG + "Pixelorama version: %s" % _api.general.get_pixelorama_version())
	print(LOG_TAG + "ExtensionsApi version: %d" % _api.get_api_version())


func _process(_delta: float) -> void:
	if not _server.is_listening():
		return

	# Accept new connections (bounded so a flood can't exhaust memory)
	while _server.is_connection_available() and _clients.size() < MAX_CLIENTS:
		var peer := _server.take_connection()
		if peer:
			_clients.append({
				"peer": peer,
				"buffer": PackedByteArray(),
				"headers_parsed": false,
				"content_length": 0,
				"header_end_index": -1,
				"state": "recv",              # "recv" -> "respond"
				"response": PackedByteArray(),
				"response_sent": 0,
				"last_active": Time.get_ticks_msec(),
			})

	# Process existing connections
	var to_remove: Array[int] = []
	for i in range(_clients.size()):
		var client: Dictionary = _clients[i]
		var peer: StreamPeerTCP = client["peer"]
		peer.poll()

		var status := peer.get_status()
		if status != StreamPeerTCP.STATUS_CONNECTED:
			to_remove.append(i)
			continue

		# Drop stale connections so a dead client can never wedge the loop.
		var idle: int = Time.get_ticks_msec() - int(client["last_active"])
		if idle > CLIENT_TIMEOUT_MS:
			peer.disconnect_from_host()
			to_remove.append(i)
			continue

		if client["state"] == "respond":
			# Flush pending response in bounded chunks; never block on a slow client.
			var remaining: int = client["response"].size() - client["response_sent"]
			if remaining <= 0:
				peer.disconnect_from_host()
				to_remove.append(i)
				continue
			var chunk_len: int = mini(remaining, MAX_RESPONSE_CHUNK)
			var chunk: PackedByteArray = client["response"].slice(client["response_sent"], client["response_sent"] + chunk_len)
			var err := peer.put_data(chunk)
			if err == OK:
				client["response_sent"] += chunk_len
				client["last_active"] = Time.get_ticks_msec()
			continue

		# state == "recv": read available request bytes
		var available := peer.get_available_bytes()
		if available > 0:
			var data := peer.get_data(mini(available, MAX_REQUEST_SIZE))
			if data[0] == OK:
				client["buffer"].append_array(data[1])
				client["last_active"] = Time.get_ticks_msec()

		# Parse headers if not done yet
		if not client["headers_parsed"]:
			var buf_str: String = client["buffer"].get_string_from_utf8()
			var header_end: int = buf_str.find("\r\n\r\n")
			if header_end != -1:
				client["headers_parsed"] = true
				client["header_end_index"] = header_end + 4  # past the \r\n\r\n

				# Extract Content-Length
				var lines: PackedStringArray = buf_str.substr(0, header_end).split("\r\n")
				for line in lines:
					if line.to_lower().begins_with("content-length:"):
						client["content_length"] = int(line.split(":")[1].strip_edges())
						break
				print(LOG_TAG + "Parsed headers. Content-Length: %d" % client["content_length"])

		# Check if we have the full body
		if client["headers_parsed"]:
			var body_received: int = client["buffer"].size() - client["header_end_index"]
			if body_received >= client["content_length"]:
				_handle_request(client)
				_flush_chunk(client)


func _flush_chunk(client: Dictionary) -> void:
	## Send up to MAX_RESPONSE_CHUNK bytes of a pending response.
	var peer: StreamPeerTCP = client["peer"]
	if client["state"] != "respond":
		return
	var remaining: int = client["response"].size() - client["response_sent"]
	if remaining <= 0:
		peer.disconnect_from_host()
		return
	var chunk_len: int = mini(remaining, MAX_RESPONSE_CHUNK)
	var chunk: PackedByteArray = client["response"].slice(client["response_sent"], client["response_sent"] + chunk_len)
	var err := peer.put_data(chunk)
	if err == OK:
		client["response_sent"] += chunk_len
		client["last_active"] = Time.get_ticks_msec()


func _handle_request(client: Dictionary) -> void:
	var buf_str: String = client["buffer"].get_string_from_utf8()
	var header_end: int = client["header_end_index"]

	# Parse request line
	var first_line: String = buf_str.split("\r\n")[0]
	var parts: PackedStringArray = first_line.split(" ")
	var method: String = parts[0] if parts.size() > 0 else ""
	var path: String = parts[1] if parts.size() > 1 else ""

	# Extract body
	var body := ""
	if header_end < buf_str.length():
		body = buf_str.substr(header_end)

	# Route
	var response_body: String
	var status_code: int

	if method == "GET" and path == "/health":
		# Health check endpoint
		var health := {
			"status": "ok",
			"server": "pix-mcp-bridge",
			"version": "0.1.0",
			"pixelorama_version": _api.general.get_pixelorama_version() if _api else "unknown",
			"api_version": _api.get_api_version() if _api else -1
		}
		response_body = JSON.stringify(health)
		status_code = 200

	elif method == "POST" and path == "/command":
		# Main command endpoint
		var result := _execute_command(body)
		response_body = JSON.stringify(result)
		status_code = 200 if result.get("success", false) else 400

	elif method == "GET" and path == "/tools":
		# List available tools
		var tools: Array = _command_handler.get_available_tools() if _command_handler else []
		response_body = JSON.stringify({"tools": tools})
		status_code = 200

	elif method == "OPTIONS":
		# CORS preflight
		response_body = ""
		status_code = 204

	else:
		response_body = JSON.stringify({"error": "Not found", "path": path, "method": method})
		status_code = 404

	# Build HTTP response (stored on the client; sent incrementally in _process).
	# Content-Length uses the UTF-8 byte count so multi-byte bodies are sized correctly.
	var response := "HTTP/1.1 %d %s\r\n" % [status_code, _status_text(status_code)]
	response += "Content-Type: application/json\r\n"
	response += "Content-Length: %d\r\n" % response_body.to_utf8_buffer().size()
	response += "Access-Control-Allow-Origin: *\r\n"
	response += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
	response += "Access-Control-Allow-Headers: Content-Type\r\n"
	response += "Connection: close\r\n"
	response += "\r\n"
	response += response_body

	client["response"] = response.to_utf8_buffer()
	client["response_sent"] = 0
	client["state"] = "respond"


func _execute_command(body: String) -> Dictionary:
	if _command_handler == null:
		return {"success": false, "error": "Command handler not initialized"}

	var json := JSON.new()
	var err := json.parse(body)
	if err != OK:
		return {"success": false, "error": "Invalid JSON: %s" % json.get_error_message()}

	var data: Variant = json.data
	if not data is Dictionary:
		return {"success": false, "error": "Request body must be a JSON object"}

	var tool_name: String = data.get("tool", "")
	var params: Dictionary = data.get("params", {})

	if tool_name.is_empty():
		return {"success": false, "error": "Missing 'tool' field in request"}

	return _command_handler.execute(tool_name, params)


func _status_text(code: int) -> String:
	match code:
		200: return "OK"
		204: return "No Content"
		400: return "Bad Request"
		404: return "Not Found"
		500: return "Internal Server Error"
	return "Unknown"


func _exit_tree() -> void:
	# Clean up all connected clients
	for client in _clients:
		var peer: StreamPeerTCP = client.get("peer")
		if peer and peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			peer.disconnect_from_host()
	_clients.clear()

	# Stop the server
	if _server.is_listening():
		_server.stop()
		print(LOG_TAG + "HTTP server stopped")
