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
	_tool_registry["draw_pixels_fast"] = Callable(self, "_cmd_draw_pixels_fast")
	_tool_registry["draw_rect"] = Callable(self, "_cmd_draw_rect")
	_tool_registry["draw_line"] = Callable(self, "_cmd_draw_line")
	_tool_registry["draw_path"] = Callable(self, "_cmd_draw_path")
	_tool_registry["draw_polygon"] = Callable(self, "_cmd_draw_polygon")
	_tool_registry["draw_ellipse"] = Callable(self, "_cmd_draw_ellipse")
	_tool_registry["draw_text"] = Callable(self, "_cmd_draw_text")
	_tool_registry["fill_area"] = Callable(self, "_cmd_fill_area")
	_tool_registry["apply_outline"] = Callable(self, "_cmd_apply_outline")
	_tool_registry["apply_dithering"] = Callable(self, "_cmd_apply_dithering")
	_tool_registry["apply_drop_shadow"] = Callable(self, "_cmd_apply_drop_shadow")
	_tool_registry["apply_glow"] = Callable(self, "_cmd_apply_glow")
	_tool_registry["apply_gradient"] = Callable(self, "_cmd_apply_gradient")
	_tool_registry["check_seamless_tile"] = Callable(self, "_cmd_check_seamless_tile")
	_tool_registry["mirror_layer"] = Callable(self, "_cmd_mirror_layer")
	_tool_registry["transform_cel"] = Callable(self, "_cmd_transform_cel")
	_tool_registry["rotate_cel"] = Callable(self, "_cmd_rotate_cel")
	_tool_registry["eval_gdscript"] = Callable(self, "_cmd_eval_gdscript")
	_tool_registry["batch_commands"] = Callable(self, "_cmd_batch_commands")

	# Inspection & QA
	_tool_registry["get_pixel"] = Callable(self, "_cmd_get_pixel")
	_tool_registry["get_pixels"] = Callable(self, "_cmd_get_pixels")
	_tool_registry["get_region"] = Callable(self, "_cmd_get_region")
	_tool_registry["get_layer_markers"] = Callable(self, "_cmd_get_layer_markers")
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

func _get_or_create_layer_id(layer: Object) -> String:
	if layer == null:
		return ""
	if layer.has_meta("mcp_layer_id"):
		return str(layer.get_meta("mcp_layer_id"))
	var new_id := "layer_%s_%s" % [str(layer.get_instance_id()), str(Time.get_ticks_msec())]
	layer.set_meta("mcp_layer_id", new_id)
	return new_id


func _resolve_layer_index(params: Dictionary, project = null) -> int:
	if project == null:
		project = _api.project.current_project
	if project == null:
		return -1

	# Priority 1: layer_id (stable handle)
	if params.has("layer_id"):
		var target_id: String = str(params["layer_id"]).strip_edges()
		for i in range(project.layers.size()):
			var lyr = project.layers[i]
			if _get_or_create_layer_id(lyr) == target_id:
				return i
		return -1

	# Priority 2: layer_name
	if params.has("layer_name"):
		var target_name: String = str(params["layer_name"]).strip_edges()
		for i in range(project.layers.size()):
			if project.layers[i].name == target_name:
				return i
		return -1

	# Priority 3: index parameter (may be integer or string name/id)
	if params.has("index"):
		var val = params["index"]
		if typeof(val) == TYPE_STRING:
			var s: String = str(val).strip_edges()
			for i in range(project.layers.size()):
				if _get_or_create_layer_id(project.layers[i]) == s or project.layers[i].name == s:
					return i
			if s.is_valid_int():
				return int(s)
			return -1
		else:
			return int(val)

	# Priority 4: layer parameter (may be integer or string name/id)
	if params.has("layer"):
		var val = params["layer"]
		if typeof(val) == TYPE_STRING:
			var s: String = str(val).strip_edges()
			for i in range(project.layers.size()):
				if _get_or_create_layer_id(project.layers[i]) == s or project.layers[i].name == s:
					return i
			if s.is_valid_int():
				return int(s)
			return -1
		else:
			return int(val)

	return project.current_layer


func _get_active_cursor_info(project = null) -> Dictionary:
	if project == null:
		project = _api.project.current_project
	if project == null:
		return {"frame": 0, "layer": 0, "layer_name": "", "layer_id": ""}
	var frame_idx: int = project.current_frame
	var layer_idx: int = project.current_layer
	var layer_name := ""
	var layer_id := ""
	if layer_idx >= 0 and layer_idx < project.layers.size():
		var lyr = project.layers[layer_idx]
		layer_name = lyr.name
		layer_id = _get_or_create_layer_id(lyr)
	return {
		"frame": frame_idx,
		"layer": layer_idx,
		"layer_name": layer_name,
		"layer_id": layer_id
	}


func _find_animation_tag(project, tag_name: String) -> Dictionary:
	var target := tag_name.strip_edges()
	if target.is_empty():
		return {"error": "Animation tag name must not be empty"}
	var total: int = project.frames.size()
	var available: Array[String] = []
	for tag in project.animation_tags:
		available.append(str(tag.name))
		if str(tag.name) == target:
			var f_from := clampi(int(tag.from) - 1, 0, maxi(0, total - 1))
			var f_to := clampi(int(tag.to) - 1, f_from, maxi(0, total - 1))
			return {
				"error": "",
				"tag": tag,
				"name": str(tag.name),
				"from_frame": f_from,
				"to_frame": f_to
			}
	var avail_str := ", ".join(available) if not available.is_empty() else "(none defined)"
	return {"error": "Animation tag '%s' not found. Available tags: %s" % [target, avail_str]}


func _resolve_frame_range(project, params: Dictionary) -> Dictionary:
	var total: int = project.frames.size()
	if total <= 0:
		return {"error": "Project has no frames"}

	var tag_name := ""
	if params.has("tag") and params["tag"] != null:
		tag_name = str(params["tag"]).strip_edges()

	var has_start := params.has("start_frame") and params["start_frame"] != null
	var has_end := params.has("end_frame") and params["end_frame"] != null
	if not has_start and params.has("from_frame") and params["from_frame"] != null:
		has_start = true
	if not has_end and params.has("to_frame") and params["to_frame"] != null:
		has_end = true

	var start_frame := 0
	var end_frame := total - 1
	var resolved_tag := ""

	if not tag_name.is_empty():
		if has_start or has_end:
			return {"error": "Specify either 'tag' or 'start_frame'/'end_frame', not both"}
		var tag_res := _find_animation_tag(project, tag_name)
		if tag_res.error != "":
			return {"error": tag_res.error}
		start_frame = int(tag_res.from_frame)
		end_frame = int(tag_res.to_frame)
		resolved_tag = str(tag_res.name)
	else:
		if has_start:
			start_frame = int(params["start_frame"]) if (params.has("start_frame") and params["start_frame"] != null) else int(params["from_frame"])
		if has_end:
			end_frame = int(params["end_frame"]) if (params.has("end_frame") and params["end_frame"] != null) else int(params["to_frame"])
		if start_frame < 0 or start_frame >= total:
			return {"error": "start_frame %d out of bounds (0..%d)" % [start_frame, total - 1]}
		if end_frame < 0 or end_frame >= total:
			return {"error": "end_frame %d out of bounds (0..%d)" % [end_frame, total - 1]}
		if start_frame > end_frame:
			return {"error": "Invalid frame range: start_frame (%d) > end_frame (%d)" % [start_frame, end_frame]}

	var frames: Array[int] = []
	for i in range(start_frame, end_frame + 1):
		frames.append(i)

	return {
		"error": "",
		"start_frame": start_frame,
		"end_frame": end_frame,
		"frames": frames,
		"count": frames.size(),
		"tag": resolved_tag
	}


func _resolve_frame_indices(
	project,
	params: Dictionary,
	prefix: String = "",
	default_all: bool = false,
	require_explicit: bool = false,
	single_key_override: String = ""
) -> Dictionary:
	var total: int = project.frames.size()
	if total <= 0:
		return {"error": "Project has no frames"}

	var all_key := prefix + "all_frames"
	var tag_key := prefix + "tag"
	var frames_key := prefix + "frames"
	var from_key := prefix + "from_frame"
	var to_key := prefix + "to_frame"
	var single_key := single_key_override if not single_key_override.is_empty() else (prefix + "frame")

	var frames: Array[int] = []
	var is_multi := false
	var resolved_tag := ""

	if params.has(all_key) and bool(params[all_key]):
		for i in range(total):
			frames.append(i)
		is_multi = true
	elif params.has(tag_key) and params[tag_key] != null and not str(params[tag_key]).strip_edges().is_empty():
		var tag_res := _find_animation_tag(project, str(params[tag_key]))
		if tag_res.error != "":
			return {"error": tag_res.error}
		for i in range(int(tag_res.from_frame), int(tag_res.to_frame) + 1):
			frames.append(i)
		is_multi = true
		resolved_tag = str(tag_res.name)
	elif params.has(frames_key) and params[frames_key] != null:
		var raw_frames = params[frames_key]
		if not (raw_frames is Array) or raw_frames.is_empty():
			return {"error": "'%s' must be a non-empty array of frame indices" % frames_key}
		var seen := {}
		for item in raw_frames:
			var fi := int(item)
			if fi < 0 or fi >= total:
				return {"error": "Frame index %d in '%s' out of bounds (0..%d)" % [fi, frames_key, total - 1]}
			if not seen.has(fi):
				seen[fi] = true
				frames.append(fi)
		is_multi = true
	elif (params.has(from_key) and params[from_key] != null) or (params.has(to_key) and params[to_key] != null):
		var f_from: int = int(params[from_key]) if (params.has(from_key) and params[from_key] != null) else 0
		var f_to: int = int(params[to_key]) if (params.has(to_key) and params[to_key] != null) else (total - 1)
		if f_from < 0 or f_from >= total:
			return {"error": "%s %d out of bounds (0..%d)" % [from_key, f_from, total - 1]}
		if f_to < 0 or f_to >= total:
			return {"error": "%s %d out of bounds (0..%d)" % [to_key, f_to, total - 1]}
		if f_from > f_to:
			return {"error": "Invalid frame range: %s (%d) > %s (%d)" % [from_key, f_from, to_key, f_to]}
		for i in range(f_from, f_to + 1):
			frames.append(i)
		is_multi = true
	elif params.has(single_key) and params[single_key] != null:
		var fi := int(params[single_key])
		if fi < 0 or fi >= total:
			return {"error": "Frame index %d out of bounds (0..%d)" % [fi, total - 1]}
		frames.append(fi)
		is_multi = false
	elif require_explicit:
		return {"error": "Missing destination frame selector (%s, %s, %s/%s, or %s)" % [single_key, frames_key, from_key, to_key, tag_key]}
	elif default_all:
		for i in range(total):
			frames.append(i)
		is_multi = true
	else:
		frames.append(clampi(project.current_frame, 0, total - 1))
		is_multi = false

	return {
		"error": "",
		"frames": frames,
		"is_multi": is_multi,
		"tag": resolved_tag
	}


func _resolve_palette_colors(project, params: Dictionary) -> Dictionary:
	var pal_name := ""
	if params.has("palette") and params["palette"] != null:
		pal_name = str(params["palette"]).strip_edges()
	var explicit_colors: Array = []
	if params.has("allowed_colors") and params["allowed_colors"] is Array:
		explicit_colors = params["allowed_colors"]

	if pal_name.is_empty() and explicit_colors.is_empty():
		return {"error": "", "enabled": false, "palette_name": "", "colors": [], "rgb_set": {}, "rgba_set": {}}

	var colors: Array[Color] = []
	var rgb_set := {}
	var rgba_set := {}
	var resolved_name := pal_name

	if not pal_name.is_empty():
		var palettes_autoload = _api.palette.autoload()
		if palettes_autoload == null:
			return {"error": "Palettes singleton not available"}

		var found_pal = null
		var avail_names: Array[String] = []

		if pal_name.to_lower() == "active":
			found_pal = palettes_autoload.current_palette
			if found_pal:
				resolved_name = str(found_pal.name)
		else:
			if project and "palettes" in project and project.palettes is Dictionary:
				for k in project.palettes.keys():
					var p = project.palettes[k]
					if p:
						avail_names.append(str(p.name))
						if str(p.name) == pal_name or str(k) == pal_name:
							found_pal = p
							resolved_name = str(p.name)
							break
			if found_pal == null and "palettes" in palettes_autoload and palettes_autoload.palettes is Dictionary:
				for k in palettes_autoload.palettes.keys():
					var p = palettes_autoload.palettes[k]
					if p:
						if not (str(p.name) in avail_names):
							avail_names.append(str(p.name))
						if str(p.name) == pal_name or str(k) == pal_name:
							found_pal = p
							resolved_name = str(p.name)
							break

		if found_pal == null:
			var avail_str := ", ".join(avail_names) if not avail_names.is_empty() else "(none)"
			return {"error": "Palette '%s' not found. Available palettes: %s" % [pal_name, avail_str]}

		for swatch in found_pal.colors.values():
			if swatch != null and "color" in swatch:
				var c: Color = swatch.color
				colors.append(c)
				var rgb_key := (c.r8 << 16) | (c.g8 << 8) | c.b8
				var rgba_key := (c.r8 << 24) | (c.g8 << 16) | (c.b8 << 8) | c.a8
				rgb_set[rgb_key] = true
				rgba_set[rgba_key] = true

	for raw_hex in explicit_colors:
		var hs := str(raw_hex).strip_edges()
		if Color.html_is_valid(hs):
			var c := Color.html(hs)
			colors.append(c)
			var rgb_key := (c.r8 << 16) | (c.g8 << 8) | c.b8
			var rgba_key := (c.r8 << 24) | (c.g8 << 16) | (c.b8 << 8) | c.a8
			rgb_set[rgb_key] = true
			rgba_set[rgba_key] = true

	if colors.is_empty():
		return {"error": "Resolved palette '%s' contains 0 valid colors" % resolved_name}

	return {
		"error": "",
		"enabled": true,
		"palette_name": resolved_name if not resolved_name.is_empty() else "custom",
		"colors": colors,
		"rgb_set": rgb_set,
		"rgba_set": rgba_set
	}


func _rasterize_ellipse_bounds(bx0: int, by0: int, bx1: int, by1: int) -> Dictionary:
	## Zingl integer Bresenham ellipse over inclusive bounding box [bx0..bx1] x [by0..by1].
	## Produces flat cardinal caps with zero 1px N/S/E/W pole nubs and deduplicated outline points.
	var x0 := mini(bx0, bx1)
	var x1 := maxi(bx0, bx1)
	var y0 := mini(by0, by1)
	var y1 := maxi(by0, by1)

	var outline: Array[Vector2i] = []
	var seen := {}
	var row_min := {}
	var row_max := {}

	var plot := func(px: int, py: int) -> void:
		var pt := Vector2i(px, py)
		if not seen.has(pt):
			seen[pt] = true
			outline.append(pt)
		if not row_min.has(py) or px < int(row_min[py]):
			row_min[py] = px
		if not row_max.has(py) or px > int(row_max[py]):
			row_max[py] = px

	var a := x1 - x0
	var b := y1 - y0

	if a == 0:
		for py in range(y0, y1 + 1):
			plot.call(x0, py)
		return {"outline": outline, "row_min": row_min, "row_max": row_max, "min_y": y0, "max_y": y1}
	if b == 0:
		for px in range(x0, x1 + 1):
			plot.call(px, y0)
		return {"outline": outline, "row_min": row_min, "row_max": row_max, "min_y": y0, "max_y": y1}

	var orig_y0 := y0
	var orig_y1 := y1
	var b1 := b & 1
	var dx: int = 4 * (1 - a) * b * b
	var dy: int = 4 * (b1 + 1) * a * a
	var err: int = dx + dy + b1 * a * a
	var e2: int = 0

	y0 += (b + 1) >> 1
	y1 = y0 - b1
	var a_step: int = 8 * a * a
	var b_step: int = 8 * b * b

	while x0 <= x1:
		plot.call(x1, y0)
		plot.call(x0, y0)
		plot.call(x0, y1)
		plot.call(x1, y1)
		e2 = 2 * err
		if e2 <= dy:
			y0 += 1
			y1 -= 1
			dy += a_step
			err += dy
		if e2 >= dx or 2 * err > dy:
			x0 += 1
			x1 -= 1
			dx += b_step
			err += dx

	while y0 - y1 < b:
		plot.call(x0 - 1, y0)
		plot.call(x1 + 1, y0)
		plot.call(x0 - 1, y1)
		plot.call(x1 + 1, y1)
		y0 += 1
		y1 -= 1

	# Ensure top/bottom pole rows are never missed on 2px-wide tall ellipses (a == 1)
	if a == 1 and not row_min.has(orig_y0):
		plot.call(x0 - 1, orig_y0)
		plot.call(x1 + 1, orig_y0)
	if a == 1 and not row_min.has(orig_y1):
		plot.call(x0 - 1, orig_y1)
		plot.call(x1 + 1, orig_y1)

	return {"outline": outline, "row_min": row_min, "row_max": row_max, "min_y": orig_y0, "max_y": orig_y1}


func _get_current_cel():
	var project = _api.project.current_project
	if project == null:
		return null
	return _api.project.get_current_cel()


func _get_current_image() -> Image:
	var cel = _get_current_cel()
	if cel == null or cel.get_class_name() != "PixelCel":
		return null
	return _cel_to_canvas_image(cel, _api.project.current_project)


func _get_cel_offset(cel) -> Vector2i:
	# Pixelorama 1.2.4 stores PixelCel.offset separately from its compact image.
	# Older supported APIs had canvas-sized images at origin.
	var value = cel.get("offset")
	if typeof(value) == TYPE_VECTOR2I:
		return value
	if typeof(value) == TYPE_VECTOR2:
		return Vector2i(value)
	return Vector2i.ZERO



func _capture_cel_undo_data(cel, cel_image: Image) -> Dictionary:
	## Mirror Project.serialize_cel_undo_data(): the cel key must carry its
	## offset so Project.deserialize_cel_undo_data() registers change_offset
	## do/undo methods. PixelCel has no serialize_undo_data() in API 10, so
	## without this entry undo/redo would restore image data but leave the
	## offset at its post-edit value, shifting pixels on canvas.
	var data := {}
	if cel.has_method("serialize_undo_data"):
		var serialized = cel.serialize_undo_data()
		if serialized is Dictionary:
			data[cel] = serialized
	if not data.has(cel):
		data[cel] = {}
	data[cel]["offset"] = _get_cel_offset(cel)
	if cel_image:
		cel_image.add_data_to_dictionary(data)
	return data


func _snapshot_cel_state(cel) -> Dictionary:
	## Capture a cel's compact image data and offset without replacing its ImageExtended instance.
	if cel == null or not cel.has_method("get_image"):
		return {}
	var src: Image = cel.get_image()
	var img_copy: Image = src.duplicate() if src != null else null
	return {
		"cel": cel,
		"image": img_copy,
		"offset": _get_cel_offset(cel),
	}


func _restore_cel_state_in_place(state: Dictionary) -> void:
	## Restore a cel's image data and offset in-place so ImageExtended object identity
	## stays intact for Pixelorama's dictionary-keyed undo/redo compression.
	if state.is_empty():
		return
	var cel = state.get("cel", null)
	var saved_img: Image = state.get("image", null)
	if cel == null or saved_img == null or not cel.has_method("get_image"):
		return
	var cel_image = cel.get_image()
	if cel_image == null:
		return
	if cel_image.has_method("copy_from_custom"):
		cel_image.copy_from_custom(saved_img, cel_image.is_indexed)
	else:
		cel_image.copy_from(saved_img)
	if cel.has_method("change_offset"):
		cel.change_offset(state.get("offset", Vector2i.ZERO))
	if cel.has_method("update_texture"):
		cel.update_texture()


func _cel_matches_snapshot(cel, state: Dictionary) -> bool:
	if cel == null or state.is_empty() or not cel.has_method("get_image"):
		return false
	if _get_cel_offset(cel) != state.get("offset", Vector2i.ZERO):
		return false
	var cur_img: Image = cel.get_image()
	var snap_img: Image = state.get("image", null)
	if cur_img == null or snap_img == null:
		return cur_img == snap_img
	if cur_img.is_empty() or snap_img.is_empty():
		return cur_img.is_empty() == snap_img.is_empty()
	return cur_img.get_size() == snap_img.get_size() and cur_img.get_data() == snap_img.get_data()

func _cel_to_canvas_image(cel, project) -> Image:
	## Return a canvas-sized working copy while leaving the compact source cel intact.
	## Pixels outside the canvas are intentionally omitted from this view; commit
	## merges only the canvas rectangle back into the source cel, preserving them.
	var width := int(project.size.x)
	var height := int(project.size.y)
	var canvas_image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var source: Image = cel.get_image()
	if source == null or source.is_empty():
		return canvas_image
	var offset := _get_cel_offset(cel)
	var overlap := Rect2i(offset, source.get_size()).intersection(Rect2i(Vector2i.ZERO, Vector2i(width, height)))
	if overlap.has_area():
		var source_rect := Rect2i(overlap.position - offset, overlap.size)
		canvas_image.blit_rect(source, source_rect, overlap.position)
	return canvas_image


func _commit_compact_cel_content(image: Image, offset: Vector2i, action_name: String, frame_idx: int, layer_idx: int) -> void:
	## Replace a cel's compact image and offset as one undoable change.
	var project = _api.project.current_project
	if project == null or frame_idx < 0 or frame_idx >= project.frames.size():
		return
	if layer_idx < 0 or layer_idx >= project.layers.size():
		return
	var cel = project.frames[frame_idx].cels[layer_idx]
	if cel == null or cel.get_class_name() != "PixelCel":
		return
	if not cel.has_method("change_offset"):
		_api.project.set_pixelcel_image(image, frame_idx, layer_idx)
		return

	var cel_image = cel.get_image()
	var ur = project.undo_redo
	var undo_data := {}
	if ur:
		ur.create_action(action_name)
		undo_data = _capture_cel_undo_data(cel, cel_image)

	cel_image.copy_from_custom(image, cel_image.is_indexed)
	cel.change_offset(offset)
	if cel.has_method("update_texture"):
		cel.update_texture()

	if ur:
		var redo_data := _capture_cel_undo_data(cel, cel_image)
		project.deserialize_cel_undo_data(redo_data, undo_data)
		ur.add_do_property(project, "selected_cels", [])
		ur.add_do_method(project.change_cel.bind(frame_idx, layer_idx))
		ur.add_undo_property(project, "selected_cels", [])
		ur.add_undo_method(project.change_cel.bind(frame_idx, layer_idx))
		var global_node = _api.get_node_or_null("/root/Global")
		if global_node and global_node.has_method("undo_or_redo"):
			ur.add_do_method(global_node.undo_or_redo.bind(false, frame_idx, layer_idx, project))
			ur.add_undo_method(global_node.undo_or_redo.bind(true, frame_idx, layer_idx, project))
		if cel.has_method("update_texture"):
			ur.add_do_method(cel.update_texture)
			ur.add_undo_method(cel.update_texture)
		ur.commit_action()
	_api.project.select_cels([[frame_idx, layer_idx]])


func _get_target_cel_and_image(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"error": "No active project", "image": null, "frame": 0, "layer": 0}

	var frame_idx: int = int(params.get("frame", project.current_frame))
	var layer_idx: int = _resolve_layer_index(params, project)

	if frame_idx < 0 or frame_idx >= project.frames.size():
		return {"error": "Frame index out of bounds: %d (0..%d)" % [frame_idx, project.frames.size() - 1], "image": null, "frame": frame_idx, "layer": layer_idx}
	if layer_idx < 0 or layer_idx >= project.layers.size():
		return {"error": "Layer index out of bounds or not found: %s (available: 0..%d)" % [str(params.get("layer_id", params.get("layer_name", params.get("layer", layer_idx)))), project.layers.size() - 1], "image": null, "frame": frame_idx, "layer": layer_idx}

	var cel = project.frames[frame_idx].cels[layer_idx]
	if cel == null or cel.get_class_name() != "PixelCel":
		return {"error": "Cel at [frame:%d, layer:%d] is not a PixelCel" % [frame_idx, layer_idx], "image": null, "frame": frame_idx, "layer": layer_idx}

	return {"error": "", "image": _cel_to_canvas_image(cel, project), "frame": frame_idx, "layer": layer_idx, "cel": cel}


func _commit_image_change(image: Image, action_name: String, frame_idx: int = -1, layer_idx: int = -1, record_undo: bool = true, pre_undo_state: Dictionary = {}) -> void:
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

	image.convert(project.get_image_format())
	var cel_image: Image = cel.get_image()

	var ur = project.undo_redo if record_undo else null
	if ur:
		ur.create_action(action_name)
		var post_state := {}
		if not pre_undo_state.is_empty():
			post_state = _snapshot_cel_state(cel)
			_restore_cel_state_in_place(pre_undo_state)
			cel_image = cel.get_image()
		var undo_data := _capture_cel_undo_data(cel, cel_image)
		if not post_state.is_empty():
			_restore_cel_state_in_place(post_state)
			cel_image = cel.get_image()

		if cel.has_method("ensure_canvas_rect_in_bounds"):
			cel.ensure_canvas_rect_in_bounds(Vector2i.ZERO, project.size)
			cel_image = cel.get_image()
			cel_image.blit_rect(
				image,
				Rect2i(Vector2i.ZERO, project.size),
				-_get_cel_offset(cel)
			)
			if cel.has_method("shrink_to_content"):
				cel.shrink_to_content()
			cel_image = cel.get_image()
		else:
			# Compatibility with older Extensions API versions whose cel images
			# always matched the canvas dimensions and had no independent offset.
			cel_image.fill(0)
			cel_image.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
		if cel_image.has_method("convert_rgb_to_indexed"):
			cel_image.convert_rgb_to_indexed()

		var redo_data := {}
		if cel.has_method("update_tilemap"):
			cel.update_tilemap()
		redo_data = _capture_cel_undo_data(cel, cel_image)

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
		# Fallback if undo_redo not available or record_undo is false
		if cel.has_method("ensure_canvas_rect_in_bounds"):
			cel.ensure_canvas_rect_in_bounds(Vector2i.ZERO, project.size)
			cel_image = cel.get_image()
			cel_image.blit_rect(
				image,
				Rect2i(Vector2i.ZERO, project.size),
				-_get_cel_offset(cel)
			)
			if cel.has_method("shrink_to_content"):
				cel.shrink_to_content()
			cel_image = cel.get_image()
		else:
			cel_image.fill(0)
			cel_image.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
		if cel_image.has_method("convert_rgb_to_indexed"):
			cel_image.convert_rgb_to_indexed()
		if cel.has_method("update_tilemap"):
			cel.update_tilemap()
		if cel.has_method("update_texture"):
			cel.update_texture()

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
	var c := default_color
	if color_val is String and color_val != "":
		if Color.html_is_valid(color_val):
			c = Color.html(color_val)
		else:
			push_warning(LOG_TAG + "Invalid color hex: '%s', using default" % color_val)
	elif color_val is Color:
		c = color_val

	# B6: Support explicit "alpha" parameter (0..255 or 0.0..1.0)
	if params.has("alpha"):
		var a_val = params["alpha"]
		if typeof(a_val) == TYPE_INT or typeof(a_val) == TYPE_FLOAT:
			var a_num: float = float(a_val)
			if a_num > 1.0:
				c.a = clampf(a_num / 255.0, 0.0, 1.0)
			else:
				c.a = clampf(a_num, 0.0, 1.0)

	return c


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
		if fill_color.a > 0.0 and project.frames.size() > 0 and project.frames[0].cels.size() > 0:
			var cel = project.frames[0].cels[0]
			if cel != null and cel.has_method("get_image"):
				if cel.has_method("ensure_canvas_rect_in_bounds"):
					cel.ensure_canvas_rect_in_bounds(Vector2i.ZERO, Vector2i(width, height))
				var c_img: Image = cel.get_image()
				if c_img:
					c_img.fill(fill_color)
				if cel.has_method("update_texture"):
					cel.update_texture()
		var canvas = _api.general.get_canvas()
		if canvas:
			canvas.set("update_all_layers", true)
			canvas.queue_redraw()
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
	var global = _api.get_node_or_null("/root/Global")
	var target_index: int = -1

	if global and "projects" in global:
		var projects_arr: Array = global.projects
		var explicit_name: String = str(params.get("name", "")).strip_edges()
		var canvas_param = params.get("canvas", null)

		# 1. Search by explicit name
		if explicit_name != "":
			for i in range(projects_arr.size()):
				if projects_arr[i].name == explicit_name or projects_arr[i].name.to_lower() == explicit_name.to_lower():
					target_index = i
					break
			if target_index == -1:
				return {
					"success": false,
					"error": "Canvas with name '%s' not found among %d open canvas(es)" % [explicit_name, projects_arr.size()]
				}

		# 2. Search by 'canvas' string or number
		elif canvas_param != null:
			var canvas_str := str(canvas_param).strip_edges()
			# Try matching by name first, even if string contains numbers
			for i in range(projects_arr.size()):
				if projects_arr[i].name == canvas_str or projects_arr[i].name.to_lower() == canvas_str.to_lower():
					target_index = i
					break
			if target_index == -1:
				if canvas_str.is_valid_int():
					target_index = int(canvas_str)
				else:
					return {
						"success": false,
						"error": "Canvas '%s' not found among %d open canvas(es)" % [canvas_str, projects_arr.size()]
					}

		# 3. Use 'index' parameter
		elif params.has("index"):
			target_index = int(params["index"])
		else:
			target_index = 0

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

	var replace_with_blank: bool = bool(params.get("replace_with_blank", true))
	var cur_idx: int = int(global.current_project_index) if "current_project_index" in global else 0
	var target_index: int = int(params.get("index", cur_idx))
	if target_index < 0 or target_index >= projects_arr.size():
		return {
			"success": false,
			"error": "Canvas index %d out of bounds (0..%d)" % [target_index, projects_arr.size() - 1]
		}

	var replaced_with_blank := false
	if projects_arr.size() <= 1:
		if not replace_with_blank:
			return {
				"success": false,
				"error": "Cannot close the only open canvas. Open or create another canvas before closing this one, or pass replace_with_blank=true."
			}
		# Create replacement blank canvas BEFORE removing the last project so Pixelorama never has 0 tabs
		var fallback_frames: Array = []
		var fallback_frame_script = load("res://src/Classes/Frame.gd")
		if fallback_frame_script:
			fallback_frames = Array([], TYPE_OBJECT, "RefCounted", fallback_frame_script)
		var blank_proj = _api.project.new_project(fallback_frames, "untitled", Vector2(64, 64), Color.TRANSPARENT)
		if blank_proj == null:
			return {"success": false, "error": "Failed to create blank replacement canvas before closing last tab"}
		replaced_with_blank = true

	var old_project = projects_arr[target_index]
	var closed_name: String = str(old_project.name)

	# Remove UI tab cleanly before freeing project
	if "tabs" in global and global.tabs and target_index < global.tabs.tab_count:
		global.tabs.remove_tab(target_index)

	# Cleanly remove project (freeing undo_redo and layer references when supported)
	if old_project != null and old_project.has_method("remove"):
		old_project.remove()
	else:
		projects_arr.remove_at(target_index)

	var next_index = clampi(target_index, 0, maxi(0, projects_arr.size() - 1))
	if not projects_arr.is_empty():
		if "current_project_index" in global:
			global.current_project_index = next_index
		if "tabs" in global and global.tabs and global.tabs.tab_count > next_index:
			global.tabs.current_tab = next_index
		_api.project.current_project = projects_arr[next_index]

	var remaining_count: int = global.projects.size()
	var new_active_index: int = int(global.current_project_index) if "current_project_index" in global else 0
	var active_name: String = str(projects_arr[new_active_index].name) if (new_active_index >= 0 and new_active_index < projects_arr.size()) else ""

	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	return {
		"success": true,
		"data": {
			"closed_index": target_index,
			"closed_name": closed_name,
			"remaining_canvases": remaining_count,
			"active_index": new_active_index,
			"active_name": active_name,
			"replaced_with_blank": replaced_with_blank,
			"message": "Closed canvas [%d] '%s'%s" % [
				target_index,
				closed_name,
				" (replaced with fresh blank 'untitled' canvas)" if replaced_with_blank else ""
			]
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

	# Clamp to canvas bounds and cap region at 128x128 to keep JSON responses bounded
	x = clampi(x, 0, image.get_width() - 1)
	y = clampi(y, 0, image.get_height() - 1)
	width = clampi(width, 1, mini(128, image.get_width() - x))
	height = clampi(height, 1, mini(128, image.get_height() - y))

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

	var orig_w := int(project.size.x)
	var orig_h := int(project.size.y)
	var img := _composite_frame_layers(project, frame_idx)

	# Region cropping (x, y, width, height)
	var has_region := params.has("x") or params.has("y") or params.has("width") or params.has("height")
	var crop_x: int = int(params.get("x", 0))
	var crop_y: int = int(params.get("y", 0))
	var crop_w: int = int(params.get("width", orig_w - crop_x))
	var crop_h: int = int(params.get("height", orig_h - crop_y))

	var applied_region = null
	if has_region:
		var rect := Rect2i(crop_x, crop_y, crop_w, crop_h).intersection(Rect2i(0, 0, orig_w, orig_h))
		if rect.has_area():
			var sub_img := Image.create_empty(rect.size.x, rect.size.y, false, img.get_format())
			sub_img.blit_rect(img, rect, Vector2i.ZERO)
			img = sub_img
			applied_region = {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}
		else:
			return {"success": false, "error": "Specified region [x:%d, y:%d, w:%d, h:%d] does not intersect canvas" % [crop_x, crop_y, crop_w, crop_h]}

	# Scale down if scale or max_size is set
	var cur_w := img.get_width()
	var cur_h := img.get_height()

	if params.has("scale"):
		var sc: float = float(params["scale"])
		if sc > 0.0 and sc != 1.0 and sc <= 32.0:
			var target_w := maxi(1, mini(4096, int(roundf(cur_w * sc))))
			var target_h := maxi(1, mini(4096, int(roundf(cur_h * sc))))
			img.resize(target_w, target_h, Image.INTERPOLATE_NEAREST)
			cur_w = target_w
			cur_h = target_h

	if params.has("max_size"):
		var max_s: int = int(params["max_size"])
		if max_s > 0 and (cur_w > max_s or cur_h > max_s):
			var ratio := float(max_s) / maxf(float(cur_w), float(cur_h))
			var target_w := maxi(1, int(roundf(cur_w * ratio)))
			var target_h := maxi(1, int(roundf(cur_h * ratio)))
			img.resize(target_w, target_h, Image.INTERPOLATE_NEAREST)
			cur_w = target_w
			cur_h = target_h

	var png_buffer := img.save_png_to_buffer()
	var b64 := Marshalls.raw_to_base64(png_buffer)
	var sc_val: float = float(params.get("scale", 1.0))
	var is_downscaled: bool = (cur_w < orig_w or cur_h < orig_h)
	return {
		"success": true,
		"data": {
			"base64": b64,
			"width": cur_w,
			"height": cur_h,
			"original_width": orig_w,
			"original_height": orig_h,
			"frame": frame_idx,
			"scale": sc_val,
			"downscaled": is_downscaled,
			"region": applied_region
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
			if cel_used.has_area():
				cel_used.position += _get_cel_offset(cel)
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

	var scale_x := float(new_w) / float(old_w)
	var scale_y := float(new_h) / float(old_h)
	for f in project.frames:
		for cel in f.cels:
			if cel.get_class_name() == "PixelCel":
				var img: Image = cel.get_image()
				var scaled_size := Vector2i(
					maxi(1, roundi(float(img.get_width()) * scale_x)),
					maxi(1, roundi(float(img.get_height()) * scale_y))
				)
				img.resize(scaled_size.x, scaled_size.y, interpolation)
				var offset := _get_cel_offset(cel)
				if cel.has_method("change_offset"):
					cel.change_offset(Vector2i(roundi(offset.x * scale_x), roundi(offset.y * scale_y)))
				if cel.has_method("update_texture"):
					cel.update_texture()

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
					"layer_index": cur_cursor.layer,
					"layer_name": cur_cursor.layer_name,
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
			var prev_cursor := _get_active_cursor_info(project)
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
			return {"success": false, "error": "Nothing to redo"}
	return {"success": false, "error": "UndoRedo system not available"}

func _put_pixel(image: Image, x: int, y: int, color: Color, blend: bool = false) -> void:
	if x < 0 or x >= image.get_width() or y < 0 or y >= image.get_height():
		return
	if blend:
		if color.a <= 0.001:
			return  # skip drawing transparent pixel when blending
		var cur: Color = image.get_pixel(x, y)
		if cur.a > 0.001:
			image.set_pixel(x, y, cur.blend(color))
			return
	image.set_pixel(x, y, color)


func _draw_flat_pixels_fast(image: Image, flat_data: Array, blend: bool) -> Dictionary:
	var w := image.get_width()
	var h := image.get_height()
	var drawn := 0
	var skipped := 0
	var total_items := flat_data.size()
	if total_items < 3:
		return {"drawn": 0, "skipped": 0}

	# Detect stride:
	# Stride 3: [x, y, "#hex", x, y, "#hex", ...]
	# Stride 6: [x, y, r, g, b, a, ...]
	var stride := 3
	var mode_hex := false

	if typeof(flat_data[2]) == TYPE_STRING:
		stride = 3
		mode_hex = true
	elif total_items >= 6 and (typeof(flat_data[2]) == TYPE_INT or typeof(flat_data[2]) == TYPE_FLOAT):
		stride = 6
		mode_hex = false
	else:
		stride = 3
		mode_hex = true

	var color_cache := {}
	var i := 0

	while i + stride <= total_items:
		var x: int = int(flat_data[i])
		var y: int = int(flat_data[i + 1])
		if x < 0 or x >= w or y < 0 or y >= h:
			skipped += 1
			i += stride
			continue

		var color: Color
		if mode_hex:
			var hex_str: String = str(flat_data[i + 2])
			if color_cache.has(hex_str):
				color = color_cache[hex_str]
			else:
				color = Color.html(hex_str) if Color.html_is_valid(hex_str) else Color.BLACK
				color_cache[hex_str] = color
		else:
			var r_val: float = float(flat_data[i + 2])
			var g_val: float = float(flat_data[i + 3])
			var b_val: float = float(flat_data[i + 4])
			var a_val: float = float(flat_data[i + 5])
			if r_val > 1.0 or g_val > 1.0 or b_val > 1.0 or a_val > 1.0:
				color = Color(r_val * 0.0039215686, g_val * 0.0039215686, b_val * 0.0039215686, a_val * 0.0039215686)
			else:
				color = Color(r_val, g_val, b_val, a_val)

		_put_pixel(image, x, y, color, blend)
		drawn += 1
		i += stride

	return {"drawn": drawn, "skipped": skipped}


func _cmd_draw_pixel(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var image: Image = target.image
	var x: int = int(params.get("x", 0))
	var y: int = int(params.get("y", 0))
	var color := _parse_color(params)
	var blend: bool = bool(params.get("blend", false))

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

	_put_pixel(image, x, y, color, blend)
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

	var blend: bool = bool(params.get("blend", false))
	var image: Image = target.image

	if params.has("flat_pixels") and (params["flat_pixels"] is Array) and not params["flat_pixels"].is_empty():
		var res := _draw_flat_pixels_fast(image, params["flat_pixels"], blend)
		_commit_image_change(image, "Draw Pixels (fast)", target.frame, target.layer)
		return {
			"success": true,
			"data": {
				"drawn": res.drawn,
				"skipped": res.skipped,
				"pixels_drawn": res.drawn,
				"pixels_clipped": res.skipped,
				"total": res.drawn + res.skipped,
				"frame": target.frame,
				"layer": target.layer
			}
		}

	if params.has("data") and (params["data"] is Array) and not params["data"].is_empty():
		var res := _draw_flat_pixels_fast(image, params["data"], blend)
		_commit_image_change(image, "Draw Pixels (fast)", target.frame, target.layer)
		return {
			"success": true,
			"data": {
				"drawn": res.drawn,
				"skipped": res.skipped,
				"pixels_drawn": res.drawn,
				"pixels_clipped": res.skipped,
				"total": res.drawn + res.skipped,
				"frame": target.frame,
				"layer": target.layer
			}
		}

	var pixels: Array = params.get("pixels", [])
	if pixels.is_empty():
		return {"success": false, "error": "Missing or empty 'pixels' or 'flat_pixels' array"}

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

		_put_pixel(image, x, y, color, blend)
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


func _cmd_draw_pixels_fast(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var raw_data: Array = []
	if params.has("data") and (params["data"] is Array):
		raw_data = params["data"]
	elif params.has("flat_pixels") and (params["flat_pixels"] is Array):
		raw_data = params["flat_pixels"]

	if raw_data.is_empty():
		if params.has("pixels") and (params["pixels"] is Array):
			return {"success": false, "error": "draw_pixels_fast requires a flat array [x,y,color,...] or [x,y,r,g,b,a,...], not an array of objects. Use 'draw_pixels' for object arrays."}
		return {"success": false, "error": "Missing or empty flat pixel array (data / flat_pixels)"}

	if not raw_data.is_empty() and (raw_data[0] is Dictionary):
		return {"success": false, "error": "draw_pixels_fast requires a flat array [x,y,color,...] or [x,y,r,g,b,a,...], not an array of objects. Use 'draw_pixels' for object arrays."}

	var blend: bool = bool(params.get("blend", false))
	var image: Image = target.image

	var res := _draw_flat_pixels_fast(image, raw_data, blend)
	_commit_image_change(image, "Draw Pixels Fast", target.frame, target.layer)

	return {
		"success": true,
		"data": {
			"drawn": res.drawn,
			"skipped": res.skipped,
			"pixels_drawn": res.drawn,
			"pixels_clipped": res.skipped,
			"total": res.drawn + res.skipped,
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
	var blend: bool = bool(params.get("blend", false))
	var max_r: int = mini(width >> 1, height >> 1)
	var corner_radius: int = clampi(int(params.get("corner_radius", 0)), 0, max_r)
	var corner_style: String = str(params.get("corner_style", "round")).to_lower()

	var img_w := image.get_width()
	var img_h := image.get_height()
	var drawn := 0
	var total := 0

	if corner_radius <= 0:
		if filled:
			total = width * height
			var clamped := Rect2i(x, y, width, height).intersection(Rect2i(0, 0, img_w, img_h))
			if clamped.has_area():
				if blend and color.a < 1.0:
					for py in range(clamped.position.y, clamped.end.y):
						for px in range(clamped.position.x, clamped.end.x):
							_put_pixel(image, px, py, color, true)
				else:
					image.fill_rect(clamped, color)
				drawn = clamped.get_area()
		else:
			total = width * 2 + maxi(0, height - 2) * 2
			for px in range(x, x + width):
				if px >= 0 and px < img_w:
					if y >= 0 and y < img_h:
						_put_pixel(image, px, y, color, blend)
						drawn += 1
					var bot := y + height - 1
					if bot >= 0 and bot < img_h and height > 1:
						_put_pixel(image, px, bot, color, blend)
						drawn += 1
			for py in range(y + 1, y + height - 1):
				if py >= 0 and py < img_h:
					if x >= 0 and x < img_w:
						_put_pixel(image, x, py, color, blend)
						drawn += 1
					var right := x + width - 1
					if right >= 0 and right < img_w and width > 1:
						_put_pixel(image, right, py, color, blend)
						drawn += 1
	else:
		# Compute symmetrical corner inset for top/bottom corner_radius rows
		var row_insets: Array[int] = []
		row_insets.resize(corner_radius)
		if corner_style == "chamfer":
			for dy in range(corner_radius):
				row_insets[dy] = corner_radius - dy
		else:
			if corner_radius == 1:
				row_insets[0] = 1
			else:
				var eb := _rasterize_ellipse_bounds(0, 0, 2 * corner_radius, 2 * corner_radius)
				var rmin: Dictionary = eb.row_min
				for dy in range(corner_radius):
					row_insets[dy] = int(rmin.get(dy, 0))

		var get_row_inset := func(row_offset: int) -> int:
			var dy_edge := mini(row_offset, (height - 1) - row_offset)
			return row_insets[dy_edge] if dy_edge < corner_radius else 0

		if filled:
			for row_off in range(height):
				var py := y + row_off
				var inset: int = get_row_inset.call(row_off)
				var lx := x + inset
				var rx_end := x + width - 1 - inset
				if rx_end < lx:
					continue
				total += (rx_end - lx + 1)
				if py < 0 or py >= img_h:
					continue
				var clx := maxi(lx, 0)
				var crx := mini(rx_end, img_w - 1)
				for px in range(clx, crx + 1):
					_put_pixel(image, px, py, color, blend)
					drawn += 1
		else:
			var outline_seen := {}
			for row_off in range(height):
				var py := y + row_off
				var inset: int = get_row_inset.call(row_off)
				var lx := x + inset
				var rx_end := x + width - 1 - inset
				if rx_end < lx:
					continue
				if row_off == 0 or row_off == height - 1:
					for px in range(lx, rx_end + 1):
						outline_seen[Vector2i(px, py)] = true
				else:
					var outer_row := row_off - 1 if row_off < (height >> 1) else row_off + 1
					var prev_inset: int = get_row_inset.call(outer_row)
					var left_span_end := maxi(lx, x + prev_inset - 1)
					var right_span_start := mini(rx_end, x + width - 1 - prev_inset + 1)
					for px in range(lx, mini(left_span_end, rx_end) + 1):
						outline_seen[Vector2i(px, py)] = true
					for px in range(maxi(right_span_start, lx), rx_end + 1):
						outline_seen[Vector2i(px, py)] = true
			total = outline_seen.size()
			for pt in outline_seen.keys():
				var pv: Vector2i = pt
				if pv.x >= 0 and pv.x < img_w and pv.y >= 0 and pv.y < img_h:
					_put_pixel(image, pv.x, pv.y, color, blend)
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
			"corner_radius": corner_radius,
			"corner_style": corner_style,
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
	var blend: bool = bool(params.get("blend", false))

	var res := _draw_line_on_image(image, x1, y1, x2, y2, color, blend)
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


func _draw_line_on_image(image: Image, x1: int, y1: int, x2: int, y2: int, color: Color, blend: bool = false) -> Dictionary:
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
			_put_pixel(image, cx, cy, color, blend)
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
	var blend: bool = bool(params.get("blend", false))
	var image: Image = target.image

	var drawn := 0
	var clipped := 0
	for i in range(points.size() - 1):
		var res := _draw_line_on_image(image, int(points[i].x), int(points[i].y), int(points[i+1].x), int(points[i+1].y), color, blend)
		drawn += res.drawn
		clipped += res.clipped

	if closed and points.size() > 2:
		var res := _draw_line_on_image(image, int(points[-1].x), int(points[-1].y), int(points[0].x), int(points[0].y), color, blend)
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
	for i in range(points_array.size()):
		var p = points_array[i]
		if not (p is Dictionary):
			return {"success": false, "error": "Point at index %d is not an object" % i}
		var px_raw = p.get("x", null)
		var py_raw = p.get("y", null)
		if px_raw == null or py_raw == null or is_nan(float(px_raw)) or is_nan(float(py_raw)):
			return {"success": false, "error": "Point at index %d has invalid or NaN coordinates: x=%s, y=%s" % [i, str(px_raw), str(py_raw)]}
		var x: int = int(roundf(float(px_raw)))
		var y: int = int(roundf(float(py_raw)))
		points.append(Vector2(x, y))
		min_x = mini(min_x, x)
		max_x = maxi(max_x, x)
		min_y = mini(min_y, y)
		max_y = maxi(max_y, y)

	var filled: bool = bool(params.get("filled", true))
	var color := _parse_color(params)
	var blend: bool = bool(params.get("blend", false))
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
						_put_pixel(image, px, py, color, blend)
						drawn += 1
					else:
						clipped += 1
	else:
		for i in range(points.size() - 1):
			var res := _draw_line_on_image(image, int(points[i].x), int(points[i].y), int(points[i+1].x), int(points[i+1].y), color, blend)
			drawn += res.drawn
			clipped += res.clipped
		var res := _draw_line_on_image(image, int(points[-1].x), int(points[-1].y), int(points[0].x), int(points[0].y), color, blend)
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
	var rx: int = maxi(0, int(params.get("rx", 1)))
	var ry: int = maxi(0, int(params.get("ry", 1)))
	var filled: bool = bool(params.get("filled", true))
	var color := _parse_color(params)
	var blend: bool = bool(params.get("blend", false))

	var img_w := image.get_width()
	var img_h := image.get_height()
	var drawn := 0
	var clipped := 0

	var eb := _rasterize_ellipse_bounds(cx - rx, cy - ry, cx + rx, cy + ry)

	if filled:
		var row_min: Dictionary = eb.row_min
		var row_max: Dictionary = eb.row_max
		for py in range(int(eb.min_y), int(eb.max_y) + 1):
			if not row_min.has(py):
				continue
			var lx: int = int(row_min[py])
			var rx_end: int = int(row_max[py])
			for px in range(lx, rx_end + 1):
				if px >= 0 and px < img_w and py >= 0 and py < img_h:
					_put_pixel(image, px, py, color, blend)
					drawn += 1
				else:
					clipped += 1
	else:
		var outline_pts: Array = eb.outline
		for pt in outline_pts:
			var pv: Vector2i = pt
			if pv.x >= 0 and pv.x < img_w and pv.y >= 0 and pv.y < img_h:
				_put_pixel(image, pv.x, pv.y, color, blend)
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
	var blend: bool = bool(params.get("blend", false))
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
			_put_pixel(image, fill_x, py, color, blend)
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
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var frame_res := _resolve_frame_indices(project, params)
	if frame_res.error != "":
		return {"success": false, "error": frame_res.error}

	var layer_idx: int = _resolve_layer_index(params, project)
	if layer_idx < 0 or layer_idx >= project.layers.size():
		return {"success": false, "error": "Layer index out of bounds or not found: %s (available: 0..%d)" % [str(params.get("layer", layer_idx)), project.layers.size() - 1]}

	var color := _parse_color(params, "color", Color.BLACK)
	var thickness: int = clampi(int(params.get("thickness", 1)), 1, 4)
	var inside: bool = bool(params.get("inside", false))
	var frame_indices: Array = frame_res.frames
	var total_count := 0
	var per_frame: Array = []

	for fi in frame_indices:
		var cel = project.frames[fi].cels[layer_idx]
		if cel == null or cel.get_class_name() != "PixelCel":
			return {"success": false, "error": "Cel at [frame:%d, layer:%d] is not a PixelCel" % [fi, layer_idx]}

		var image: Image = _cel_to_canvas_image(cel, project)
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

		_commit_image_change(outlined_img, "Apply Outline", fi, layer_idx)
		total_count += count
		per_frame.append({"frame": fi, "outline_pixels": count})

	return {
		"success": true,
		"data": {
			"outline_pixels": total_count,
			"color": color.to_html(),
			"thickness": thickness,
			"inside": inside,
			"frame": frame_indices[0],
			"frames": frame_indices,
			"frames_processed": frame_indices.size(),
			"per_frame": per_frame,
			"layer": layer_idx,
			"layer_name": project.layers[layer_idx].name
		}
	}


func _cmd_apply_dithering(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var frame_res := _resolve_frame_indices(project, params)
	if frame_res.error != "":
		return {"success": false, "error": frame_res.error}

	var layer_idx: int = _resolve_layer_index(params, project)
	if layer_idx < 0 or layer_idx >= project.layers.size():
		return {"success": false, "error": "Layer index out of bounds or not found: %s (available: 0..%d)" % [str(params.get("layer", layer_idx)), project.layers.size() - 1]}

	var raw_c1 := str(params.get("color1", "")).strip_edges()
	var raw_c2 := str(params.get("color2", "")).strip_edges()
	var use_c1 := (not raw_c1.is_empty()) and (raw_c1.to_lower() != "keep")
	var use_c2 := (not raw_c2.is_empty()) and (raw_c2.to_lower() != "keep")

	if not use_c1 and not use_c2:
		return {"success": false, "error": "At least one of 'color1' or 'color2' must be a valid hex color (not both omitted/'keep')"}

	var col1 := Color.TRANSPARENT
	var col2 := Color.TRANSPARENT
	if use_c1:
		if raw_c1.to_lower() == "transparent":
			col1 = Color.TRANSPARENT
		elif Color.html_is_valid(raw_c1):
			col1 = Color.html(raw_c1)
		else:
			return {"success": false, "error": "Invalid color1 hex: '%s'" % raw_c1}
	if use_c2:
		if raw_c2.to_lower() == "transparent":
			col2 = Color.TRANSPARENT
		elif Color.html_is_valid(raw_c2):
			col2 = Color.html(raw_c2)
		else:
			return {"success": false, "error": "Invalid color2 hex: '%s'" % raw_c2}

	var pattern: String = str(params.get("pattern", "checker_50")).to_lower()
	var shape: String = str(params.get("shape", "rect")).to_lower()
	var within_selection: bool = bool(params.get("within_selection", true))
	var preserve_alpha: bool = bool(params.get("preserve_alpha", false))
	var alpha_threshold: float = clampf(float(params.get("alpha_threshold", 0.01)), 0.0, 1.0)
	var blend: bool = bool(params.get("blend", false))

	var has_sel: bool = within_selection and ("has_selection" in project) and bool(project.has_selection)
	var sel_map = project.selection_map if (has_sel and ("selection_map" in project)) else null
	if sel_map == null:
		has_sel = false

	var canvas_w := int(project.size.x)
	var canvas_h := int(project.size.y)
	var has_explicit_rect := (
		(params.has("x") and params["x"] != null)
		or (params.has("y") and params["y"] != null)
		or (params.has("width") and params["width"] != null)
		or (params.has("height") and params["height"] != null)
	)

	var rx := 0
	var ry := 0
	var rw := canvas_w
	var rh := canvas_h
	if has_explicit_rect:
		rx = int(params.get("x", 0))
		ry = int(params.get("y", 0))
		rw = maxi(1, int(params.get("width", canvas_w - rx)))
		rh = maxi(1, int(params.get("height", canvas_h - ry)))
	elif has_sel and sel_map.has_method("get_used_rect"):
		var srect: Rect2i = sel_map.get_used_rect()
		if srect.has_area():
			rx = srect.position.x
			ry = srect.position.y
			rw = srect.size.x
			rh = srect.size.y

	var ellipse_row_min := {}
	var ellipse_row_max := {}
	if shape == "ellipse":
		var eb := _rasterize_ellipse_bounds(rx, ry, rx + rw - 1, ry + rh - 1)
		ellipse_row_min = eb.row_min
		ellipse_row_max = eb.row_max

	var bayer4 := [
		[  0.5 / 16.0,  8.5 / 16.0,  2.5 / 16.0, 10.5 / 16.0 ],
		[ 12.5 / 16.0,  4.5 / 16.0, 14.5 / 16.0,  6.5 / 16.0 ],
		[  3.5 / 16.0, 11.5 / 16.0,  1.5 / 16.0,  9.5 / 16.0 ],
		[ 15.5 / 16.0,  7.5 / 16.0, 13.5 / 16.0,  5.5 / 16.0 ]
	]

	var frame_indices: Array = frame_res.frames
	var total_drawn := 0
	var y_start := maxi(0, ry)
	var y_end := mini(canvas_h, ry + rh)
	var x_start := maxi(0, rx)
	var x_end := mini(canvas_w, rx + rw)

	for fi in frame_indices:
		var cel = project.frames[fi].cels[layer_idx]
		if cel == null or cel.get_class_name() != "PixelCel":
			return {"success": false, "error": "Cel at [frame:%d, layer:%d] is not a PixelCel" % [fi, layer_idx]}

		var image: Image = _cel_to_canvas_image(cel, project)
		var frame_drawn := 0

		for py in range(y_start, y_end):
			var row_x0 := x_start
			var row_x1 := x_end
			if shape == "ellipse":
				if not ellipse_row_min.has(py):
					continue
				row_x0 = maxi(x_start, int(ellipse_row_min[py]))
				row_x1 = mini(x_end, int(ellipse_row_max[py]) + 1)

			for px in range(row_x0, row_x1):
				if has_sel:
					var selected := false
					if sel_map.has_method("is_pixel_selected"):
						selected = sel_map.is_pixel_selected(Vector2i(px, py), true, project)
					else:
						selected = sel_map.get_pixel(px, py).a > 0.01
					if not selected:
						continue

				if preserve_alpha:
					if image.get_pixel(px, py).a <= alpha_threshold:
						continue

				var use_second := false
				match pattern:
					"checker_50":
						use_second = posmod(px + py, 2) == 0
					"light_25":
						use_second = (posmod(px, 2) == 0) and (posmod(py, 2) == 0)
					"dense_75":
						use_second = not ((posmod(px, 2) == 1) and (posmod(py, 2) == 1))
					"bayer_25":
						use_second = bayer4[posmod(py, 4)][posmod(px, 4)] < 0.25
					"bayer_50":
						use_second = bayer4[posmod(py, 4)][posmod(px, 4)] < 0.50
					"bayer_75":
						use_second = bayer4[posmod(py, 4)][posmod(px, 4)] < 0.75
					"horizontal":
						use_second = posmod(py, 2) == 0
					"vertical":
						use_second = posmod(px, 2) == 0
					"diagonal":
						use_second = posmod(px + py, 4) == 0
					_:
						use_second = posmod(px + py, 2) == 0

				if use_second:
					if use_c2:
						_put_pixel(image, px, py, col2, blend)
						frame_drawn += 1
				else:
					if use_c1:
						_put_pixel(image, px, py, col1, blend)
						frame_drawn += 1

		_commit_image_change(image, "Apply Dithering", fi, layer_idx)
		total_drawn += frame_drawn

	return {
		"success": true,
		"data": {
			"x": rx,
			"y": ry,
			"width": rw,
			"height": rh,
			"pattern": pattern,
			"shape": shape,
			"within_selection": has_sel,
			"preserve_alpha": preserve_alpha,
			"pixels_drawn": total_drawn,
			"frame": frame_indices[0],
			"frames": frame_indices,
			"frames_processed": frame_indices.size(),
			"layer": layer_idx,
			"layer_name": project.layers[layer_idx].name
		}
	}


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
	elif mode == "mirror_bottom_to_top":
		var half_h := h / 2
		for y in range(half_h):
			for x in range(w):
				var px = image.get_pixel(x, h - 1 - y)
				new_img.set_pixel(x, y, px)
	else:
		if axis == "vertical":
			new_img.flip_y()
		else:
			new_img.flip_x()

	_commit_image_change(new_img, "Mirror / Flip Layer", target.frame, target.layer)
	return {"success": true, "data": {"axis": axis, "mode": mode, "frame": target.frame, "layer": target.layer}}


func _cmd_transform_cel(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var frame_res := _resolve_frame_indices(project, params)
	if frame_res.error != "":
		return {"success": false, "error": frame_res.error}

	var layer_idx: int = _resolve_layer_index(params, project)
	if layer_idx < 0 or layer_idx >= project.layers.size():
		return {"success": false, "error": "Layer index out of bounds or not found: %s (available: 0..%d)" % [str(params.get("layer", layer_idx)), project.layers.size() - 1]}

	var dx: int = int(params.get("dx", 0))
	var dy: int = int(params.get("dy", 0))
	var wrap_around: bool = bool(params.get("wrap_around", false))
	var frame_indices: Array = frame_res.frames
	var total_shifted := 0

	for fi in frame_indices:
		var cel = project.frames[fi].cels[layer_idx]
		if cel == null or cel.get_class_name() != "PixelCel":
			return {"success": false, "error": "Cel at [frame:%d, layer:%d] is not a PixelCel" % [fi, layer_idx]}

		if not wrap_around and cel.has_method("copy_content") and cel.has_method("change_offset"):
			var content = cel.copy_content()
			var shifted_count := 0
			var compact_image: Image = content[0]
			var used := compact_image.get_used_rect()
			for py in range(used.position.y, used.end.y):
				for px in range(used.position.x, used.end.x):
					if compact_image.get_pixel(px, py).a > 0.001:
						shifted_count += 1
			_commit_compact_cel_content(
				content[0],
				content[1] + Vector2i(dx, dy),
				"Transform Cel (%d, %d)" % [dx, dy],
				fi,
				layer_idx
			)
			total_shifted += shifted_count
			continue

		var image: Image = _cel_to_canvas_image(cel, project)
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

		_commit_image_change(new_image, "Transform Cel (%d, %d)" % [dx, dy], fi, layer_idx)
		total_shifted += shifted_pixels

	return {
		"success": true,
		"data": {
			"dx": dx,
			"dy": dy,
			"wrap_around": wrap_around,
			"shifted_pixels": total_shifted,
			"frame": frame_indices[0],
			"frames": frame_indices,
			"frames_processed": frame_indices.size(),
			"layer": layer_idx,
			"layer_name": project.layers[layer_idx].name
		}
	}


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
	var preserve_alpha: bool = bool(params.get("preserve_alpha", false))

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
					var out_a: float = px.a if preserve_alpha else new_color.a
					modified_img.set_pixel(x, y, Color(new_color.r, new_color.g, new_color.b, out_a))
					replaced_count += 1

	_commit_image_change(modified_img, "Color Replace", target.frame, target.layer)
	return {"success": true, "data": {"replaced_pixels": replaced_count, "old_color": old_color.to_html(), "new_color": new_color.to_html(), "preserve_alpha": preserve_alpha, "frame": target.frame, "layer": target.layer}}


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

	var above_layer: int = project.layers.size() - 1
	if params.has("above_layer"):
		above_layer = _resolve_layer_index({"layer": params["above_layer"]}, project)
	if above_layer < 0 or above_layer >= project.layers.size():
		return {"success": false, "error": "Invalid above_layer index: %d" % above_layer}

	_api.project.add_new_layer(above_layer, layer_name, type)

	# Ensure all layer.index properties are strictly synchronized
	for i in range(project.layers.size()):
		project.layers[i].index = i
	project.order_layers()
	if project.has_signal("layers_updated"):
		project.layers_updated.emit()

	var new_layer_idx := above_layer + 1
	project.current_layer = clampi(new_layer_idx, 0, project.layers.size() - 1)
	_api.project.current_layer = project.current_layer
	_api.project.select_cels([[project.current_frame, project.current_layer]])

	var canvas = _api.general.get_canvas()
	if canvas:
		if "project_changed" in canvas:
			canvas.project_changed = true
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	var actual_name := layer_name
	var new_layer_id := ""
	if new_layer_idx < project.layers.size():
		var lyr = project.layers[new_layer_idx]
		actual_name = lyr.name
		new_layer_id = _get_or_create_layer_id(lyr)

	return {
		"success": true,
		"data": {
			"name": actual_name,
			"layer_id": new_layer_id,
			"type": type,
			"above_layer": above_layer,
			"layer_index": new_layer_idx,
			"total_layers": project.layers.size(),
			"active_cursor": _get_active_cursor_info(project)
		}
	}


func _cmd_delete_layer(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}
	if project.layers.size() <= 1:
		return {"success": false, "error": "Cannot delete the only layer in project"}

	var layer_index: int = _resolve_layer_index(params, project)
	if layer_index < 0 or layer_index >= project.layers.size():
		return {"success": false, "error": "Invalid layer index or identifier: %s" % str(params.get("index", params.get("layer_id", params.get("layer", layer_index))))}

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

	var layer_index: int = _resolve_layer_index(params, project)
	if layer_index < 0 or layer_index >= project.layers.size():
		return {"success": false, "error": "Invalid layer index or identifier: %s" % str(params.get("index", params.get("layer_id", params.get("layer", layer_index))))}

	var opacity: float = float(params.get("opacity", 1.0))
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

	return {
		"success": true,
		"data": {
			"index": layer_index,
			"layer_id": _get_or_create_layer_id(project.layers[layer_index]),
			"opacity": opacity
		}
	}


func _cmd_set_layer_blend_mode(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var layer_index: int = _resolve_layer_index(params, project)
	if layer_index < 0 or layer_index >= project.layers.size():
		return {"success": false, "error": "Invalid layer index or identifier: %s" % str(params.get("index", params.get("layer_id", params.get("layer", layer_index))))}

	var blend_mode: int = int(params.get("blend_mode", 0))
	project.layers[layer_index].blend_mode = blend_mode
	var canvas = _api.general.get_canvas()
	if canvas:
		if "project_changed" in canvas:
			canvas.project_changed = true
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()
	return {
		"success": true,
		"data": {
			"index": layer_index,
			"layer_id": _get_or_create_layer_id(project.layers[layer_index]),
			"blend_mode": blend_mode
		}
	}


func _cmd_set_layer_visibility(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var layer_index: int = _resolve_layer_index(params, project)
	if layer_index < 0 or layer_index >= project.layers.size():
		return {"success": false, "error": "Invalid layer index or identifier: %s" % str(params.get("index", params.get("layer_id", params.get("layer", layer_index))))}

	var visible: bool = bool(params.get("visible", true))
	project.layers[layer_index].visible = visible
	var canvas = _api.general.get_canvas()
	if canvas:
		if "project_changed" in canvas:
			canvas.project_changed = true
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()
	return {
		"success": true,
		"data": {
			"index": layer_index,
			"layer_id": _get_or_create_layer_id(project.layers[layer_index]),
			"visible": visible
		}
	}


func _cmd_set_layer_name(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var index: int = _resolve_layer_index(params, project)
	var name: String = str(params.get("name", "")).strip_edges()

	if index < 0 or index >= project.layers.size():
		return {"success": false, "error": "Invalid layer index: %d" % index}
	if name == "":
		return {"success": false, "error": "Layer name cannot be empty"}

	var old_name: String = project.layers[index].name
	project.layers[index].name = name
	return {
		"success": true,
		"data": {
			"index": index,
			"layer_id": _get_or_create_layer_id(project.layers[index]),
			"old_name": old_name,
			"new_name": name
		}
	}


func _cmd_reorder_layers(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var from_index: int = -1
	if params.has("from_index"):
		from_index = _resolve_layer_index({"layer": params["from_index"]}, project)
	var to_index: int = -1
	if params.has("to_index"):
		to_index = _resolve_layer_index({"layer": params["to_index"]}, project)

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
		var type_str := "Pixel"
		if layer.has_method("get_layer_type"):
			var t: int = layer.get_layer_type()
			match t:
				0: type_str = "Pixel"
				1: type_str = "Group"
				2: type_str = "3D"
				3: type_str = "TileMap"
				4: type_str = "Audio"
				_: type_str = "Pixel"
		elif "type" in layer:
			match int(layer.type):
				0: type_str = "Pixel"
				1: type_str = "Group"
				2: type_str = "3D"
				3: type_str = "TileMap"
				4: type_str = "Audio"
				_: type_str = "Pixel"

		layers.append({
			"index": i,
			"layer_id": _get_or_create_layer_id(layer),
			"name": layer.name,
			"visible": layer.visible,
			"locked": layer.locked,
			"opacity": layer.opacity,
			"blend_mode": layer.blend_mode,
			"type": type_str,
		})

	return {"success": true, "data": {"layers": layers, "current_layer": project.current_layer, "total_layers": project.layers.size()}}


# ─────────────────────────────────────────────
# FRAME COMMANDS
# ─────────────────────────────────────────────

func _cmd_add_frame(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var after_frame: int = int(params.get("after_frame", project.current_frame))
	if after_frame < 0 or after_frame >= project.frames.size():
		return {"success": false, "error": "Invalid after_frame index: %d" % after_frame}

	var count: int = clampi(int(params.get("count", 1)), 1, 500)
	var old_current_frame: int = project.current_frame

	if project.has_method("new_empty_frame") and project.has_method("add_frames") and project.undo_redo != null:
		var new_frames: Array = []
		var indices := PackedInt32Array()
		var new_animation_tags: Array = project.animation_tags.duplicate()
		for i in range(new_animation_tags.size()):
			new_animation_tags[i] = new_animation_tags[i].duplicate()

		for k in range(count):
			var insert_at := after_frame + 1 + k
			var frame = project.new_empty_frame()
			for l in range(project.layers.size()):
				if project.layers[l].new_cels_linked:
					var prev_cel = project.frames[after_frame].cels[l]
					if prev_cel.link_set == null:
						prev_cel.link_set = {"cels": [prev_cel]}
					elif not prev_cel.link_set.has("cels"):
						prev_cel.link_set["cels"] = [prev_cel]
					frame.cels[l].set_content(prev_cel.get_content(), prev_cel.image_texture)
					frame.cels[l].link_set = prev_cel.link_set
			new_frames.append(frame)
			indices.append(insert_at)
			for tag in new_animation_tags:
				if insert_at >= tag.from and insert_at <= tag.to:
					tag.to += 1
				elif insert_at < tag.from:
					tag.from += 1
					tag.to += 1

		var action_name := "Add Frame" if count == 1 else "Add %d Frames" % count
		project.undo_redo.create_action(action_name)
		project.undo_redo.add_do_method(project.add_frames.bind(new_frames, indices))
		project.undo_redo.add_undo_method(project.remove_frames.bind(indices))
		project.undo_redo.add_do_property(project, "animation_tags", new_animation_tags)
		project.undo_redo.add_undo_property(project, "animation_tags", project.animation_tags)
		project.undo_redo.add_do_method(project.change_cel.bind(after_frame + count))
		project.undo_redo.add_undo_method(project.change_cel.bind(old_current_frame))
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
	else:
		for k in range(count):
			_api.project.add_new_frame(after_frame + k)

	return {
		"success": true,
		"data": {
			"after_frame": after_frame,
			"count": count,
			"inserted_range": [after_frame + 1, after_frame + count],
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

	var src_index: int = int(params.get("index", project.current_frame))
	if src_index < 0 or src_index >= project.frames.size():
		return {"success": false, "error": "Invalid frame index: %d" % src_index}

	var count: int = clampi(int(params.get("count", 1)), 1, 100)
	var insert_at: int = src_index + 1
	var src_frame = project.frames[src_index]
	var frame_script = src_frame.get_script()
	var frame_class = load("res://src/Classes/Frame.gd") if frame_script == null else null

	# Count non-transparent pixels in source frame once
	var src_pixels := 0
	for l in range(project.layers.size()):
		var sc = src_frame.cels[l]
		if sc.get_class_name() == "PixelCel":
			var img: Image = sc.get_image()
			if img:
				var used := img.get_used_rect()
				for y in range(used.position.y, used.end.y):
					for x in range(used.position.x, used.end.x):
						if img.get_pixel(x, y).a > 0.01:
							src_pixels += 1

	var new_frames: Array = []
	var indices := PackedInt32Array()
	var new_animation_tags: Array = project.animation_tags.duplicate()
	for i in new_animation_tags.size():
		new_animation_tags[i] = new_animation_tags[i].duplicate()

	for k in range(count):
		var new_frame = frame_script.new() if frame_script else (frame_class.new() if frame_class else null)
		if new_frame != null and "duration" in new_frame:
			new_frame.duration = src_frame.duration

		for l in range(project.layers.size()):
			var src_cel = src_frame.cels[l]
			var new_cel = src_cel.duplicate_cel()
			if project.layers[l].new_cels_linked:
				if src_cel.link_set == null:
					src_cel.link_set = {"cels": [src_cel]}
				elif not src_cel.link_set.has("cels"):
					src_cel.link_set["cels"] = [src_cel]
				new_cel.set_content(src_cel.get_content(), src_cel.image_texture)
				new_cel.link_set = src_cel.link_set
			else:
				new_cel.set_content(src_cel.copy_content())
			new_frame.cels.append(new_cel)

		var target_idx := insert_at + k
		new_frames.append(new_frame)
		indices.append(target_idx)

		for tag in new_animation_tags:
			if target_idx >= tag.from and target_idx <= tag.to:
				tag.to += 1
			elif target_idx < tag.from:
				tag.from += 1
				tag.to += 1

	var total_pixels_copied := src_pixels * count
	var action_name := "Add Frame" if count == 1 else "Duplicate Frame (%dx)" % count
	project.undo_redo.create_action(action_name)
	project.undo_redo.add_do_method(project.add_frames.bind(new_frames, indices))
	project.undo_redo.add_undo_method(project.remove_frames.bind(indices))
	project.undo_redo.add_do_property(project, "animation_tags", new_animation_tags)
	project.undo_redo.add_undo_property(project, "animation_tags", project.animation_tags)
	project.undo_redo.add_do_method(project.change_cel.bind(insert_at + count - 1))
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
	if src_pixels == 0:
		warning = "Source frame contained 0 colored pixels; new frame has empty cels"

	return {
		"success": true,
		"data": {
			"duplicated_from": src_index,
			"inserted_at": insert_at,
			"count": count,
			"inserted_range": [insert_at, insert_at + count - 1],
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

	var duration: float = float(params.get("duration", 1.0))
	if duration <= 0.0:
		return {"success": false, "error": "Duration must be > 0"}

	var frame_res := _resolve_frame_indices(project, params, "", false, false, "index")
	if frame_res.error != "":
		return {"success": false, "error": frame_res.error}

	var frame_indices: Array = frame_res.frames
	for fi in frame_indices:
		project.frames[fi].duration = duration

	return {
		"success": true,
		"data": {
			"index": frame_indices[0],
			"frames": frame_indices,
			"frames_updated": frame_indices.size(),
			"duration": duration
		}
	}


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

	var frame_index: int = int(params.get("frame", project.current_frame))
	var layer_index: int = _resolve_layer_index(params, project)

	if frame_index < 0 or frame_index >= project.frames.size():
		return {"success": false, "error": "Invalid frame index: %d" % frame_index}
	if layer_index < 0 or layer_index >= project.layers.size():
		return {"success": false, "error": "Invalid layer index or identifier: %s" % str(params.get("layer", layer_index))}

	project.change_cel(frame_index, layer_index)
	return {
		"success": true,
		"data": {
			"frame": project.current_frame,
			"layer": project.current_layer,
			"layer_id": _get_or_create_layer_id(project.layers[project.current_layer]),
			"layer_name": project.layers[project.current_layer].name
		}
	}


func _cmd_copy_cel(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var src_frame: int = int(params.get("src_frame", project.current_frame))
	var src_layer: int = -1
	if params.has("src_layer") and params["src_layer"] != null:
		src_layer = _resolve_layer_index({"layer": params["src_layer"]}, project)
	else:
		src_layer = project.current_layer

	var dst_layer: int = src_layer
	if params.has("dst_layer") and params["dst_layer"] != null:
		dst_layer = _resolve_layer_index({"layer": params["dst_layer"]}, project)

	if src_frame < 0 or src_frame >= project.frames.size():
		return {"success": false, "error": "Source frame index out of bounds: %d" % src_frame}
	if src_layer < 0 or src_layer >= project.layers.size():
		return {"success": false, "error": "Source layer out of bounds or not found: %s" % str(params.get("src_layer", src_layer))}
	if dst_layer < 0 or dst_layer >= project.layers.size():
		return {"success": false, "error": "Destination layer out of bounds or not found: %s" % str(params.get("dst_layer", dst_layer))}

	var dst_res := _resolve_frame_indices(project, params, "dst_", false, true)
	if dst_res.error != "":
		return {"success": false, "error": dst_res.error}
	var dst_frames: Array = dst_res.frames

	var src_cel = project.frames[src_frame].cels[src_layer]
	if src_cel.get_class_name() != "PixelCel":
		return {"success": false, "error": "Source cel is not a PixelCel"}

	# Deep-clone pixels from source once
	var src_image: Image = src_cel.get_image()
	var used_rect := src_image.get_used_rect()
	var pixels_copied := 0
	if used_rect.size.x > 0 and used_rect.size.y > 0:
		for y in range(used_rect.position.y, used_rect.end.y):
			for x in range(used_rect.position.x, used_rect.end.x):
				if src_image.get_pixel(x, y).a > 0.001:
					pixels_copied += 1

	var copied_frames: Array[int] = []
	for dst_f in dst_frames:
		var dst_cel = project.frames[dst_f].cels[dst_layer]
		if dst_cel.get_class_name() != "PixelCel":
			return {"success": false, "error": "Destination cel at [frame:%d, layer:%d] is not a PixelCel" % [dst_f, dst_layer]}
		if dst_f == src_frame and dst_layer == src_layer:
			continue
		if src_cel.has_method("copy_content") and dst_cel.has_method("change_offset"):
			var source_content = src_cel.copy_content()
			_commit_compact_cel_content(source_content[0], source_content[1], "Copy Cel", dst_f, dst_layer)
		else:
			var copy_img = Image.create_empty(src_image.get_width(), src_image.get_height(), false, Image.FORMAT_RGBA8)
			copy_img.copy_from(src_image)
			_commit_image_change(copy_img, "Copy Cel", dst_f, dst_layer)
		copied_frames.append(dst_f)

	var canvas = _api.general.get_canvas()
	if canvas:
		if "project_changed" in canvas:
			canvas.project_changed = true
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	var result_data: Dictionary = {
		"src_frame": src_frame,
		"src_layer": src_layer,
		"src_layer_id": _get_or_create_layer_id(project.layers[src_layer]),
		"dst_frame": dst_frames[0],
		"dst_frames": copied_frames,
		"cels_copied": copied_frames.size(),
		"dst_layer": dst_layer,
		"dst_layer_id": _get_or_create_layer_id(project.layers[dst_layer]),
		"pixels_copied": pixels_copied
	}
	if pixels_copied == 0:
		result_data["warning"] = "Source cel was completely transparent"

	return {"success": true, "data": result_data}


func _cmd_clear_cel(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var frame_res := _resolve_frame_indices(project, params)
	if frame_res.error != "":
		return {"success": false, "error": frame_res.error}

	var layer_index: int = _resolve_layer_index(params, project)
	if layer_index < 0 or layer_index >= project.layers.size():
		return {"success": false, "error": "Invalid layer index or identifier: %s" % str(params.get("layer", layer_index))}

	var frame_indices: Array = frame_res.frames
	for fi in frame_indices:
		var cel = project.frames[fi].cels[layer_index]
		if cel == null or cel.get_class_name() != "PixelCel":
			return {"success": false, "error": "Target cel at [frame:%d, layer:%d] is not a PixelCel" % [fi, layer_index]}
		var cleared_img := Image.create(int(project.size.x), int(project.size.y), false, Image.FORMAT_RGBA8)
		_commit_image_change(cleared_img, "Clear Cel", fi, layer_index)

	return {
		"success": true,
		"data": {
			"frame": frame_indices[0],
			"frames": frame_indices,
			"frames_cleared": frame_indices.size(),
			"layer": layer_index,
			"layer_id": _get_or_create_layer_id(project.layers[layer_index]),
			"layer_name": project.layers[layer_index].name,
			"can_undo": true,
			"message": "Cel(s) cleared successfully (action recorded in undo history)"
		}
	}


func _cmd_batch_commands(params: Dictionary) -> Dictionary:
	var ops = params.get("operations", [])
	if not (ops is Array) or ops.is_empty():
		return {"success": false, "error": "Missing or empty 'operations' array"}
	if ops.size() > 200:
		return {"success": false, "error": "Batch size %d exceeds maximum of 200 operations per call" % ops.size()}

	var stop_on_error: bool = bool(params.get("stop_on_error", true))
	var results: Array = []
	var succeeded := 0
	var failed := 0
	var stopped_early := false

	for i in range(ops.size()):
		var op = ops[i]
		if not (op is Dictionary) or not op.has("tool"):
			failed += 1
			results.append({"index": i, "tool": "", "success": false, "error": "Operation must be an object with a 'tool' name"})
			if stop_on_error:
				stopped_early = true
				break
			continue

		var op_tool := str(op.get("tool", "")).strip_edges()
		if op_tool == "batch_commands" or op_tool == "eval_gdscript":
			failed += 1
			results.append({"index": i, "tool": op_tool, "success": false, "error": "Tool '%s' is not permitted inside batch_commands" % op_tool})
			if stop_on_error:
				stopped_early = true
				break
			continue

		if not _tool_registry.has(op_tool):
			failed += 1
			results.append({"index": i, "tool": op_tool, "success": false, "error": "Unknown tool: %s" % op_tool})
			if stop_on_error:
				stopped_early = true
				break
			continue

		var op_params: Dictionary = op.get("params", {}) if (op.get("params", {}) is Dictionary) else {}
		var res: Dictionary = _tool_registry[op_tool].call(op_params)
		if bool(res.get("success", false)):
			succeeded += 1
			results.append({"index": i, "tool": op_tool, "success": true, "data": res.get("data", {})})
		else:
			failed += 1
			results.append({"index": i, "tool": op_tool, "success": false, "error": str(res.get("error", "Unknown error"))})
			if stop_on_error:
				stopped_early = true
				break

	return {
		"success": failed == 0,
		"error": "" if failed == 0 else ("Batch completed with %d failure(s) out of %d executed operation(s)" % [failed, results.size()]),
		"data": {
			"total_requested": ops.size(),
			"executed": results.size(),
			"succeeded": succeeded,
			"failed": failed,
			"stopped_early": stopped_early,
			"results": results
		}
	}


func _cmd_export_animation(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var mode: String = str(params.get("mode", "frames"))  # "frames" or "spritesheet"
	var dir_path: String = str(params.get("path", "")).strip_edges()
	var exact_path: String = str(params.get("exact_path", "")).strip_edges()
	var exact_filename: String = str(params.get("exact_filename", "")).strip_edges()

	if mode == "spritesheet" and not exact_path.is_empty():
		if not exact_path.to_lower().ends_with(".png"):
			exact_path += ".png"
		var exact_dir := exact_path.get_base_dir()
		if not exact_dir.is_empty() and not DirAccess.dir_exists_absolute(exact_dir):
			DirAccess.make_dir_recursive_absolute(exact_dir)
	else:
		if dir_path.is_empty():
			return {"success": false, "error": "Missing 'path' directory parameter"}
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)

	var range_res := _resolve_frame_range(project, params)
	if range_res.error != "":
		return {"success": false, "error": range_res.error}

	var start_frame: int = int(range_res.start_frame)
	var end_frame: int = int(range_res.end_frame)
	var frame_count: int = int(range_res.count)
	var tag_name: String = str(range_res.tag)

	var prefix: String = str(params.get("prefix", "frame"))
	var scale_factor: int = clampi(int(params.get("scale", 1)), 1, 32)
	var drawing_algos = _api.general.get_drawing_algos()
	var w := int(project.size.x)
	var h := int(project.size.y)
	var exported: Array = []

	if mode == "spritesheet":
		var cols: int = int(params.get("columns", frame_count))
		cols = maxi(1, cols)
		var rows := ceili(float(frame_count) / float(cols))
		var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGBA8)

		for idx in range(frame_count):
			var src_frame := start_frame + idx
			var frame_img := Image.create(w, h, false, Image.FORMAT_RGBA8)
			if drawing_algos != null:
				drawing_algos.blend_layers(frame_img, project.frames[src_frame], Vector2i.ZERO, project)
			else:
				frame_img = _composite_frame_layers(project, src_frame)
			var col := idx % cols
			var row := int(idx / cols)
			sheet.blit_rect(frame_img, Rect2i(0, 0, w, h), Vector2i(col * w, row * h))

		if scale_factor > 1:
			sheet.resize(sheet.get_width() * scale_factor, sheet.get_height() * scale_factor, Image.INTERPOLATE_NEAREST)

		var sheet_path := ""
		if not exact_path.is_empty():
			sheet_path = exact_path
		elif not exact_filename.is_empty():
			var fn := exact_filename if exact_filename.to_lower().ends_with(".png") else (exact_filename + ".png")
			sheet_path = dir_path.path_join(fn)
		else:
			sheet_path = dir_path.path_join("%s_spritesheet.png" % prefix)

		var err := sheet.save_png(sheet_path)
		if err != OK:
			return {"success": false, "error": "Failed to save spritesheet to '%s': %s" % [sheet_path, error_string(err)]}
		return {
			"success": true,
			"data": {
				"mode": "spritesheet",
				"path": sheet_path,
				"frames": frame_count,
				"start_frame": start_frame,
				"end_frame": end_frame,
				"tag": tag_name,
				"columns": cols,
				"rows": rows,
				"scale": scale_factor,
				"width": sheet.get_width(),
				"height": sheet.get_height()
			}
		}
	else:
		for i in range(start_frame, end_frame + 1):
			var frame_img := Image.create(w, h, false, Image.FORMAT_RGBA8)
			if drawing_algos != null:
				drawing_algos.blend_layers(frame_img, project.frames[i], Vector2i.ZERO, project)
			else:
				frame_img = _composite_frame_layers(project, i)
			if scale_factor > 1:
				frame_img.resize(w * scale_factor, h * scale_factor, Image.INTERPOLATE_NEAREST)
			var file_path := dir_path.path_join("%s_%04d.png" % [prefix, i])
			var err := frame_img.save_png(file_path)
			if err != OK:
				return {"success": false, "error": "Failed to save frame %d: %s" % [i, error_string(err)]}
			exported.append(file_path)

		return {
			"success": true,
			"data": {
				"mode": "frames",
				"files": exported,
				"count": exported.size(),
				"start_frame": start_frame,
				"end_frame": end_frame,
				"tag": tag_name,
				"scale": scale_factor,
				"width": w * scale_factor,
				"height": h * scale_factor
			}
		}


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

	var target_layer: int = project.current_layer
	if params.has("layer") and params["layer"] != null:
		target_layer = _resolve_layer_index(params, project)
		if target_layer < 0 or target_layer >= project.layers.size():
			return {"success": false, "error": "Invalid layer index or identifier: %s" % str(params["layer"])}
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

	var range_res := _resolve_frame_range(project, params)
	if range_res.error != "":
		return {"success": false, "error": range_res.error}

	var start_frame: int = int(range_res.start_frame)
	var end_frame: int = int(range_res.end_frame)
	var frame_count: int = int(range_res.count)
	var tag_name: String = str(range_res.tag)
	var scale_factor: int = clampi(int(params.get("scale", 1)), 1, 32)
	var out_w: int = int(project.size.x) * scale_factor
	var out_h: int = int(project.size.y) * scale_factor

	var dir_name := path.get_base_dir()
	if dir_name != "" and not DirAccess.dir_exists_absolute(dir_name):
		DirAccess.make_dir_recursive_absolute(dir_name)

	var GIFExporterClass = load("res://addons/gdgifexporter/exporter.gd")
	if not GIFExporterClass:
		return {"success": false, "error": "GIF exporter not supported in this build"}

	var exporter = GIFExporterClass.new(out_w, out_h)

	for i in range(start_frame, end_frame + 1):
		var frame_img: Image = _blend_frame_layers(project, i)
		if scale_factor > 1:
			frame_img.resize(out_w, out_h, Image.INTERPOLATE_NEAREST)
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
				"frames": frame_count,
				"start_frame": start_frame,
				"end_frame": end_frame,
				"tag": tag_name,
				"scale": scale_factor,
				"size_bytes": file_data.size(),
				"width": out_w,
				"height": out_h
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

	var range_res := _resolve_frame_range(project, params)
	if range_res.error != "":
		return {"success": false, "error": range_res.error}

	var start_frame: int = int(range_res.start_frame)
	var end_frame: int = int(range_res.end_frame)
	var frame_count: int = int(range_res.count)
	var tag_name: String = str(range_res.tag)
	var scale_factor: int = clampi(int(params.get("scale", 1)), 1, 32)

	var dir_name := path.get_base_dir()
	if dir_name != "" and not DirAccess.dir_exists_absolute(dir_name):
		DirAccess.make_dir_recursive_absolute(dir_name)

	var apng_stream_script = load("res://addons/aimg_io/apng_stream.gd")
	if not apng_stream_script:
		var first_img = _blend_frame_layers(project, start_frame)
		if scale_factor > 1:
			first_img.resize(first_img.get_width() * scale_factor, first_img.get_height() * scale_factor, Image.INTERPOLATE_NEAREST)
		var err = first_img.save_png(path)
		if err == OK:
			return {"success": true, "data": {"path": path, "frames": 1, "format": "png", "scale": scale_factor, "width": first_img.get_width(), "height": first_img.get_height(), "warning": "APNG stream writer not available, saved standard PNG"}}
		return {"success": false, "error": "Failed to export APNG to %s" % path}

	var w := int(project.size.x) * scale_factor
	var h := int(project.size.y) * scale_factor
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
	for local_idx in range(frame_count):
		var frame_idx := start_frame + local_idx
		var img := _blend_frame_layers(project, frame_idx)
		if scale_factor > 1:
			img.resize(w, h, Image.INTERPOLATE_NEAREST)
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
		var duration: float = maxf(0.01, project.frames[frame_idx].duration)
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

		# 4. IDAT (first exported frame) or fdAT (subsequent frames)
		chunk = stream.start_chunk()
		if local_idx != 0:
			chunk.put_32(sequence)
			sequence += 1

		var raw_data: PackedByteArray = img.get_data()
		var scanlines := StreamPeerBuffer.new()
		for y in range(h):
			scanlines.put_8(0) # filter type 0 (None)
			scanlines.put_data(raw_data.slice(y * w * 4, (y + 1) * w * 4))

		var compressed: PackedByteArray = scanlines.data_array.compress(FileAccess.COMPRESSION_DEFLATE)
		chunk.put_data(compressed)

		if local_idx == 0:
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
			"start_frame": start_frame,
			"end_frame": end_frame,
			"tag": tag_name,
			"scale": scale_factor,
			"width": w,
			"height": h,
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

		var dst_cel = project.frames[target_f].cels[layer_idx]
		if src_cel.has_method("copy_content") and dst_cel.has_method("change_offset"):
			var source_content = src_cel.copy_content()
			_commit_compact_cel_content(
				source_content[0],
				source_content[1] + Vector2i(cur_dx, cur_dy),
				"Tween Cel",
				target_f,
				layer_idx
			)
		else:
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

	var src_idx: int = _resolve_layer_index(params, project)
	if src_idx < 0 or src_idx >= project.layers.size():
		return {"success": false, "error": "Invalid layer index or identifier: %s" % str(params.get("index", params.get("layer", src_idx)))}

	var src_layer = project.layers[src_idx]
	var new_name = src_layer.name + " Copy"
	_api.project.add_new_layer(src_idx, new_name, 0)

	var new_layer_idx := src_idx + 1
	for f in range(project.frames.size()):
		var src_cel = project.frames[f].cels[src_idx]
		if src_cel.get_class_name() == "PixelCel":
			if src_cel.has_method("copy_content") and src_cel.has_method("change_offset"):
				var source_content = src_cel.copy_content()
				_commit_compact_cel_content(source_content[0], source_content[1], "Duplicate Layer Cel", f, new_layer_idx)
			else:
				var src_img = src_cel.get_image()
				var clone_img = Image.create_empty(src_img.get_width(), src_img.get_height(), false, Image.FORMAT_RGBA8)
				clone_img.copy_from(src_img)
				_api.project.set_pixelcel_image(clone_img, f, new_layer_idx)

	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	var new_layer = project.layers[new_layer_idx]
	return {
		"success": true,
		"data": {
			"source_index": src_idx,
			"source_layer_id": _get_or_create_layer_id(src_layer),
			"new_index": new_layer_idx,
			"new_layer_id": _get_or_create_layer_id(new_layer),
			"name": new_name,
			"total_layers": project.layers.size()
		}
	}


func _cmd_merge_layers(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}
	if project.layers.size() <= 1:
		return {"success": false, "error": "Cannot merge when only 1 layer exists"}

	var src_idx: int = -1
	if params.has("source_index"):
		src_idx = _resolve_layer_index({"layer": params["source_index"]}, project)
	else:
		src_idx = _resolve_layer_index(params, project)

	var dst_idx: int = -1
	if params.has("target_index"):
		dst_idx = _resolve_layer_index({"layer": params["target_index"]}, project)
	else:
		dst_idx = maxi(0, src_idx - 1)

	if src_idx < 0 or src_idx >= project.layers.size() or dst_idx < 0 or dst_idx >= project.layers.size():
		return {"success": false, "error": "Invalid layer indices: source=%d, target=%d" % [src_idx, dst_idx]}
	if src_idx == dst_idx:
		return {"success": false, "error": "source_index and target_index cannot be identical"}

	for f in range(project.frames.size()):
		var src_cel = project.frames[f].cels[src_idx]
		var dst_cel = project.frames[f].cels[dst_idx]
		if src_cel.get_class_name() == "PixelCel" and dst_cel.get_class_name() == "PixelCel":
			var src_img: Image = src_cel.get_image()
			var dst_img: Image = dst_cel.get_image()
			if src_cel.has_method("copy_content") and dst_cel.has_method("change_offset"):
				var src_rect := Rect2i(_get_cel_offset(src_cel), src_img.get_size())
				var dst_rect := Rect2i(_get_cel_offset(dst_cel), dst_img.get_size())
				var merged_rect := src_rect.merge(dst_rect)
				var blended := Image.create_empty(merged_rect.size.x, merged_rect.size.y, false, Image.FORMAT_RGBA8)
				blended.blend_rect(dst_img, Rect2i(Vector2i.ZERO, dst_img.get_size()), dst_rect.position - merged_rect.position)
				blended.blend_rect(src_img, Rect2i(Vector2i.ZERO, src_img.get_size()), src_rect.position - merged_rect.position)
				_commit_compact_cel_content(blended, merged_rect.position, "Merge Layer Cels", f, dst_idx)
			else:
				var blended = Image.create_empty(dst_img.get_width(), dst_img.get_height(), false, Image.FORMAT_RGBA8)
				blended.copy_from(dst_img)
				blended.blend_rect(src_img, Rect2i(Vector2i.ZERO, src_img.get_size()), Vector2i.ZERO)
				_api.project.set_pixelcel_image(blended, f, dst_idx)

	var target_layer = project.layers[dst_idx]
	var target_layer_id := _get_or_create_layer_id(target_layer)

	project.remove_layers(PackedInt32Array([src_idx]))
	project.current_layer = clampi(dst_idx, 0, project.layers.size() - 1)
	_api.project.current_layer = project.current_layer
	_api.project.select_cels([[project.current_frame, project.current_layer]])

	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	return {
		"success": true,
		"data": {
			"merged_into": dst_idx,
			"target_layer_id": target_layer_id,
			"remaining_layers": project.layers.size()
		}
	}


func _cmd_create_layer_group(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var group_name: String = params.get("name", "Group")
	var above_layer: int = project.layers.size() - 1
	if params.has("above_layer") and params["above_layer"] != null:
		above_layer = _resolve_layer_index({"layer": params["above_layer"]}, project)
		if above_layer < 0 or above_layer >= project.layers.size():
			return {"success": false, "error": "Invalid above_layer index or identifier: %s" % str(params["above_layer"])}
	above_layer = clampi(above_layer, 0, project.layers.size() - 1)

	_api.project.add_new_layer(above_layer, group_name, 1)

	# Ensure all layer.index properties are strictly synchronized
	for i in range(project.layers.size()):
		project.layers[i].index = i
	project.order_layers()
	if project.has_signal("layers_updated"):
		project.layers_updated.emit()

	var new_layer_idx := above_layer + 1
	project.current_layer = clampi(new_layer_idx, 0, project.layers.size() - 1)
	_api.project.current_layer = project.current_layer
	_api.project.select_cels([[project.current_frame, project.current_layer]])

	var canvas = _api.general.get_canvas()
	if canvas:
		if "project_changed" in canvas:
			canvas.project_changed = true
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	return {"success": true, "data": {"name": group_name, "type": "GroupLayer", "index": new_layer_idx, "total_layers": project.layers.size()}}


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

	var project = _api.project.current_project
	var radius: int = int(params.get("radius", 2))
	var glow_hex: String = params.get("color", "#3498db")
	var intensity: float = float(params.get("intensity", 0.6))
	var as_new_layer: bool = bool(params.get("as_new_layer", false))
	var falloff_mode: String = params.get("falloff", "smooth")  # "smooth", "linear", "dither"

	# Selective Glow Targeting
	var has_source_color: bool = params.has("source_color") and String(params["source_color"]).strip_edges() != ""
	var source_col: Color = Color.html(params.get("source_color", "")) if has_source_color else Color.WHITE
	var tolerance: float = float(params.get("tolerance", 0.15))

	var has_luma_thresh: bool = params.has("luminance_threshold")
	var luma_thresh: float = float(params.get("luminance_threshold", 0.0))

	var has_rect: bool = params.has("rect") and (params["rect"] is Array) and params["rect"].size() >= 4
	var bound_rect := Rect2i(0, 0, 0, 0)
	if has_rect:
		var r_arr: Array = params["rect"]
		bound_rect = Rect2i(int(r_arr[0]), int(r_arr[1]), int(r_arr[2]), int(r_arr[3]))

	var has_sel: bool = ("has_selection" in project) and project.has_selection
	var sel_map = project.selection_map if ("selection_map" in project) else null

	var glow_col := Color.html(glow_hex) if Color.html_is_valid(glow_hex) else Color(0.2, 0.6, 1.0, 1.0)
	var img: Image = target.image

	var w := img.get_width()
	var h := img.get_height()
	var glow_img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)

	var bayer4: Array = [
		[ 0.5/16.0,  8.5/16.0,  2.5/16.0, 10.5/16.0],
		[12.5/16.0,  4.5/16.0, 14.5/16.0,  6.5/16.0],
		[ 3.5/16.0, 11.5/16.0,  1.5/16.0,  9.5/16.0],
		[15.5/16.0,  7.5/16.0, 13.5/16.0,  5.5/16.0]
	]

	var emitter_count := 0

	for y in range(h):
		for x in range(w):
			var px := img.get_pixel(x, y)
			if px.a <= 0.05:
				continue

			# 1. Check bounding rect filter
			if has_rect and not bound_rect.has_point(Vector2i(x, y)):
				continue

			# 2. Check active selection mask
			if has_sel and sel_map != null:
				if sel_map.get_pixel(x, y).a < 0.01:
					continue

			# 3. Check source color match
			if has_source_color:
				var c_diff := absf(px.r - source_col.r) + absf(px.g - source_col.g) + absf(px.b - source_col.b)
				if c_diff > (tolerance * 3.0):
					continue

			# 4. Check luminance threshold
			if has_luma_thresh:
				var px_luma := px.r * 0.299 + px.g * 0.587 + px.b * 0.114
				if px_luma < luma_thresh:
					continue

			emitter_count += 1

			# Cast glow around qualifying emitter pixel
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					var d := Vector2(dx, dy).length()
					if d > 0.0 and d <= float(radius):
						var gx := x + dx
						var gy := y + dy
						if gx >= 0 and gx < w and gy >= 0 and gy < h:
							var norm_dist := d / float(radius + 1)
							var falloff := 0.0
							if falloff_mode == "linear":
								falloff = (1.0 - norm_dist) * intensity
							elif falloff_mode == "dither":
								var base_val := (1.0 - norm_dist) * intensity
								var b_thresh: float = bayer4[gy % 4][gx % 4]
								falloff = intensity if base_val > b_thresh else 0.0
							else:  # "smooth" (quadratic feathering)
								falloff = pow(1.0 - norm_dist, 2.0) * intensity

							if falloff > 0.0:
								var cur = glow_img.get_pixel(gx, gy)
								var new_a = maxf(cur.a, falloff)
								glow_img.set_pixel(gx, gy, Color(glow_col.r, glow_col.g, glow_col.b, new_a))

	var glow_layer_idx: int = target.layer
	if as_new_layer:
		# Add new layer ABOVE target.layer so it illuminates rather than hides under opaque cels
		_api.project.add_new_layer(target.layer, "Glow", 0)
		glow_layer_idx = target.layer + 1
		if glow_layer_idx < project.layers.size():
			project.layers[glow_layer_idx].blend_mode = 9  # BaseLayer.BlendModes.ADD
		_api.project.set_pixelcel_image(glow_img, target.frame, glow_layer_idx)
	else:
		var composite := img.duplicate()
		for gy in range(h):
			for gx in range(w):
				var g_px: Color = glow_img.get_pixel(gx, gy)
				if g_px.a > 0.001:
					var base_px: Color = composite.get_pixel(gx, gy)
					if base_px.a <= 0.001:
						composite.set_pixel(gx, gy, g_px)
					else:
						# Additive glow on top of existing cel pixels
						var out_r := minf(1.0, base_px.r + g_px.r * g_px.a)
						var out_g := minf(1.0, base_px.g + g_px.g * g_px.a)
						var out_b := minf(1.0, base_px.b + g_px.b * g_px.a)
						var out_a := maxf(base_px.a, g_px.a)
						composite.set_pixel(gx, gy, Color(out_r, out_g, out_b, out_a))
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
			"glow_layer_id": _get_or_create_layer_id(project.layers[glow_layer_idx]) if (as_new_layer and glow_layer_idx >= 0 and glow_layer_idx < project.layers.size()) else "",
			"emitters_found": emitter_count,
			"candidate_pixels": emitter_count,
			"falloff": falloff_mode,
			"frame": target.frame,
			"layer": target.layer
		}
	}


func _cmd_apply_gradient(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var project = _api.project.current_project
	var x1: int = int(roundf(float(params.get("x1", 0))))
	var y1: int = int(roundf(float(params.get("y1", 0))))
	var x2: int = int(roundf(float(params.get("x2", int(project.size.x)))))
	var y2: int = int(roundf(float(params.get("y2", int(project.size.y)))))
	var col1_hex: String = str(params.get("color1", "#ffffff"))
	var col2_hex: String = str(params.get("color2", "#000000"))
	var blend: bool = bool(params.get("blend", true))
	var grad_type: String = str(params.get("type", "linear"))
	var shape: String = str(params.get("shape", ""))
	var direction: String = str(params.get("direction", "auto")).to_lower()
	var falloff: String = str(params.get("falloff", "linear"))
	var feather_val: float = clampf(float(params.get("feather", 0.0)), 0.0, 1.0)
	if falloff == "feather" and feather_val <= 0.0:
		feather_val = 0.5

	var is_elliptical: bool = (grad_type in ["elliptical", "ellipse"] or shape in ["elliptical", "ellipse"])
	var is_radial: bool = (grad_type in ["radial", "circle"] or shape in ["radial", "circle"]) or is_elliptical

	var rx1 := mini(x1, x2)
	var ry1 := mini(y1, y2)
	var rx2 := maxi(x1, x2)
	var ry2 := maxi(y1, y2)
	if rx1 == rx2:
		rx2 = rx1 + 1
	if ry1 == ry2:
		ry2 = ry1 + 1
	var rw := maxf(1.0, float(rx2 - rx1))
	var rh := maxf(1.0, float(ry2 - ry1))

	var is_horizontal: bool = false
	if direction == "horizontal" or grad_type in ["horizontal", "linear_h", "linear_x"]:
		is_horizontal = true
	elif direction == "vertical" or grad_type in ["vertical", "linear_v", "linear_y"]:
		is_horizontal = false
	elif direction == "auto" or direction == "":
		is_horizontal = (rw > rh)

	var alpha_mod: float = clampf(float(params.get("alpha", 1.0)), 0.0, 1.0)
	var col1 := Color.html(col1_hex) if Color.html_is_valid(col1_hex) else Color.WHITE
	var col2 := Color.html(col2_hex) if Color.html_is_valid(col2_hex) else Color.BLACK
	col1.a *= alpha_mod
	col2.a *= alpha_mod

	var dither_param = params.get("dither", null)
	var dither: bool
	if dither_param != null:
		dither = bool(dither_param)
	else:
		var has_transparent_endpoint: bool = (col1.a <= 0.01 or col2.a <= 0.01)
		dither = not has_transparent_endpoint

	var img: Image = target.image

	var bayer4 := [
		[  0.5/16.0,  8.5/16.0,  2.5/16.0, 10.5/16.0 ],
		[ 12.5/16.0,  4.5/16.0, 14.5/16.0,  6.5/16.0 ],
		[  3.5/16.0, 11.5/16.0,  1.5/16.0,  9.5/16.0 ],
		[ 15.5/16.0,  7.5/16.0, 13.5/16.0,  5.5/16.0 ]
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
				if is_radial:
					var cx := float(rx1 + rx2) * 0.5
					var cy := float(ry1 + ry2) * 0.5
					if is_elliptical:
						var rad_x := maxf(0.5, rw * 0.5)
						var rad_y := maxf(0.5, rh * 0.5)
						var norm_x := (float(x) - cx) / rad_x
						var norm_y := (float(y) - cy) / rad_y
						t = clampf(sqrt(norm_x * norm_x + norm_y * norm_y), 0.0, 1.0)
					else:
						var max_r := maxf(rw, rh) * 0.5
						t = clampf(Vector2(x - cx, y - cy).length() / max_r, 0.0, 1.0)
				else:
					if is_horizontal:
						t = clampf(float(x - rx1) / rw, 0.0, 1.0)
					else:
						t = clampf(float(y - ry1) / rh, 0.0, 1.0)

				# Falloff curves
				match falloff:
					"smooth", "smoothstep":
						t = t * t * (3.0 - 2.0 * t)
					"inverse_square":
						t = 1.0 - (1.0 - t) * (1.0 - t)
					"exponential", "exp":
						t = clampf((1.0 - exp(-3.0 * t)) / (1.0 - exp(-3.0)), 0.0, 1.0)
					"feather":
						var f_mode := clampf(feather_val if feather_val > 0.0 else 0.25, 0.01, 0.5)
						if t < f_mode:
							var u := t / f_mode
							t = f_mode * (u * u * (3.0 - 2.0 * u))
						elif t > (1.0 - f_mode):
							var u := (t - (1.0 - f_mode)) / f_mode
							t = (1.0 - f_mode) + f_mode * (u * u * (3.0 - 2.0 * u))
					_:
						pass

				# Edge softening if feather is provided and falloff wasn't already feather
				if feather_val > 0.0 and falloff != "feather":
					var f := clampf(feather_val * 0.5, 0.001, 0.5)
					if t < f:
						var u := t / f
						t = f * (u * u * (3.0 - 2.0 * u))
					elif t > (1.0 - f):
						var u := (t - (1.0 - f)) / f
						t = (1.0 - f) + f * (u * u * (3.0 - 2.0 * u))

				var final_col: Color
				if dither:
					var threshold = bayer4[y % 4][x % 4]
					final_col = col1 if t < threshold else col2
				else:
					final_col = col1.lerp(col2, t)

				if blend:
					if final_col.a <= 0.001:
						continue
					var cur: Color = img.get_pixel(x, y)
					if cur.a <= 0.001:
						img.set_pixel(x, y, final_col)
					else:
						img.set_pixel(x, y, cur.blend(final_col))
				else:
					img.set_pixel(x, y, final_col)

	_commit_image_change(img, "Apply Gradient", target.frame, target.layer)

	return {
		"success": true,
		"data": {
			"type": grad_type,
			"shape": shape,
			"direction": "horizontal" if is_horizontal else "vertical",
			"inferred_direction": "horizontal" if (rw > rh) else "vertical",
			"falloff": falloff,
			"blend": blend,
			"dither": dither,
			"alpha": alpha_mod,
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

	var text: String = str(params.get("text", ""))
	var start_x: int = int(params.get("x", 0))
	var start_y: int = int(params.get("y", 0))
	var col_hex: String = str(params.get("color", "#ffffff"))
	var font_size: int = int(params.get("font_size", 8))

	if text.is_empty():
		return {"success": false, "error": "Missing 'text' parameter"}

	var effective_scale := 1
	if params.has("scale") and params["scale"] != null:
		effective_scale = clampi(int(params["scale"]), 1, 8)
	elif params.has("font_size") and params["font_size"] != null:
		var fs: int = int(params["font_size"])
		if fs <= 10:
			effective_scale = 1
		elif fs <= 18:
			effective_scale = 2
		elif fs <= 26:
			effective_scale = 3
		elif fs <= 34:
			effective_scale = 4
		else:
			effective_scale = maxi(1, int(roundf(float(fs) / 7.0)))

	var letter_spacing: int = clampi(int(params.get("letter_spacing", 1)), 0, 16)
	var cell_width: int = 0
	if params.has("cell_width") and params["cell_width"] != null:
		cell_width = clampi(int(params["cell_width"]), 1, 32)

	var line_step := maxi(7 * effective_scale, font_size)
	var text_col := Color.html(col_hex) if Color.html_is_valid(col_hex) else Color.WHITE

	var has_shadow := false
	var shadow_col := Color.BLACK
	var shadow_ox := effective_scale
	var shadow_oy := effective_scale
	if params.has("shadow_color") and params["shadow_color"] != null and not str(params["shadow_color"]).strip_edges().is_empty():
		var sh_hex := str(params["shadow_color"]).strip_edges()
		if not Color.html_is_valid(sh_hex):
			return {"success": false, "error": "Invalid shadow_color hex: '%s'" % sh_hex}
		shadow_col = Color.html(sh_hex)
		has_shadow = true
		if params.has("shadow_offset_x") and params["shadow_offset_x"] != null:
			shadow_ox = int(params["shadow_offset_x"])
		if params.has("shadow_offset_y") and params["shadow_offset_y"] != null:
			shadow_oy = int(params["shadow_offset_y"])

	var has_outline := false
	var outline_col := Color.BLACK
	var outline_mode: String = str(params.get("outline_mode", "full")).to_lower()
	if params.has("outline_color") and params["outline_color"] != null and not str(params["outline_color"]).strip_edges().is_empty():
		var ol_hex := str(params["outline_color"]).strip_edges()
		if not Color.html_is_valid(ol_hex):
			return {"success": false, "error": "Invalid outline_color hex: '%s'" % ol_hex}
		outline_col = Color.html(ol_hex)
		has_outline = true

	var img: Image = target.image
	var img_w := img.get_width()
	var img_h := img.get_height()

	var ink_pixels := {}
	var outline_pixels := {}
	var chars_drawn := 0
	var unsupported_chars := 0

	var min_x := 999999
	var min_y := 999999
	var max_x := -999999
	var max_y := -999999
	var has_ink := false
	var max_advance := 0

	var outline_dirs: Array[Vector2i] = []
	if outline_mode == "cardinal":
		outline_dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	else:
		outline_dirs = [
			Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
			Vector2i(-1, 0),                   Vector2i(1, 0),
			Vector2i(-1, 1),  Vector2i(0, 1),  Vector2i(1, 1)
		]

	var lines := text.split("\n")
	var cur_y := start_y

	for line in lines:
		var cur_tx := 0
		var line_ink_texels := {}

		for ch in line:
			var glyph_info := _get_bitmap_glyph_info(ch)
			var glyph_matrix: Array = glyph_info.matrix
			if not bool(glyph_info.supported):
				unsupported_chars += 1

			var glyph_w: int = glyph_matrix[0].size() if glyph_matrix.size() > 0 else 3
			for gy in range(glyph_matrix.size()):
				var row: Array = glyph_matrix[gy]
				for gx in range(row.size()):
					if row[gx] == 1:
						line_ink_texels[Vector2i(cur_tx + gx, gy)] = true

			if cell_width > 0:
				cur_tx += cell_width
			else:
				cur_tx += glyph_w + letter_spacing
			chars_drawn += 1

		var line_advance := cur_tx * effective_scale
		if line_advance > max_advance:
			max_advance = line_advance

		for t in line_ink_texels.keys():
			var tv: Vector2i = t
			for by in range(effective_scale):
				for bx in range(effective_scale):
					var px := start_x + tv.x * effective_scale + bx
					var py := cur_y + tv.y * effective_scale + by
					ink_pixels[Vector2i(px, py)] = true
					if px < min_x: min_x = px
					if py < min_y: min_y = py
					if px > max_x: max_x = px
					if py > max_y: max_y = py
					has_ink = true

		if has_outline:
			var line_outline_texels := {}
			for t in line_ink_texels.keys():
				var tv: Vector2i = t
				for d in outline_dirs:
					var nt := tv + d
					if not line_ink_texels.has(nt):
						line_outline_texels[nt] = true
			for ot in line_outline_texels.keys():
				var otv: Vector2i = ot
				for by in range(effective_scale):
					for bx in range(effective_scale):
						var px := start_x + otv.x * effective_scale + bx
						var py := cur_y + otv.y * effective_scale + by
						outline_pixels[Vector2i(px, py)] = true

		cur_y += line_step

	# Remove any cross-line outline overlap with ink
	if has_outline:
		for ip in ink_pixels.keys():
			outline_pixels.erase(ip)

	var full_min_x := min_x
	var full_min_y := min_y
	var full_max_x := max_x
	var full_max_y := max_y
	var has_any := has_ink

	# Pass 1: Shadow (back-most)
	if has_shadow:
		var shadow_pixels := {}
		for ip in ink_pixels.keys():
			var v: Vector2i = ip
			shadow_pixels[Vector2i(v.x + shadow_ox, v.y + shadow_oy)] = true
		if has_outline:
			for op in outline_pixels.keys():
				var v: Vector2i = op
				shadow_pixels[Vector2i(v.x + shadow_ox, v.y + shadow_oy)] = true
		var sh_blend := shadow_col.a < 0.999
		for sp in shadow_pixels.keys():
			var v: Vector2i = sp
			if v.x < full_min_x: full_min_x = v.x
			if v.y < full_min_y: full_min_y = v.y
			if v.x > full_max_x: full_max_x = v.x
			if v.y > full_max_y: full_max_y = v.y
			has_any = true
			if v.x >= 0 and v.x < img_w and v.y >= 0 and v.y < img_h:
				_put_pixel(img, v.x, v.y, shadow_col, sh_blend)

	# Pass 2: Outline (middle)
	if has_outline:
		var ol_blend := outline_col.a < 0.999
		for op in outline_pixels.keys():
			var v: Vector2i = op
			if v.x < full_min_x: full_min_x = v.x
			if v.y < full_min_y: full_min_y = v.y
			if v.x > full_max_x: full_max_x = v.x
			if v.y > full_max_y: full_max_y = v.y
			has_any = true
			if v.x >= 0 and v.x < img_w and v.y >= 0 and v.y < img_h:
				_put_pixel(img, v.x, v.y, outline_col, ol_blend)

	# Pass 3: Main text ink (front-most)
	var text_blend := text_col.a < 0.999
	for ip in ink_pixels.keys():
		var v: Vector2i = ip
		if v.x >= 0 and v.x < img_w and v.y >= 0 and v.y < img_h:
			_put_pixel(img, v.x, v.y, text_col, text_blend)

	_commit_image_change(img, "Draw Text", target.frame, target.layer)

	var bbox := {
		"left": min_x if has_ink else start_x,
		"top": min_y if has_ink else start_y,
		"right": max_x if has_ink else start_x,
		"bottom": max_y if has_ink else start_y,
		"width": (max_x - min_x + 1) if has_ink else 0,
		"height": (max_y - min_y + 1) if has_ink else 0,
		"advance": max_advance
	}

	var full_bbox := {
		"left": full_min_x if has_any else start_x,
		"top": full_min_y if has_any else start_y,
		"right": full_max_x if has_any else start_x,
		"bottom": full_max_y if has_any else start_y,
		"width": (full_max_x - full_min_x + 1) if has_any else 0,
		"height": (full_max_y - full_min_y + 1) if has_any else 0,
		"advance": max_advance
	}

	var default_advance := (cell_width if cell_width > 0 else (4 + letter_spacing)) * effective_scale
	return {
		"success": true,
		"data": {
			"text": text,
			"chars_drawn": chars_drawn,
			"unsupported_chars": unsupported_chars,
			"scale": effective_scale,
			"glyph_height": 5 * effective_scale,
			"char_advance": default_advance,
			"line_height": line_step,
			"pos": [start_x, start_y],
			"bounding_box": bbox,
			"full_bounding_box": full_bbox,
			"has_shadow": has_shadow,
			"has_outline": has_outline,
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

	var top: int = int(params.get("top", 32))
	var truncated_colors: Array = usage_list
	if top > 0 and usage_list.size() > top:
		truncated_colors = usage_list.slice(0, top)

	return {
		"success": true,
		"data": {
			"all_layers": all_layers,
			"frame": frame_idx,
			"unique_colors_count": usage_list.size(),
			"total_colored_pixels": total_pixels,
			"top": top,
			"colors": truncated_colors
		}
	}


func _cmd_clean_isolated_pixels(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var img: Image = target.image
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
		_commit_image_change(img, "Clean Isolated Pixels", target.frame, target.layer)

	return {"success": true, "data": {"isolated_pixels_cleaned": cleaned, "frame": target.frame, "layer": target.layer}}


func _cmd_remap_to_palette(params: Dictionary) -> Dictionary:
	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var palette_arr: Array = params.get("palette_colors", [])
	if palette_arr.is_empty():
		return {"success": false, "error": "Missing 'palette_colors' array"}

	var colors: Array[Color] = []
	for hex in palette_arr:
		if Color.html_is_valid(str(hex)):
			colors.append(Color.html(str(hex)))

	if colors.is_empty():
		return {"success": false, "error": "No valid colors in palette_colors"}

	var img: Image = target.image

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

	_commit_image_change(img, "Remap to Palette", target.frame, target.layer)

	return {"success": true, "data": {"remapped_pixels": remapped_count, "palette_size": colors.size(), "frame": target.frame, "layer": target.layer}}


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

		var cel_img: Image = _cel_to_canvas_image(cel, project)
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


const _ASCII_GLYPHS: Dictionary = {
	# Uppercase A-Z (5px tall, baseline row 4 — exact backward compatibility)
	"A": [[0,1,1,0],[1,0,0,1],[1,1,1,1],[1,0,0,1],[1,0,0,1]],
	"B": [[1,1,1,0],[1,0,0,1],[1,1,1,0],[1,0,0,1],[1,1,1,0]],
	"C": [[0,1,1,1],[1,0,0,0],[1,0,0,0],[1,0,0,0],[0,1,1,1]],
	"D": [[1,1,1,0],[1,0,0,1],[1,0,0,1],[1,0,0,1],[1,1,1,0]],
	"E": [[1,1,1,1],[1,0,0,0],[1,1,1,0],[1,0,0,0],[1,1,1,1]],
	"F": [[1,1,1,1],[1,0,0,0],[1,1,1,0],[1,0,0,0],[1,0,0,0]],
	"G": [[0,1,1,1],[1,0,0,0],[1,0,1,1],[1,0,0,1],[0,1,1,1]],
	"H": [[1,0,0,1],[1,0,0,1],[1,1,1,1],[1,0,0,1],[1,0,0,1]],
	"I": [[1,1,1],[0,1,0],[0,1,0],[0,1,0],[1,1,1]],
	"J": [[0,0,1,1],[0,0,0,1],[0,0,0,1],[1,0,0,1],[0,1,1,0]],
	"K": [[1,0,0,1],[1,0,1,0],[1,1,0,0],[1,0,1,0],[1,0,0,1]],
	"L": [[1,0,0,0],[1,0,0,0],[1,0,0,0],[1,0,0,0],[1,1,1,1]],
	"M": [[1,0,0,0,1],[1,1,0,1,1],[1,0,1,0,1],[1,0,0,0,1],[1,0,0,0,1]],
	"N": [[1,0,0,1],[1,1,0,1],[1,0,1,1],[1,0,0,1],[1,0,0,1]],
	"O": [[0,1,1,0],[1,0,0,1],[1,0,0,1],[1,0,0,1],[0,1,1,0]],
	"P": [[1,1,1,0],[1,0,0,1],[1,1,1,0],[1,0,0,0],[1,0,0,0]],
	"Q": [[0,1,1,0],[1,0,0,1],[1,0,0,1],[1,0,1,0],[0,1,0,1]],
	"R": [[1,1,1,0],[1,0,0,1],[1,1,1,0],[1,0,1,0],[1,0,0,1]],
	"S": [[0,1,1,1],[1,0,0,0],[0,1,1,0],[0,0,0,1],[1,1,1,0]],
	"T": [[1,1,1,1,1],[0,0,1,0,0],[0,0,1,0,0],[0,0,1,0,0],[0,0,1,0,0]],
	"U": [[1,0,0,1],[1,0,0,1],[1,0,0,1],[1,0,0,1],[0,1,1,0]],
	"V": [[1,0,0,1],[1,0,0,1],[1,0,0,1],[0,1,1,0],[0,1,0,0]],
	"W": [[1,0,0,0,1],[1,0,0,0,1],[1,0,1,0,1],[1,1,0,1,1],[1,0,0,0,1]],
	"X": [[1,0,0,1],[0,1,1,0],[0,1,1,0],[1,0,0,1],[1,0,0,1]],
	"Y": [[1,0,0,1],[0,1,1,0],[0,0,1,0],[0,0,1,0],[0,0,1,0]],
	"Z": [[1,1,1,1],[0,0,1,0],[0,1,0,0],[1,0,0,0],[1,1,1,1]],

	# Lowercase a-z (x-height rows 1..4, ascenders rows 0..4, descenders g/j/p/q/y row 5)
	"a": [[0,0,0,0],[0,1,1,0],[1,0,0,1],[1,0,0,1],[0,1,1,1]],
	"b": [[1,0,0,0],[1,0,0,0],[1,1,1,0],[1,0,0,1],[1,1,1,0]],
	"c": [[0,0,0,0],[0,1,1,1],[1,0,0,0],[1,0,0,0],[0,1,1,1]],
	"d": [[0,0,0,1],[0,0,0,1],[0,1,1,1],[1,0,0,1],[0,1,1,1]],
	"e": [[0,0,0,0],[0,1,1,0],[1,1,1,1],[1,0,0,0],[0,1,1,1]],
	"f": [[0,1,1],[1,0,0],[1,1,1],[1,0,0],[1,0,0]],
	"g": [[0,0,0,0],[0,1,1,1],[1,0,0,1],[0,1,1,1],[0,0,0,1],[0,1,1,0]],
	"h": [[1,0,0,0],[1,0,0,0],[1,1,1,0],[1,0,0,1],[1,0,0,1]],
	"i": [[1],[0],[1],[1],[1]],
	"j": [[0,0,1],[0,0,0],[0,0,1],[0,0,1],[0,0,1],[1,1,0]],
	"k": [[1,0,0],[1,0,0],[1,0,1],[1,1,0],[1,0,1]],
	"l": [[1,0],[1,0],[1,0],[1,0],[0,1]],
	"m": [[0,0,0,0,0],[1,1,0,1,1],[1,0,1,0,1],[1,0,1,0,1],[1,0,0,0,1]],
	"n": [[0,0,0,0],[1,1,1,0],[1,0,0,1],[1,0,0,1],[1,0,0,1]],
	"o": [[0,0,0,0],[0,1,1,0],[1,0,0,1],[1,0,0,1],[0,1,1,0]],
	"p": [[0,0,0,0],[1,1,1,0],[1,0,0,1],[1,0,0,1],[1,1,1,0],[1,0,0,0]],
	"q": [[0,0,0,0],[0,1,1,1],[1,0,0,1],[1,0,0,1],[0,1,1,1],[0,0,0,1]],
	"r": [[0,0,0],[0,1,1],[1,0,0],[1,0,0],[1,0,0]],
	"s": [[0,0,0,0],[0,1,1,1],[1,1,0,0],[0,0,1,1],[1,1,1,0]],
	"t": [[0,1,0],[1,1,1],[0,1,0],[0,1,0],[0,0,1]],
	"u": [[0,0,0,0],[1,0,0,1],[1,0,0,1],[1,0,0,1],[0,1,1,1]],
	"v": [[0,0,0],[1,0,1],[1,0,1],[1,0,1],[0,1,0]],
	"w": [[0,0,0,0,0],[1,0,0,0,1],[1,0,1,0,1],[1,0,1,0,1],[0,1,0,1,0]],
	"x": [[0,0,0,0],[1,0,0,1],[0,1,1,0],[0,1,1,0],[1,0,0,1]],
	"y": [[0,0,0,0],[1,0,0,1],[1,0,0,1],[0,1,1,1],[0,0,0,1],[0,1,1,0]],
	"z": [[0,0,0,0],[1,1,1,1],[0,0,1,0],[0,1,0,0],[1,1,1,1]],

	# Digits 0-9
	"0": [[0,1,1,0],[1,0,0,1],[1,0,0,1],[1,0,0,1],[0,1,1,0]],
	"1": [[0,1,0],[1,1,0],[0,1,0],[0,1,0],[1,1,1]],
	"2": [[1,1,1,0],[0,0,0,1],[0,1,1,0],[1,0,0,0],[1,1,1,1]],
	"3": [[1,1,1,0],[0,0,0,1],[0,1,1,0],[0,0,0,1],[1,1,1,0]],
	"4": [[1,0,0,1],[1,0,0,1],[1,1,1,1],[0,0,0,1],[0,0,0,1]],
	"5": [[1,1,1,1],[1,0,0,0],[1,1,1,0],[0,0,0,1],[1,1,1,0]],
	"6": [[0,1,1,0],[1,0,0,0],[1,1,1,0],[1,0,0,1],[0,1,1,0]],
	"7": [[1,1,1,1],[0,0,0,1],[0,0,1,0],[0,1,0,0],[0,1,0,0]],
	"8": [[0,1,1,0],[1,0,0,1],[0,1,1,0],[1,0,0,1],[0,1,1,0]],
	"9": [[0,1,1,0],[1,0,0,1],[0,1,1,1],[0,0,0,1],[0,1,1,0]],

	# Complete ASCII punctuation & symbols (32..47, 58..64, 91..96, 123..126)
	" ": [[0,0],[0,0],[0,0],[0,0],[0,0]],
	"!": [[1],[1],[1],[0],[1]],
	"\"": [[1,0,1],[1,0,1],[0,0,0],[0,0,0],[0,0,0]],
	"#": [[0,1,0,1,0],[1,1,1,1,1],[0,1,0,1,0],[1,1,1,1,1],[0,1,0,1,0]],
	"$": [[0,1,1,1,0],[1,0,1,0,0],[0,1,1,1,0],[0,0,1,0,1],[0,1,1,1,0]],
	"%": [[1,1,0,0,1],[1,1,0,1,0],[0,0,1,0,0],[0,1,0,1,1],[1,0,0,1,1]],
	"&": [[0,1,1,0,0],[1,0,0,1,0],[0,1,1,0,0],[1,0,1,0,1],[0,1,1,0,1]],
	"'": [[1],[1],[0],[0],[0]],
	"(": [[0,1],[1,0],[1,0],[1,0],[0,1]],
	")": [[1,0],[0,1],[0,1],[0,1],[1,0]],
	"*": [[1,0,1],[0,1,0],[1,0,1],[0,0,0],[0,0,0]],
	"+": [[0,1,0],[0,1,0],[1,1,1],[0,1,0],[0,1,0]],
	",": [[0,0],[0,0],[0,0],[0,1],[1,0]],
	"-": [[0,0,0],[0,0,0],[1,1,1],[0,0,0],[0,0,0]],
	".": [[0],[0],[0],[0],[1]],
	"/": [[0,0,1],[0,0,1],[0,1,0],[1,0,0],[1,0,0]],
	":": [[0],[1],[0],[1],[0]],
	";": [[0,0],[0,1],[0,0],[0,1],[1,0]],
	"<": [[0,0,1],[0,1,0],[1,0,0],[0,1,0],[0,0,1]],
	"=": [[0,0,0],[1,1,1],[0,0,0],[1,1,1],[0,0,0]],
	">": [[1,0,0],[0,1,0],[0,0,1],[0,1,0],[1,0,0]],
	"?": [[1,1,1],[0,0,1],[0,1,0],[0,0,0],[0,1,0]],
	"@": [[0,1,1,1,0],[1,0,0,0,1],[1,0,1,1,1],[1,0,1,0,1],[0,1,1,0,0]],
	"[": [[1,1],[1,0],[1,0],[1,0],[1,1]],
	"\\": [[1,0,0],[1,0,0],[0,1,0],[0,0,1],[0,0,1]],
	"]": [[1,1],[0,1],[0,1],[0,1],[1,1]],
	"^": [[0,1,0],[1,0,1],[0,0,0],[0,0,0],[0,0,0]],
	"_": [[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0],[1,1,1,1]],
	"`": [[1,0],[0,1],[0,0],[0,0],[0,0]],
	"{": [[0,1,1],[0,1,0],[1,1,0],[0,1,0],[0,1,1]],
	"|": [[1],[1],[1],[1],[1]],
	"}": [[1,1,0],[0,1,0],[0,1,1],[0,1,0],[1,1,0]],
	"~": [[0,0,0,0],[0,1,0,1],[1,0,1,0],[0,0,0,0],[0,0,0,0]],
}

const _FALLBACK_GLYPH: Array = [[1,1,1],[1,0,1],[1,0,1],[1,0,1],[1,1,1]]


func _get_bitmap_glyph_info(ch: String) -> Dictionary:
	if _ASCII_GLYPHS.has(ch):
		return {"matrix": _ASCII_GLYPHS[ch], "supported": true}
	return {"matrix": _FALLBACK_GLYPH, "supported": false}


func _get_bitmap_glyph(ch: String) -> Array:
	return _get_bitmap_glyph_info(ch).matrix


func _validate_single_frame_image(
	img: Image,
	frame_idx: int,
	target_layer: int,
	check_holes: bool,
	solid_threshold: float,
	check_orphans: bool,
	orphan_distance: int,
	palette_info: Dictionary,
	palette_tolerance: float,
	ignore_alpha_for_palette: bool
) -> Dictionary:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var used_rect := img.get_used_rect()
	var pal_enabled: bool = bool(palette_info.get("enabled", false))

	if used_rect.size.x == 0 or used_rect.size.y == 0:
		var empty_res := {
			"empty": true,
			"total_opaque_pixels": 0,
			"fully_opaque_pixels": 0,
			"semi_transparent_pixels": 0,
			"non_transparent_pixels": 0,
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
		if pal_enabled:
			empty_res["palette_name"] = str(palette_info.palette_name)
			empty_res["palette_compliant"] = true
			empty_res["off_palette_pixel_count"] = 0
			empty_res["off_palette_color_count"] = 0
			empty_res["off_palette_colors"] = []
		return empty_res

	# 1. Color counting, non-transparent classification, and optional palette validation
	var color_map := {}
	var fully_opaque := 0
	var semi_transparent := 0
	var total_non_transparent := 0
	var off_palette_map := {}
	var off_palette_pixel_count := 0
	var rgb_set: Dictionary = palette_info.get("rgb_set", {})
	var rgba_set: Dictionary = palette_info.get("rgba_set", {})
	var pal_colors: Array = palette_info.get("colors", [])
	var color_in_palette_cache := {}

	for y in range(used_rect.position.y, used_rect.end.y):
		for x in range(used_rect.position.x, used_rect.end.x):
			var c := img.get_pixel(x, y)
			if c.a > 0.05:
				total_non_transparent += 1
				if c.a >= 0.99:
					fully_opaque += 1
				else:
					semi_transparent += 1
				var hex := "#" + c.to_html(c.a < 0.99)
				color_map[hex] = color_map.get(hex, 0) + 1

				if pal_enabled:
					var cache_key: int = ((c.r8 << 16) | (c.g8 << 8) | c.b8) if ignore_alpha_for_palette else ((c.r8 << 24) | (c.g8 << 16) | (c.b8 << 8) | c.a8)
					var matched := false
					if color_in_palette_cache.has(cache_key):
						matched = bool(color_in_palette_cache[cache_key])
					else:
						if palette_tolerance <= 0.0:
							matched = rgb_set.has(cache_key) if ignore_alpha_for_palette else rgba_set.has(cache_key)
						else:
							for pc in pal_colors:
								var pcol: Color = pc
								var dr := c.r - pcol.r
								var dg := c.g - pcol.g
								var db := c.b - pcol.b
								var dist_sq := dr * dr + dg * dg + db * db
								if not ignore_alpha_for_palette:
									var da := c.a - pcol.a
									dist_sq += da * da
								if sqrt(dist_sq) <= palette_tolerance:
									matched = true
									break
						color_in_palette_cache[cache_key] = matched

					if not matched:
						off_palette_pixel_count += 1
						if not off_palette_map.has(hex):
							off_palette_map[hex] = {"color": hex, "count": 0, "sample_coords": []}
						off_palette_map[hex]["count"] = int(off_palette_map[hex]["count"]) + 1
						var samples: Array = off_palette_map[hex]["sample_coords"]
						if samples.size() < 5:
							samples.append([x, y])

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
			if img.get_pixel(x, 0).a < solid_threshold:
				outside[x] = true
				queue.append(Vector2i(x, 0))
			var b_idx := (h - 1) * w + x
			if img.get_pixel(x, h - 1).a < solid_threshold and not outside[b_idx]:
				outside[b_idx] = true
				queue.append(Vector2i(x, h - 1))

		for y in range(h):
			var l_idx := y * w
			if img.get_pixel(0, y).a < solid_threshold and not outside[l_idx]:
				outside[l_idx] = true
				queue.append(Vector2i(0, y))
			var r_idx := y * w + (w - 1)
			if img.get_pixel(w - 1, y).a < solid_threshold and not outside[r_idx]:
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
					if not outside[n_idx] and img.get_pixel(np.x, np.y).a < solid_threshold:
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

	var res := {
		"empty": false,
		"total_opaque_pixels": fully_opaque,
		"fully_opaque_pixels": fully_opaque,
		"semi_transparent_pixels": semi_transparent,
		"non_transparent_pixels": total_non_transparent,
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
	if pal_enabled:
		res["palette_name"] = str(palette_info.palette_name)
		res["palette_compliant"] = off_palette_pixel_count == 0
		res["off_palette_pixel_count"] = off_palette_pixel_count
		res["off_palette_color_count"] = off_palette_map.size()
		res["off_palette_colors"] = off_palette_map.values()
	return res


func _cmd_validate_sprite(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var all_layers: bool = bool(params.get("all_layers", false))
	var check_holes: bool = bool(params.get("check_holes", true))
	var check_orphans: bool = bool(params.get("check_orphans", true))
	var orphan_distance: int = int(params.get("orphan_distance", 1))
	var solid_threshold: float = float(params.get("solid_threshold", 0.5))
	var palette_tolerance: float = maxf(0.0, float(params.get("palette_tolerance", 0.0)))
	var ignore_alpha_for_palette: bool = bool(params.get("ignore_alpha_for_palette", true))

	var palette_info := _resolve_palette_colors(project, params)
	if palette_info.error != "":
		return {"success": false, "error": palette_info.error}

	var frame_res := _resolve_frame_indices(project, params)
	if frame_res.error != "":
		return {"success": false, "error": frame_res.error}
	var frame_indices: Array = frame_res.frames

	var target_layer: int = project.current_layer
	if not all_layers:
		target_layer = _resolve_layer_index(params, project)
		if target_layer < 0 or target_layer >= project.layers.size():
			return {"success": false, "error": "Layer index out of bounds or not found: %s (available: 0..%d)" % [str(params.get("layer", target_layer)), project.layers.size() - 1]}

	var per_frame: Array = []
	for fi in frame_indices:
		var img: Image = null
		if all_layers:
			img = _composite_frame_layers(project, fi)
		else:
			var cel = project.frames[fi].cels[target_layer]
			if cel == null or cel.get_class_name() != "PixelCel":
				return {"success": false, "error": "Cel at [frame:%d, layer:%d] is not a PixelCel" % [fi, target_layer]}
			img = _cel_to_canvas_image(cel, project)
		if img == null:
			return {"success": false, "error": "No active image to validate at frame %d" % fi}

		per_frame.append(_validate_single_frame_image(
			img, fi, target_layer, check_holes, solid_threshold, check_orphans, orphan_distance,
			palette_info, palette_tolerance, ignore_alpha_for_palette
		))

	if not bool(frame_res.is_multi):
		return {"success": true, "data": per_frame[0]}

	var empty_frames: Array[int] = []
	var total_holes := 0
	var total_stray := 0
	var union_colors := {}
	var total_off_pal_pixels := 0
	var agg_off_pal := {}

	for fr in per_frame:
		if bool(fr.empty):
			empty_frames.append(int(fr.frame))
		total_holes += int(fr.enclosed_hole_count)
		total_stray += int(fr.stray_pixel_count)
		for col_hex in fr.unique_colors:
			union_colors[col_hex] = true
		if bool(palette_info.enabled):
			total_off_pal_pixels += int(fr.get("off_palette_pixel_count", 0))
			for entry in fr.get("off_palette_colors", []):
				var ch: String = str(entry.color)
				if not agg_off_pal.has(ch):
					agg_off_pal[ch] = {"color": ch, "count": 0, "frames": [], "sample_coords": []}
				agg_off_pal[ch]["count"] = int(agg_off_pal[ch]["count"]) + int(entry.count)
				var flist: Array = agg_off_pal[ch]["frames"]
				if not (int(fr.frame) in flist):
					flist.append(int(fr.frame))
				var scoords: Array = agg_off_pal[ch]["sample_coords"]
				for sc in entry.get("sample_coords", []):
					if scoords.size() < 5:
						scoords.append([int(fr.frame), sc[0], sc[1]])

	var agg := {
		"multi_frame": true,
		"frames_checked": frame_indices.size(),
		"frame_indices": frame_indices,
		"tag": str(frame_res.tag),
		"all_layers": all_layers,
		"layer": target_layer,
		"layer_name": project.layers[target_layer].name if (not all_layers and target_layer >= 0 and target_layer < project.layers.size()) else "all",
		"empty_frames": empty_frames,
		"total_holes": total_holes,
		"total_stray_pixels": total_stray,
		"union_unique_color_count": union_colors.size(),
		"union_unique_colors": union_colors.keys(),
		"per_frame": per_frame
	}
	if bool(palette_info.enabled):
		agg["palette_name"] = str(palette_info.palette_name)
		agg["palette_compliant"] = total_off_pal_pixels == 0
		agg["total_off_palette_pixels"] = total_off_pal_pixels
		agg["off_palette_color_count"] = agg_off_pal.size()
		agg["off_palette_colors"] = agg_off_pal.values()

	return {"success": true, "data": agg}


func _cmd_get_layer_markers(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var layer_idx: int = _resolve_layer_index(params, project)
	if layer_idx < 0 or layer_idx >= project.layers.size():
		return {"success": false, "error": "Layer index out of bounds or not found: %s (available: 0..%d)" % [str(params.get("layer", layer_idx)), project.layers.size() - 1]}

	var frame_res := _resolve_frame_indices(project, params, "", true)
	if frame_res.error != "":
		return {"success": false, "error": frame_res.error}

	var include_alpha: bool = bool(params.get("include_alpha", false))
	var include_empty_frames: bool = bool(params.get("include_empty_frames", false))
	var min_alpha: float = clampf(float(params.get("min_alpha", 0.01)), 0.0, 1.0)
	var max_pixels_per_frame: int = clampi(int(params.get("max_pixels_per_frame", 4096)), 1, 65536)

	var color_filter := {}
	var has_filter := false
	if params.has("colors") and params["colors"] is Array and not params["colors"].is_empty():
		has_filter = true
		for raw_hex in params["colors"]:
			var hs := str(raw_hex).strip_edges()
			if Color.html_is_valid(hs):
				var fc := Color.html(hs)
				color_filter["#" + fc.to_html(include_alpha).to_lower()] = true

	var layer_obj = project.layers[layer_idx]
	var frame_indices: Array = frame_res.frames
	var markers := {}
	var total_markers := 0
	var truncated_frames: Array[int] = []

	for fi in frame_indices:
		var cel = project.frames[fi].cels[layer_idx]
		if cel == null or cel.get_class_name() != "PixelCel":
			return {"success": false, "error": "Cel at [frame:%d, layer:%d] is not a PixelCel" % [fi, layer_idx]}

		var img: Image = _cel_to_canvas_image(cel, project)
		var used := img.get_used_rect()
		var frame_map := {}
		var frame_count := 0
		var frame_truncated := false

		if used.size.x > 0 and used.size.y > 0:
			for y in range(used.position.y, used.end.y):
				if frame_truncated:
					break
				for x in range(used.position.x, used.end.x):
					var c := img.get_pixel(x, y)
					if c.a >= min_alpha:
						var hex := "#" + c.to_html(include_alpha).to_lower()
						if has_filter and not color_filter.has(hex):
							continue
						if not frame_map.has(hex):
							frame_map[hex] = []
						frame_map[hex].append([x, y])
						frame_count += 1
						total_markers += 1
						if frame_count >= max_pixels_per_frame:
							frame_truncated = true
							truncated_frames.append(fi)
							break

		if include_empty_frames or not frame_map.is_empty():
			markers[str(fi)] = frame_map

	return {
		"success": true,
		"data": {
			"layer": layer_idx,
			"layer_name": str(layer_obj.name),
			"layer_id": _get_or_create_layer_id(layer_obj),
			"visible": bool(layer_obj.visible),
			"frames_scanned": frame_indices,
			"tag": str(frame_res.tag),
			"total_markers": total_markers,
			"truncated_frames": truncated_frames,
			"markers": markers
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


# ─────────────────────────────────────────────
# SCRIPT EVALUATION & CONTEXT HELPERS
# ─────────────────────────────────────────────

class ApiContext extends RefCounted:
	var _api: Node
	var _project
	var _handler

	func _init(api: Node, project, handler) -> void:
		_api = api
		_project = project
		_handler = handler

	func get_pixel(x: int, y: int, layer = -1, frame: int = -1) -> Color:
		if _project == null:
			return Color.TRANSPARENT
		var f_idx: int = frame if frame >= 0 else _project.current_frame
		var has_custom_layer := not (typeof(layer) == TYPE_INT and layer == -1)
		var l_idx: int = _handler._resolve_layer_index({"layer": layer}, _project) if has_custom_layer else _project.current_layer
		if f_idx < 0 or f_idx >= _project.frames.size() or l_idx < 0 or l_idx >= _project.layers.size():
			return Color.TRANSPARENT
		var cel = _project.frames[f_idx].cels[l_idx]
		if cel == null or cel.get_class_name() != "PixelCel":
			return Color.TRANSPARENT
		if x < 0 or x >= int(_project.size.x) or y < 0 or y >= int(_project.size.y):
			return Color.TRANSPARENT
		var img: Image = _handler._cel_to_canvas_image(cel, _project)
		return img.get_pixel(x, y)

	func get_layer_image(layer = -1, frame: int = -1, fallback_empty: bool = true) -> Image:
		var w: int = int(_project.size.x) if _project else 64
		var h: int = int(_project.size.y) if _project else 64
		if _project == null:
			return Image.create(w, h, false, Image.FORMAT_RGBA8) if fallback_empty else null
		var f_idx: int = frame if frame >= 0 else _project.current_frame
		var has_custom_layer := not (typeof(layer) == TYPE_INT and layer == -1)
		var l_idx: int = _handler._resolve_layer_index({"layer": layer}, _project) if has_custom_layer else _project.current_layer
		if f_idx < 0 or f_idx >= _project.frames.size() or l_idx < 0 or l_idx >= _project.layers.size():
			return Image.create(w, h, false, Image.FORMAT_RGBA8) if fallback_empty else null
		var cel = _project.frames[f_idx].cels[l_idx]
		if cel == null or cel.get_class_name() != "PixelCel":
			return Image.create(w, h, false, Image.FORMAT_RGBA8) if fallback_empty else null
		var img: Image = cel.get_image()
		if img == null:
			return Image.create(w, h, false, Image.FORMAT_RGBA8) if fallback_empty else null
		return _handler._cel_to_canvas_image(cel, _project)

	func has_layer(layer) -> bool:
		if _project == null:
			return false
		if typeof(layer) == TYPE_INT:
			return layer >= 0 and layer < _project.layers.size()
		var s: String = str(layer).strip_edges()
		for i in range(_project.layers.size()):
			if _handler._get_or_create_layer_id(_project.layers[i]) == s or _project.layers[i].name == s:
				return true
		if s.is_valid_int():
			var idx := int(s)
			return idx >= 0 and idx < _project.layers.size()
		return false

	func is_valid_image(img: Variant) -> bool:
		return img is Image and img != null and not img.is_empty()

	func get_composite_image(frame: int = -1) -> Image:
		var w: int = int(_project.size.x) if _project else 64
		var h: int = int(_project.size.y) if _project else 64
		if _project == null:
			return Image.create(w, h, false, Image.FORMAT_RGBA8)
		var f_idx: int = frame if frame >= 0 else _project.current_frame
		var res: Image = _handler._composite_frame_layers(_project, f_idx)
		if res == null:
			return Image.create(w, h, false, Image.FORMAT_RGBA8)
		return res

	func get_layers() -> Array:
		var list: Array = []
		if _project == null:
			return list
		for i in range(_project.layers.size()):
			var lyr = _project.layers[i]
			list.append({
				"index": i,
				"name": lyr.name,
				"id": _handler._get_or_create_layer_id(lyr),
				"visible": lyr.is_visible_in_hierarchy() if lyr.has_method("is_visible_in_hierarchy") else lyr.visible
			})
		return list

	func get_canvas_size() -> Vector2i:
		return _project.size if _project else Vector2i.ZERO

	func create_image(width: int = -1, height: int = -1) -> Image:
		var w: int = width if width > 0 else (int(_project.size.x) if _project else 64)
		var h: int = height if height > 0 else (int(_project.size.y) if _project else 64)
		return Image.create(w, h, false, Image.FORMAT_RGBA8)

	func set_pixel_safe(image: Image, x: int, y: int, color: Color) -> bool:
		if image != null and x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
			image.set_pixel(x, y, color)
			return true
		return false

	func get_api_version() -> int:
		return _api.get_api_version() if _api and _api.has_method("get_api_version") else -1

	var raw_api:
		get: return _api

	func _get(property: StringName):
		if _api != null and property in _api:
			return _api.get(property)
		return null


func _get_godot_log_file() -> FileAccess:
	var path := "user://logs/godot.log"
	if FileAccess.file_exists(path):
		return FileAccess.open(path, FileAccess.READ)
	var alt_path := OS.get_user_data_dir() + "/logs/godot.log"
	if FileAccess.file_exists(alt_path):
		return FileAccess.open(alt_path, FileAccess.READ)
	return null


func _get_godot_log_pos() -> int:
	var f := _get_godot_log_file()
	if f == null:
		return 0
	var pos := f.get_length()
	f.close()
	return pos


func _extract_godot_log_tail(from_pos: int = -1) -> String:
	var f := _get_godot_log_file()
	if f == null:
		return ""
	var total_len := f.get_length()
	if from_pos >= 0 and from_pos >= total_len:
		f.close()
		return ""
	var start := from_pos
	if start < 0:
		start = maxi(0, total_len - 4096)
	f.seek(start)
	var content := f.get_as_text()
	f.close()
	return content


func _extract_compile_error_from_log(log_tail: String, full_source: String) -> String:
	var lines := log_tail.split("\n")
	var err_msg := ""
	var line_num := -1
	for i in range(lines.size() - 1, -1, -1):
		var l := lines[i].strip_edges()
		if l.begins_with("at: GDScript::reload") and line_num == -1:
			var colon_idx := l.rfind(":")
			if colon_idx != -1:
				var end_paren := l.find(")", colon_idx)
				if end_paren != -1:
					line_num = int(l.substr(colon_idx + 1, end_paren - colon_idx - 1))
		elif (l.begins_with("SCRIPT ERROR: Parse Error:") or l.begins_with("SCRIPT ERROR:")) and err_msg == "":
			err_msg = l.replace("SCRIPT ERROR:", "").strip_edges()
			if l.find("Parse Error:") != -1:
				err_msg = l.substr(l.find("Parse Error:")).strip_edges()
			if line_num != -1:
				break

	if err_msg != "":
		if line_num > 0:
			var code_lines := full_source.split("\n")
			var snippet := ""
			if line_num <= code_lines.size():
				snippet = code_lines[line_num - 1].strip_edges()
			return "%s (at line %d: '%s')" % [err_msg, line_num, snippet]
		return err_msg
	return ""


func _extract_runtime_error_from_log(log_tail: String, full_source: String) -> String:
	if log_tail.strip_edges() == "":
		return ""
	var lines := log_tail.split("\n")
	var err_msg := ""
	var line_num := -1
	for i in range(lines.size() - 1, -1, -1):
		var l := lines[i].strip_edges()
		if (l.begins_with("at: run") or l.begins_with("at: execute")) and line_num == -1:
			var colon_idx := l.rfind(":")
			if colon_idx != -1:
				var end_paren := l.find(")", colon_idx)
				if end_paren != -1:
					line_num = int(l.substr(colon_idx + 1, end_paren - colon_idx - 1))
		elif (l.begins_with("SCRIPT ERROR:") or l.begins_with("ERROR:")) and err_msg == "":
			if l.find("Parse Error:") != -1 or l.find("GDScript::reload") != -1:
				continue
			err_msg = l.replace("SCRIPT ERROR:", "").replace("ERROR:", "").strip_edges()
			if line_num != -1:
				break

	if err_msg != "":
		if line_num > 0:
			var code_lines := full_source.split("\n")
			var snippet := ""
			if line_num <= code_lines.size():
				snippet = code_lines[line_num - 1].strip_edges()
			return "%s (at line %d: '%s')" % [err_msg, line_num, snippet]
		return err_msg
	return ""


func _cmd_eval_gdscript(params: Dictionary) -> Dictionary:
	var code: String = params.get("code", "")
	if code.strip_edges() == "":
		return {"success": false, "error": "Missing or empty code to evaluate"}

	var target := _get_target_cel_and_image(params)
	if target.error != "":
		return {"success": false, "error": target.error}

	var image: Image = target.image
	var frame_idx: int = target.frame
	var layer_idx: int = target.layer
	var project = _api.project.current_project

	var script_params: Dictionary = {}
	if params.has("params") and (params["params"] is Dictionary):
		script_params = params["params"]
	var record_undo: bool = bool(params.get("record_undo", true))

	var full_source := ""
	if code.find("func execute") != -1 or code.find("func run") != -1:
		if not code.begins_with("extends"):
			full_source = "extends RefCounted\n\n" + code
		else:
			full_source = code
	else:
		full_source = "extends RefCounted\n\nfunc run(api, image: Image, project, params: Dictionary) -> Variant:\n"
		var lines := code.split("\n")
		var min_indent := -1
		for line in lines:
			var stripped := line.strip_edges()
			if stripped == "":
				continue
			var count := 0
			for i in range(line.length()):
				var ch := line[i]
				if ch == " " or ch == "\t":
					count += 1
				else:
					break
			if min_indent == -1 or count < min_indent:
				min_indent = count
		if min_indent == -1:
			min_indent = 0

		for line in lines:
			var stripped := line.strip_edges()
			if stripped == "":
				full_source += "\n"
				continue
			var count := 0
			var idx := 0
			while idx < line.length() and count < min_indent:
				var ch := line[idx]
				if ch == " " or ch == "\t":
					count += 1
					idx += 1
				else:
					break
			var rel_line := line.substr(idx)
			var rel_tabs := ""
			while rel_line.begins_with("    "):
				rel_tabs += "\t"
				rel_line = rel_line.substr(4)
			while rel_line.begins_with("  "):
				rel_tabs += "\t"
				rel_line = rel_line.substr(2)
			while rel_line.begins_with("\t"):
				rel_tabs += "\t"
				rel_line = rel_line.substr(1)
			full_source += "\t" + rel_tabs + rel_line + "\n"
		full_source += "\treturn null\n"

	# Transparent bounds guarding: rewrite .set_pixel and non-api .get_pixel calls to prevent native Godot SIGSEGV heap overflows
	var regex_set_px := RegEx.new()
	regex_set_px.compile("\\b([a-zA-Z0-9_]+)\\.set_pixel\\s*\\(")
	if regex_set_px.is_valid():
		full_source = regex_set_px.sub(full_source, "_safe_set_pixel($1, ", true)

	var regex_get_px := RegEx.new()
	regex_get_px.compile("\\b(?!(?:api)\\b)([a-zA-Z0-9_]+)\\.get_pixel\\s*\\(")
	if regex_get_px.is_valid():
		full_source = regex_get_px.sub(full_source, "_safe_get_pixel($1, ", true)

	# Safe get_width / get_height guarding: rewrite .get_width() and .get_height() calls to prevent native SIGSEGV on null instances
	var regex_get_w := RegEx.new()
	regex_get_w.compile("\\b([a-zA-Z0-9_]+)\\.get_width\\s*\\(\\s*\\)")
	if regex_get_w.is_valid():
		full_source = regex_get_w.sub(full_source, "_safe_get_width($1)", true)

	var regex_get_h := RegEx.new()
	regex_get_h.compile("\\b([a-zA-Z0-9_]+)\\.get_height\\s*\\(\\s*\\)")
	if regex_get_h.is_valid():
		full_source = regex_get_h.sub(full_source, "_safe_get_height($1)", true)

	# Safe cast guarding: strip inline unsafe casts like '(expr as PackedFloat32Array)[x]' or 'expr as Array[x]'
	# In Godot release builds, static indexing on 'as Packed*Array' crashes C++ with SIGSEGV if the cast yields null.
	# Stripping 'as Packed*Array' allows dynamic Variant indexing, which safely raises a GDScript error instead of crashing.
	var regex_unsafe_cast := RegEx.new()
	regex_unsafe_cast.compile("\\s*\\bas\\s+(?:Packed[A-Za-z0-9]+Array|Array)(?=\\s*\\)\\s*\\[|\\s*\\[)")
	if regex_unsafe_cast.is_valid():
		full_source = regex_unsafe_cast.sub(full_source, "", true)

	var safe_helpers := "\n\nstatic var _clipped_pixel_count: int = 0\n\nstatic func _safe_get_width(img: Variant) -> int:\n\tif img != null and img.has_method(\"get_width\"):\n\t\treturn img.get_width()\n\treturn 0\n\nstatic func _safe_get_height(img: Variant) -> int:\n\tif img != null and img.has_method(\"get_height\"):\n\t\treturn img.get_height()\n\treturn 0\n\nstatic func _safe_set_pixel(img: Variant, px: int, py: int, col: Color) -> void:\n\tif img != null and img.has_method(\"set_pixel\") and img.has_method(\"get_width\") and img.has_method(\"get_height\"):\n\t\tif px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():\n\t\t\timg.set_pixel(px, py, col)\n\t\t\treturn\n\t_clipped_pixel_count += 1\n\nstatic func _safe_get_pixel(img: Variant, px: int, py: int) -> Color:\n\tif img != null and img.has_method(\"get_pixel\") and img.has_method(\"get_width\") and img.has_method(\"get_height\"):\n\t\tif px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():\n\t\t\treturn img.get_pixel(px, py)\n\treturn Color(0, 0, 0, 0)\n"
	full_source += safe_helpers

	var log_pos_before_compile := _get_godot_log_pos()
	var script := GDScript.new()
	script.source_code = full_source
	var err = script.reload()

	# Auto-fallback: If ERR_PARSE_ERROR (43), check if static type inference ':=' on Variant failed
	if err != OK:
		var regex_infer := RegEx.new()
		regex_infer.compile("\\bvar\\s+([a-zA-Z_]\\w*)\\s*:=")
		if regex_infer.is_valid() and regex_infer.search(full_source) != null:
			var patched_source := regex_infer.sub(full_source, "var $1 =", true)
			var retry_script := GDScript.new()
			retry_script.source_code = patched_source
			var retry_err = retry_script.reload()
			if retry_err == OK:
				script = retry_script
				full_source = patched_source
				err = OK

	if err != OK:
		OS.delay_msec(25)
		var log_tail := _extract_godot_log_tail(log_pos_before_compile)
		var parse_err := _extract_compile_error_from_log(log_tail, full_source)
		if parse_err == "":
			log_tail = _extract_godot_log_tail(-1)
			parse_err = _extract_compile_error_from_log(log_tail, full_source)
		var err_str := "Failed to compile GDScript (Error code %d)" % err
		if parse_err != "":
			err_str = "Failed to compile GDScript: %s" % parse_err
		return {
			"success": false,
			"error": err_str,
			"source": full_source
		}

	var instance = script.new()
	if instance == null:
		return {"success": false, "error": "Failed to instantiate GDScript"}

	if instance.get("_clipped_pixel_count") != null:
		instance.set("_clipped_pixel_count", 0)

	var method_name := ""
	var method_info: Dictionary = {}
	if instance.has_method("run"):
		method_name = "run"
	elif instance.has_method("execute"):
		method_name = "execute"
	else:
		return {"success": false, "error": "Script must define 'run(api, image, project, params)' or 'execute(api, image, project, params)'"}

	for m in instance.get_method_list():
		if m["name"] == method_name:
			method_info = m
			break

	var api_ctx = ApiContext.new(_api, project, self)

	# Scripts may access cel.get_image() directly and write in canvas
	# coordinates. Pixelorama 1.2.4 cels start compact (often 1x1), so grow
	# the cel image to cover the canvas first; the commit below shrinks it
	# back to its used rect, preserving any out-of-canvas pixels.
	# Snapshot the target cel BEFORE any expansion or script execution so both
	# read-only restoration and Undo ("Ctrl+Z") restore the true pre-eval cel.
	var cel_before = target.get("cel", null)
	var pre_eval_target_state := _snapshot_cel_state(cel_before)
	var expanded_frame_cels: Array = []
	if full_source.contains("get_image") and project != null and frame_idx >= 0 and frame_idx < project.frames.size():
		for frame_cel in project.frames[frame_idx].cels:
			if frame_cel != null and frame_cel.has_method("ensure_canvas_rect_in_bounds"):
				var pre_state := _snapshot_cel_state(frame_cel)
				frame_cel.ensure_canvas_rect_in_bounds(Vector2i.ZERO, project.size)
				var post_expand_state := _snapshot_cel_state(frame_cel)
				expanded_frame_cels.append({
					"cel": frame_cel,
					"pre_state": pre_state,
					"expanded_state": post_expand_state,
				})

	# Snapshot the cel (post-expansion) and the working image so direct cel edits
	# made by the script (offset changes, set_pixel on cel.get_image(), resizes)
	# are detected and not clobbered by committing the stale working image below.
	var offset_before := Vector2i.ZERO
	var cel_size_before := Vector2i.ZERO
	var cel_data_before := PackedByteArray()
	if cel_before != null and cel_before.has_method("get_image"):
		offset_before = _get_cel_offset(cel_before)
		var cel_img_before: Image = cel_before.get_image()
		if cel_img_before != null and not cel_img_before.is_empty():
			cel_size_before = cel_img_before.get_size()
			cel_data_before = cel_img_before.get_data()
	var image_data_before := PackedByteArray()
	if image != null and not image.is_empty():
		image_data_before = image.get_data()

	var call_args: Array = []
	var m_args: Array = method_info.get("args", [])
	for arg in m_args:
		var aname: String = str(arg.get("name", "")).to_lower()
		var cname: String = str(arg.get("class_name", ""))
		if aname in ["image", "img", "cel"] or cname == "Image":
			call_args.append(image)
		elif aname in ["params", "dict", "parameters"]:
			call_args.append(script_params)
		elif aname in ["project", "proj"]:
			call_args.append(project)
		elif aname in ["api", "extensions_api", "node"]:
			call_args.append(api_ctx)
		else:
			var pos := call_args.size()
			if pos == 0:
				call_args.append(api_ctx)
			elif pos == 1:
				call_args.append(image)
			elif pos == 2:
				call_args.append(project)
			elif pos == 3:
				call_args.append(script_params)
			else:
				call_args.append(null)

	var log_pos_before_run := _get_godot_log_pos()
	var result = instance.callv(method_name, call_args)

	OS.delay_msec(25)
	var log_tail_run := _extract_godot_log_tail(log_pos_before_run)
	var runtime_err := _extract_runtime_error_from_log(log_tail_run, full_source)
	if runtime_err != "":
		for entry in expanded_frame_cels:
			_restore_cel_state_in_place(entry["pre_state"])
		_restore_cel_state_in_place(pre_eval_target_state)
		return {
			"success": false,
			"error": "GDScript runtime error: %s" % runtime_err,
			"source": full_source
		}

	var clipped_pixels: int = 0
	if instance.get("_clipped_pixel_count") != null:
		clipped_pixels = int(instance.get("_clipped_pixel_count"))

	var resized_canvas := false
	var prev_size = project.size if project != null else Vector2i.ZERO

	if result is Image:
		if result.get_size() != project.size:
			var new_w: int = int(result.get_width())
			var new_h: int = int(result.get_height())
			resized_canvas = true
			project.size = Vector2i(new_w, new_h)
			var canvas_node = _api.general.get_canvas()
			if canvas_node:
				var cam = canvas_node.get("camera")
				if cam and cam.has_method("fit_to_frame"):
					cam.fit_to_frame()
		image = result
	elif result is PackedByteArray:
		var w := int(project.size.x)
		var h := int(project.size.y)
		if script_params.has("width") and script_params.has("height"):
			var pw := int(script_params["width"])
			var ph := int(script_params["height"])
			if pw > 0 and ph > 0 and (result.size() == pw * ph * 4 or result.size() == pw * ph * 3):
				w = pw
				h = ph
				if Vector2i(w, h) != project.size:
					resized_canvas = true
					project.size = Vector2i(w, h)
					var canvas_node = _api.general.get_canvas()
					if canvas_node:
						var cam = canvas_node.get("camera")
						if cam and cam.has_method("fit_to_frame"):
							cam.fit_to_frame()
		if result.size() == w * h * 4:
			var img_from_bytes := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, result)
			if img_from_bytes:
				image = img_from_bytes
		elif result.size() == w * h * 3:
			var img_from_bytes := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, result)
			if img_from_bytes:
				img_from_bytes.convert(Image.FORMAT_RGBA8)
				image = img_from_bytes
		else:
			for entry in expanded_frame_cels:
				_restore_cel_state_in_place(entry["pre_state"])
			_restore_cel_state_in_place(pre_eval_target_state)
			return {
				"success": false,
				"error": "PackedByteArray size %d does not match canvas dimensions %dx%d (expected %d bytes for RGBA8 or %d for RGB8). Note: Canvas size is %dx%d; use 'create_canvas' to match your intended buffer dimensions." % [result.size(), w, h, w * h * 4, w * h * 3, int(project.size.x), int(project.size.y)],
				"source": full_source
			}

	# Restore any non-target cels on the frame that were only expanded as a
	# precaution and not actually modified by the script; shrink & refresh any
	# non-target cels the script intentionally modified directly.
	var cel_now = null
	if project != null and frame_idx >= 0 and frame_idx < project.frames.size() and layer_idx >= 0 and layer_idx < project.layers.size():
		cel_now = project.frames[frame_idx].cels[layer_idx]
	for entry in expanded_frame_cels:
		var fcel = entry["cel"]
		if fcel == cel_now:
			continue
		if _cel_matches_snapshot(fcel, entry["expanded_state"]):
			_restore_cel_state_in_place(entry["pre_state"])
		else:
			if fcel.has_method("shrink_to_content"):
				fcel.shrink_to_content()
			if fcel.has_method("update_texture"):
				fcel.update_texture()

	# Only commit (and therefore only create an undo action) when the script
	# actually changed something. Read-only scripts used to push a no-op
	# "Eval GDScript" action onto the undo stack, which displaced the real
	# previous action and cleared the redo stack on the next undo.
	var should_commit := result is Image or result is PackedByteArray
	if not should_commit and image != null and not image.is_empty():
		if image_data_before.is_empty() or image.get_data() != image_data_before:
			should_commit = true
	if not should_commit and not (result is Image) and not (result is PackedByteArray) and cel_now != null and cel_now.has_method("get_image"):
		var cel_img_now: Image = cel_now.get_image()
		var cel_changed := _get_cel_offset(cel_now) != offset_before
		if cel_img_now == null or cel_img_now.is_empty():
			cel_changed = cel_changed or cel_size_before != Vector2i.ZERO
		else:
			cel_changed = cel_changed or cel_img_now.get_size() != cel_size_before or cel_img_now.get_data() != cel_data_before
		var image_unchanged := image != null and not image.is_empty() and image.get_data() == image_data_before
		if cel_changed and image_unchanged:
			image = _cel_to_canvas_image(cel_now, project)
		if cel_changed:
			should_commit = true

	# A read-only script must leave the target cel exactly as it found it.
	if not should_commit:
		_restore_cel_state_in_place(pre_eval_target_state)

	if should_commit and image != null:
		_commit_image_change(image, "Eval GDScript", frame_idx, layer_idx, record_undo, pre_eval_target_state)
		OS.delay_msec(1)

	var canvas = _api.general.get_canvas()
	if canvas:
		if "project_changed" in canvas:
			canvas.project_changed = true
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()

	var result_repr = result
	if result is Image:
		result_repr = "Image updated"
	elif result is PackedByteArray:
		result_repr = "Image buffer updated"

	var result_data := {
		"result": result_repr,
		"value": result if not (result is Image or result is PackedByteArray) else null,
		"frame": frame_idx,
		"layer": layer_idx
	}
	if resized_canvas:
		result_data["canvas_resized"] = true
		result_data["previous_size"] = [int(prev_size.x), int(prev_size.y)]
		result_data["new_size"] = [int(project.size.x), int(project.size.y)]
		var resize_warn := "⚠️ Canvas automatically resized from %dx%d to %dx%d because returned buffer had different dimensions." % [int(prev_size.x), int(prev_size.y), int(project.size.x), int(project.size.y)]
		if result_data.has("warning"):
			result_data["warning"] += "\n" + resize_warn
		else:
			result_data["warning"] = resize_warn
	if clipped_pixels > 0:
		result_data["clipped_pixels"] = clipped_pixels
		var clip_warn := "⚠️ %d pixel writes were clipped outside canvas bounds (%dx%d). Use 'create_canvas' to expand canvas dimensions if you intended a larger drawing area!" % [clipped_pixels, int(project.size.x), int(project.size.y)]
		if result_data.has("warning"):
			result_data["warning"] += "\n" + clip_warn
		else:
			result_data["warning"] = clip_warn
		if result_repr == null or str(result_repr) == "ok" or str(result_repr) == "":
			result_data["result"] = "⚠️ %d pixels clipped outside canvas bounds (%dx%d)" % [clipped_pixels, int(project.size.x), int(project.size.y)]
		else:
			result_data["result"] = "%s (⚠️ %d pixels clipped outside %dx%d canvas)" % [str(result_repr), clipped_pixels, int(project.size.x), int(project.size.y)]

	return {
		"success": true,
		"data": result_data
	}



