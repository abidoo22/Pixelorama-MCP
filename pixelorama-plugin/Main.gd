## pix-MCP Bridge — Main Extension Entry Point
## Uses a dedicated background Thread with non-blocking multiplexed TCP client handling
## (immune to idle browser preconnect sockets, slow readers, and unfocused SceneTree pauses)
## and safely dispatches all Pixelorama commands to the Main Thread via call_deferred + Semaphore.
extends Node

const PORT: int = 7373
const MAX_REQUEST_SIZE: int = 4194304       # 4 MB max request body + headers
const MAX_RESPONSE_CHUNK: int = 65536       # max bytes written per poll via put_partial_data
const MAX_CLIENTS: int = 32                 # max concurrent open TCP sockets
const IDLE_HEADER_TIMEOUT_MS: int = 5000    # drop silent preconnect sockets quickly
const BODY_READ_TIMEOUT_MS: int = 30000     # drop stalled partial request uploads
const SEND_TIMEOUT_MS: int = 15000          # drop stalled/dead response readers

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
	var timed_out: bool = false


func _enter_tree() -> void:
	# Keep extension active even when Pixelorama pauses SceneTree on focus loss
	process_mode = Node.PROCESS_MODE_ALWAYS

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
	print(LOG_TAG + "Thread-safe multiplexed background listener active")


func _server_worker_loop() -> void:
	var clients: Array = []

	while _is_running:
		if not _server.is_listening():
			OS.delay_msec(20)
			continue

		var did_work := false

		# Accept incoming connections; if full, evict oldest silent socket without headers
		while _server.is_connection_available():
			if clients.size() >= MAX_CLIENTS:
				var evicted := false
				for idx in range(clients.size()):
					var candidate: Dictionary = clients[idx]
					if candidate["state"] == "recv" and not candidate["headers_parsed"]:
						var old_peer: StreamPeerTCP = candidate["peer"]
						old_peer.disconnect_from_host()
						clients.remove_at(idx)
						evicted = true
						break
				if not evicted:
					break

			var peer := _server.take_connection()
			if peer:
				peer.set_no_delay(true)
				var now := Time.get_ticks_msec()
				clients.append({
					"peer": peer,
					"buffer": PackedByteArray(),
					"headers_parsed": false,
					"content_length": 0,
					"header_end_index": -1,
					"state": "recv",
					"response": PackedByteArray(),
					"response_sent": 0,
					"connected_at": now,
					"last_active": now,
				})
				did_work = true

		# Poll all active clients non-blockingly and remove completed/stale ones in reverse order
		var now := Time.get_ticks_msec()
		for i in range(clients.size() - 1, -1, -1):
			var client: Dictionary = clients[i]
			var peer: StreamPeerTCP = client["peer"]
			peer.poll()

			var status := peer.get_status()
			if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
				clients.remove_at(i)
				continue
			if status == StreamPeerTCP.STATUS_CONNECTING:
				if now - int(client["connected_at"]) > IDLE_HEADER_TIMEOUT_MS:
					peer.disconnect_from_host()
					clients.remove_at(i)
				continue

			if client["state"] == "respond":
				if _flush_response_chunk(client):
					did_work = true
				var remaining: int = client["response"].size() - int(client["response_sent"])
				if remaining <= 0:
					peer.disconnect_from_host()
					clients.remove_at(i)
					continue
				if now - int(client["last_active"]) > SEND_TIMEOUT_MS:
					peer.disconnect_from_host()
					clients.remove_at(i)
					continue
				continue

			# state == "recv": read available request bytes
			var available := peer.get_available_bytes()
			if available > 0:
				var read_cap := mini(available, MAX_REQUEST_SIZE - client["buffer"].size() + 1)
				if read_cap > 0:
					var data := peer.get_data(read_cap)
					if data[0] == OK and data[1].size() > 0:
						client["buffer"].append_array(data[1])
						client["last_active"] = Time.get_ticks_msec()
						did_work = true

			if client["buffer"].size() > MAX_REQUEST_SIZE:
				_queue_http_response(client, 413, JSON.stringify({"success": false, "error": "Payload too large"}))
				_flush_response_chunk(client)
				if int(client["response_sent"]) >= client["response"].size():
					peer.disconnect_from_host()
					clients.remove_at(i)
				continue

			if not client["headers_parsed"]:
				var header_end := _find_header_end(client["buffer"])
				if header_end != -1:
					client["headers_parsed"] = true
					client["header_end_index"] = header_end + 4

					var header_bytes: PackedByteArray = client["buffer"].slice(0, header_end)
					var header_str := header_bytes.get_string_from_utf8()
					var invalid_cl := false
					for line in header_str.split("\r\n"):
						if line.to_lower().begins_with("content-length:"):
							var cl_str := line.substr(15).strip_edges()
							if not cl_str.is_valid_int():
								invalid_cl = true
							else:
								client["content_length"] = int(cl_str)
								if int(client["content_length"]) < 0:
									invalid_cl = true
							break

					if invalid_cl:
						_queue_http_response(client, 400, JSON.stringify({"success": false, "error": "Invalid Content-Length"}))
						_flush_response_chunk(client)
						if int(client["response_sent"]) >= client["response"].size():
							peer.disconnect_from_host()
							clients.remove_at(i)
						continue

					if int(client["header_end_index"]) + int(client["content_length"]) > MAX_REQUEST_SIZE:
						_queue_http_response(client, 413, JSON.stringify({"success": false, "error": "Payload too large"}))
						_flush_response_chunk(client)
						if int(client["response_sent"]) >= client["response"].size():
							peer.disconnect_from_host()
							clients.remove_at(i)
						continue

			if client["headers_parsed"]:
				var body_received: int = client["buffer"].size() - int(client["header_end_index"])
				if body_received >= int(client["content_length"]):
					_process_http_request(client)
					_flush_response_chunk(client)
					did_work = true
					if int(client["response_sent"]) >= client["response"].size():
						peer.disconnect_from_host()
						clients.remove_at(i)
					continue

			var timeout_limit := BODY_READ_TIMEOUT_MS if bool(client["headers_parsed"]) else IDLE_HEADER_TIMEOUT_MS
			if Time.get_ticks_msec() - int(client["last_active"]) > timeout_limit:
				peer.disconnect_from_host()
				clients.remove_at(i)
				continue

		if not did_work:
			OS.delay_msec(1 if clients.size() > 0 else 2)

	for client in clients:
		var peer: StreamPeerTCP = client["peer"]
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			peer.disconnect_from_host()


func _flush_response_chunk(client: Dictionary) -> bool:
	if client["state"] != "respond":
		return false
	var peer: StreamPeerTCP = client["peer"]
	var response: PackedByteArray = client["response"]
	var sent_so_far: int = int(client["response_sent"])
	var remaining: int = response.size() - sent_so_far
	if remaining <= 0:
		return false
	var chunk_len: int = mini(remaining, MAX_RESPONSE_CHUNK)
	var chunk: PackedByteArray = response.slice(sent_so_far, sent_so_far + chunk_len)
	var res := peer.put_partial_data(chunk)
	if res[0] == OK and int(res[1]) > 0:
		client["response_sent"] = sent_so_far + int(res[1])
		client["last_active"] = Time.get_ticks_msec()
		return true
	return false


func _queue_http_response(client: Dictionary, status_code: int, response_body: String) -> void:
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

	client["response"] = full_response
	client["response_sent"] = 0
	client["state"] = "respond"
	client["last_active"] = Time.get_ticks_msec()


func _find_header_end(buf: PackedByteArray) -> int:
	var sz := buf.size()
	if sz < 4:
		return -1
	for i in range(sz - 3):
		if buf[i] == 13 and buf[i + 1] == 10 and buf[i + 2] == 13 and buf[i + 3] == 10:
			return i
	return -1


func _process_http_request(client: Dictionary) -> void:
	var buffer: PackedByteArray = client["buffer"]
	var header_end: int = int(client["header_end_index"])
	var content_length: int = int(client["content_length"])

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
			"version": "0.2.3",
			"pixelorama_version": _api.general.get_pixelorama_version() if _api else "unknown",
			"api_version": _api.get_api_version() if _api else -1
		}
		response_body = JSON.stringify(health)
		status_code = 200

	elif method == "POST" and path == "/command":
		var result := _dispatch_command_to_main_thread(body)
		response_body = JSON.stringify(result)
		if result.get("success", false):
			status_code = 200
		elif str(result.get("error", "")).find("timed out") != -1:
			status_code = 504
		else:
			status_code = 400

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

	# Free request buffer now that response is built
	client["buffer"] = PackedByteArray()
	_queue_http_response(client, status_code, response_body)


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

	const EXEC_TIMEOUT_MS := 60000
	var start_exec := Time.get_ticks_msec()
	var completed := false
	while _is_running:
		if req.semaphore.try_wait():
			completed = true
			break
		if Time.get_ticks_msec() - start_exec > EXEC_TIMEOUT_MS:
			break
		OS.delay_msec(2)

	if not completed:
		req.timed_out = true
		push_warning(LOG_TAG + "Execution timed out for tool '%s' after %d ms" % [tool_name, EXEC_TIMEOUT_MS])
		return {
			"success": false,
			"error": "Command execution timed out on main thread after %d ms" % EXEC_TIMEOUT_MS
		}

	return req.response


func _execute_on_main_thread(req: PendingRequest) -> void:
	if req.timed_out:
		req.semaphore.post()
		return

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
		413: return "Content Too Large"
		500: return "Internal Server Error"
		504: return "Gateway Timeout"
	return "Unknown"


func _exit_tree() -> void:
	_is_running = false

	if _server.is_listening():
		_server.stop()

	if _thread.is_started():
		_thread.wait_to_finish()

	OS.low_processor_usage_mode = true
	print(LOG_TAG + "HTTP server and background thread stopped")
