## pix-MCP Bridge — Main Extension Entry Point
## Uses a dedicated background Thread for instant TCP socket reception (even when minimized)
## and safely dispatches all Pixelorama commands to the Main Thread via call_deferred + Semaphore
## to prevent any OpenGL / SceneTree threading collisions or crashes.
extends Node

const PORT: int = 7373
const MAX_REQUEST_SIZE: int = 4194304  # 4 MB max request body

var _server: TCPServer = TCPServer.new()
var _thread: Thread = Thread.new()
var _is_running: bool = false
var _api: Node = null
var _command_handler: RefCounted = null

const LOG_TAG: String = "[pix-MCP] "

class PendingRequest extends RefCounted:
	var tool_name: String = ""
	var params: Dictionary = {}
	var response: Dictionary = {}
	var semaphore: Semaphore = Semaphore.new()


func _enter_tree() -> void:
	# Prevent Godot from deep-sleeping when unfocused/minimized
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 1000

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

	_is_running = true
	_thread.start(_server_worker_loop)
	print(LOG_TAG + "Thread-safe background listener active")


func _server_worker_loop() -> void:
	while _is_running:
		if not _server.is_listening():
			OS.delay_msec(20)
			continue

		if _server.is_connection_available():
			var peer := _server.take_connection()
			if peer:
				_handle_peer_connection(peer)
		else:
			OS.delay_msec(2)


func _handle_peer_connection(peer: StreamPeerTCP) -> void:
	var buffer := PackedByteArray()
	var headers_parsed := false
	var content_length := 0
	var header_end_index := -1
	var start_time := Time.get_ticks_msec()
	const TIMEOUT_MS := 10000

	while _is_running and peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		peer.poll()
		var available := peer.get_available_bytes()
		if available > 0:
			var data := peer.get_data(mini(available, MAX_REQUEST_SIZE))
			if data[0] == OK:
				buffer.append_array(data[1])

		if not headers_parsed:
			var header_end := _find_header_end(buffer)
			if header_end != -1:
				headers_parsed = true
				header_end_index = header_end + 4

				var header_bytes := buffer.slice(0, header_end)
				var header_str := header_bytes.get_string_from_utf8()
				var lines := header_str.split("\r\n")
				for line in lines:
					if line.to_lower().begins_with("content-length:"):
						content_length = int(line.split(":")[1].strip_edges())
						break

		if headers_parsed:
			var body_received := buffer.size() - header_end_index
			if body_received >= content_length:
				_process_http_request(peer, buffer, header_end_index, content_length)
				return

		if Time.get_ticks_msec() - start_time > TIMEOUT_MS:
			push_warning(LOG_TAG + "Client request timed out")
			peer.disconnect_from_host()
			return

		OS.delay_msec(1)

	if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		peer.disconnect_from_host()


func _find_header_end(buf: PackedByteArray) -> int:
	var sz := buf.size()
	if sz < 4:
		return -1
	for i in range(sz - 3):
		if buf[i] == 13 and buf[i + 1] == 10 and buf[i + 2] == 13 and buf[i + 3] == 10:
			return i
	return -1


func _process_http_request(peer: StreamPeerTCP, buffer: PackedByteArray, header_end: int, content_length: int) -> void:
	var header_bytes := buffer.slice(0, header_end)
	var header_str := header_bytes.get_string_from_utf8()
	var first_line := header_str.split("\r\n")[0]
	var parts := first_line.split(" ")
	var method: String = parts[0] if parts.size() > 0 else ""
	var path: String = parts[1] if parts.size() > 1 else ""

	var body := ""
	if header_end < buffer.size():
		var body_len: int = content_length if content_length > 0 else (buffer.size() - header_end)
		var body_bytes := buffer.slice(header_end, header_end + body_len)
		body = body_bytes.get_string_from_utf8()

	var response_body: String
	var status_code: int

	if method == "GET" and path == "/health":
		var health := {
			"status": "ok",
			"server": "pix-mcp-bridge",
			"version": "0.2.0",
			"pixelorama_version": _api.general.get_pixelorama_version() if _api else "unknown",
			"api_version": _api.get_api_version() if _api else -1
		}
		response_body = JSON.stringify(health)
		status_code = 200

	elif method == "POST" and path == "/command":
		var result := _dispatch_command_to_main_thread(body)
		response_body = JSON.stringify(result)
		status_code = 200 if result.get("success", false) else 400

	elif method == "GET" and path == "/tools":
		var tools: Array = _command_handler.get_available_tools() if _command_handler else []
		response_body = JSON.stringify({"tools": tools})
		status_code = 200

	elif method == "OPTIONS":
		response_body = ""
		status_code = 204
	else:
		response_body = JSON.stringify({"error": "Not found", "path": path, "method": method})
		status_code = 404

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


func _dispatch_command_to_main_thread(body: String) -> Dictionary:
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

	var req := PendingRequest.new()
	req.tool_name = tool_name
	req.params = params

	call_deferred("_execute_on_main_thread", req)
	req.semaphore.wait()

	return req.response


func _execute_on_main_thread(req: PendingRequest) -> void:
	if _command_handler != null:
		req.response = _command_handler.execute(req.tool_name, req.params)
	else:
		req.response = {"success": false, "error": "Command handler not initialized"}
	req.semaphore.post()


func _status_text(code: int) -> String:
	match code:
		200: return "OK"
		204: return "No Content"
		400: return "Bad Request"
		404: return "Not Found"
		500: return "Internal Server Error"
	return "Unknown"


func _exit_tree() -> void:
	_is_running = false

	if _server.is_listening():
		_server.stop()

	if _thread.is_started():
		_thread.wait_to_finish()

	OS.low_processor_usage_mode = true
	print(LOG_TAG + "HTTP server and background thread stopped")
