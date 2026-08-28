## pix-MCP Bridge — Main Extension Entry Point
## This extension runs a local HTTP server inside Pixelorama that accepts
## JSON commands from the pix-MCP server, translating them into
## Pixelorama API calls (drawing, layers, palettes, export, etc.)
extends Node

const PORT: int = 7373
const MAX_REQUEST_SIZE: int = 4194304  # 4 MB max request body

var _server: TCPServer = TCPServer.new()
var _clients: Array = []
var _api: Node = null
var _command_handler: RefCounted = null

## Logging prefix
const LOG_TAG: String = "[pix-MCP] "


func _enter_tree() -> void:
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

	# Accept new connections
	while _server.is_connection_available():
		var peer := _server.take_connection()
		if peer:
			_clients.append({
				"peer": peer,
				"buffer": PackedByteArray(),
				"state": "reading_headers",
				"headers_parsed": false,
				"content_length": 0,
				"header_end_index": -1,
			})

	# Process existing connections
	var to_remove: Array[int] = []
	for i in range(_clients.size()):
		var client: Dictionary = _clients[i]
		var peer: StreamPeerTCP = client["peer"]
		peer.poll()

		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			to_remove.append(i)
			continue

		# Read available data
		var available := peer.get_available_bytes()
		if available > 0:
			var data := peer.get_data(mini(available, MAX_REQUEST_SIZE))
			if data[0] == OK:  # error code
				client["buffer"].append_array(data[1])

		# Parse headers if not done yet
		if not client["headers_parsed"]:
			var header_end := _find_header_end(client["buffer"])
			if header_end != -1:
				client["headers_parsed"] = true
				client["header_end_index"] = header_end + 4  # past the \r\n\r\n

				# Extract Content-Length from header string
				var header_bytes: PackedByteArray = client["buffer"].slice(0, header_end)
				var header_str := header_bytes.get_string_from_utf8()
				var lines: PackedStringArray = header_str.split("\r\n")
				for line in lines:
					if line.to_lower().begins_with("content-length:"):
						client["content_length"] = int(line.split(":")[1].strip_edges())
						break
				print(LOG_TAG + "Parsed headers. Content-Length: %d, header_end_index: %d" % [client["content_length"], client["header_end_index"]])

		# Check if we have the full body
		if client["headers_parsed"]:
			var body_received: int = client["buffer"].size() - client["header_end_index"]
			if body_received >= client["content_length"]:
				print(LOG_TAG + "Body fully received: %d/%d bytes. Handling request..." % [body_received, client["content_length"]])
				_handle_request(client)
				to_remove.append(i)
			else:
				# Log waiting once in a while or when more bytes arrive
				if available > 0:
					print(LOG_TAG + "Waiting for body: %d/%d bytes received" % [body_received, client["content_length"]])

	# Clean up disconnected/completed clients (reverse order)
	to_remove.sort()
	to_remove.reverse()
	for idx in to_remove:
		if idx < _clients.size():
			_clients.remove_at(idx)


func _find_header_end(buf: PackedByteArray) -> int:
	var sz := buf.size()
	if sz < 4:
		return -1
	for i in range(sz - 3):
		if buf[i] == 13 and buf[i + 1] == 10 and buf[i + 2] == 13 and buf[i + 3] == 10:
			return i
	return -1


func _handle_request(client: Dictionary) -> void:
	var peer: StreamPeerTCP = client["peer"]
	var header_end: int = client["header_end_index"]
	var buffer: PackedByteArray = client["buffer"]

	# Parse request line from headers
	var header_bytes: PackedByteArray = buffer.slice(0, header_end)
	var header_str: String = header_bytes.get_string_from_utf8()
	var first_line: String = header_str.split("\r\n")[0]
	var parts: PackedStringArray = first_line.split(" ")
	var method: String = parts[0] if parts.size() > 0 else ""
	var path: String = parts[1] if parts.size() > 1 else ""

	# Extract body bytes
	var body := ""
	if header_end < buffer.size():
		var body_bytes: PackedByteArray = buffer.slice(header_end, header_end + client["content_length"] if client["content_length"] > 0 else buffer.size())
		body = body_bytes.get_string_from_utf8()

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

	# Send HTTP response
	var body_bytes: PackedByteArray = response_body.to_utf8_buffer()
	var response_header := "HTTP/1.1 %d %s\r\n" % [status_code, _status_text(status_code)]
	response_header += "Content-Type: application/json; charset=utf-8\r\n"
	response_header += "Content-Length: %d\r\n" % body_bytes.size()
	response_header += "Access-Control-Allow-Origin: *\r\n"
	response_header += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
	response_header += "Access-Control-Allow-Headers: Content-Type\r\n"
	response_header += "Connection: close\r\n"
	response_header += "\r\n"

	var full_response := response_header.to_utf8_buffer()
	full_response.append_array(body_bytes)

	peer.put_data(full_response)
	peer.disconnect_from_host()


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
