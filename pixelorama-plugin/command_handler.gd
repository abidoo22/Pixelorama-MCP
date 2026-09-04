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
	_tool_registry["open_project"] = Callable(self, "_cmd_open_project")
	_tool_registry["get_canvas_info"] = Callable(self, "_cmd_get_canvas_info")
	_tool_registry["list_canvases"] = Callable(self, "_cmd_list_canvases")
	_tool_registry["switch_canvas"] = Callable(self, "_cmd_switch_canvas")
	_tool_registry["close_canvas"] = Callable(self, "_cmd_close_canvas")
	_tool_registry["rename_canvas"] = Callable(self, "_cmd_rename_canvas")
	_tool_registry["save_project"] = Callable(self, "_cmd_save_project")
	_tool_registry["export_image"] = Callable(self, "_cmd_export_image")
	_tool_registry["export_gif"] = Callable(self, "_cmd_export_gif")
	_tool_registry["export_apng"] = Callable(self, "_cmd_export_apng")
	_tool_registry["export_aseprite_json"] = Callable(self, "_cmd_export_aseprite_json")
	_tool_registry["import_spritesheet"] = Callable(self, "_cmd_import_spritesheet")
	_tool_registry["get_canvas_snapshot"] = Callable(self, "_cmd_get_canvas_snapshot")
	_tool_registry["get_canvas_image_base64"] = Callable(self, "_cmd_get_canvas_image_base64")
	_tool_registry["fit_viewport"] = Callable(self, "_cmd_fit_viewport")
	_tool_registry["crop_to_content"] = Callable(self, "_cmd_crop_to_content")
	_tool_registry["scale_canvas"] = Callable(self, "_cmd_scale_canvas")
	_tool_registry["set_tile_mode"] = Callable(self, "_cmd_set_tile_mode")
	_tool_registry["set_symmetry_guide"] = Callable(self, "_cmd_set_symmetry_guide")
	_tool_registry["set_onion_skinning"] = Callable(self, "_cmd_set_onion_skinning")

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
	_tool_registry["draw_text"] = Callable(self, "_cmd_draw_text")
	_tool_registry["fill_area"] = Callable(self, "_cmd_fill_area")
	_tool_registry["apply_outline"] = Callable(self, "_cmd_apply_outline")
	_tool_registry["apply_drop_shadow"] = Callable(self, "_cmd_apply_drop_shadow")
	_tool_registry["apply_glow"] = Callable(self, "_cmd_apply_glow")
	_tool_registry["apply_gradient"] = Callable(self, "_cmd_apply_gradient")
	_tool_registry["check_seamless_tile"] = Callable(self, "_cmd_check_seamless_tile")
	_tool_registry["mirror_layer"] = Callable(self, "_cmd_mirror_layer")
	_tool_registry["transform_cel"] = Callable(self, "_cmd_transform_cel")
	_tool_registry["rotate_cel"] = Callable(self, "_cmd_rotate_cel")

	# Inspection & QA
	_tool_registry["get_pixel"] = Callable(self, "_cmd_get_pixel")
	_tool_registry["get_pixels"] = Callable(self, "_cmd_get_pixels")
	_tool_registry["get_region"] = Callable(self, "_cmd_get_region")
	_tool_registry["get_palette_usage"] = Callable(self, "_cmd_get_palette_usage")
	_tool_registry["clean_isolated_pixels"] = Callable(self, "_cmd_clean_isolated_pixels")

	# Colour & Palette
	_tool_registry["set_color"] = Callable(self, "_cmd_set_color")
	_tool_registry["get_color"] = Callable(self, "_cmd_get_color")
	_tool_registry["color_replace"] = Callable(self, "_cmd_color_replace")
	_tool_registry["adjust_hsv"] = Callable(self, "_cmd_adjust_hsv")
	_tool_registry["remap_to_palette"] = Callable(self, "_cmd_remap_to_palette")
	_tool_registry["get_palette_colors"] = Callable(self, "_cmd_get_palette_colors")
	_tool_registry["create_palette"] = Callable(self, "_cmd_create_palette")
	_tool_registry["add_palette_color"] = Callable(self, "_cmd_add_palette_color")
	_tool_registry["set_palette_color"] = Callable(self, "_cmd_set_palette_color")
	_tool_registry["list_palettes"] = Callable(self, "_cmd_list_palettes")
	_tool_registry["switch_palette"] = Callable(self, "_cmd_switch_palette")
	_tool_registry["delete_palette"] = Callable(self, "_cmd_delete_palette")

	# Layers
	_tool_registry["add_layer"] = Callable(self, "_cmd_add_layer")
	_tool_registry["duplicate_layer"] = Callable(self, "_cmd_duplicate_layer")
	_tool_registry["merge_layers"] = Callable(self, "_cmd_merge_layers")
	_tool_registry["create_layer_group"] = Callable(self, "_cmd_create_layer_group")
	_tool_registry["delete_layer"] = Callable(self, "_cmd_delete_layer")
	_tool_registry["get_layers"] = Callable(self, "_cmd_get_layers")
	_tool_registry["set_layer_opacity"] = Callable(self, "_cmd_set_layer_opacity")
	_tool_registry["set_layer_blend_mode"] = Callable(self, "_cmd_set_layer_blend_mode")
	_tool_registry["set_layer_visibility"] = Callable(self, "_cmd_set_layer_visibility")
	_tool_registry["set_layer_name"] = Callable(self, "_cmd_set_layer_name")
	_tool_registry["reorder_layers"] = Callable(self, "_cmd_reorder_layers")

	# Frames & Animation Tags
	_tool_registry["add_frame"] = Callable(self, "_cmd_add_frame")
	_tool_registry["delete_frame"] = Callable(self, "_cmd_delete_frame")
	_tool_registry["duplicate_frame"] = Callable(self, "_cmd_duplicate_frame")
	_tool_registry["set_frame_duration"] = Callable(self, "_cmd_set_frame_duration")
	_tool_registry["switch_frame"] = Callable(self, "_cmd_switch_frame")
	_tool_registry["get_frames"] = Callable(self, "_cmd_get_frames")
	_tool_registry["get_fps"] = Callable(self, "_cmd_get_fps")
	_tool_registry["set_fps"] = Callable(self, "_cmd_set_fps")
	_tool_registry["reverse_frames"] = Callable(self, "_cmd_reverse_frames")
	_tool_registry["tween_cel"] = Callable(self, "_cmd_tween_cel")
	_tool_registry["add_animation_tag"] = Callable(self, "_cmd_add_animation_tag")
	_tool_registry["get_animation_tags"] = Callable(self, "_cmd_get_animation_tags")
	_tool_registry["delete_animation_tag"] = Callable(self, "_cmd_delete_animation_tag")
	_tool_registry["switch_cel"] = Callable(self, "_cmd_switch_cel")
	_tool_registry["copy_cel"] = Callable(self, "_cmd_copy_cel")
	_tool_registry["clear_cel"] = Callable(self, "_cmd_clear_cel")
	_tool_registry["export_animation"] = Callable(self, "_cmd_export_animation")

	# Selection
	_tool_registry["select_rect"] = Callable(self, "_cmd_select_rect")
	_tool_registry["select_by_color"] = Callable(self, "_cmd_select_by_color")
	_tool_registry["invert_selection"] = Callable(self, "_cmd_invert_selection")
	_tool_registry["transform_selection"] = Callable(self, "_cmd_transform_selection")
	_tool_registry["select_all"] = Callable(self, "_cmd_select_all")
	_tool_registry["deselect"] = Callable(self, "_cmd_deselect")
	_tool_registry["validate_sprite"] = Callable(self, "_cmd_validate_sprite")
	_tool_registry["get_history"] = Callable(self, "_cmd_get_history")

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

func _get_active_cursor_info(project = null) -> Dictionary:
	if project == null:
		project = _api.project.current_project
	if project == null:
		return {"frame": 0, "layer": 0, "layer_name": ""}
	var frame_idx: int = project.current_frame
	var layer_idx: int = project.current_layer
	var layer_name := ""
	if layer_idx >= 0 and layer_idx < project.layers.size():
		layer_name = project.layers[layer_idx].name
	return {
		"frame": frame_idx,
		"layer": layer_idx,
		"layer_name": layer_name
	}


func _get_current_cel():
	var project = _api.project.current_project
	if project == null:
		return null
	return _api.project.get_current_cel()


func _get_current_image() -> Image:
	var cel = _get_current_cel()
	if cel == null or cel.get_class_name() != "PixelCel":
		return null
	return cel.get_image().duplicate()


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

	return {"error": "", "image": cel.get_image().duplicate(), "frame": frame_idx, "layer": layer_idx, "cel": cel}


func _commit_image_change(image: Image, action_name: String, frame_idx: int = -1, layer_idx: int = -1) -> void:
	## Commits the modified image through Pixelorama's undo system.
	## This ensures every AI action is undoable by the user.
	var project = _api.project.current_project
	if project == null:
		return

	if frame_idx < 0:
		frame_idx = project.current_frame
	if layer_idx < 0:
		layer_idx = project.current_layer

	if frame_idx < 0 or frame_idx >= project.frames.size():
		return
	if layer_idx < 0 or layer_idx >= project.layers.size():
		return

	var cel = project.frames[frame_idx].cels[layer_idx]
	if cel == null or cel.get_class_name() != "PixelCel":
		return

	var cel_image: Image = cel.get_image()
	image.convert(project.get_image_format())

	var ur = project.undo_redo
	if ur:
		ur.create_action(action_name)
		var undo_data := {}
		if cel.has_method("serialize_undo_data"):
			undo_data[cel] = cel.serialize_undo_data()
		cel_image.add_data_to_dictionary(undo_data)

		cel_image.fill(0)
		cel_image.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
		if cel_image.has_method("convert_rgb_to_indexed"):
			cel_image.convert_rgb_to_indexed()

		var redo_data := {}
		if cel.has_method("update_tilemap"):
			cel.update_tilemap()
		if cel.has_method("serialize_undo_data"):
			redo_data[cel] = cel.serialize_undo_data()
		cel_image.add_data_to_dictionary(redo_data)

		project.deserialize_cel_undo_data(redo_data, undo_data)
		ur.add_do_property(project, "selected_cels", [])
		ur.add_do_method(project.change_cel.bind(frame_idx, layer_idx))
		var global_node = _api.get_node_or_null("/root/Global")
		if global_node and global_node.has_method("undo_or_redo"):
			ur.add_do_method(global_node.undo_or_redo.bind(false, frame_idx, layer_idx, project))

		ur.add_undo_property(project, "selected_cels", [])
		ur.add_undo_method(project.change_cel.bind(frame_idx, layer_idx))
		if cel.has_method("update_texture"):
			ur.add_do_method(cel.update_texture)
			ur.add_undo_method(cel.update_texture)
		if global_node and global_node.has_method("undo_or_redo"):
			ur.add_undo_method(global_node.undo_or_redo.bind(true, frame_idx, layer_idx, project))
		ur.commit_action()
	else:
		# Fallback if undo_redo not available
		cel_image.fill(0)
		cel_image.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)

	# Select the current cel to trigger a switch/refresh signal
	_api.project.select_cels([[frame_idx, layer_idx]])

	# Request redraw on the main canvas
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

	if projects_arr.size() <= 1:
		return {
			"success": false,
			"error": "Cannot close the only open canvas. Open or create another canvas before closing this one."
		}

	var cur_idx: int = int(global.current_project_index) if "current_project_index" in global else 0
	var target_index: int = int(params.get("index", cur_idx))
	if target_index < 0 or target_index >= projects_arr.size():
		return {
			"success": false,
			"error": "Canvas index %d out of bounds (0..%d)" % [target_index, projects_arr.size() - 1]
		}

	var closed_name = projects_arr[target_index].name

	# Remove project from projects array
	projects_arr.remove_at(target_index)

	# Remove UI tab only if tab_count is still greater than projects count
	if "tabs" in global and global.tabs and global.tabs.tab_count > projects_arr.size():
		if target_index < global.tabs.tab_count:
			global.tabs.remove_tab(target_index)

	if projects_arr.is_empty():
		var fallback_frames: Array = []
		var fallback_frame_script = load("res://src/Classes/Frame.gd")
		if fallback_frame_script:
			fallback_frames = Array([], TYPE_OBJECT, "RefCounted", fallback_frame_script)
		_api.project.new_project(fallback_frames, "untitled", Vector2(64, 64), Color.TRANSPARENT)
	else:
		var next_index = clampi(target_index, 0, projects_arr.size() - 1)
		if "current_project_index" in global:
			global.current_project_index = next_index
		if "tabs" in global and global.tabs and global.tabs.tab_count > next_index:
			global.tabs.current_tab = next_index
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


func _cmd_rename_canvas(params: Dictionary) -> Dictionary:
	var global = _api.general.get_global()
	if global == null:
		return {"success": false, "error": "Global singleton not found"}

	var name: String = str(params.get("name", "")).strip_edges()
	if name.is_empty():
		return {"success": false, "error": "Canvas name cannot be empty"}

	var projects_arr = global.projects if "projects" in global else []
	if projects_arr.is_empty():
		return {"success": false, "error": "No open canvases"}

	var cur_idx: int = int(global.current_project_index) if "current_project_index" in global else 0
	var target_index: int = int(params.get("index", cur_idx))
	if target_index < 0 or target_index >= projects_arr.size():
		return {"success": false, "error": "Canvas index %d out of bounds (0..%d)" % [target_index, projects_arr.size() - 1]}

	var proj = projects_arr[target_index]
	var old_name: String = proj.name
	proj.name = name

	return {
		"success": true,
		"data": {
			"index": target_index,
			"old_name": old_name,
			"name": name,
			"message": "Renamed canvas [%d] from '%s' to '%s'" % [target_index, old_name, name]
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

	if project.save_path == "":
		return {"success": false, "error": "No save path set. Use Pixelorama's File > Save As first or specify 'path'."}

	var file_path = project.save_path
	if not file_path.ends_with(".pxo"):
		file_path += ".pxo"
		project.save_path = file_path

	var global = _api.get_node_or_null("/root/Global")
	if global and "current_project" in global:
		global.current_project = project
	_api.project.current_project = project

	var open_save = _api.import.open_save_autoload()
	if open_save == null:
		open_save = _api.get_node_or_null("/root/OpenSave")

	if open_save:
		if open_save.has_method("save_pxo_file"):
			open_save.save_pxo_file(file_path, false)
		elif open_save.has_method("save_project"):
			open_save.save_project(file_path)
		elif open_save.has_method("save_pxo"):
			open_save.save_pxo(file_path)
		elif open_save.has_method("save_resource"):
			open_save.save_resource(file_path, false)

	# Verify file on disk
	if FileAccess.file_exists(file_path):
		var fa = FileAccess.open(file_path, FileAccess.READ)
		var size_bytes: int = fa.get_length() if fa else 0
		if fa:
			fa.close()
		if "has_changed" in project:
			project.has_changed = false
		return {
			"success": true,
			"data": {
				"path": file_path,
				"size_bytes": size_bytes,
				"message": "Project saved successfully to %s (%d bytes)" % [file_path, size_bytes]
			}
		}
	else:
		# Direct ResourceSaver fallback
		var res_err = ResourceSaver.save(project, file_path)
		if res_err == OK and FileAccess.file_exists(file_path):
			var fa = FileAccess.open(file_path, FileAccess.READ)
			var size_bytes: int = fa.get_length() if fa else 0
			if fa:
				fa.close()
			if "has_changed" in project:
				project.has_changed = false
			return {
				"success": true,
				"data": {
					"path": file_path,
					"size_bytes": size_bytes,
					"message": "Project saved successfully to %s (%d bytes)" % [file_path, size_bytes]
				}
			}

		return {
			"success": false,
			"error": "Failed to save project file: file was not written to disk at '%s'" % file_path
		}


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

	var scale_factor: int = int(params.get("scale", 1))
	scale_factor = clampi(scale_factor, 1, 32)

	var dir_name := path.get_base_dir()
	if dir_name != "" and not DirAccess.dir_exists_absolute(dir_name):
		DirAccess.make_dir_recursive_absolute(dir_name)

	var img := _composite_frame_layers(project, frame_idx)
	if scale_factor > 1:
		img.resize(img.get_width() * scale_factor, img.get_height() * scale_factor, Image.INTERPOLATE_NEAREST)

	var err := img.save_png(path)
	if err == OK:
		return {
			"success": true,
			"data": {
				"path": path,
				"format": "png",
				"scale": scale_factor,
				"width": img.get_width(),
				"height": img.get_height()
			}
		}
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

	var w := int(project.size.x)
	var h := int(project.size.y)
	var img := _composite_frame_layers(project, frame_idx)

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

	var orig_w := int(project.size.x)
	var orig_h := int(project.size.y)

	var drawing_algos = _api.general.get_drawing_algos()
	if not drawing_algos:
		return {"success": false, "error": "DrawingAlgos not accessible"}

	# Calculate used_rect to verify content exists and return bounding box metadata
	var used_rect := Rect2i()
	for cel in project.get_all_pixel_cels():
		if cel.get_class_name() == "PixelCel":
			var cel_used: Rect2i = cel.get_image().get_used_rect()
			if cel_used != Rect2i(0, 0, 0, 0):
				if used_rect == Rect2i(0, 0, 0, 0):
					used_rect = cel_used
				else:
					used_rect = used_rect.merge(cel_used)

	if used_rect == Rect2i(0, 0, 0, 0):
		return {"success": false, "error": "Canvas is completely empty"}

	# Use Pixelorama's native crop_to_content which handles all cels, layer offsets,
	# selections, symmetry axes, and undo/redo without any clipping!
	drawing_algos.crop_to_content()

	var new_w := int(project.size.x)
	var new_h := int(project.size.y)

	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.queue_redraw()
		var cam = canvas.get("camera")
		if cam and cam.has_method("fit_to_frame"):
			cam.fit_to_frame()

	return {
		"success": true,
		"data": {
			"original_size": [orig_w, orig_h],
			"new_size": [new_w, new_h],
			"crop_rect": [used_rect.position.x, used_rect.position.y, used_rect.size.x, used_rect.size.y]
		}
	}


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
	var project = _api.project.current_project
	var ur = _get_undo_redo()
	if ur != null:
		if ur.has_undo():
			var action_name: String = ur.get_current_action_name()
			var prev_cursor := _get_active_cursor_info(project)
			ur.undo()
			var canvas = _api.general.get_canvas()
			if canvas:
				if "project_changed" in canvas:
					canvas.project_changed = true
				canvas.set("update_all_layers", true)
				canvas.queue_redraw()
				if canvas.has_method("update_texture") and project:
					canvas.update_texture(project.current_layer)

			var cur_cursor := _get_active_cursor_info(project)

			return {
				"success": true,
				"data": {
					"message": "Undone: %s" % action_name,
					"action": action_name,
					"target_layer": prev_cursor.layer_name,
					"target_layer_index": prev_cursor.layer,
					"active_layer_index": cur_cursor.layer,
					"active_layer_name": cur_cursor.layer_name,
					"frame": cur_cursor.frame,
					"active_cursor": cur_cursor,
					"has_undo": ur.has_undo(),
					"has_redo": ur.has_redo()
				}
			}
		else:
			return {"success": false, "error": "Nothing to undo"}
	return {"success": false, "error": "UndoRedo system not available"}


func _cmd_redo(_params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	var ur = _get_undo_redo()
	if ur != null:
		if ur.has_redo():
			ur.redo()
			var action_name: String = ur.get_current_action_name()
			var canvas = _api.general.get_canvas()
			if canvas:
				if "project_changed" in canvas:
					canvas.project_changed = true
				canvas.set("update_all_layers", true)
				canvas.queue_redraw()
				if canvas.has_method("update_texture") and project:
					canvas.update_texture(project.current_layer)

			var cur_cursor := _get_active_cursor_info(project)

			return {
				"success": true,
				"data": {
					"message": "Redone: %s" % action_name,
					"action": action_name,
					"layer_index": cur_cursor.layer,
					"layer_name": cur_cursor.layer_name,
					"frame": cur_cursor.frame,
					"active_cursor": cur_cursor,
					"has_undo": ur.has_undo(),
					"has_redo": ur.has_redo()
				}
			}
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
	var color_str: String = str(params.get("color", "")).strip_edges()
	if color_str.is_empty() or not Color.html_is_valid(color_str):
		return {
			"success": false,
			"error": "Invalid color hex format: '%s'. Expected valid hex color like '#FF5733' or '#00FF00'" % color_str
		}

	var color := Color.html(color_str)
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

	# Ensure all layer.index properties are strictly synchronized
	for i in range(project.layers.size()):
		project.layers[i].index = i
	project.order_layers()
	if project.has_signal("layers_updated"):
		project.layers_updated.emit()

	var canvas = _api.general.get_canvas()
	if canvas:
		if "project_changed" in canvas:
			canvas.project_changed = true
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	var new_layer_idx := above_layer + 1
	var actual_name := layer_name
	if new_layer_idx < project.layers.size():
		actual_name = project.layers[new_layer_idx].name

	return {
		"success": true,
		"data": {
			"name": actual_name,
			"type": type,
			"above_layer": above_layer,
			"layer_index": new_layer_idx,
			"active_cursor": _get_active_cursor_info(project)
		}
	}


func _cmd_delete_layer(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}
	if project.layers.size() <= 1:
		return {"success": false, "error": "Cannot delete the only layer in project"}

	var layer_index: int = params.get("index", project.current_layer)
	if layer_index < 0 or layer_index >= project.layers.size():
		return {"success": false, "error": "Invalid layer index: %d" % layer_index}

	project.remove_layers(PackedInt32Array([layer_index]))
	project.current_layer = clampi(project.current_layer, 0, project.layers.size() - 1)
	_api.project.current_layer = project.current_layer
	_api.project.select_cels([[project.current_frame, project.current_layer]])

	# Ensure all layer.index properties are strictly synchronized
	for i in range(project.layers.size()):
		project.layers[i].index = i
	project.order_layers()
	if project.has_signal("layers_updated"):
		project.layers_updated.emit()

	var canvas = _api.general.get_canvas()
	if canvas:
		if "project_changed" in canvas:
			canvas.project_changed = true
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	return {
		"success": true,
		"data": {
			"deleted": layer_index,
			"remaining_layers": project.layers.size(),
			"current_layer": project.current_layer,
			"active_cursor": _get_active_cursor_info(project)
		}
	}


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
		if "project_changed" in canvas:
			canvas.project_changed = true
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	var timeline = _api.get_node_or_null("/root/Global/AnimationTimeline")
	if timeline and timeline.has_method("_update_layer_settings_ui"):
		timeline._update_layer_settings_ui()

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
		if "project_changed" in canvas:
			canvas.project_changed = true
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
		if "project_changed" in canvas:
			canvas.project_changed = true
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

	# Reorder layers array
	var layer_item = project.layers.pop_at(from_index)
	project.layers.insert(to_index, layer_item)

	# Reorder corresponding cels across all animation frames
	for frame in project.frames:
		if from_index < frame.cels.size():
			var cel_item = frame.cels.pop_at(from_index)
			var insert_cel_at: int = mini(to_index, frame.cels.size())
			frame.cels.insert(insert_cel_at, cel_item)

	# Update all layer.index properties to match their new array positions
	for i in range(project.layers.size()):
		project.layers[i].index = i

	# Synchronize ordered_layers and emit layers_updated
	project.order_layers()
	if project.has_signal("layers_updated"):
		project.layers_updated.emit()

	# Update active layer index
	if project.current_layer == from_index:
		project.current_layer = to_index
	elif from_index < project.current_layer and to_index >= project.current_layer:
		project.current_layer -= 1
	elif from_index > project.current_layer and to_index <= project.current_layer:
		project.current_layer += 1

	project.current_layer = clampi(project.current_layer, 0, project.layers.size() - 1)
	_api.project.select_cels([[project.current_frame, project.current_layer]])

	var canvas = _api.general.get_canvas()
	if canvas:
		if "project_changed" in canvas:
			canvas.project_changed = true
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	return {
		"success": true,
		"data": {
			"from_index": from_index,
			"to_index": to_index,
			"layers_count": project.layers.size(),
			"current_layer": project.current_layer,
			"active_cursor": _get_active_cursor_info(project)
		}
	}


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

	return {
		"success": true,
		"data": {
			"after_frame": after_frame,
			"total_frames": project.frames.size(),
			"active_cursor": _get_active_cursor_info(project)
		}
	}


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
	project.current_frame = clampi(project.current_frame, 0, project.frames.size() - 1)
	_api.project.current_frame = project.current_frame
	_api.project.select_cels([[project.current_frame, project.current_layer]])

	return {
		"success": true,
		"data": {
			"deleted": frame_index,
			"total_frames": project.frames.size(),
			"current_frame": project.current_frame,
			"active_cursor": _get_active_cursor_info(project)
		}
	}


func _cmd_duplicate_frame(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var src_index: int = params.get("index", project.current_frame)
	if src_index < 0 or src_index >= project.frames.size():
		return {"success": false, "error": "Invalid frame index: %d" % src_index}

	var insert_at: int = src_index + 1
	var src_frame = project.frames[src_index]
	var frame_script = src_frame.get_script()
	var new_frame = frame_script.new() if frame_script else null
	if new_frame == null:
		var frame_class = load("res://src/Classes/Frame.gd")
		if frame_class:
			new_frame = frame_class.new()
	if new_frame != null and "duration" in new_frame:
		new_frame.duration = src_frame.duration

	var total_pixels_copied: int = 0

	for l in range(project.layers.size()):
		var src_cel = src_frame.cels[l]
		var new_cel = src_cel.duplicate_cel()
		if project.layers[l].new_cels_linked:
			if src_cel.link_set == null:
				src_cel.link_set = {}
			new_cel.set_content(src_cel.get_content(), src_cel.image_texture)
			new_cel.link_set = src_cel.link_set
		else:
			new_cel.set_content(src_cel.copy_content())

		if new_cel.get_class_name() == "PixelCel":
			var img: Image = new_cel.get_image()
			if img:
				for y in range(img.get_height()):
					for x in range(img.get_width()):
						if img.get_pixel(x, y).a > 0.01:
							total_pixels_copied += 1

		new_frame.cels.append(new_cel)

	# Animation tags replication
	var new_animation_tags: Array = project.animation_tags.duplicate()
	for i in new_animation_tags.size():
		new_animation_tags[i] = new_animation_tags[i].duplicate()
	for tag in new_animation_tags:
		if insert_at >= tag.from && insert_at <= tag.to:
			tag.to += 1
		elif insert_at < tag.from:
			tag.from += 1
			tag.to += 1

	project.undo_redo.create_action("Add Frame")
	project.undo_redo.add_do_method(project.add_frames.bind([new_frame], [insert_at]))
	project.undo_redo.add_undo_method(project.remove_frames.bind([insert_at]))
	project.undo_redo.add_do_property(project, "animation_tags", new_animation_tags)
	project.undo_redo.add_undo_property(project, "animation_tags", project.animation_tags)
	project.undo_redo.add_do_method(project.change_cel.bind(insert_at))
	project.undo_redo.add_undo_method(project.change_cel.bind(project.current_frame))
	var global_node = _api.get_node_or_null("/root/Global")
	if global_node and global_node.has_method("undo_or_redo"):
		project.undo_redo.add_do_method(global_node.undo_or_redo.bind(false))
		project.undo_redo.add_undo_method(global_node.undo_or_redo.bind(true))
	project.undo_redo.commit_action()

	var canvas = _api.general.get_canvas()
	if canvas:
		if "project_changed" in canvas:
			canvas.project_changed = true
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	var warning := ""
	if total_pixels_copied == 0:
		warning = "Source frame contained 0 colored pixels; new frame has empty cels"

	return {
		"success": true,
		"data": {
			"duplicated_from": src_index,
			"inserted_at": insert_at,
			"total_frames": project.frames.size(),
			"pixels_copied": total_pixels_copied,
			"warning": warning,
			"active_cursor": _get_active_cursor_info(project)
		}
	}


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

	# Deep-clone pixels from source to destination
	var src_image: Image = src_cel.get_image()
	var copy_img = Image.create_empty(src_image.get_width(), src_image.get_height(), false, Image.FORMAT_RGBA8)
	copy_img.copy_from(src_image)

	var used_rect := src_image.get_used_rect()
	var pixels_copied := 0
	if used_rect.size.x > 0 and used_rect.size.y > 0:
		for y in range(used_rect.position.y, used_rect.end.y):
			for x in range(used_rect.position.x, used_rect.end.x):
				if src_image.get_pixel(x, y).a > 0.001:
					pixels_copied += 1

	_commit_image_change(copy_img, "Copy Cel", dst_frame, dst_layer)

	var canvas = _api.general.get_canvas()
	if canvas:
		if "project_changed" in canvas:
			canvas.project_changed = true
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	var result_data: Dictionary = {
		"src_frame": src_frame,
		"src_layer": src_layer,
		"dst_frame": dst_frame,
		"dst_layer": dst_layer,
		"pixels_copied": pixels_copied
	}
	if pixels_copied == 0:
		result_data["warning"] = "Source cel was completely transparent"

	return {"success": true, "data": result_data}


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
	if palettes_autoload == null:
		return {"success": false, "error": "Palettes singleton not available"}

	var name: String = params.get("name", "New Palette")
	var width: int = int(params.get("width", 8))
	var height: int = int(params.get("height", 8))
	var is_global: bool = bool(params.get("is_global", true))

	if width <= 0:
		width = 8
	if height <= 0:
		height = 8

	var colors_arr: Array = params.get("colors", [])
	if colors_arr.size() > (width * height):
		height = int(ceil(float(colors_arr.size()) / float(width)))

	palettes_autoload.create_new_palette(0, name, "", width, height, false, 0, is_global)
	var current_palette = palettes_autoload.current_palette

	var added := 0
	if current_palette and colors_arr.size() > 0:
		for c_val in colors_arr:
			if c_val is String and Color.html_is_valid(c_val):
				if not current_palette.is_full():
					current_palette.add_color(Color.html(c_val))
					added += 1
		palettes_autoload.save_palette()

	if current_palette:
		palettes_autoload.select_palette(current_palette.name)
		if palettes_autoload.has_signal("new_palette_created"):
			palettes_autoload.new_palette_created.emit()
		var global_node = _api.get_node_or_null("/root/Global")
		if global_node and global_node.has_signal("palette_panel_updated"):
			global_node.palette_panel_updated.emit()

	var actual_w: int = int(current_palette.width) if current_palette else width
	var actual_h: int = int(current_palette.height) if current_palette else height
	return {
		"success": true,
		"data": {
			"name": name,
			"width": actual_w,
			"height": actual_h,
			"is_global": is_global,
			"colors_added": added
		}
	}


func _cmd_add_palette_color(params: Dictionary) -> Dictionary:
	var palettes_autoload = _api.palette.autoload()
	if palettes_autoload == null:
		return {"success": false, "error": "Palettes singleton not available"}

	var current_palette = palettes_autoload.current_palette
	if current_palette == null:
		return {"success": false, "error": "No active palette"}

	var colors_arr: Array = params.get("colors", [])
	var single_color = params.get("color", "")
	if colors_arr.is_empty() and single_color != "":
		colors_arr = [single_color]

	if colors_arr.is_empty():
		return {"success": false, "error": "Missing 'color' or 'colors' parameter"}

	if current_palette.is_full():
		return {
			"success": false,
			"error": "Palette '%s' is full (%d/%d swatches used)" % [
				current_palette.name,
				current_palette.colors.size(),
				current_palette.width * current_palette.height
			]
		}

	var added := 0
	for c_val in colors_arr:
		if c_val is String and Color.html_is_valid(c_val):
			if not current_palette.is_full():
				current_palette.add_color(Color.html(c_val))
				added += 1

	if added == 0:
		return {"success": false, "error": "No valid colors were added to palette '%s'" % current_palette.name}

	palettes_autoload.save_palette()

	var global_node = _api.get_node_or_null("/root/Global")
	if global_node and global_node.has_signal("palette_panel_updated"):
		global_node.palette_panel_updated.emit()

	return {"success": true, "data": {"colors_added": added, "palette_name": current_palette.name}}


func _cmd_set_palette_color(params: Dictionary) -> Dictionary:
	var palettes_autoload = _api.palette.autoload()
	if palettes_autoload == null:
		return {"success": false, "error": "Palettes singleton not available"}

	var current_palette = palettes_autoload.current_palette
	if current_palette == null:
		return {"success": false, "error": "No active palette"}

	var index: int = params.get("index", -1)
	if index < 0 or index >= (current_palette.width * current_palette.height):
		return {"success": false, "error": "Invalid index: %d" % index}

	var color := _parse_color(params)
	current_palette.set_color(index, color)
	palettes_autoload.save_palette()

	var global_node = _api.get_node_or_null("/root/Global")
	if global_node and global_node.has_signal("palette_panel_updated"):
		global_node.palette_panel_updated.emit()

	return {"success": true, "data": {"index": index, "color": color.to_html()}}


func _cmd_list_palettes(_params: Dictionary) -> Dictionary:
	var palettes_autoload = _api.palette.autoload()
	if palettes_autoload == null:
		return {"success": false, "error": "Palettes singleton not available"}

	var project = _api.project.current_project
	var active_name: String = palettes_autoload.current_palette.name if palettes_autoload.current_palette else ""
	var pal_list: Array = []

	# Global palettes
	if "palettes" in palettes_autoload and palettes_autoload.palettes is Dictionary:
		for pal_name in palettes_autoload.palettes.keys():
			var pal = palettes_autoload.palettes[pal_name]
			if pal:
				pal_list.append({
					"name": pal.name,
					"width": pal.width,
					"height": pal.height,
					"colors_count": pal.colors.size(),
					"is_global": true,
					"is_active": (pal.name == active_name)
				})

	# Project palettes
	if project and "palettes" in project and project.palettes is Dictionary:
		for pal_name in project.palettes.keys():
			var pal = project.palettes[pal_name]
			if pal:
				pal_list.append({
					"name": pal.name,
					"width": pal.width,
					"height": pal.height,
					"colors_count": pal.colors.size(),
					"is_global": false,
					"is_active": (pal.name == active_name)
				})

	return {
		"success": true,
		"data": {
			"palettes": pal_list,
			"active_palette": active_name,
			"total": pal_list.size()
		}
	}


func _cmd_switch_palette(params: Dictionary) -> Dictionary:
	var palettes_autoload = _api.palette.autoload()
	if palettes_autoload == null:
		return {"success": false, "error": "Palettes singleton not available"}

	var name: String = params.get("name", "")
	if name.is_empty():
		return {"success": false, "error": "Missing 'name' parameter"}

	palettes_autoload.select_palette(name)
	var current = palettes_autoload.current_palette
	if current == null or current.name != name:
		return {"success": false, "error": "Palette '%s' not found" % name}

	var global_node = _api.get_node_or_null("/root/Global")
	if global_node and global_node.has_signal("palette_panel_updated"):
		global_node.palette_panel_updated.emit()

	return {
		"success": true,
		"data": {
			"name": current.name,
			"width": current.width,
			"height": current.height,
			"colors_count": current.colors.size(),
			"is_global": not current.is_project_palette if "is_project_palette" in current else true
		}
	}


func _cmd_delete_palette(params: Dictionary) -> Dictionary:
	var palettes_autoload = _api.palette.autoload()
	if palettes_autoload == null:
		return {"success": false, "error": "Palettes singleton not available"}

	var name: String = params.get("name", "")
	if name.is_empty():
		return {"success": false, "error": "Missing 'name' parameter"}

	var target_palette = null
	if "palettes" in palettes_autoload and palettes_autoload.palettes is Dictionary and palettes_autoload.palettes.has(name):
		target_palette = palettes_autoload.palettes[name]
	else:
		var project = _api.project.current_project
		if project and "palettes" in project and project.palettes is Dictionary and project.palettes.has(name):
			target_palette = project.palettes[name]

	if target_palette == null:
		return {"success": false, "error": "Palette '%s' not found" % name}

	palettes_autoload.palette_delete_and_reselect(true, target_palette)
	var new_active: String = palettes_autoload.current_palette.name if palettes_autoload.current_palette else ""

	var global_node = _api.get_node_or_null("/root/Global")
	if global_node and global_node.has_signal("palette_panel_updated"):
		global_node.palette_panel_updated.emit()

	return {
		"success": true,
		"data": {
			"deleted": name,
			"active_palette": new_active,
			"message": "Palette '%s' deleted. Active palette is now '%s'" % [name, new_active]
		}
	}


# ==============================================================================
# Area 1: Project & Asset Management
# ==============================================================================

func _cmd_open_project(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return {"success": false, "error": "Missing 'path' parameter"}
	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File does not exist: %s" % path}

	var open_save = _api.import.open_save_autoload()
	if open_save == null:
		open_save = _api.get_node_or_null("/root/OpenSave")

	if open_save and open_save.has_method("open_pxo_file"):
		open_save.open_pxo_file(path, false, false)
	else:
		return {"success": false, "error": "OpenSave singleton not available"}

	var project = _api.project.current_project
	if project:
		return {
			"success": true,
			"data": {
				"name": project.name,
				"width": int(project.size.x),
				"height": int(project.size.y),
				"layers": project.layers.size(),
				"frames": project.frames.size(),
				"path": path
			}
		}
	return {"success": false, "error": "Failed to open project"}


func _cmd_import_spritesheet(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var frame_width: int = int(params.get("frame_width", 32))
	var frame_height: int = int(params.get("frame_height", 32))
	var start_frame: int = int(params.get("start_frame", 0))
	var max_frames: int = int(params.get("max_frames", -1))
	var layer_idx: int = int(params.get("layer", -1))

	if path.is_empty() or not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: %s" % path}
	if frame_width <= 0 or frame_height <= 0:
		return {"success": false, "error": "Invalid frame dimensions: %dx%d" % [frame_width, frame_height]}

	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return {"success": false, "error": "Failed to load spritesheet image from %s" % path}

	var cols: int = int(img.get_width() / frame_width)
	var rows: int = int(img.get_height() / frame_height)
	var total_tiles: int = cols * rows
	if total_tiles <= 0:
		return {"success": false, "error": "Spritesheet dimensions smaller than single frame"}

	var num_frames: int = total_tiles if max_frames <= 0 else mini(max_frames, total_tiles)
	var project = _api.project.current_project
	if project == null:
		var fallback_frames: Array = []
		var fallback_frame_script = load("res://src/Classes/Frame.gd")
		if fallback_frame_script:
			fallback_frames = Array([], TYPE_OBJECT, "RefCounted", fallback_frame_script)
		project = _api.project.new_project(fallback_frames, path.get_file().get_basename(), Vector2(frame_width, frame_height), Color.TRANSPARENT)
		_api.project.current_project = project

	var target_layer: int = layer_idx if layer_idx >= 0 else project.current_layer
	target_layer = clampi(target_layer, 0, project.layers.size() - 1)

	var frame_counter := 0
	for r in range(rows):
		for c in range(cols):
			if frame_counter >= num_frames:
				break
			var target_frame_idx := start_frame + frame_counter
			while target_frame_idx >= project.frames.size():
				_api.project.add_new_frame(project.frames.size() - 1)

			var tile_rect := Rect2i(c * frame_width, r * frame_height, frame_width, frame_height)
			var tile_img := Image.create_empty(frame_width, frame_height, false, Image.FORMAT_RGBA8)
			tile_img.blit_rect(img, tile_rect, Vector2i.ZERO)
			_api.project.set_pixelcel_image(tile_img, target_frame_idx, target_layer)
			frame_counter += 1

	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	return {
		"success": true,
		"data": {
			"frames_imported": frame_counter,
			"frame_size": [frame_width, frame_height],
			"columns": cols,
			"rows": rows,
			"total_frames": project.frames.size()
		}
	}


class SafeMedianCutQuant extends RefCounted:
	var transparency: bool = false

	func quantize(image: Image) -> Array:
		var data: PackedByteArray = image.get_data()
		var unique_colors: Dictionary = {}
		var pixels: Array = []
		transparency = false

		for i in range(0, data.size(), 4):
			if data[i + 3] == 0:
				transparency = true
				continue
			var r = data[i]
			var g = data[i + 1]
			var b = data[i + 2]
			var key = (r << 16) | (g << 8) | b
			if not key in unique_colors:
				unique_colors[key] = [r, g, b]
			pixels.append([r, g, b])

		if pixels.size() == 0:
			return [PackedByteArray(), [], transparency]

		var max_palette_size: int = 255 if transparency else 256
		var color_array: Array = []

		if unique_colors.size() <= max_palette_size:
			color_array = unique_colors.values()
		else:
			var buckets := [pixels]
			for step in range(8):
				var next_buckets := []
				for b in buckets:
					if b.size() > 1:
						var cut_res = _median_cut_bucket(b)
						if cut_res[0].size() == 0 or cut_res[1].size() == 0:
							next_buckets += cut_res
						else:
							next_buckets += cut_res
					else:
						next_buckets.append(b)
				buckets = next_buckets

			var avg_colors: Dictionary = {}
			for b in buckets:
				if b.size() > 0:
					var avg = _avg_bucket(b)
					avg_colors[avg] = true
			color_array = avg_colors.keys()

			while color_array.size() > max_palette_size:
				color_array.pop_back()

		if transparency:
			color_array = [[0, 0, 0]] + color_array

		var codes := _map_pixels_to_codes(image, color_array, transparency)
		return [codes, color_array, transparency]

	func _median_cut_bucket(colors: Array) -> Array:
		var min_c := [255, 255, 255]
		var max_c := [0, 0, 0]
		for c in colors:
			for ch in range(3):
				min_c[ch] = mini(c[ch], min_c[ch])
				max_c[ch] = maxi(c[ch], max_c[ch])
		var dr: int = int(max_c[0]) - int(min_c[0])
		var dg: int = int(max_c[1]) - int(min_c[1])
		var db: int = int(max_c[2]) - int(min_c[2])
		var axis := 0
		if dg > dr and dg >= db:
			axis = 1
		elif db > dr and db >= dg:
			axis = 2

		var axis_vals: Array = []
		for c in colors:
			axis_vals.append(c[axis])
		axis_vals.sort()
		var median_val: int = axis_vals[axis_vals.size() >> 1]

		var left := []
		var right := []
		for c in colors:
			if c[axis] < median_val:
				left.append(c)
			else:
				right.append(c)
		return [left, right]

	func _avg_bucket(b: Array) -> Array:
		var r := 0
		var g := 0
		var b_tot := 0
		var sz := b.size()
		for c in b:
			r += c[0]
			g += c[1]
			b_tot += c[2]
		return [r / sz, g / sz, b_tot / sz]

	func _map_pixels_to_codes(image: Image, colors: Array, has_transparency: bool) -> PackedByteArray:
		var gpu_res := _try_gpu(image, colors)
		if not gpu_res.is_empty():
			return gpu_res
		return _cpu_map(image, colors, has_transparency)

	func _try_gpu(image: Image, colors: Array) -> PackedByteArray:
		if DisplayServer.get_name() == "headless":
			return PackedByteArray()
		var shader: Shader = null
		if ResourceLoader.exists("res://lookup_similar.gdshader"):
			shader = load("res://lookup_similar.gdshader") as Shader
		elif ResourceLoader.exists("res://addons/gdgifexporter/lookup_similar.gdshader"):
			shader = load("res://addons/gdgifexporter/lookup_similar.gdshader") as Shader
		if shader == null:
			return PackedByteArray()

		var vp := RenderingServer.viewport_create()
		var canvas := RenderingServer.canvas_create()
		RenderingServer.viewport_attach_canvas(vp, canvas)
		RenderingServer.viewport_set_size(vp, image.get_width(), image.get_height())
		RenderingServer.viewport_set_disable_3d(vp, true)
		RenderingServer.viewport_set_active(vp, true)

		var ci_rid := RenderingServer.canvas_item_create()
		RenderingServer.viewport_set_canvas_transform(vp, canvas, Transform3D())
		RenderingServer.canvas_item_set_parent(ci_rid, canvas)
		var texture := ImageTexture.create_from_image(image)
		RenderingServer.canvas_item_add_texture_rect(ci_rid, Rect2(Vector2.ZERO, image.get_size()), texture)

		var mat_rid := RenderingServer.material_create()
		RenderingServer.material_set_shader(mat_rid, shader.get_rid())
		var lut := Image.create(256, 1, false, Image.FORMAT_RGB8)
		lut.fill(Color8(colors[0][0], colors[0][1], colors[0][2]))
		for i in colors.size():
			lut.set_pixel(i, 0, Color8(colors[i][0], colors[i][1], colors[i][2]))
		var lut_tex := ImageTexture.create_from_image(lut)
		RenderingServer.material_set_param(mat_rid, "lut", [lut_tex])
		RenderingServer.canvas_item_set_material(ci_rid, mat_rid)

		RenderingServer.viewport_set_update_mode(vp, RenderingServer.VIEWPORT_UPDATE_ONCE)
		RenderingServer.force_draw(false)
		var rendered = RenderingServer.texture_2d_get(RenderingServer.viewport_get_texture(vp))

		RenderingServer.free_rid(vp)
		RenderingServer.free_rid(canvas)
		RenderingServer.free_rid(ci_rid)
		RenderingServer.free_rid(mat_rid)

		if rendered != null and not rendered.is_empty():
			rendered.convert(Image.FORMAT_R8)
			return rendered.get_data()

		return PackedByteArray()

	func _cpu_map(image: Image, colors: Array, has_transparency: bool) -> PackedByteArray:
		var w := image.get_width()
		var h := image.get_height()
		var data: PackedByteArray = image.get_data()
		var result: PackedByteArray = PackedByteArray()
		result.resize(w * h)

		var cache: Dictionary = {}
		var colors_sz := colors.size()
		var start_idx := 1 if has_transparency else 0
		var out_idx := 0

		for i in range(0, data.size(), 4):
			if data[i + 3] == 0:
				result[out_idx] = 0
				out_idx += 1
				continue

			var r := int(data[i])
			var g := int(data[i + 1])
			var b := int(data[i + 2])
			var key := (r << 16) | (g << 8) | b
			var c_idx = cache.get(key, -1)
			if c_idx != -1:
				result[out_idx] = c_idx
			else:
				var best_idx := start_idx
				var best_dist := 99999999
				for ci in range(start_idx, colors_sz):
					var dr: int = r - int(colors[ci][0])
					var dg: int = g - int(colors[ci][1])
					var db: int = b - int(colors[ci][2])
					var dist: int = dr * dr + dg * dg + db * db
					if dist < best_dist:
						best_dist = dist
						best_idx = ci
						if dist <= 2:
							break
				cache[key] = best_idx
				result[out_idx] = best_idx
			out_idx += 1

		return result


func _cmd_export_gif(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return {"success": false, "error": "Missing 'path' parameter"}
	if not path.ends_with(".gif"):
		path += ".gif"

	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var dir_name := path.get_base_dir()
	if dir_name != "" and not DirAccess.dir_exists_absolute(dir_name):
		DirAccess.make_dir_recursive_absolute(dir_name)

	var GIFExporterClass = load("res://addons/gdgifexporter/exporter.gd")
	if not GIFExporterClass:
		return {"success": false, "error": "GIF exporter not supported in this build"}

	var exporter = GIFExporterClass.new(int(project.size.x), int(project.size.y))
	var total_frames: int = project.frames.size()

	for i in range(total_frames):
		var frame_img = _blend_frame_layers(project, i)
		var duration: float = project.frames[i].duration / maxf(0.1, float(project.fps))
		var add_err = exporter.add_frame(frame_img, duration, SafeMedianCutQuant)
		if add_err != 0:
			push_warning(LOG_TAG + "Frame %d add returned status: %d" % [i, add_err])

	var file_data: PackedByteArray = exporter.export_file_data()
	if file_data.is_empty():
		return {"success": false, "error": "Failed to generate GIF data"}

	var fa = FileAccess.open(path, FileAccess.WRITE)
	if fa:
		fa.store_buffer(file_data)
		fa.close()
		return {
			"success": true,
			"data": {
				"path": path,
				"frames": total_frames,
				"size_bytes": file_data.size(),
				"width": int(project.size.x),
				"height": int(project.size.y)
			}
		}
	else:
		return {"success": false, "error": "Failed to open output path: %s" % path}


func _cmd_export_apng(params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return {"success": false, "error": "Missing 'path' parameter"}
	if not path.ends_with(".apng") and not path.ends_with(".png"):
		path += ".apng"

	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var dir_name := path.get_base_dir()
	if dir_name != "" and not DirAccess.dir_exists_absolute(dir_name):
		DirAccess.make_dir_recursive_absolute(dir_name)

	var frame_count: int = project.frames.size()
	var apng_stream_script = load("res://addons/aimg_io/apng_stream.gd")
	if not apng_stream_script:
		var first_img = _blend_frame_layers(project, 0)
		var err = first_img.save_png(path)
		if err == OK:
			return {"success": true, "data": {"path": path, "frames": 1, "format": "png", "warning": "APNG stream writer not available, saved standard PNG"}}
		return {"success": false, "error": "Failed to export APNG to %s" % path}

	var first_frame_img := _blend_frame_layers(project, 0)
	var w := first_frame_img.get_width()
	var h := first_frame_img.get_height()
	var fps: float = maxf(1.0, float(project.fps))

	var stream = apng_stream_script.new()
	stream.write_magic()

	# 1. IHDR
	var chunk = stream.start_chunk()
	chunk.put_32(w)
	chunk.put_32(h)
	chunk.put_32(0x08060000) # bit depth 8, color type 6 (RGBA)
	chunk.put_8(0)
	stream.write_chunk("IHDR", chunk.data_array)

	# 2. acTL (animation control)
	chunk = stream.start_chunk()
	chunk.put_32(frame_count)
	chunk.put_32(0) # 0 = infinite loop
	stream.write_chunk("acTL", chunk.data_array)

	var sequence := 0
	for i in range(frame_count):
		var img := _blend_frame_layers(project, i)
		img.convert(Image.FORMAT_RGBA8)

		# 3. fcTL (frame control)
		chunk = stream.start_chunk()
		chunk.put_32(sequence)
		sequence += 1
		chunk.put_32(w)
		chunk.put_32(h)
		chunk.put_32(0) # x offset
		chunk.put_32(0) # y offset

		# Frame delay calculation
		var duration: float = maxf(0.01, project.frames[i].duration)
		var den: int = clampi(int(round(fps)), 1, 32767)
		var num: float = duration * float(den)
		while num < 16384 and den < 16384:
			num *= 2
			den *= 2
		chunk.put_16(int(round(num)))
		chunk.put_16(den)

		chunk.put_8(0) # dispose_op: 0 (none)
		chunk.put_8(0) # blend_op: 0 (source)
		stream.write_chunk("fcTL", chunk.data_array)

		# 4. IDAT (frame 0) or fdAT (frames > 0)
		chunk = stream.start_chunk()
		if i != 0:
			chunk.put_32(sequence)
			sequence += 1

		var raw_data: PackedByteArray = img.get_data()
		var scanlines := StreamPeerBuffer.new()
		for y in range(h):
			scanlines.put_8(0) # filter type 0 (None)
			scanlines.put_data(raw_data.slice(y * w * 4, (y + 1) * w * 4))

		var compressed: PackedByteArray = scanlines.data_array.compress(FileAccess.COMPRESSION_DEFLATE)
		chunk.put_data(compressed)

		if i == 0:
			stream.write_chunk("IDAT", chunk.data_array)
		else:
			stream.write_chunk("fdAT", chunk.data_array)

	# 5. IEND
	stream.write_chunk("IEND", PackedByteArray())

	var file_bytes: PackedByteArray = stream.finish()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "error": "Failed to write APNG to file: %s" % path}
	file.store_buffer(file_bytes)
	file.close()

	return {
		"success": true,
		"data": {
			"path": path,
			"frames": frame_count,
			"format": "apng",
			"size_bytes": file_bytes.size()
		}
	}


func _cmd_export_aseprite_json(params: Dictionary) -> Dictionary:
	var target_dir: String = params.get("target_dir", "")
	var base_name: String = params.get("base_name", "")
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	if target_dir.is_empty():
		return {"success": false, "error": "Missing 'target_dir' parameter"}
	if base_name.is_empty():
		base_name = project.name if not project.name.is_empty() else "spritesheet"

	var frame_w := int(project.size.x)
	var frame_h := int(project.size.y)
	var total_frames: int = project.frames.size()
	var sheet_img := Image.create_empty(frame_w * total_frames, frame_h, false, Image.FORMAT_RGBA8)

	var frames_dict: Dictionary = {}
	for i in range(total_frames):
		var blended = _blend_frame_layers(project, i)
		sheet_img.blit_rect(blended, Rect2i(0, 0, frame_w, frame_h), Vector2i(i * frame_w, 0))
		var duration_ms: int = int((project.frames[i].duration / maxf(0.1, float(project.fps))) * 1000.0)
		frames_dict["%s_%d" % [base_name, i]] = {
			"frame": {"x": i * frame_w, "y": 0, "w": frame_w, "h": frame_h},
			"rotated": false,
			"trimmed": false,
			"spriteSourceSize": {"x": 0, "y": 0, "w": frame_w, "h": frame_h},
			"sourceSize": {"w": frame_w, "h": frame_h},
			"duration": duration_ms
		}

	var tags_list: Array = []
	for tag in project.animation_tags:
		tags_list.append({
			"name": tag.name,
			"from": tag.from - 1,
			"to": tag.to - 1,
			"direction": "forward",
			"color": tag.color.to_html()
		})

	var meta_dict: Dictionary = {
		"app": "Pixelorama-MCP",
		"version": "0.3.0",
		"image": "%s.png" % base_name,
		"format": "RGBA8888",
		"size": {"w": frame_w * total_frames, "h": frame_h},
		"scale": "1",
		"frameTags": tags_list
	}

	var out_png_path = target_dir.path_join("%s.png" % base_name)
	var out_json_path = target_dir.path_join("%s.json" % base_name)

	sheet_img.save_png(out_png_path)
	var json_str = JSON.stringify({"frames": frames_dict, "meta": meta_dict}, "\t")
	var fa = FileAccess.open(out_json_path, FileAccess.WRITE)
	if fa:
		fa.store_string(json_str)
		fa.close()

	return {
		"success": true,
		"data": {
			"png_path": out_png_path,
			"json_path": out_json_path,
			"frames_count": total_frames,
			"tags_count": tags_list.size()
		}
	}


# ==============================================================================
# Area 2: Animation Superchargers & Timeline
# ==============================================================================

func _cmd_add_animation_tag(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var tag_name: String = params.get("name", "anim")
	var from_frame: int = int(params.get("from_frame", 0))
	var to_frame: int = int(params.get("to_frame", project.frames.size() - 1))
	var color_hex: String = params.get("color", "#ff5500")

	from_frame = clampi(from_frame, 0, project.frames.size() - 1)
	to_frame = clampi(to_frame, from_frame, project.frames.size() - 1)

	var tag_color := Color.html(color_hex) if Color.html_is_valid(color_hex) else Color(randf(), randf(), randf())

	var AnimationTagClass = load("res://src/Classes/AnimationTag.gd")
	if AnimationTagClass:
		var new_tag = AnimationTagClass.new(tag_name, tag_color, from_frame + 1, to_frame + 1)
		project.animation_tags.append(new_tag)
		project.animation_tags = project.animation_tags

		return {
			"success": true,
			"data": {
				"name": tag_name,
				"from_frame": from_frame,
				"to_frame": to_frame,
				"color": tag_color.to_html(),
				"total_tags": project.animation_tags.size()
			}
		}

	return {"success": false, "error": "AnimationTag class not available"}


func _cmd_get_animation_tags(_params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var tags_data: Array = []
	for i in range(project.animation_tags.size()):
		var tag = project.animation_tags[i]
		tags_data.append({
			"index": i,
			"name": tag.name,
			"from_frame": tag.from - 1,
			"to_frame": tag.to - 1,
			"color": tag.color.to_html(),
			"frames_count": (tag.to - tag.from) + 1
		})

	return {"success": true, "data": {"tags": tags_data, "total": tags_data.size()}}


func _cmd_delete_animation_tag(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var target_index: int = int(params.get("index", -1))
	var target_name: String = params.get("name", "")

	if target_index < 0 and not target_name.is_empty():
		for i in range(project.animation_tags.size()):
			if project.animation_tags[i].name == target_name:
				target_index = i
				break

	if target_index >= 0 and target_index < project.animation_tags.size():
		var deleted_name = project.animation_tags[target_index].name
		project.animation_tags.remove_at(target_index)
		project.animation_tags = project.animation_tags
		return {"success": true, "data": {"deleted": deleted_name, "remaining_tags": project.animation_tags.size()}}

	return {"success": false, "error": "Animation tag not found"}


func _cmd_reverse_frames(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var from_idx: int = int(params.get("from_frame", 0))
	var to_idx: int = int(params.get("to_frame", project.frames.size() - 1))

	from_idx = clampi(from_idx, 0, project.frames.size() - 1)
	to_idx = clampi(to_idx, from_idx, project.frames.size() - 1)

	var sub_slice: Array = project.frames.slice(from_idx, to_idx + 1)
	sub_slice.reverse()
	for i in range(sub_slice.size()):
		project.frames[from_idx + i] = sub_slice[i]

	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	return {"success": true, "data": {"reversed_from": from_idx, "reversed_to": to_idx, "total_frames": project.frames.size()}}


func _cmd_tween_cel(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var src_frame: int = int(params.get("src_frame", 0))
	var dst_frame: int = int(params.get("dst_frame", project.frames.size() - 1))
	var layer_idx: int = int(params.get("layer", project.current_layer))
	var dx: int = int(params.get("dx", 0))
	var dy: int = int(params.get("dy", 0))

	if src_frame < 0 or src_frame >= project.frames.size() or dst_frame < 0 or dst_frame >= project.frames.size():
		return {"success": false, "error": "Invalid frame indices"}
	if layer_idx < 0 or layer_idx >= project.layers.size():
		return {"success": false, "error": "Invalid layer index"}

	var span := absi(dst_frame - src_frame)
	if span == 0:
		return {"success": true, "data": {"message": "src_frame equals dst_frame"}}

	var src_cel = project.frames[src_frame].cels[layer_idx]
	if src_cel.get_class_name() != "PixelCel":
		return {"success": false, "error": "Source cel is not a PixelCel"}

	var base_img = src_cel.get_image()
	var step_dir := 1 if dst_frame > src_frame else -1

	for step in range(1, span + 1):
		var target_f := src_frame + (step * step_dir)
		var t := float(step) / float(span)
		var cur_dx := int(round(float(dx) * t))
		var cur_dy := int(round(float(dy) * t))

		var tween_img = Image.create_empty(base_img.get_width(), base_img.get_height(), false, Image.FORMAT_RGBA8)
		tween_img.blit_rect(base_img, Rect2i(Vector2i.ZERO, base_img.get_size()), Vector2i(cur_dx, cur_dy))
		_api.project.set_pixelcel_image(tween_img, target_f, layer_idx)

	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	return {"success": true, "data": {"tweened_frames": span, "layer": layer_idx, "dx": dx, "dy": dy}}


# ==============================================================================
# Area 3: Advanced Selections & Floating Transforms
# ==============================================================================

func _cmd_select_by_color(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var target_hex: String = params.get("color", "")
	var tolerance: float = float(params.get("tolerance", 0.05))
	var contiguous: bool = bool(params.get("contiguous", false))
	var start_x: int = int(params.get("start_x", 0))
	var start_y: int = int(params.get("start_y", 0))

	if target_hex.is_empty() or not Color.html_is_valid(target_hex):
		return {"success": false, "error": "Invalid hex color"}

	var target_color = Color.html(target_hex)
	var img = _get_current_image()
	if img == null:
		return {"success": false, "error": "No active image"}

	var w := int(project.size.x)
	var h := int(project.size.y)
	var selected_count := 0

	project.selection_map.clear()
	if project.selection_map.get_size() != Vector2i(w, h):
		project.selection_map.copy_from(Image.create_empty(w, h, false, Image.FORMAT_LA8))

	if contiguous:
		var visited: Dictionary = {}
		var queue: Array[Vector2i] = [Vector2i(start_x, start_y)]
		while not queue.is_empty():
			var p = queue.pop_front()
			if p.x < 0 or p.x >= w or p.y < 0 or p.y >= h or visited.has(p):
				continue
			visited[p] = true
			var col = img.get_pixelv(p)
			if _color_distance(col, target_color) <= tolerance:
				project.selection_map.set_pixel(p.x, p.y, Color(1, 1, 1, 1))
				selected_count += 1
				queue.append(Vector2i(p.x + 1, p.y))
				queue.append(Vector2i(p.x - 1, p.y))
				queue.append(Vector2i(p.x, p.y + 1))
				queue.append(Vector2i(p.x, p.y - 1))
	else:
		for y in range(h):
			for x in range(w):
				var col = img.get_pixel(x, y)
				if _color_distance(col, target_color) <= tolerance:
					project.selection_map.set_pixel(x, y, Color(1, 1, 1, 1))
					selected_count += 1

	project.selection_map_changed()
	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.queue_redraw()

	return {"success": true, "data": {"color": target_hex, "selected_pixels": selected_count, "contiguous": contiguous}}


func _cmd_invert_selection(_params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var w := int(project.size.x)
	var h := int(project.size.y)
	for y in range(h):
		for x in range(w):
			var cur = project.selection_map.get_pixel(x, y)
			var new_a = 0.0 if cur.a > 0.1 else 1.0
			project.selection_map.set_pixel(x, y, Color(1, 1, 1, new_a))

	project.selection_map_changed()
	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.queue_redraw()

	return {"success": true, "data": {"has_selection": project.has_selection}}


func _cmd_transform_selection(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}
	if not project.has_selection:
		return {"success": false, "error": "No active selection to transform"}

	var dx: int = int(params.get("dx", 0))
	var dy: int = int(params.get("dy", 0))

	var img = _get_current_image()
	if img == null:
		return {"success": false, "error": "No active image"}

	var w := int(project.size.x)
	var h := int(project.size.y)
	var selected_pixels: Dictionary = {}

	for y in range(h):
		for x in range(w):
			if project.selection_map.get_pixel(x, y).a > 0.1:
				selected_pixels[Vector2i(x, y)] = img.get_pixel(x, y)
				img.set_pixel(x, y, Color.TRANSPARENT)

	var new_selection_map = Image.create_empty(w, h, false, Image.FORMAT_LA8)
	for p in selected_pixels.keys():
		var col: Color = selected_pixels[p]
		var nx: int = p.x + dx
		var ny: int = p.y + dy
		if nx >= 0 and nx < w and ny >= 0 and ny < h:
			img.set_pixel(nx, ny, col)
			new_selection_map.set_pixel(nx, ny, Color(1, 1, 1, 1))

	project.selection_map.copy_from(new_selection_map)
	project.selection_map_changed()
	_commit_image_change(img, "Transform Selection", project.current_frame, project.current_layer)

	return {"success": true, "data": {"dx": dx, "dy": dy, "transformed_pixels": selected_pixels.size()}}


# ==============================================================================
# Area 4: Layer Operations & Organization
# ==============================================================================

func _cmd_duplicate_layer(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var src_idx: int = int(params.get("index", project.current_layer))
	if src_idx < 0 or src_idx >= project.layers.size():
		return {"success": false, "error": "Invalid layer index: %d" % src_idx}

	var src_layer = project.layers[src_idx]
	var new_name = src_layer.name + " Copy"
	_api.project.add_new_layer(src_idx, new_name, 0)

	var new_layer_idx := src_idx + 1
	for f in range(project.frames.size()):
		var src_cel = project.frames[f].cels[src_idx]
		if src_cel.get_class_name() == "PixelCel":
			var src_img = src_cel.get_image()
			var clone_img = Image.create_empty(src_img.get_width(), src_img.get_height(), false, Image.FORMAT_RGBA8)
			clone_img.copy_from(src_img)
			_api.project.set_pixelcel_image(clone_img, f, new_layer_idx)

	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	return {"success": true, "data": {"source_index": src_idx, "new_index": new_layer_idx, "name": new_name, "total_layers": project.layers.size()}}


func _cmd_merge_layers(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}
	if project.layers.size() <= 1:
		return {"success": false, "error": "Cannot merge when only 1 layer exists"}

	var src_idx: int = int(params.get("source_index", project.current_layer))
	var dst_idx: int = int(params.get("target_index", maxi(0, src_idx - 1)))

	if src_idx < 0 or src_idx >= project.layers.size() or dst_idx < 0 or dst_idx >= project.layers.size():
		return {"success": false, "error": "Invalid layer indices"}
	if src_idx == dst_idx:
		return {"success": false, "error": "source_index and target_index cannot be identical"}

	for f in range(project.frames.size()):
		var src_cel = project.frames[f].cels[src_idx]
		var dst_cel = project.frames[f].cels[dst_idx]
		if src_cel.get_class_name() == "PixelCel" and dst_cel.get_class_name() == "PixelCel":
			var src_img = src_cel.get_image()
			var dst_img = dst_cel.get_image()
			var blended = Image.create_empty(dst_img.get_width(), dst_img.get_height(), false, Image.FORMAT_RGBA8)
			blended.copy_from(dst_img)
			blended.blend_rect(src_img, Rect2i(Vector2i.ZERO, src_img.get_size()), Vector2i.ZERO)
			_api.project.set_pixelcel_image(blended, f, dst_idx)

	project.remove_layers(PackedInt32Array([src_idx]))
	project.current_layer = clampi(dst_idx, 0, project.layers.size() - 1)
	_api.project.current_layer = project.current_layer
	_api.project.select_cels([[project.current_frame, project.current_layer]])

	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	return {"success": true, "data": {"merged_into": dst_idx, "remaining_layers": project.layers.size()}}


func _cmd_create_layer_group(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var group_name: String = params.get("name", "Group")
	var above_layer: int = int(params.get("above_layer", project.current_layer))
	above_layer = clampi(above_layer, 0, project.layers.size() - 1)

	_api.project.add_new_layer(above_layer, group_name, 1)

	return {"success": true, "data": {"name": group_name, "type": "GroupLayer", "index": above_layer + 1, "total_layers": project.layers.size()}}


# ==============================================================================
# Area 5: Visual FX & Procedural Polish
# ==============================================================================

func _cmd_apply_drop_shadow(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var offset_x: int = int(params.get("offset_x", 1))
	var offset_y: int = int(params.get("offset_y", 1))
	var shadow_hex: String = params.get("color", "#000000")
	var opacity: float = float(params.get("opacity", 0.5))
	var as_new_layer: bool = bool(params.get("as_new_layer", false))

	var shadow_col := Color.html(shadow_hex) if Color.html_is_valid(shadow_hex) else Color(0, 0, 0, 1)
	shadow_col.a = opacity

	var img: Image = target.image
	var w := img.get_width()
	var h := img.get_height()
	var shadow_img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)

	var shadow_pixel_count := 0
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.05:
				var sx := x + offset_x
				var sy := y + offset_y
				if sx >= 0 and sx < w and sy >= 0 and sy < h:
					shadow_img.set_pixel(sx, sy, shadow_col)
					shadow_pixel_count += 1

	var shadow_layer_idx: int = target.layer
	if as_new_layer:
		if target.layer > 0:
			_api.project.add_new_layer(target.layer - 1, "Shadow", 0)
			shadow_layer_idx = target.layer
		else:
			_api.project.add_new_layer(0, "Shadow", 0)
			_cmd_reorder_layers({"from_index": 1, "to_index": 0})
			shadow_layer_idx = 0
		_api.project.set_pixelcel_image(shadow_img, target.frame, shadow_layer_idx)
	else:
		var final_img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		final_img.blit_rect(shadow_img, Rect2i(0, 0, w, h), Vector2i.ZERO)
		final_img.blend_rect(img, Rect2i(0, 0, w, h), Vector2i.ZERO)
		_commit_image_change(final_img, "Apply Drop Shadow", target.frame, target.layer)

	var canvas = _api.general.get_canvas()
	if canvas:
		if "project_changed" in canvas:
			canvas.project_changed = true
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	return {
		"success": true,
		"data": {
			"shadow_pixels": shadow_pixel_count,
			"offset": [offset_x, offset_y],
			"as_new_layer": as_new_layer,
			"shadow_layer_index": shadow_layer_idx,
			"frame": target.frame,
			"layer": target.layer
		}
	}


func _cmd_apply_glow(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var radius: int = int(params.get("radius", 2))
	var glow_hex: String = params.get("color", "#3498db")
	var intensity: float = float(params.get("intensity", 0.6))
	var as_new_layer: bool = bool(params.get("as_new_layer", false))

	var glow_col := Color.html(glow_hex) if Color.html_is_valid(glow_hex) else Color(0.2, 0.6, 1.0, 1.0)
	var img: Image = target.image

	var w := img.get_width()
	var h := img.get_height()
	var glow_img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)

	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.05:
				for dy in range(-radius, radius + 1):
					for dx in range(-radius, radius + 1):
						var d := Vector2(dx, dy).length()
						if d > 0.0 and d <= float(radius):
							var gx := x + dx
							var gy := y + dy
							if gx >= 0 and gx < w and gy >= 0 and gy < h:
								var falloff := (1.0 - (d / float(radius + 1))) * intensity
								var cur = glow_img.get_pixel(gx, gy)
								var new_a = maxf(cur.a, falloff)
								glow_img.set_pixel(gx, gy, Color(glow_col.r, glow_col.g, glow_col.b, new_a))

	var glow_layer_idx: int = target.layer
	if as_new_layer:
		if target.layer > 0:
			_api.project.add_new_layer(target.layer - 1, "Glow", 0)
			glow_layer_idx = target.layer
		else:
			_api.project.add_new_layer(0, "Glow", 0)
			_cmd_reorder_layers({"from_index": 1, "to_index": 0})
			glow_layer_idx = 0
		_api.project.set_pixelcel_image(glow_img, target.frame, glow_layer_idx)
	else:
		var composite := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		composite.blend_rect(glow_img, Rect2i(0, 0, w, h), Vector2i.ZERO)
		composite.blend_rect(img, Rect2i(0, 0, w, h), Vector2i.ZERO)
		_commit_image_change(composite, "Apply Glow", target.frame, target.layer)

	var canvas = _api.general.get_canvas()
	if canvas:
		if "project_changed" in canvas:
			canvas.project_changed = true
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	return {
		"success": true,
		"data": {
			"radius": radius,
			"color": glow_hex,
			"intensity": intensity,
			"as_new_layer": as_new_layer,
			"glow_layer_index": glow_layer_idx,
			"frame": target.frame,
			"layer": target.layer
		}
	}


func _cmd_apply_gradient(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var project = _api.project.current_project
	var x1: int = int(params.get("x1", 0))
	var y1: int = int(params.get("y1", 0))
	var x2: int = int(params.get("x2", int(project.size.x)))
	var y2: int = int(params.get("y2", int(project.size.y)))
	var col1_hex: String = params.get("color1", "#ffffff")
	var col2_hex: String = params.get("color2", "#000000")
	var dither: bool = bool(params.get("dither", true))
	var grad_type: String = params.get("type", "linear")

	var col1 := Color.html(col1_hex) if Color.html_is_valid(col1_hex) else Color.WHITE
	var col2 := Color.html(col2_hex) if Color.html_is_valid(col2_hex) else Color.BLACK

	var img: Image = target.image

	var rx1 := mini(x1, x2)
	var ry1 := mini(y1, y2)
	var rx2 := maxi(x1, x2)
	var ry2 := maxi(y1, y2)
	var rw := maxf(1.0, float(rx2 - rx1))
	var rh := maxf(1.0, float(ry2 - ry1))

	var bayer4 := [
		[ 0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0 ],
		[12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0 ],
		[ 3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0 ],
		[15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0 ]
	]

	var has_sel: bool = ("has_selection" in project) and project.has_selection
	var sel_map = project.selection_map if ("selection_map" in project) else null

	for y in range(ry1, ry2):
		for x in range(rx1, rx2):
			if x >= 0 and x < int(project.size.x) and y >= 0 and y < int(project.size.y):
				# Clip to active selection mask if selection exists
				if has_sel and sel_map != null:
					if sel_map.get_pixel(x, y).a < 0.01:
						continue

				var t := 0.0
				if grad_type == "radial":
					var cx := float(rx1 + rx2) * 0.5
					var cy := float(ry1 + ry2) * 0.5
					var max_r := maxf(rw, rh) * 0.5
					t = clampf(Vector2(x - cx, y - cy).length() / max_r, 0.0, 1.0)
				else:
					t = clampf(float(y - ry1) / rh, 0.0, 1.0)

				var final_col: Color
				if dither:
					var threshold = bayer4[y % 4][x % 4]
					final_col = col1 if t < threshold else col2
				else:
					final_col = col1.lerp(col2, t)

				img.set_pixel(x, y, final_col)

	_commit_image_change(img, "Apply Gradient", target.frame, target.layer)

	return {
		"success": true,
		"data": {
			"type": grad_type,
			"dither": dither,
			"bounds": [rx1, ry1, rx2, ry2],
			"frame": target.frame,
			"layer": target.layer,
			"selection_clipped": has_sel
		}
	}


func _cmd_check_seamless_tile(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var img: Image = target.image
	var w: int = img.get_width()
	var h: int = img.get_height()

	var tile_w: int = int(params.get("tile_width", 0))
	var tile_h: int = int(params.get("tile_height", 0))
	if tile_w <= 0 or tile_w > w:
		tile_w = w
	if tile_h <= 0 or tile_h > h:
		tile_h = h

	var fix_seams: bool = bool(params.get("fix_seams", false))
	var dry_run: bool = bool(params.get("dry_run", false))

	var cols: int = w / tile_w
	var rows: int = h / tile_h
	var x_mismatches: int = 0
	var y_mismatches: int = 0

	for ty in range(rows):
		for tx in range(cols):
			var ox: int = tx * tile_w
			var oy: int = ty * tile_h

			# Horizontal seams (left edge vs right edge of this tile)
			for y in range(oy, oy + tile_h):
				var left = img.get_pixel(ox, y)
				var right = img.get_pixel(ox + tile_w - 1, y)
				if not left.is_equal_approx(right):
					x_mismatches += 1
					if fix_seams and not dry_run:
						var avg = left.lerp(right, 0.5)
						img.set_pixel(ox, y, avg)
						img.set_pixel(ox + tile_w - 1, y, avg)

			# Vertical seams (top edge vs bottom edge of this tile)
			for x in range(ox, ox + tile_w):
				var top = img.get_pixel(x, oy)
				var bottom = img.get_pixel(x, oy + tile_h - 1)
				if not top.is_equal_approx(bottom):
					y_mismatches += 1
					if fix_seams and not dry_run:
						var avg = top.lerp(bottom, 0.5)
						img.set_pixel(x, oy, avg)
						img.set_pixel(x, oy + tile_h - 1, avg)

	var is_seamless: bool = (x_mismatches == 0 and y_mismatches == 0)
	var actually_fixed: bool = fix_seams and not dry_run and not is_seamless

	if actually_fixed:
		_commit_image_change(img, "Fix Seamless Tile", target.frame, target.layer)
		var canvas = _api.general.get_canvas()
		if canvas:
			if "project_changed" in canvas:
				canvas.project_changed = true
			canvas.set("update_all_layers", true)
			canvas.queue_redraw()

	return {
		"success": true,
		"data": {
			"is_seamless": is_seamless or actually_fixed,
			"horizontal_seam_errors": x_mismatches,
			"vertical_seam_errors": y_mismatches,
			"tiles_checked": cols * rows,
			"tile_width": tile_w,
			"tile_height": tile_h,
			"seams_fixed": actually_fixed,
			"dry_run": dry_run,
			"frame": target.frame,
			"layer": target.layer
		}
	}


# ==============================================================================
# Area 6: Typography, QA & Palettes
# ==============================================================================

func _cmd_draw_text(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var text: String = params.get("text", "")
	var start_x: int = int(params.get("x", 0))
	var start_y: int = int(params.get("y", 0))
	var col_hex: String = params.get("color", "#ffffff")
	var font_size: int = int(params.get("font_size", 8))

	if text.is_empty():
		return {"success": false, "error": "Missing 'text' parameter"}

	var text_col := Color.html(col_hex) if Color.html_is_valid(col_hex) else Color.WHITE
	var img: Image = target.image

	var cur_x := start_x
	var cur_y := start_y
	var chars_drawn := 0

	for ch in text:
		if ch == '\n':
			cur_x = start_x
			cur_y += font_size + 2
			continue

		var glyph_matrix = _get_bitmap_glyph(ch)
		for gy in range(glyph_matrix.size()):
			for gx in range(glyph_matrix[gy].size()):
				if glyph_matrix[gy][gx] == 1:
					var px := cur_x + gx
					var py := cur_y + gy
					if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
						img.set_pixel(px, py, text_col)
		cur_x += glyph_matrix[0].size() + 1
		chars_drawn += 1

	_commit_image_change(img, "Draw Text", target.frame, target.layer)

	return {
		"success": true,
		"data": {
			"text": text,
			"chars_drawn": chars_drawn,
			"pos": [start_x, start_y],
			"frame": target.frame,
			"layer": target.layer
		}
	}


func _cmd_get_palette_usage(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var all_layers: bool = bool(params.get("all_layers", true))
	var frame_idx: int = int(params.get("frame", project.current_frame))
	var img: Image = null

	if all_layers:
		img = _composite_frame_layers(project, frame_idx)
	else:
		var target := _get_target_cel_and_image(params)
		if target.error != "":
			return {"success": false, "error": target.error}
		img = target.image

	if img == null:
		return {"success": false, "error": "No image available to analyze"}

	var counts: Dictionary = {}
	var total_pixels := 0

	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c = img.get_pixel(x, y)
			if c.a > 0.01:
				var hex = c.to_html(true)
				counts[hex] = counts.get(hex, 0) + 1
				total_pixels += 1

	var usage_list: Array = []
	for hex in counts.keys():
		usage_list.append({
			"color": "#" + hex,
			"count": counts[hex],
			"percentage": roundf((float(counts[hex]) / maxf(1.0, float(total_pixels))) * 1000.0) / 10.0
		})

	usage_list.sort_custom(func(a, b): return a.count > b.count)
	return {
		"success": true,
		"data": {
			"all_layers": all_layers,
			"frame": frame_idx,
			"unique_colors_count": usage_list.size(),
			"total_colored_pixels": total_pixels,
			"colors": usage_list
		}
	}


func _cmd_clean_isolated_pixels(_params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var img = _get_current_image()
	if img == null:
		return {"success": false, "error": "No active image"}

	var w := img.get_width()
	var h := img.get_height()
	var cleaned := 0

	for y in range(h):
		for x in range(w):
			var c = img.get_pixel(x, y)
			if c.a > 0.01:
				var matching_neighbors := 0
				var neighbor_offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
				for dir in neighbor_offsets:
					var nx: int = x + dir.x
					var ny: int = y + dir.y
					if nx >= 0 and nx < w and ny >= 0 and ny < h:
						if _color_distance(img.get_pixel(nx, ny), c) < 0.1:
							matching_neighbors += 1
				if matching_neighbors == 0:
					img.set_pixel(x, y, Color.TRANSPARENT)
					cleaned += 1

	if cleaned > 0:
		_commit_image_change(img, "Clean Isolated Pixels", project.current_frame, project.current_layer)

	return {"success": true, "data": {"isolated_pixels_cleaned": cleaned}}


func _cmd_remap_to_palette(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var palette_arr: Array = params.get("palette_colors", [])
	if palette_arr.is_empty():
		return {"success": false, "error": "Missing 'palette_colors' array"}

	var colors: Array[Color] = []
	for hex in palette_arr:
		if Color.html_is_valid(str(hex)):
			colors.append(Color.html(str(hex)))

	if colors.is_empty():
		return {"success": false, "error": "No valid colors in palette_colors"}

	var img = _get_current_image()
	if img == null:
		return {"success": false, "error": "No active image"}

	var remapped_count := 0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c = img.get_pixel(x, y)
			if c.a > 0.01:
				var best_col := colors[0]
				var min_dist := _color_distance(c, colors[0])
				for pal_col in colors:
					var dist := _color_distance(c, pal_col)
					if dist < min_dist:
						min_dist = dist
						best_col = pal_col
				best_col.a = c.a
				img.set_pixel(x, y, best_col)
				remapped_count += 1

	_commit_image_change(img, "Remap to Palette", project.current_frame, project.current_layer)

	return {"success": true, "data": {"remapped_pixels": remapped_count, "palette_size": colors.size()}}


# ==============================================================================
# Area 7: Viewport & Art Guides
# ==============================================================================

func _cmd_set_tile_mode(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var mode_str: String = params.get("mode", "both").to_lower()
	var mode_int := 0
	match mode_str:
		"off", "none": mode_int = 0
		"both", "all": mode_int = 1
		"x", "horizontal": mode_int = 2
		"y", "vertical": mode_int = 3
		_: mode_int = 1

	project.tile_mode = mode_int
	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.queue_redraw()

	return {"success": true, "data": {"tile_mode": mode_str, "mode_int": mode_int}}


func _cmd_set_symmetry_guide(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var horiz: bool = bool(params.get("horizontal", false))
	var vert: bool = bool(params.get("vertical", false))
	var x_pos: int = int(params.get("x_pos", int(project.size.x / 2)))
	var y_pos: int = int(params.get("y_pos", int(project.size.y / 2)))

	project.show_x_symmetry = horiz
	project.show_y_symmetry = vert
	project.x_symmetry_point = x_pos
	project.y_symmetry_point = y_pos

	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.queue_redraw()

	return {"success": true, "data": {"horizontal": horiz, "vertical": vert, "x_symmetry": x_pos, "y_symmetry": y_pos}}


func _cmd_set_onion_skinning(params: Dictionary) -> Dictionary:
	var enabled: bool = bool(params.get("enabled", true))
	var past_frames: int = int(params.get("past_frames", 1))
	var future_frames: int = int(params.get("future_frames", 1))
	var blue_red_tint: bool = bool(params.get("blue_red_tint", true))

	var global = _api.get_node_or_null("/root/Global")
	if global:
		if "onion_skinning" in global:
			global.onion_skinning = enabled
		if "onion_past_frames" in global:
			global.onion_past_frames = past_frames
		if "onion_future_frames" in global:
			global.onion_future_frames = future_frames
		if "onion_skinning_past_color" in global:
			global.onion_skinning_past_color = Color.BLUE if blue_red_tint else Color.WHITE
		if "onion_skinning_future_color" in global:
			global.onion_skinning_future_color = Color.RED if blue_red_tint else Color.WHITE

	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.queue_redraw()

	return {"success": true, "data": {"enabled": enabled, "past_frames": past_frames, "future_frames": future_frames}}


# ==============================================================================
# Internal Helpers
# ==============================================================================

func _color_distance(c1: Color, c2: Color) -> float:
	return absf(c1.r - c2.r) + absf(c1.g - c2.g) + absf(c1.b - c2.b) + absf(c1.a - c2.a)


func _blend_frame_layers(project, frame_idx: int) -> Image:
	return _composite_frame_layers(project, frame_idx)


func _composite_frame_layers(project, frame_idx: int) -> Image:
	var w := int(project.size.x)
	var h := int(project.size.y)
	var blended := Image.create(w, h, false, Image.FORMAT_RGBA8)
	if frame_idx < 0 or frame_idx >= project.frames.size():
		return blended

	var frame = project.frames[frame_idx]

	# Ensure ordered_layers is up-to-date
	project.order_layers(frame_idx)

	for i in range(project.layers.size()):
		var layer_idx: int = project.ordered_layers[i] if i < project.ordered_layers.size() else i
		if layer_idx < 0 or layer_idx >= project.layers.size():
			continue

		var layer = project.layers[layer_idx]
		if not layer.visible or not layer.is_visible_in_hierarchy():
			continue
		if layer_idx >= frame.cels.size():
			continue

		var cel = frame.cels[layer_idx]
		if cel == null or not cel.has_method("get_image"):
			continue

		var cel_img: Image = cel.get_image()
		if cel_img == null or cel_img.is_empty():
			continue

		var final_opacity: float = layer.opacity
		if "opacity" in cel:
			final_opacity *= float(cel.opacity)

		if final_opacity <= 0.001:
			continue

		if final_opacity < 0.999:
			var src: Image = cel_img.duplicate()
			var sw: int = src.get_width()
			var sh: int = src.get_height()
			for y in range(sh):
				for x in range(sw):
					var col: Color = src.get_pixel(x, y)
					if col.a > 0.001:
						col.a *= final_opacity
						src.set_pixel(x, y, col)
			blended.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i.ZERO)
		else:
			blended.blend_rect(cel_img, Rect2i(Vector2i.ZERO, cel_img.get_size()), Vector2i.ZERO)

	return blended


func _get_bitmap_glyph(ch: String) -> Array:
	var c = ch.to_upper()
	match c:
		"A": return [[0,1,1,0],[1,0,0,1],[1,1,1,1],[1,0,0,1],[1,0,0,1]]
		"B": return [[1,1,1,0],[1,0,0,1],[1,1,1,0],[1,0,0,1],[1,1,1,0]]
		"C": return [[0,1,1,1],[1,0,0,0],[1,0,0,0],[1,0,0,0],[0,1,1,1]]
		"D": return [[1,1,1,0],[1,0,0,1],[1,0,0,1],[1,0,0,1],[1,1,1,0]]
		"E": return [[1,1,1,1],[1,0,0,0],[1,1,1,0],[1,0,0,0],[1,1,1,1]]
		"F": return [[1,1,1,1],[1,0,0,0],[1,1,1,0],[1,0,0,0],[1,0,0,0]]
		"G": return [[0,1,1,1],[1,0,0,0],[1,0,1,1],[1,0,0,1],[0,1,1,1]]
		"H": return [[1,0,0,1],[1,0,0,1],[1,1,1,1],[1,0,0,1],[1,0,0,1]]
		"I": return [[1,1,1],[0,1,0],[0,1,0],[0,1,0],[1,1,1]]
		"J": return [[0,0,1,1],[0,0,0,1],[0,0,0,1],[1,0,0,1],[0,1,1,0]]
		"K": return [[1,0,0,1],[1,0,1,0],[1,1,0,0],[1,0,1,0],[1,0,0,1]]
		"L": return [[1,0,0,0],[1,0,0,0],[1,0,0,0],[1,0,0,0],[1,1,1,1]]
		"M": return [[1,0,0,0,1],[1,1,0,1,1],[1,0,1,0,1],[1,0,0,0,1],[1,0,0,0,1]]
		"N": return [[1,0,0,1],[1,1,0,1],[1,0,1,1],[1,0,0,1],[1,0,0,1]]
		"O": return [[0,1,1,0],[1,0,0,1],[1,0,0,1],[1,0,0,1],[0,1,1,0]]
		"P": return [[1,1,1,0],[1,0,0,1],[1,1,1,0],[1,0,0,0],[1,0,0,0]]
		"Q": return [[0,1,1,0],[1,0,0,1],[1,0,0,1],[1,0,1,0],[0,1,0,1]]
		"R": return [[1,1,1,0],[1,0,0,1],[1,1,1,0],[1,0,1,0],[1,0,0,1]]
		"S": return [[0,1,1,1],[1,0,0,0],[0,1,1,0],[0,0,0,1],[1,1,1,0]]
		"T": return [[1,1,1,1,1],[0,0,1,0,0],[0,0,1,0,0],[0,0,1,0,0],[0,0,1,0,0]]
		"U": return [[1,0,0,1],[1,0,0,1],[1,0,0,1],[1,0,0,1],[0,1,1,0]]
		"V": return [[1,0,0,1],[1,0,0,1],[1,0,0,1],[0,1,1,0],[0,1,0,0]]
		"W": return [[1,0,0,0,1],[1,0,0,0,1],[1,0,1,0,1],[1,1,0,1,1],[1,0,0,0,1]]
		"X": return [[1,0,0,1],[0,1,1,0],[0,1,1,0],[1,0,0,1],[1,0,0,1]]
		"Y": return [[1,0,0,1],[0,1,1,0],[0,0,1,0],[0,0,1,0],[0,0,1,0]]
		"Z": return [[1,1,1,1],[0,0,1,0],[0,1,0,0],[1,0,0,0],[1,1,1,1]]
		"0": return [[0,1,1,0],[1,0,0,1],[1,0,0,1],[1,0,0,1],[0,1,1,0]]
		"1": return [[0,1,0],[1,1,0],[0,1,0],[0,1,0],[1,1,1]]
		"2": return [[1,1,1,0],[0,0,0,1],[0,1,1,0],[1,0,0,0],[1,1,1,1]]
		"3": return [[1,1,1,0],[0,0,0,1],[0,1,1,0],[0,0,0,1],[1,1,1,0]]
		"4": return [[1,0,0,1],[1,0,0,1],[1,1,1,1],[0,0,0,1],[0,0,0,1]]
		"5": return [[1,1,1,1],[1,0,0,0],[1,1,1,0],[0,0,0,1],[1,1,1,0]]
		"6": return [[0,1,1,0],[1,0,0,0],[1,1,1,0],[1,0,0,1],[0,1,1,0]]
		"7": return [[1,1,1,1],[0,0,0,1],[0,0,1,0],[0,1,0,0],[0,1,0,0]]
		"8": return [[0,1,1,0],[1,0,0,1],[0,1,1,0],[1,0,0,1],[0,1,1,0]]
		"9": return [[0,1,1,0],[1,0,0,1],[0,1,1,1],[0,0,0,1],[0,1,1,0]]
		" ": return [[0,0],[0,0],[0,0],[0,0],[0,0]]
		"!": return [[1],[1],[1],[0],[1]]
		"?": return [[1,1,1],[0,0,1],[0,1,0],[0,0,0],[0,1,0]]
		".": return [[0],[0],[0],[0],[1]]
		",": return [[0],[0],[0],[1],[1]]
		":": return [[0],[1],[0],[1],[0]]
		"-": return [[0,0,0],[0,0,0],[1,1,1],[0,0,0],[0,0,0]]
		"+": return [[0,1,0],[0,1,0],[1,1,1],[0,1,0],[0,1,0]]
		_: return [[1,1,1],[1,0,1],[1,0,1],[1,0,1],[1,1,1]]


func _cmd_validate_sprite(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var all_layers: bool = bool(params.get("all_layers", false))
	var frame_idx: int = int(params.get("frame", project.current_frame))
	var check_holes: bool = bool(params.get("check_holes", true))
	var check_orphans: bool = bool(params.get("check_orphans", true))
	var orphan_distance: int = int(params.get("orphan_distance", 1))

	var img: Image = null
	var target_layer: int = project.current_layer
	if all_layers:
		img = _composite_frame_layers(project, frame_idx)
	else:
		var target := _get_target_cel_and_image(params)
		if target.error != "":
			return {"success": false, "error": target.error}
		img = target.image
		target_layer = target.layer

	if img == null:
		return {"success": false, "error": "No active image to validate"}

	var w: int = img.get_width()
	var h: int = img.get_height()
	var used_rect := img.get_used_rect()

	if used_rect.size.x == 0 or used_rect.size.y == 0:
		return {
			"success": true,
			"data": {
				"empty": true,
				"total_opaque_pixels": 0,
				"unique_color_count": 0,
				"unique_colors": [],
				"bounds": {"x": 0, "y": 0, "width": 0, "height": 0},
				"canvas_size": {"width": w, "height": h},
				"stray_pixels": [],
				"stray_pixel_count": 0,
				"enclosed_holes": [],
				"enclosed_hole_count": 0,
				"frame": frame_idx,
				"layer": target_layer
			}
		}

	# 1. Color counting & non-transparent pixel map
	var color_map := {}
	var total_opaque := 0
	for y in range(h):
		for x in range(w):
			var c := img.get_pixel(x, y)
			if c.a > 0.05:
				total_opaque += 1
				var hex := "#" + c.to_html(c.a < 0.99)
				color_map[hex] = color_map.get(hex, 0) + 1

	# 2. Stray / orphan pixels detection
	var stray_pixels: Array = []
	if check_orphans:
		var dist := maxi(1, orphan_distance)
		for y in range(used_rect.position.y, used_rect.end.y):
			for x in range(used_rect.position.x, used_rect.end.x):
				if img.get_pixel(x, y).a > 0.05:
					var has_neighbor := false
					for dy in range(-dist, dist + 1):
						for dx in range(-dist, dist + 1):
							if dx == 0 and dy == 0:
								continue
							var nx := x + dx
							var ny := y + dy
							if nx >= 0 and nx < w and ny >= 0 and ny < h:
								if img.get_pixel(nx, ny).a > 0.05:
									has_neighbor = true
									break
						if has_neighbor:
							break
					if not has_neighbor:
						var c := img.get_pixel(x, y)
						stray_pixels.append({
							"x": x,
							"y": y,
							"color": "#" + c.to_html(c.a < 0.99)
						})

	# 3. Enclosed holes detection via exterior flood fill
	var enclosed_holes: Array = []
	if check_holes:
		var outside: Array = []
		outside.resize(w * h)
		outside.fill(false)

		var queue: Array = []

		for x in range(w):
			if img.get_pixel(x, 0).a <= 0.05:
				outside[x] = true
				queue.append(Vector2i(x, 0))
			var b_idx := (h - 1) * w + x
			if img.get_pixel(x, h - 1).a <= 0.05 and not outside[b_idx]:
				outside[b_idx] = true
				queue.append(Vector2i(x, h - 1))

		for y in range(h):
			var l_idx := y * w
			if img.get_pixel(0, y).a <= 0.05 and not outside[l_idx]:
				outside[l_idx] = true
				queue.append(Vector2i(0, y))
			var r_idx := y * w + (w - 1)
			if img.get_pixel(w - 1, y).a <= 0.05 and not outside[r_idx]:
				outside[r_idx] = true
				queue.append(Vector2i(w - 1, y))

		while queue.size() > 0:
			var p: Vector2i = queue.pop_back()
			var neighbors = [
				Vector2i(p.x + 1, p.y),
				Vector2i(p.x - 1, p.y),
				Vector2i(p.x, p.y + 1),
				Vector2i(p.x, p.y - 1)
			]
			for np in neighbors:
				if np.x >= 0 and np.x < w and np.y >= 0 and np.y < h:
					var n_idx: int = np.y * w + np.x
					if not outside[n_idx] and img.get_pixel(np.x, np.y).a <= 0.05:
						outside[n_idx] = true
						queue.append(np)

		var visited_hole: Array = []
		visited_hole.resize(w * h)
		visited_hole.fill(false)

		for y in range(used_rect.position.y, used_rect.end.y):
			for x in range(used_rect.position.x, used_rect.end.x):
				var idx: int = y * w + x
				if not outside[idx] and not visited_hole[idx] and img.get_pixel(x, y).a <= 0.05:
					var hole_queue := [Vector2i(x, y)]
					visited_hole[idx] = true
					var hole_pixel_count := 0
					var min_x := x
					var max_x := x
					var min_y := y
					var max_y := y

					while hole_queue.size() > 0:
						var hp: Vector2i = hole_queue.pop_back()
						hole_pixel_count += 1
						min_x = mini(min_x, hp.x)
						max_x = maxi(max_x, hp.x)
						min_y = mini(min_y, hp.y)
						max_y = maxi(max_y, hp.y)

						var h_neighbors = [
							Vector2i(hp.x + 1, hp.y),
							Vector2i(hp.x - 1, hp.y),
							Vector2i(hp.x, hp.y + 1),
							Vector2i(hp.x, hp.y - 1)
						]
						for nhp in h_neighbors:
							if nhp.x >= 0 and nhp.x < w and nhp.y >= 0 and nhp.y < h:
								var h_idx: int = nhp.y * w + nhp.x
								if not outside[h_idx] and not visited_hole[h_idx] and img.get_pixel(nhp.x, nhp.y).a <= 0.05:
									visited_hole[h_idx] = true
									hole_queue.append(nhp)

					enclosed_holes.append({
						"pixel_count": hole_pixel_count,
						"bounds": {
							"x": min_x,
							"y": min_y,
							"width": max_x - min_x + 1,
							"height": max_y - min_y + 1
						},
						"center": [int((min_x + max_x) / 2.0), int((min_y + max_y) / 2.0)]
					})

	return {
		"success": true,
		"data": {
			"empty": false,
			"total_opaque_pixels": total_opaque,
			"unique_color_count": color_map.size(),
			"unique_colors": color_map.keys(),
			"bounds": {
				"x": used_rect.position.x,
				"y": used_rect.position.y,
				"width": used_rect.size.x,
				"height": used_rect.size.y
			},
			"canvas_size": {"width": w, "height": h},
			"stray_pixels": stray_pixels.slice(0, 50),
			"stray_pixel_count": stray_pixels.size(),
			"enclosed_holes": enclosed_holes,
			"enclosed_hole_count": enclosed_holes.size(),
			"frame": frame_idx,
			"layer": target_layer
		}
	}


func _cmd_get_history(params: Dictionary) -> Dictionary:
	var ur = _get_undo_redo()
	if ur == null:
		return {"success": false, "error": "UndoRedo system not available"}

	var limit: int = int(params.get("limit", 20))
	if limit <= 0:
		limit = 20

	var total_count: int = ur.get_history_count()
	var current_idx: int = ur.get_current_action()
	var current_name: String = ur.get_current_action_name() if total_count > 0 and current_idx >= 0 else ""

	var actions: Array = []
	var start_idx: int = maxi(0, total_count - limit)
	for i in range(start_idx, total_count):
		actions.append({
			"index": i,
			"name": ur.get_action_name(i),
			"is_current": (i == current_idx)
		})

	var project = _api.project.current_project
	var cursor_info := _get_active_cursor_info(project) if project else {}

	return {
		"success": true,
		"data": {
			"current_action_index": current_idx,
			"current_action_name": current_name,
			"history_count": total_count,
			"can_undo": ur.has_undo(),
			"can_redo": ur.has_redo(),
			"actions": actions,
			"active_cursor": cursor_info
		}
	}


