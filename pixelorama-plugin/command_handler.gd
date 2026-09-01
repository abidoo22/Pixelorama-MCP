## pix-MCP Command Handler
## Routes incoming tool commands to the appropriate API handler and returns results.
##
## IMPORTANT DESIGN NOTE on image commits:
## We use set_pixelcel_image() which goes through Pixelorama's undo/redo system.
## This is intentional — it means every AI drawing action is undoable by the user.
## For batch operations (draw_pixels), we batch all pixel changes into a single
## commit to keep the undo history clean and performant.
extends RefCounted

var _api: Node = null

const LOG_TAG: String = "[pix-MCP] "

## Map of tool_name -> Callable
var _tool_registry: Dictionary = {}


func initialize(api: Node) -> void:
	_api = api
	_register_tools()


func _register_tools() -> void:
	# Canvas & Project
	_tool_registry["create_canvas"] = Callable(self, "_cmd_create_canvas")
	_tool_registry["get_canvas_info"] = Callable(self, "_cmd_get_canvas_info")
	_tool_registry["list_canvases"] = Callable(self, "_cmd_list_canvases")
	_tool_registry["switch_canvas"] = Callable(self, "_cmd_switch_canvas")
	_tool_registry["close_canvas"] = Callable(self, "_cmd_close_canvas")
	_tool_registry["save_project"] = Callable(self, "_cmd_save_project")
	_tool_registry["export_image"] = Callable(self, "_cmd_export_image")
	_tool_registry["get_canvas_snapshot"] = Callable(self, "_cmd_get_canvas_snapshot")
	_tool_registry["get_canvas_image_base64"] = Callable(self, "_cmd_get_canvas_image_base64")
	_tool_registry["fit_viewport"] = Callable(self, "_cmd_fit_viewport")
	_tool_registry["crop_to_content"] = Callable(self, "_cmd_crop_to_content")
	_tool_registry["scale_canvas"] = Callable(self, "_cmd_scale_canvas")

	# Drawing & Painting & History
	_tool_registry["undo"] = Callable(self, "_cmd_undo")
	_tool_registry["redo"] = Callable(self, "_cmd_redo")
	_tool_registry["draw_pixel"] = Callable(self, "_cmd_draw_pixel")
	_tool_registry["draw_pixels"] = Callable(self, "_cmd_draw_pixels")
	_tool_registry["draw_rect"] = Callable(self, "_cmd_draw_rect")
	_tool_registry["draw_line"] = Callable(self, "_cmd_draw_line")
	_tool_registry["draw_path"] = Callable(self, "_cmd_draw_path")
	_tool_registry["draw_polygon"] = Callable(self, "_cmd_draw_polygon")
	_tool_registry["draw_ellipse"] = Callable(self, "_cmd_draw_ellipse")
	_tool_registry["fill_area"] = Callable(self, "_cmd_fill_area")
	_tool_registry["apply_outline"] = Callable(self, "_cmd_apply_outline")
	_tool_registry["mirror_layer"] = Callable(self, "_cmd_mirror_layer")
	_tool_registry["transform_cel"] = Callable(self, "_cmd_transform_cel")
	_tool_registry["rotate_cel"] = Callable(self, "_cmd_rotate_cel")

	# Inspection
	_tool_registry["get_pixel"] = Callable(self, "_cmd_get_pixel")
	_tool_registry["get_pixels"] = Callable(self, "_cmd_get_pixels")
	_tool_registry["get_region"] = Callable(self, "_cmd_get_region")

	# Colour
	_tool_registry["set_color"] = Callable(self, "_cmd_set_color")
	_tool_registry["get_color"] = Callable(self, "_cmd_get_color")
	_tool_registry["color_replace"] = Callable(self, "_cmd_color_replace")
	_tool_registry["adjust_hsv"] = Callable(self, "_cmd_adjust_hsv")

	# Layers
	_tool_registry["add_layer"] = Callable(self, "_cmd_add_layer")
	_tool_registry["delete_layer"] = Callable(self, "_cmd_delete_layer")
	_tool_registry["get_layers"] = Callable(self, "_cmd_get_layers")
	_tool_registry["set_layer_opacity"] = Callable(self, "_cmd_set_layer_opacity")
	_tool_registry["set_layer_blend_mode"] = Callable(self, "_cmd_set_layer_blend_mode")
	_tool_registry["set_layer_visibility"] = Callable(self, "_cmd_set_layer_visibility")
	_tool_registry["set_layer_name"] = Callable(self, "_cmd_set_layer_name")
	_tool_registry["reorder_layers"] = Callable(self, "_cmd_reorder_layers")

	# Frames & Animation
	_tool_registry["add_frame"] = Callable(self, "_cmd_add_frame")
	_tool_registry["delete_frame"] = Callable(self, "_cmd_delete_frame")
	_tool_registry["duplicate_frame"] = Callable(self, "_cmd_duplicate_frame")
	_tool_registry["set_frame_duration"] = Callable(self, "_cmd_set_frame_duration")
	_tool_registry["switch_frame"] = Callable(self, "_cmd_switch_frame")
	_tool_registry["get_frames"] = Callable(self, "_cmd_get_frames")
	_tool_registry["get_fps"] = Callable(self, "_cmd_get_fps")
	_tool_registry["set_fps"] = Callable(self, "_cmd_set_fps")
	_tool_registry["switch_cel"] = Callable(self, "_cmd_switch_cel")
	_tool_registry["copy_cel"] = Callable(self, "_cmd_copy_cel")
	_tool_registry["clear_cel"] = Callable(self, "_cmd_clear_cel")
	_tool_registry["export_animation"] = Callable(self, "_cmd_export_animation")

	# Selection
	_tool_registry["select_rect"] = Callable(self, "_cmd_select_rect")
	_tool_registry["select_all"] = Callable(self, "_cmd_select_all")
	_tool_registry["deselect"] = Callable(self, "_cmd_deselect")

	# Palette
	_tool_registry["get_palette_colors"] = Callable(self, "_cmd_get_palette_colors")
	_tool_registry["create_palette"] = Callable(self, "_cmd_create_palette")
	_tool_registry["add_palette_color"] = Callable(self, "_cmd_add_palette_color")
	_tool_registry["set_palette_color"] = Callable(self, "_cmd_set_palette_color")

	print(LOG_TAG + "Registered %d tools" % _tool_registry.size())


func get_available_tools() -> Array:
	var tools: Array = []
	for tool_name in _tool_registry.keys():
		tools.append(tool_name)
	return tools


func execute(tool_name: String, params: Dictionary) -> Dictionary:
	if not _tool_registry.has(tool_name):
		return {"success": false, "error": "Unknown tool: %s" % tool_name}

	print(LOG_TAG + "Executing: %s" % tool_name)
	var callable: Callable = _tool_registry[tool_name]
	return callable.call(params)


# ─────────────────────────────────────────────
# SHARED HELPERS
# ─────────────────────────────────────────────

func _get_current_cel():
	var project = _api.project.current_project
	if project == null:
		return null
	return _api.project.get_current_cel()


func _get_current_image() -> Image:
	var cel = _get_current_cel()
	if cel == null or cel.get_class_name() != "PixelCel":
		return null
	return cel.get_image()


func _get_target_cel_and_image(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"error": "No active project", "image": null, "frame": 0, "layer": 0}

	var frame_idx: int = int(params.get("frame", project.current_frame))
	var layer_idx: int = int(params.get("layer", project.current_layer))

	if frame_idx < 0 or frame_idx >= project.frames.size():
		return {"error": "Frame index out of bounds: %d (0..%d)" % [frame_idx, project.frames.size() - 1], "image": null, "frame": frame_idx, "layer": layer_idx}
	if layer_idx < 0 or layer_idx >= project.layers.size():
		return {"error": "Layer index out of bounds: %d (0..%d)" % [layer_idx, project.layers.size() - 1], "image": null, "frame": frame_idx, "layer": layer_idx}

	var cel = project.frames[frame_idx].cels[layer_idx]
	if cel == null or cel.get_class_name() != "PixelCel":
		return {"error": "Cel at [frame:%d, layer:%d] is not a PixelCel" % [frame_idx, layer_idx], "image": null, "frame": frame_idx, "layer": layer_idx}

	return {"error": "", "image": cel.get_image(), "frame": frame_idx, "layer": layer_idx, "cel": cel}


func _commit_image_change(image: Image, _action_name: String, frame_idx: int = -1, layer_idx: int = -1) -> void:
	## Commits the modified image through Pixelorama's undo system.
	## This ensures every AI action is undoable by the user.
	var project = _api.project.current_project
	if project == null:
		return

	if frame_idx < 0:
		frame_idx = project.current_frame
	if layer_idx < 0:
		layer_idx = project.current_layer

	# 1. Duplicate the image to force a new object reference in Godot,
	# which ensures Pixelorama's caches detect the change and update the canvas.
	var dup_image := image.duplicate()
	_api.project.set_pixelcel_image(
		dup_image,
		frame_idx,
		layer_idx
	)

	# 2. Programmatically select the current cel to trigger a switch/refresh signal
	_api.project.select_cels([[frame_idx, layer_idx]])

	# 3. Request redraw on the main canvas (necessary in Pixelorama v1.1.9+ as it doesn't continuously redraw when idle)
	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.queue_redraw()
		if canvas.has_method("update_texture"):
			canvas.update_texture(layer_idx)


func _parse_color(params: Dictionary, key: String = "color", default_color: Color = Color.BLACK) -> Color:
	var color_val = params.get(key, "")
	if color_val is String and color_val != "":
		if Color.html_is_valid(color_val):
			return Color.html(color_val)
		else:
			push_warning(LOG_TAG + "Invalid color hex: '%s', using default" % color_val)
			return default_color
	return default_color


# ─────────────────────────────────────────────
# CANVAS & PROJECT COMMANDS
# ─────────────────────────────────────────────

func _cmd_create_canvas(params: Dictionary) -> Dictionary:
	var width: int = params.get("width", 64)
	var height: int = params.get("height", 64)
	var name: String = params.get("name", "untitled")
	var fill_color_hex: String = params.get("fill_color", "")

	# Validate dimensions
	if width <= 0 or width > 4096 or height <= 0 or height > 4096:
		return {"success": false, "error": "Invalid dimensions: %dx%d (must be 1-4096)" % [width, height]}

	var fill_color := Color.TRANSPARENT
	if fill_color_hex != "" and Color.html_is_valid(fill_color_hex):
		fill_color = Color.html(fill_color_hex)

	var frames: Array = []
	var frame_script = load("res://src/Classes/Frame.gd")
	if frame_script:
		frames = Array([], TYPE_OBJECT, "RefCounted", frame_script)

	var project = _api.project.new_project(
		frames,
		name,
		Vector2(width, height),
		fill_color
	)

	if project:
		_api.project.current_project = project
		return {
			"success": true,
			"data": {
				"name": name,
				"width": width,
				"height": height,
				"message": "Canvas created: %dx%d" % [width, height]
			}
		}
	return {"success": false, "error": "Failed to create canvas"}


func _cmd_get_canvas_info(_params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	return {
		"success": true,
		"data": {
			"name": project.name,
			"width": project.size.x,
			"height": project.size.y,
			"layers": project.layers.size(),
			"frames": project.frames.size(),
			"current_frame": project.current_frame,
			"current_layer": project.current_layer,
		}
	}


func _cmd_list_canvases(_params: Dictionary) -> Dictionary:
	var global = _api.get_node_or_null("/root/Global")
	var projects_list: Array = []
	var active_index: int = 0

	if global and "projects" in global:
		if "current_project_index" in global:
			active_index = int(global.current_project_index)
		var projects_arr: Array = global.projects
		for i in range(projects_arr.size()):
			var p = projects_arr[i]
			if p:
				projects_list.append({
					"index": i,
					"name": p.name,
					"width": int(p.size.x),
					"height": int(p.size.y),
					"layers": p.layers.size(),
					"frames": p.frames.size(),
					"save_path": p.save_path,
					"has_unsaved_changes": p.has_changed if "has_changed" in p else false,
					"is_active": (i == active_index)
				})
	elif _api.project.current_project:
		var p = _api.project.current_project
		projects_list.append({
			"index": 0,
			"name": p.name,
			"width": int(p.size.x),
			"height": int(p.size.y),
			"layers": p.layers.size(),
			"frames": p.frames.size(),
			"save_path": p.save_path,
			"has_unsaved_changes": p.has_changed if "has_changed" in p else false,
			"is_active": true
		})

	return {
		"success": true,
		"data": {
			"total_canvases": projects_list.size(),
			"active_index": active_index,
			"canvases": projects_list
		}
	}


func _cmd_switch_canvas(params: Dictionary) -> Dictionary:
	var target_index: int = int(params.get("index", 0))
	var global = _api.get_node_or_null("/root/Global")

	if global and "projects" in global:
		var projects_arr: Array = global.projects
		if target_index < 0 or target_index >= projects_arr.size():
			return {
				"success": false,
				"error": "Canvas index %d out of bounds (0..%d)" % [target_index, max(0, projects_arr.size() - 1)]
			}

		if "tabs" in global and global.tabs:
			global.tabs.current_tab = target_index
		else:
			global.current_project_index = target_index
			_api.project.current_project = projects_arr[target_index]

		var active_p = projects_arr[target_index]
		return {
			"success": true,
			"data": {
				"active_index": target_index,
				"name": active_p.name,
				"width": int(active_p.size.x),
				"height": int(active_p.size.y),
				"message": "Switched to canvas [%d] '%s'" % [target_index, active_p.name]
			}
		}
	elif _api.project.current_project:
		if target_index == 0:
			var p = _api.project.current_project
			return {
				"success": true,
				"data": {
					"active_index": 0,
					"name": p.name,
					"width": int(p.size.x),
					"height": int(p.size.y),
					"message": "Already on active canvas [0]"
				}
			}
		return {"success": false, "error": "Canvas index out of bounds: only 1 canvas open"}

	return {"success": false, "error": "No open canvases"}


func _cmd_close_canvas(params: Dictionary) -> Dictionary:
	var global = _api.get_node_or_null("/root/Global")
	if not global or not ("projects" in global):
		return {"success": false, "error": "Global project manager not accessible"}

	var projects_arr: Array = global.projects
	if projects_arr.is_empty():
		return {"success": false, "error": "No open canvases to close"}

	var cur_idx: int = int(global.current_project_index) if "current_project_index" in global else 0
	var target_index: int = int(params.get("index", cur_idx))
	if target_index < 0 or target_index >= projects_arr.size():
		return {
			"success": false,
			"error": "Canvas index %d out of bounds (0..%d)" % [target_index, projects_arr.size() - 1]
		}

	var closed_name = projects_arr[target_index].name

	if "tabs" in global and global.tabs:
		if global.tabs.has_method("tab_close"):
			global.tabs.tab_close(target_index)
		elif global.has_method("close_project"):
			global.close_project(target_index)
		else:
			projects_arr.remove_at(target_index)
			if projects_arr.is_empty():
				var fallback_frames: Array = []
				var fallback_frame_script = load("res://src/Classes/Frame.gd")
				if fallback_frame_script:
					fallback_frames = Array([], TYPE_OBJECT, "RefCounted", fallback_frame_script)
				_api.project.new_project(fallback_frames, "untitled", Vector2(64, 64), Color.TRANSPARENT)
			else:
				var next_index = clampi(target_index, 0, projects_arr.size() - 1)
				global.tabs.current_tab = next_index
	else:
		projects_arr.remove_at(target_index)
		if projects_arr.is_empty():
			var fallback_frames: Array = []
			var fallback_frame_script = load("res://src/Classes/Frame.gd")
			if fallback_frame_script:
				fallback_frames = Array([], TYPE_OBJECT, "RefCounted", fallback_frame_script)
			_api.project.new_project(fallback_frames, "untitled", Vector2(64, 64), Color.TRANSPARENT)
		else:
			var next_index = clampi(target_index, 0, projects_arr.size() - 1)
			_api.project.current_project = projects_arr[next_index]

	var remaining_count: int = global.projects.size()
	var new_active_index: int = int(global.current_project_index) if "current_project_index" in global else 0

	return {
		"success": true,
		"data": {
			"closed_index": target_index,
			"closed_name": closed_name,
			"remaining_canvases": remaining_count,
			"active_index": new_active_index,
			"message": "Closed canvas [%d] '%s'" % [target_index, closed_name]
		}
	}


func _cmd_get_canvas_snapshot(params: Dictionary) -> Dictionary:
	## Returns pixel data for a region of the canvas as a compact text map.
	## Useful for AI to "see" what's currently drawn and make decisions.
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var image := _get_current_image()
	if image == null:
		return {"success": false, "error": "No active pixel cel"}

	var x: int = params.get("x", 0)
	var y: int = params.get("y", 0)
	var width: int = params.get("width", mini(image.get_width(), 64))
	var height: int = params.get("height", mini(image.get_height(), 64))

	# Clamp to canvas bounds
	x = clampi(x, 0, image.get_width() - 1)
	y = clampi(y, 0, image.get_height() - 1)
	width = mini(width, image.get_width() - x)
	height = mini(height, image.get_height() - y)

	# Build a compact color map — unique colors indexed, then a grid of indices
	var color_map: Dictionary = {}
	var color_list: Array = []
	var grid: Array = []

	for py in range(y, y + height):
		var row: Array = []
		for px in range(x, x + width):
			var c := image.get_pixel(px, py)
			var hex := c.to_html()
			if not color_map.has(hex):
				color_map[hex] = color_list.size()
				color_list.append(hex)
			row.append(color_map[hex])
		grid.append(row)

	return {
		"success": true,
		"data": {
			"x": x,
			"y": y,
			"width": width,
			"height": height,
			"colors": color_list,
			"grid": grid,
		}
	}


func _cmd_save_project(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var target_path: String = params.get("path", "")
	if target_path != "":
		project.save_path = target_path

	var open_save = _api.import.open_save_autoload()
	if project.save_path != "":
		open_save.save_pxo(project.save_path)
		return {"success": true, "data": {"path": project.save_path}}
	else:
		return {"success": false, "error": "No save path set. Use Pixelorama's File > Save As first or specify 'path'."}


func _cmd_export_image(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return {"success": false, "error": "Missing 'path' parameter"}

	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var frame_idx: int = params.get("frame", 0)
	if frame_idx >= project.frames.size():
		return {"success": false, "error": "Frame index %d out of range (0-%d)" % [frame_idx, project.frames.size() - 1]}

	var dir_name := path.get_base_dir()
	if dir_name != "" and not DirAccess.dir_exists_absolute(dir_name):
		DirAccess.make_dir_recursive_absolute(dir_name)

	# Use Pixelorama's DrawingAlgos to properly blend all visible layers
	var drawing_algos = _api.general.get_drawing_algos()
	var img := Image.create(int(project.size.x), int(project.size.y), false, Image.FORMAT_RGBA8)
	var frame = project.frames[frame_idx]
	drawing_algos.blend_layers(img, frame, Vector2i.ZERO, project)

	var err := img.save_png(path)
	if err == OK:
		return {"success": true, "data": {"path": path, "format": "png"}}
	return {"success": false, "error": "Failed to save image: %s" % error_string(err)}


func _cmd_fit_viewport(_params: Dictionary) -> Dictionary:
	var canvas = _api.general.get_canvas()
	if canvas:
		var camera = canvas.get("camera")
		if camera and camera.has_method("fit_to_frame"):
			camera.fit_to_frame()
		elif canvas.has_node("Camera2D"):
			var cam = canvas.get_node("Camera2D")
			if cam.has_method("fit_to_frame"):
				cam.fit_to_frame()
		canvas.queue_redraw()
	return {"success": true, "data": {"message": "Viewport centered and fitted to canvas"}}


func _cmd_get_canvas_image_base64(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var frame_idx: int = params.get("frame", project.current_frame)
	if frame_idx < 0 or frame_idx >= project.frames.size():
		return {"success": false, "error": "Frame index out of bounds"}

	var drawing_algos = _api.general.get_drawing_algos()
	var w := int(project.size.x)
	var h := int(project.size.y)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var frame = project.frames[frame_idx]
	drawing_algos.blend_layers(img, frame, Vector2i.ZERO, project)

	var png_buffer := img.save_png_to_buffer()
	var b64 := Marshalls.raw_to_base64(png_buffer)
	return {
		"success": true,
		"data": {
			"base64": b64,
			"width": w,
			"height": h,
			"frame": frame_idx
		}
	}


func _cmd_crop_to_content(_params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var min_x := 999999
	var min_y := 999999
	var max_x := -1
	var max_y := -1
	var w := int(project.size.x)
	var h := int(project.size.y)

	for f in project.frames:
		for cel in f.cels:
			if cel.get_class_name() == "PixelCel":
				var img: Image = cel.get_image()
				for y in range(h):
					for x in range(w):
						if img.get_pixel(x, y).a > 0.01:
							min_x = mini(min_x, x)
							min_y = mini(min_y, y)
							max_x = maxi(max_x, x)
							max_y = maxi(max_y, y)

	if max_x == -1:
		return {"success": false, "error": "Canvas is completely empty"}

	var new_w := max_x - min_x + 1
	var new_h := max_y - min_y + 1
	var crop_rect := Rect2i(min_x, min_y, new_w, new_h)

	for f in project.frames:
		for cel in f.cels:
			if cel.get_class_name() == "PixelCel":
				var old_img: Image = cel.get_image()
				var cropped_img := Image.create(new_w, new_h, false, Image.FORMAT_RGBA8)
				cropped_img.blit_rect(old_img, crop_rect, Vector2i.ZERO)
				cel.set_image(cropped_img)

	project.size = Vector2i(new_w, new_h)
	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.queue_redraw()
		var cam = canvas.get("camera")
		if cam and cam.has_method("fit_to_frame"):
			cam.fit_to_frame()

	return {"success": true, "data": {"original_size": [w, h], "new_size": [new_w, new_h], "crop_rect": [min_x, min_y, new_w, new_h]}}


func _cmd_scale_canvas(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var factor: int = int(params.get("factor", 0))
	var target_w: int = int(params.get("width", 0))
	var target_h: int = int(params.get("height", 0))
	var interpolation: int = Image.INTERPOLATE_NEAREST

	var old_w := int(project.size.x)
	var old_h := int(project.size.y)
	var new_w := old_w
	var new_h := old_h

	if factor > 0:
		new_w = old_w * factor
		new_h = old_h * factor
	elif target_w > 0 and target_h > 0:
		new_w = target_w
		new_h = target_h
	else:
		return {"success": false, "error": "Provide either 'factor' (> 0) or 'width' and 'height'"}

	for f in project.frames:
		for cel in f.cels:
			if cel.get_class_name() == "PixelCel":
				var img: Image = cel.get_image()
				img.resize(new_w, new_h, interpolation)

	project.size = Vector2i(new_w, new_h)
	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.queue_redraw()
		var cam = canvas.get("camera")
		if cam and cam.has_method("fit_to_frame"):
			cam.fit_to_frame()

	return {"success": true, "data": {"original_size": [old_w, old_h], "new_size": [new_w, new_h]}}




func _get_undo_redo() -> Object:
	var project = _api.project.current_project
	if project:
		if "undo_redo" in project and project.undo_redo != null:
			return project.undo_redo
	var global = _api.general.get_global()
	if global:
		if "undo_redo" in global and global.undo_redo != null:
			return global.undo_redo
		if "current_project" in global and global.current_project != null:
			if "undo_redo" in global.current_project and global.current_project.undo_redo != null:
				return global.current_project.undo_redo
	return null


func _cmd_undo(_params: Dictionary) -> Dictionary:
	var ur = _get_undo_redo()
	if ur != null:
		if ur.has_undo():
			var action_name: String = ur.get_current_action_name()
			ur.undo()
			var canvas = _api.general.get_canvas()
			if canvas:
				canvas.queue_redraw()
			return {"success": true, "data": {"message": "Undone: %s" % action_name, "action": action_name}}
		else:
			return {"success": false, "error": "Nothing to undo"}
	return {"success": false, "error": "UndoRedo system not available"}


func _cmd_redo(_params: Dictionary) -> Dictionary:
	var ur = _get_undo_redo()
	if ur != null:
		if ur.has_redo():
			ur.redo()
			var canvas = _api.general.get_canvas()
			if canvas:
				canvas.queue_redraw()
			return {"success": true, "data": {"message": "Redone action"}}
		else:
			return {"success": false, "error": "Nothing to redo"}
	return {"success": false, "error": "UndoRedo system not available"}

func _cmd_draw_pixel(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var image: Image = target.image
	var x: int = int(params.get("x", 0))
	var y: int = int(params.get("y", 0))
	var color := _parse_color(params)

	if x < 0 or x >= image.get_width() or y < 0 or y >= image.get_height():
		return {
			"success": true,
			"data": {
				"x": x,
				"y": y,
				"color": color.to_html(),
				"pixels_drawn": 0,
				"pixels_clipped": 1,
				"frame": target.frame,
				"layer": target.layer
			}
		}

	image.set_pixel(x, y, color)
	_commit_image_change(image, "Draw Pixel", target.frame, target.layer)
	return {
		"success": true,
		"data": {
			"x": x,
			"y": y,
			"color": color.to_html(),
			"pixels_drawn": 1,
			"pixels_clipped": 0,
			"frame": target.frame,
			"layer": target.layer
		}
	}


func _cmd_draw_pixels(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var pixels: Array = params.get("pixels", [])
	if pixels.is_empty():
		return {"success": false, "error": "Missing or empty 'pixels' array"}

	var image: Image = target.image
	var w := image.get_width()
	var h := image.get_height()
	var drawn := 0
	var skipped := 0
	var color_cache := {}

	for pixel in pixels:
		if not pixel is Dictionary:
			skipped += 1
			continue
		var x: int = int(pixel.get("x", -1))
		var y: int = int(pixel.get("y", -1))
		if x < 0 or x >= w or y < 0 or y >= h:
			skipped += 1
			continue

		var color_str: String = str(pixel.get("color", ""))
		var color: Color
		if color_cache.has(color_str):
			color = color_cache[color_str]
		else:
			color = _parse_color(pixel)
			color_cache[color_str] = color

		image.set_pixel(x, y, color)
		drawn += 1

	_commit_image_change(image, "Draw Pixels (batch)", target.frame, target.layer)
	return {
		"success": true,
		"data": {
			"drawn": drawn,
			"skipped": skipped,
			"pixels_drawn": drawn,
			"pixels_clipped": skipped,
			"total": pixels.size(),
			"frame": target.frame,
			"layer": target.layer
		}
	}


func _cmd_draw_rect(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var image: Image = target.image
	var x: int = int(params.get("x", 0))
	var y: int = int(params.get("y", 0))
	var width: int = int(params.get("width", 1))
	var height: int = int(params.get("height", 1))
	var filled: bool = bool(params.get("filled", true))
	var color := _parse_color(params)

	var img_w := image.get_width()
	var img_h := image.get_height()
	var drawn := 0
	var total := 0

	if filled:
		total = width * height
		var clamped := Rect2i(x, y, width, height).intersection(Rect2i(0, 0, img_w, img_h))
		if clamped.has_area():
			image.fill_rect(clamped, color)
			drawn = clamped.get_area()
	else:
		total = width * 2 + maxi(0, height - 2) * 2
		for px in range(x, x + width):
			if px >= 0 and px < img_w:
				if y >= 0 and y < img_h:
					image.set_pixel(px, y, color)
					drawn += 1
				var bot := y + height - 1
				if bot >= 0 and bot < img_h and height > 1:
					image.set_pixel(px, bot, color)
					drawn += 1
		for py in range(y + 1, y + height - 1):
			if py >= 0 and py < img_h:
				if x >= 0 and x < img_w:
					image.set_pixel(x, py, color)
					drawn += 1
				var right := x + width - 1
				if right >= 0 and right < img_w and width > 1:
					image.set_pixel(right, py, color)
					drawn += 1

	_commit_image_change(image, "Draw Rectangle", target.frame, target.layer)
	return {
		"success": true,
		"data": {
			"x": x,
			"y": y,
			"width": width,
			"height": height,
			"filled": filled,
			"pixels_drawn": drawn,
			"pixels_clipped": maxi(0, total - drawn),
			"frame": target.frame,
			"layer": target.layer
		}
	}


func _cmd_draw_line(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var image: Image = target.image
	var x1: int = int(params.get("x1", 0))
	var y1: int = int(params.get("y1", 0))
	var x2: int = int(params.get("x2", 0))
	var y2: int = int(params.get("y2", 0))
	var color := _parse_color(params)

	var res := _draw_line_on_image(image, x1, y1, x2, y2, color)
	_commit_image_change(image, "Draw Line", target.frame, target.layer)
	return {
		"success": true,
		"data": {
			"x1": x1,
			"y1": y1,
			"x2": x2,
			"y2": y2,
			"pixels_drawn": res.drawn,
			"pixels_clipped": res.clipped,
			"frame": target.frame,
			"layer": target.layer
		}
	}


func _draw_line_on_image(image: Image, x1: int, y1: int, x2: int, y2: int, color: Color) -> Dictionary:
	var dx := absi(x2 - x1)
	var dy := -absi(y2 - y1)
	var sx := 1 if x1 < x2 else -1
	var sy := 1 if y1 < y2 else -1
	var err := dx + dy
	var cx := x1
	var cy := y1
	var drawn := 0
	var clipped := 0

	while true:
		if cx >= 0 and cx < image.get_width() and cy >= 0 and cy < image.get_height():
			image.set_pixel(cx, cy, color)
			drawn += 1
		else:
			clipped += 1
		if cx == x2 and cy == y2:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			cx += sx
		if e2 <= dx:
			err += dx
			cy += sy
	return {"drawn": drawn, "clipped": clipped}


func _cmd_draw_path(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var points: Array = params.get("points", [])
	if points.size() < 2:
		return {"success": false, "error": "Path requires at least 2 points"}
	var closed: bool = bool(params.get("closed", false))
	var color := _parse_color(params)
	var image: Image = target.image

	var drawn := 0
	var clipped := 0
	for i in range(points.size() - 1):
		var res := _draw_line_on_image(image, int(points[i].x), int(points[i].y), int(points[i+1].x), int(points[i+1].y), color)
		drawn += res.drawn
		clipped += res.clipped

	if closed and points.size() > 2:
		var res := _draw_line_on_image(image, int(points[-1].x), int(points[-1].y), int(points[0].x), int(points[0].y), color)
		drawn += res.drawn
		clipped += res.clipped

	_commit_image_change(image, "Draw Path", target.frame, target.layer)
	return {
		"success": true,
		"data": {
			"points": points.size(),
			"closed": closed,
			"pixels_drawn": drawn,
			"pixels_clipped": clipped,
			"frame": target.frame,
			"layer": target.layer
		}
	}


func _cmd_draw_polygon(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var points_array: Array = params.get("points", [])
	if points_array.size() < 3:
		return {"success": false, "error": "Polygon requires at least 3 points"}

	var points := PackedVector2Array()
	var min_x := 999999
	var max_x := -999999
	var min_y := 999999
	var max_y := -999999
	for p in points_array:
		var x = int(p.get("x", 0))
		var y = int(p.get("y", 0))
		points.append(Vector2(x, y))
		min_x = mini(min_x, x)
		max_x = maxi(max_x, x)
		min_y = mini(min_y, y)
		max_y = maxi(max_y, y)

	var filled: bool = bool(params.get("filled", true))
	var color := _parse_color(params)
	var image: Image = target.image

	var drawn := 0
	var clipped := 0
	var w := image.get_width()
	var h := image.get_height()

	if filled:
		for py in range(min_y, max_y + 1):
			for px in range(min_x, max_x + 1):
				if Geometry2D.is_point_in_polygon(Vector2(px, py), points):
					if px >= 0 and px < w and py >= 0 and py < h:
						image.set_pixel(px, py, color)
						drawn += 1
					else:
						clipped += 1
	else:
		for i in range(points.size() - 1):
			var res := _draw_line_on_image(image, int(points[i].x), int(points[i].y), int(points[i+1].x), int(points[i+1].y), color)
			drawn += res.drawn
			clipped += res.clipped
		var res := _draw_line_on_image(image, int(points[-1].x), int(points[-1].y), int(points[0].x), int(points[0].y), color)
		drawn += res.drawn
		clipped += res.clipped

	_commit_image_change(image, "Draw Polygon", target.frame, target.layer)
	return {
		"success": true,
		"data": {
			"points": points.size(),
			"filled": filled,
			"pixels_drawn": drawn,
			"pixels_clipped": clipped,
			"frame": target.frame,
			"layer": target.layer
		}
	}


func _cmd_draw_ellipse(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var image: Image = target.image
	var cx: int = int(params.get("cx", 0))
	var cy: int = int(params.get("cy", 0))
	var rx: int = int(params.get("rx", 1))
	var ry: int = int(params.get("ry", 1))
	var filled: bool = bool(params.get("filled", true))
	var color := _parse_color(params)

	var img_w := image.get_width()
	var img_h := image.get_height()
	var drawn := 0
	var clipped := 0

	if filled:
		for py in range(cy - ry, cy + ry + 1):
			for px in range(cx - rx, cx + rx + 1):
				var nx: float = float(px - cx) / float(rx) if rx > 0 else 0.0
				var ny: float = float(py - cy) / float(ry) if ry > 0 else 0.0
				if nx * nx + ny * ny <= 1.0:
					if px >= 0 and px < img_w and py >= 0 and py < img_h:
						image.set_pixel(px, py, color)
						drawn += 1
					else:
						clipped += 1
	else:
		var steps := maxi(maxi(rx, ry) * 8, 32)
		for i in range(steps):
			var angle := (float(i) / float(steps)) * TAU
			var px := cx + roundi(float(rx) * cos(angle))
			var py := cy + roundi(float(ry) * sin(angle))
			if px >= 0 and px < img_w and py >= 0 and py < img_h:
				image.set_pixel(px, py, color)
				drawn += 1
			else:
				clipped += 1

	_commit_image_change(image, "Draw Ellipse", target.frame, target.layer)
	return {
		"success": true,
		"data": {
			"cx": cx,
			"cy": cy,
			"rx": rx,
			"ry": ry,
			"filled": filled,
			"pixels_drawn": drawn,
			"pixels_clipped": clipped,
			"frame": target.frame,
			"layer": target.layer
		}
	}
func _cmd_fill_area(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var x: int = int(params.get("x", 0))
	var y: int = int(params.get("y", 0))
	var color := _parse_color(params)
	var image: Image = target.image

	var w := image.get_width()
	var h := image.get_height()

	if x < 0 or x >= w or y < 0 or y >= h:
		return {"success": false, "error": "Seed point (%d, %d) out of bounds (%dx%d)" % [x, y, w, h]}

	var target_color := image.get_pixel(x, y)
	if target_color.is_equal_approx(color):
		return {"success": true, "data": {"message": "Fill color same as target, no change", "pixels_filled": 0, "frame": target.frame, "layer": target.layer}}

	var filled_count := 0
	var stack: Array[Vector2i] = [Vector2i(x, y)]
	var visited := PackedByteArray()
	visited.resize(w * h)
	visited.fill(0)

	while stack.size() > 0:
		var pos: Vector2i = stack.pop_back()
		var px: int = pos.x
		var py: int = pos.y

		if px < 0 or px >= w or py < 0 or py >= h:
			continue

		var idx: int = py * w + px
		if visited[idx] == 1:
			continue
		visited[idx] = 1

		if not image.get_pixel(px, py).is_equal_approx(target_color):
			continue

		# Scan left
		var left: int = px
		while left > 0 and image.get_pixel(left - 1, py).is_equal_approx(target_color):
			left -= 1
			visited[py * w + left] = 1

		# Scan right
		var right: int = px
		while right < w - 1 and image.get_pixel(right + 1, py).is_equal_approx(target_color):
			right += 1
			visited[py * w + right] = 1

		# Fill the scanline
		for fill_x in range(left, right + 1):
			image.set_pixel(fill_x, py, color)
			filled_count += 1
			if py > 0:
				var up_idx: int = (py - 1) * w + fill_x
				if visited[up_idx] == 0:
					stack.append(Vector2i(fill_x, py - 1))
			if py < h - 1:
				var down_idx: int = (py + 1) * w + fill_x
				if visited[down_idx] == 0:
					stack.append(Vector2i(fill_x, py + 1))

	_commit_image_change(image, "Fill Area", target.frame, target.layer)
	return {"success": true, "data": {"x": x, "y": y, "pixels_filled": filled_count, "frame": target.frame, "layer": target.layer}}


func _cmd_apply_outline(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var image: Image = target.image
	var color := _parse_color(params, "color", Color.BLACK)
	var thickness: int = int(params.get("thickness", 1))
	thickness = clampi(thickness, 1, 4)
	var inside: bool = bool(params.get("inside", false))

	var w := image.get_width()
	var h := image.get_height()
	var outlined_img := image.duplicate()
	var count := 0

	for y in range(h):
		for x in range(w):
			var current_alpha := image.get_pixel(x, y).a
			if inside:
				if current_alpha > 0.1:
					var is_border := false
					for dy in range(-thickness, thickness + 1):
						for dx in range(-thickness, thickness + 1):
							if dx == 0 and dy == 0:
								continue
							var nx := x + dx
							var ny := y + dy
							if nx < 0 or nx >= w or ny < 0 or ny >= h or image.get_pixel(nx, ny).a <= 0.1:
								is_border = true
								break
						if is_border:
							break
					if is_border:
						outlined_img.set_pixel(x, y, color)
						count += 1
			else:
				if current_alpha <= 0.1:
					var is_border := false
					for dy in range(-thickness, thickness + 1):
						for dx in range(-thickness, thickness + 1):
							if dx == 0 and dy == 0:
								continue
							var nx := x + dx
							var ny := y + dy
							if nx >= 0 and nx < w and ny >= 0 and ny < h and image.get_pixel(nx, ny).a > 0.1:
								is_border = true
								break
						if is_border:
							break
					if is_border:
						outlined_img.set_pixel(x, y, color)
						count += 1

	_commit_image_change(outlined_img, "Apply Outline", target.frame, target.layer)
	return {"success": true, "data": {"outline_pixels": count, "color": color.to_html(), "thickness": thickness, "inside": inside, "frame": target.frame, "layer": target.layer}}


func _cmd_mirror_layer(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var image: Image = target.image
	var axis: String = str(params.get("axis", "horizontal"))
	var mode: String = str(params.get("mode", "flip"))
	var w := image.get_width()
	var h := image.get_height()
	var new_img := image.duplicate()

	if mode == "mirror_left_to_right":
		var half_w := w / 2
		for y in range(h):
			for x in range(half_w):
				var px = image.get_pixel(x, y)
				new_img.set_pixel(w - 1 - x, y, px)
	elif mode == "mirror_right_to_left":
		var half_w := w / 2
		for y in range(h):
			for x in range(half_w):
				var px = image.get_pixel(w - 1 - x, y)
				new_img.set_pixel(x, y, px)
	elif mode == "mirror_top_to_bottom":
		var half_h := h / 2
		for y in range(half_h):
			for x in range(w):
				var px = image.get_pixel(x, y)
				new_img.set_pixel(x, h - 1 - y, px)
	else:
		if axis == "vertical":
			new_img.flip_y()
		else:
			new_img.flip_x()

	_commit_image_change(new_img, "Mirror / Flip Layer", target.frame, target.layer)
	return {"success": true, "data": {"axis": axis, "mode": mode, "frame": target.frame, "layer": target.layer}}


func _cmd_transform_cel(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var image: Image = target.image
	var dx: int = int(params.get("dx", 0))
	var dy: int = int(params.get("dy", 0))
	var wrap_around: bool = bool(params.get("wrap_around", false))

	var w := image.get_width()
	var h := image.get_height()
	var new_image := Image.create(w, h, false, Image.FORMAT_RGBA8)

	var shifted_pixels := 0
	for y in range(h):
		for x in range(w):
			var src_px := image.get_pixel(x, y)
			if src_px.a > 0.001:
				var nx := x + dx
				var ny := y + dy
				if wrap_around:
					nx = posmod(nx, w)
					ny = posmod(ny, h)
				if nx >= 0 and nx < w and ny >= 0 and ny < h:
					new_image.set_pixel(nx, ny, src_px)
					shifted_pixels += 1

	_commit_image_change(new_image, "Transform Cel (%d, %d)" % [dx, dy], target.frame, target.layer)
	return {"success": true, "data": {"dx": dx, "dy": dy, "wrap_around": wrap_around, "shifted_pixels": shifted_pixels, "frame": target.frame, "layer": target.layer}}


func _cmd_rotate_cel(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var image: Image = target.image
	var angle: int = int(params.get("angle", 90))

	var new_image: Image = image.duplicate()
	if angle == 90:
		new_image.rotate_90(CLOCKWISE)
	elif angle == 180:
		new_image.rotate_180()
	elif angle == 270 or angle == -90:
		new_image.rotate_90(COUNTERCLOCKWISE)
	else:
		return {"success": false, "error": "Angle must be 90, 180, or 270 degrees"}

	_commit_image_change(new_image, "Rotate Cel %d°" % angle, target.frame, target.layer)
	return {"success": true, "data": {"angle": angle, "frame": target.frame, "layer": target.layer}}


# ─────────────────────────────────────────────
# INSPECTION COMMANDS
# ─────────────────────────────────────────────

func _cmd_get_pixel(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var image: Image = target.image
	var x: int = int(params.get("x", 0))
	var y: int = int(params.get("y", 0))

	if x < 0 or x >= image.get_width() or y < 0 or y >= image.get_height():
		return {"success": false, "error": "Coordinates (%d, %d) out of canvas bounds (%d×%d)" % [x, y, image.get_width(), image.get_height()]}

	var col: Color = image.get_pixel(x, y)
	return {
		"success": true,
		"data": {
			"x": x,
			"y": y,
			"color": "#" + col.to_html(),
			"r": col.r8,
			"g": col.g8,
			"b": col.b8,
			"a": col.a8,
			"frame": target.frame,
			"layer": target.layer
		}
	}


func _cmd_get_pixels(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var image: Image = target.image
	var coords: Array = params.get("coords", [])
	var results: Array = []
	var w := image.get_width()
	var h := image.get_height()

	for pt in coords:
		if not pt is Dictionary:
			continue
		var px: int = int(pt.get("x", 0))
		var py: int = int(pt.get("y", 0))
		if px >= 0 and px < w and py >= 0 and py < h:
			var col: Color = image.get_pixel(px, py)
			results.append({"x": px, "y": py, "color": "#" + col.to_html(), "r": col.r8, "g": col.g8, "b": col.b8, "a": col.a8})
		else:
			results.append({"x": px, "y": py, "color": null, "error": "out_of_bounds"})

	return {"success": true, "data": {"pixels": results, "count": results.size(), "frame": target.frame, "layer": target.layer}}


func _cmd_get_region(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var image: Image = target.image
	var x: int = int(params.get("x", 0))
	var y: int = int(params.get("y", 0))
	var width: int = int(params.get("width", 16))
	var height: int = int(params.get("height", 16))

	var w := image.get_width()
	var h := image.get_height()

	x = clampi(x, 0, w - 1)
	y = clampi(y, 0, h - 1)
	width = clampi(width, 1, w - x)
	height = clampi(height, 1, h - y)

	var rows: Array = []
	for ry in range(y, y + height):
		var row: Array = []
		for rx in range(x, x + width):
			var col: Color = image.get_pixel(rx, ry)
			row.append("#" + col.to_html())
		rows.append(row)

	return {"success": true, "data": {"x": x, "y": y, "width": width, "height": height, "grid": rows, "frame": target.frame, "layer": target.layer}}


# ─────────────────────────────────────────────
# COLOUR COMMANDS
# ─────────────────────────────────────────────

func _cmd_set_color(params: Dictionary) -> Dictionary:
	var color := _parse_color(params)
	var button: int = params.get("button", 0)  # 0 = left (foreground), 1 = right (background)

	var tools_autoload = _api.tools.autoload()
	if button == 0:
		tools_autoload.assign_color(color, MOUSE_BUTTON_LEFT)
	else:
		tools_autoload.assign_color(color, MOUSE_BUTTON_RIGHT)

	return {"success": true, "data": {"color": color.to_html(), "button": button}}


func _cmd_get_color(_params: Dictionary) -> Dictionary:
	var tools_autoload = _api.tools.autoload()
	return {
		"success": true,
		"data": {
			"foreground": tools_autoload.get_assigned_color(MOUSE_BUTTON_LEFT).to_html(),
			"background": tools_autoload.get_assigned_color(MOUSE_BUTTON_RIGHT).to_html(),
		}
	}


func _cmd_color_replace(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var image: Image = target.image
	var old_color := _parse_color(params, "old_color", Color.BLACK)
	var new_color := _parse_color(params, "new_color", Color.WHITE)
	var tolerance: float = float(params.get("tolerance", 0.05))

	var w := image.get_width()
	var h := image.get_height()
	var modified_img := image.duplicate()
	var replaced_count := 0

	for y in range(h):
		for x in range(w):
			var px := image.get_pixel(x, y)
			if px.a > 0.01:
				var dist := sqrt(pow(px.r - old_color.r, 2) + pow(px.g - old_color.g, 2) + pow(px.b - old_color.b, 2))
				if dist <= tolerance:
					modified_img.set_pixel(x, y, Color(new_color.r, new_color.g, new_color.b, px.a))
					replaced_count += 1

	_commit_image_change(modified_img, "Color Replace", target.frame, target.layer)
	return {"success": true, "data": {"replaced_pixels": replaced_count, "old_color": old_color.to_html(), "new_color": new_color.to_html(), "frame": target.frame, "layer": target.layer}}


func _cmd_adjust_hsv(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var image: Image = target.image
	var hue_shift: float = float(params.get("hue_shift", 0.0))
	var saturation_mult: float = float(params.get("saturation", 1.0))
	var value_mult: float = float(params.get("value", 1.0))

	var h_norm: float = hue_shift / 360.0

	var w := image.get_width()
	var h := image.get_height()
	var modified_img := image.duplicate()
	var modified_count := 0

	for y in range(h):
		for x in range(w):
			var px := image.get_pixel(x, y)
			if px.a > 0.01:
				var h_val := fposmod(px.h + h_norm, 1.0)
				var s_val := clampf(px.s * saturation_mult, 0.0, 1.0)
				var v_val := clampf(px.v * value_mult, 0.0, 1.0)
				var new_col := Color.from_hsv(h_val, s_val, v_val, px.a)
				modified_img.set_pixel(x, y, new_col)
				modified_count += 1

	_commit_image_change(modified_img, "Adjust HSV", target.frame, target.layer)
	return {"success": true, "data": {"modified_pixels": modified_count, "hue_shift": hue_shift, "saturation": saturation_mult, "value": value_mult, "frame": target.frame, "layer": target.layer}}


# ─────────────────────────────────────────────
# LAYER COMMANDS
# ─────────────────────────────────────────────

func _cmd_add_layer(params: Dictionary) -> Dictionary:
	var layer_name: String = params.get("name", "")
	var type: int = params.get("type", 0)  # 0=Pixel, 1=Group, 2=3D

	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	if type < 0 or type > 2:
		return {"success": false, "error": "Invalid layer type: %d (must be 0=Pixel, 1=Group, 2=3D)" % type}

	var above_layer: int = params.get("above_layer", project.current_layer)
	if above_layer < 0 or above_layer >= project.layers.size():
		return {"success": false, "error": "Invalid above_layer index: %d" % above_layer}

	_api.project.add_new_layer(above_layer, layer_name, type)

	return {"success": true, "data": {"name": layer_name, "type": type, "above_layer": above_layer}}


func _cmd_delete_layer(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var layer_index: int = params.get("index", -1)
	if layer_index < 0 or layer_index >= project.layers.size():
		return {"success": false, "error": "Invalid layer index: %d" % layer_index}

	project.remove_layers(PackedInt32Array([layer_index]))
	return {"success": true, "data": {"message": "Layer %d deleted" % layer_index}}


func _cmd_set_layer_opacity(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var layer_index: int = params.get("index", -1)
	if layer_index < 0 or layer_index >= project.layers.size():
		return {"success": false, "error": "Invalid layer index: %d" % layer_index}

	var opacity: float = params.get("opacity", 1.0)
	opacity = clampf(opacity, 0.0, 1.0)
	project.layers[layer_index].opacity = opacity
	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()
	return {"success": true, "data": {"index": layer_index, "opacity": opacity}}


func _cmd_set_layer_blend_mode(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var layer_index: int = params.get("index", -1)
	if layer_index < 0 or layer_index >= project.layers.size():
		return {"success": false, "error": "Invalid layer index: %d" % layer_index}

	var blend_mode: int = params.get("blend_mode", 0)
	project.layers[layer_index].blend_mode = blend_mode
	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()
	return {"success": true, "data": {"index": layer_index, "blend_mode": blend_mode}}


func _cmd_set_layer_visibility(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var layer_index: int = params.get("index", -1)
	if layer_index < 0 or layer_index >= project.layers.size():
		return {"success": false, "error": "Invalid layer index: %d" % layer_index}

	var visible: bool = params.get("visible", true)
	project.layers[layer_index].visible = visible
	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()
	return {"success": true, "data": {"index": layer_index, "visible": visible}}


func _cmd_set_layer_name(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var index: int = int(params.get("index", project.current_layer))
	var name: String = str(params.get("name", "")).strip_edges()

	if index < 0 or index >= project.layers.size():
		return {"success": false, "error": "Invalid layer index: %d" % index}
	if name == "":
		return {"success": false, "error": "Layer name cannot be empty"}

	var old_name: String = project.layers[index].name
	project.layers[index].name = name
	return {"success": true, "data": {"index": index, "old_name": old_name, "new_name": name}}


func _cmd_reorder_layers(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var from_index: int = int(params.get("from_index", -1))
	var to_index: int = int(params.get("to_index", -1))

	if from_index < 0 or from_index >= project.layers.size():
		return {"success": false, "error": "Invalid from_index: %d" % from_index}
	if to_index < 0 or to_index >= project.layers.size():
		return {"success": false, "error": "Invalid to_index: %d" % to_index}
	if from_index == to_index:
		return {"success": true, "data": {"from_index": from_index, "to_index": to_index, "message": "No change"}}

	if _api.project.has_method("move_layer"):
		_api.project.move_layer(from_index, to_index)
	elif project.has_method("move_layers"):
		project.move_layers(PackedInt32Array([from_index]), to_index)
	elif project.has_method("move_layer"):
		project.move_layer(from_index, to_index)

	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	return {"success": true, "data": {"from_index": from_index, "to_index": to_index}}


func _cmd_get_layers(_params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var layers: Array = []
	for i in range(project.layers.size()):
		var layer = project.layers[i]
		layers.append({
			"index": i,
			"name": layer.name,
			"visible": layer.visible,
			"locked": layer.locked,
			"opacity": layer.opacity,
			"blend_mode": layer.blend_mode,
			"type": layer.get_class_name(),
		})

	return {"success": true, "data": {"layers": layers, "current_layer": project.current_layer}}


# ─────────────────────────────────────────────
# FRAME COMMANDS
# ─────────────────────────────────────────────

func _cmd_add_frame(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var after_frame: int = params.get("after_frame", project.current_frame)
	if after_frame < 0 or after_frame >= project.frames.size():
		return {"success": false, "error": "Invalid after_frame index: %d" % after_frame}

	_api.project.add_new_frame(after_frame)

	return {"success": true, "data": {"after_frame": after_frame, "total_frames": project.frames.size()}}


func _cmd_get_frames(_params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var frames: Array = []
	for i in range(project.frames.size()):
		var frame = project.frames[i]
		frames.append({
			"index": i,
			"duration": frame.duration,
			"cels": frame.cels.size(),
		})

	return {
		"success": true,
		"data": {
			"frames": frames,
			"current_frame": project.current_frame,
			"total_frames": project.frames.size()
		}
	}


func _cmd_delete_frame(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}
	if project.frames.size() <= 1:
		return {"success": false, "error": "Cannot delete the only frame"}

	var frame_index: int = params.get("index", project.current_frame)
	if frame_index < 0 or frame_index >= project.frames.size():
		return {"success": false, "error": "Invalid frame index: %d" % frame_index}

	project.remove_frames(PackedInt32Array([frame_index]))
	return {"success": true, "data": {"deleted": frame_index, "total_frames": project.frames.size()}}


func _cmd_duplicate_frame(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var src_index: int = params.get("index", project.current_frame)
	if src_index < 0 or src_index >= project.frames.size():
		return {"success": false, "error": "Invalid frame index: %d" % src_index}

	var insert_at := src_index + 1
	_api.project.add_new_frame(src_index)

	# Copy pixel cel images from src_index into newly inserted frame (at insert_at)
	var src_frame = project.frames[src_index]
	var dst_frame = project.frames[insert_at]
	for layer_idx in range(mini(src_frame.cels.size(), dst_frame.cels.size())):
		var src_cel = src_frame.cels[layer_idx]
		var dst_cel = dst_frame.cels[layer_idx]
		if src_cel != null and dst_cel != null and src_cel.get_class_name() == "PixelCel" and dst_cel.get_class_name() == "PixelCel":
			var src_img: Image = src_cel.get_image()
			if src_img:
				var copy_img := src_img.duplicate()
				_api.project.set_pixelcel_image(copy_img, insert_at, layer_idx)

	dst_frame.duration = src_frame.duration
	return {"success": true, "data": {"duplicated_from": src_index, "inserted_at": insert_at, "total_frames": project.frames.size()}}


func _cmd_set_frame_duration(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var frame_index: int = params.get("index", project.current_frame)
	if frame_index < 0 or frame_index >= project.frames.size():
		return {"success": false, "error": "Invalid frame index: %d" % frame_index}

	var duration: float = params.get("duration", 1.0)
	if duration <= 0.0:
		return {"success": false, "error": "Duration must be > 0"}

	project.frames[frame_index].duration = duration
	return {"success": true, "data": {"index": frame_index, "duration": duration}}


func _cmd_switch_frame(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var frame_index: int = params.get("index", project.current_frame)
	if frame_index < 0 or frame_index >= project.frames.size():
		return {"success": false, "error": "Invalid frame index: %d" % frame_index}

	project.change_cel(frame_index, project.current_layer)
	return {"success": true, "data": {"current_frame": project.current_frame}}


func _cmd_get_fps(_params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}
	return {"success": true, "data": {"fps": project.fps}}


func _cmd_set_fps(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var fps: float = params.get("fps", 12.0)
	if fps <= 0.0:
		return {"success": false, "error": "FPS must be > 0"}

	project.fps = fps
	return {"success": true, "data": {"fps": project.fps}}


func _cmd_switch_cel(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var frame_index: int = params.get("frame", project.current_frame)
	var layer_index: int = params.get("layer", project.current_layer)

	if frame_index < 0 or frame_index >= project.frames.size():
		return {"success": false, "error": "Invalid frame index: %d" % frame_index}
	if layer_index < 0 or layer_index >= project.layers.size():
		return {"success": false, "error": "Invalid layer index: %d" % layer_index}

	project.change_cel(frame_index, layer_index)
	return {"success": true, "data": {"frame": project.current_frame, "layer": project.current_layer}}


func _cmd_copy_cel(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var src_frame: int = params.get("src_frame", project.current_frame)
	var src_layer: int = params.get("src_layer", project.current_layer)
	var dst_frame: int = params.get("dst_frame", -1)
	var dst_layer: int = params.get("dst_layer", -1)

	if dst_frame < 0 or dst_layer < 0:
		return {"success": false, "error": "dst_frame and dst_layer are required"}
	if src_frame >= project.frames.size() or dst_frame >= project.frames.size():
		return {"success": false, "error": "Frame index out of bounds"}
	if src_layer >= project.layers.size() or dst_layer >= project.layers.size():
		return {"success": false, "error": "Layer index out of bounds"}

	var src_cel = project.frames[src_frame].cels[src_layer]
	if src_cel.get_class_name() != "PixelCel":
		return {"success": false, "error": "Source cel is not a PixelCel"}

	var dst_cel = project.frames[dst_frame].cels[dst_layer]
	if dst_cel.get_class_name() != "PixelCel":
		return {"success": false, "error": "Destination cel is not a PixelCel"}

	# Copy pixels from source to destination
	var src_image: Image = src_cel.get_image()
	var dst_image: Image = dst_cel.get_image()
	dst_image.blit_rect(src_image, Rect2i(0, 0, src_image.get_width(), src_image.get_height()), Vector2i.ZERO)
	_api.project.set_pixelcel_image(dst_image, dst_frame, dst_layer)
	return {"success": true, "data": {"src_frame": src_frame, "src_layer": src_layer, "dst_frame": dst_frame, "dst_layer": dst_layer}}


func _cmd_clear_cel(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var frame_index: int = params.get("frame", project.current_frame)
	var layer_index: int = params.get("layer", project.current_layer)

	if frame_index < 0 or frame_index >= project.frames.size():
		return {"success": false, "error": "Invalid frame index: %d" % frame_index}
	if layer_index < 0 or layer_index >= project.layers.size():
		return {"success": false, "error": "Invalid layer index: %d" % layer_index}

	var cel = project.frames[frame_index].cels[layer_index]
	if cel == null or cel.get_class_name() != "PixelCel":
		return {"success": false, "error": "Target cel is not a PixelCel"}

	var cleared_img := Image.create(int(project.size.x), int(project.size.y), false, Image.FORMAT_RGBA8)
	_commit_image_change(cleared_img, "Clear Cel", frame_index, layer_index)
	return {"success": true, "data": {"frame": frame_index, "layer": layer_index}}


func _cmd_export_animation(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var dir_path: String = params.get("path", "")
	if dir_path.is_empty():
		return {"success": false, "error": "Missing 'path' directory parameter"}

	# Ensure export directory exists
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var prefix: String = params.get("prefix", "frame")
	var mode: String = params.get("mode", "frames")  # "frames" or "spritesheet"
	var drawing_algos = _api.general.get_drawing_algos()
	var w := int(project.size.x)
	var h := int(project.size.y)
	var exported: Array = []

	if mode == "spritesheet":
		var cols: int = params.get("columns", project.frames.size())
		cols = maxi(1, cols)
		var rows := ceili(float(project.frames.size()) / float(cols))
		var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGBA8)

		for i in range(project.frames.size()):
			var frame_img := Image.create(w, h, false, Image.FORMAT_RGBA8)
			drawing_algos.blend_layers(frame_img, project.frames[i], Vector2i.ZERO, project)
			var col := i % cols
			var row := i / cols
			sheet.blit_rect(frame_img, Rect2i(0, 0, w, h), Vector2i(col * w, row * h))

		var sheet_path := dir_path.path_join("%s_spritesheet.png" % prefix)
		var err := sheet.save_png(sheet_path)
		if err != OK:
			return {"success": false, "error": "Failed to save spritesheet to '%s': %s" % [sheet_path, error_string(err)]}
		return {"success": true, "data": {"mode": "spritesheet", "path": sheet_path, "frames": project.frames.size(), "columns": cols, "rows": rows}}
	else:
		# Export individual frames
		var start_frame: int = params.get("start_frame", 0)
		var end_frame: int = params.get("end_frame", project.frames.size() - 1)
		end_frame = clampi(end_frame, 0, project.frames.size() - 1)
		start_frame = clampi(start_frame, 0, end_frame)

		for i in range(start_frame, end_frame + 1):
			var frame_img := Image.create(w, h, false, Image.FORMAT_RGBA8)
			drawing_algos.blend_layers(frame_img, project.frames[i], Vector2i.ZERO, project)
			var file_path := dir_path.path_join("%s_%04d.png" % [prefix, i])
			var err := frame_img.save_png(file_path)
			if err != OK:
				return {"success": false, "error": "Failed to save frame %d: %s" % [i, error_string(err)]}
			exported.append(file_path)

		return {"success": true, "data": {"mode": "frames", "files": exported, "count": exported.size()}}


# ─────────────────────────────────────────────
# SELECTION COMMANDS
# ─────────────────────────────────────────────

func _cmd_select_rect(params: Dictionary) -> Dictionary:
	var x: int = params.get("x", 0)
	var y: int = params.get("y", 0)
	var width: int = params.get("width", 1)
	var height: int = params.get("height", 1)
	var operation: int = params.get("operation", 0)  # 0=add, 1=subtract, 2=intersect

	_api.selection.select_rect(Rect2i(x, y, width, height), operation)
	return {"success": true, "data": {"x": x, "y": y, "width": width, "height": height}}


func _cmd_select_all(_params: Dictionary) -> Dictionary:
	_api.selection.select_all()
	return {"success": true, "data": {"message": "Selected all"}}


func _cmd_deselect(_params: Dictionary) -> Dictionary:
	_api.selection.clear_selection()
	return {"success": true, "data": {"message": "Selection cleared"}}


# ─────────────────────────────────────────────
# PALETTE COMMANDS
# ─────────────────────────────────────────────

func _cmd_get_palette_colors(_params: Dictionary) -> Dictionary:
	var palettes_autoload = _api.palette.autoload()
	var current_palette = palettes_autoload.current_palette
	if current_palette == null:
		return {"success": false, "error": "No active palette"}

	var colors: Array = []
	for i in range(current_palette.width * current_palette.height):
		if current_palette.colors.has(i):
			var swatch = current_palette.colors[i]
			colors.append({
				"index": i,
				"color": swatch.color.to_html()
			})

	return {
		"success": true,
		"data": {
			"palette_name": current_palette.name,
			"colors": colors,
			"width": current_palette.width,
			"height": current_palette.height,
		}
	}


func _cmd_create_palette(params: Dictionary) -> Dictionary:
	var palettes_autoload = _api.palette.autoload()
	var name: String = params.get("name", "New Palette")
	var width: int = params.get("width", 8)
	var height: int = params.get("height", 8)
	var is_global: bool = params.get("is_global", true)

	palettes_autoload.create_new_palette(0, name, "", width, height, false, 0, is_global)
	return {"success": true, "data": {"name": name, "width": width, "height": height, "is_global": is_global}}


func _cmd_add_palette_color(params: Dictionary) -> Dictionary:
	var palettes_autoload = _api.palette.autoload()
	var current_palette = palettes_autoload.current_palette
	if current_palette == null:
		return {"success": false, "error": "No active palette"}

	var color := _parse_color(params)
	if current_palette.is_full():
		return {"success": false, "error": "Palette is full"}

	current_palette.add_color(color)
	palettes_autoload.save_palette()
	return {"success": true, "data": {"color": color.to_html()}}


func _cmd_set_palette_color(params: Dictionary) -> Dictionary:
	var palettes_autoload = _api.palette.autoload()
	var current_palette = palettes_autoload.current_palette
	if current_palette == null:
		return {"success": false, "error": "No active palette"}

	var index: int = params.get("index", -1)
	if index < 0 or index >= (current_palette.width * current_palette.height):
		return {"success": false, "error": "Invalid index: %d" % index}

	var color := _parse_color(params)
	current_palette.set_color(index, color)
	palettes_autoload.save_palette()
	return {"success": true, "data": {"index": index, "color": color.to_html()}}
