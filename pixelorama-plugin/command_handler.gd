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
	_tool_registry["save_project"] = Callable(self, "_cmd_save_project")
	_tool_registry["export_image"] = Callable(self, "_cmd_export_image")
	_tool_registry["get_canvas_snapshot"] = Callable(self, "_cmd_get_canvas_snapshot")
	_tool_registry["fit_viewport"] = Callable(self, "_cmd_fit_viewport")

	# Drawing & Painting
	_tool_registry["draw_pixel"] = Callable(self, "_cmd_draw_pixel")
	_tool_registry["draw_pixels"] = Callable(self, "_cmd_draw_pixels")
	_tool_registry["draw_rect"] = Callable(self, "_cmd_draw_rect")
	_tool_registry["draw_line"] = Callable(self, "_cmd_draw_line")
	_tool_registry["draw_path"] = Callable(self, "_cmd_draw_path")
	_tool_registry["draw_polygon"] = Callable(self, "_cmd_draw_polygon")
	_tool_registry["draw_ellipse"] = Callable(self, "_cmd_draw_ellipse")
	_tool_registry["fill_area"] = Callable(self, "_cmd_fill_area")

	# Colour
	_tool_registry["set_color"] = Callable(self, "_cmd_set_color")
	_tool_registry["get_color"] = Callable(self, "_cmd_get_color")

	# Layers
	_tool_registry["add_layer"] = Callable(self, "_cmd_add_layer")
	_tool_registry["delete_layer"] = Callable(self, "_cmd_delete_layer")
	_tool_registry["get_layers"] = Callable(self, "_cmd_get_layers")
	_tool_registry["set_layer_opacity"] = Callable(self, "_cmd_set_layer_opacity")
	_tool_registry["set_layer_blend_mode"] = Callable(self, "_cmd_set_layer_blend_mode")
	_tool_registry["set_layer_visibility"] = Callable(self, "_cmd_set_layer_visibility")

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


func _commit_image_change(image: Image, _action_name: String) -> void:
	## Commits the modified image through Pixelorama's undo system.
	## This ensures every AI action is undoable by the user.
	var project = _api.project.current_project
	if project == null:
		return
	
	# 1. Duplicate the image to force a new object reference in Godot,
	# which ensures Pixelorama's caches detect the change and update the canvas.
	var dup_image := image.duplicate()
	_api.project.set_pixelcel_image(
		dup_image,
		project.current_frame,
		project.current_layer
	)

	# 2. Programmatically select the current cel to trigger a switch/refresh signal
	_api.project.select_cels([[project.current_frame, project.current_layer]])

	# 3. Request redraw on the main canvas (necessary in Pixelorama v1.1.9+ as it doesn't continuously redraw when idle)
	var canvas = _api.general.get_canvas()
	if canvas:
		canvas.queue_redraw()
		if canvas.has_method("update_texture"):
			canvas.update_texture(project.current_layer)


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

	var project = _api.project.new_project(
		[] as Array[Frame],
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


func _cmd_save_project(_params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var open_save = _api.import.open_save_autoload()
	if project.save_path != "":
		open_save.save_pxo(project.save_path)
		return {"success": true, "data": {"path": project.save_path}}
	else:
		return {"success": false, "error": "No save path set. Use Pixelorama's File > Save As first."}


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




# ─────────────────────────────────────────────
# DRAWING & PAINTING COMMANDS
# ─────────────────────────────────────────────

func _cmd_draw_pixel(params: Dictionary) -> Dictionary:
	var x: int = params.get("x", 0)
	var y: int = params.get("y", 0)
	var color := _parse_color(params)

	var image := _get_current_image()
	if image == null:
		return {"success": false, "error": "No active pixel cel"}

	if x < 0 or x >= image.get_width() or y < 0 or y >= image.get_height():
		return {"success": false, "error": "Coordinates (%d, %d) out of bounds (%dx%d)" % [x, y, image.get_width(), image.get_height()]}

	image.set_pixel(x, y, color)
	_commit_image_change(image, "Draw Pixel")
	return {"success": true, "data": {"x": x, "y": y, "color": color.to_html()}}


func _cmd_draw_pixels(params: Dictionary) -> Dictionary:
	## Batch draw multiple pixels in a single undo-able operation.
	## Expects "pixels" as an array of {"x": int, "y": int, "color": "#hex"} objects.
	## Optimized with color caching to avoid redundant string parsing in the loop.
	var pixels: Array = params.get("pixels", [])
	if pixels.is_empty():
		return {"success": false, "error": "Missing or empty 'pixels' array"}

	var image := _get_current_image()
	if image == null:
		return {"success": false, "error": "No active pixel cel"}

	var w := image.get_width()
	var h := image.get_height()
	var drawn := 0
	var skipped := 0

	var color_cache := {}

	for pixel in pixels:
		if not pixel is Dictionary:
			skipped += 1
			continue
		var x: int = pixel.get("x", -1)
		var y: int = pixel.get("y", -1)
		if x < 0 or x >= w or y < 0 or y >= h:
			skipped += 1
			continue
		
		var color_str: String = pixel.get("color", "")
		var color: Color
		if color_cache.has(color_str):
			color = color_cache[color_str]
		else:
			color = _parse_color(pixel)
			color_cache[color_str] = color
			
		image.set_pixel(x, y, color)
		drawn += 1

	# Single commit for all pixels — one undo step
	_commit_image_change(image, "Draw Pixels (batch)")
	return {
		"success": true,
		"data": {
			"drawn": drawn,
			"skipped": skipped,
			"total": pixels.size()
		}
	}


func _cmd_draw_rect(params: Dictionary) -> Dictionary:
	var x: int = params.get("x", 0)
	var y: int = params.get("y", 0)
	var width: int = params.get("width", 1)
	var height: int = params.get("height", 1)
	var filled: bool = params.get("filled", true)
	var color := _parse_color(params)

	var image := _get_current_image()
	if image == null:
		return {"success": false, "error": "No active pixel cel"}

	var img_w := image.get_width()
	var img_h := image.get_height()

	if filled:
		# Clamp the fill rect to canvas bounds for safety
		var clamped := Rect2i(x, y, width, height).intersection(Rect2i(0, 0, img_w, img_h))
		if clamped.has_area():
			image.fill_rect(clamped, color)
	else:
		# Draw outline only — top, bottom, left, right edges
		for px in range(x, x + width):
			if px >= 0 and px < img_w:
				if y >= 0 and y < img_h:
					image.set_pixel(px, y, color)
				var bot := y + height - 1
				if bot >= 0 and bot < img_h and height > 1:
					image.set_pixel(px, bot, color)
		for py in range(y + 1, y + height - 1):  # Exclude corners (already drawn)
			if py >= 0 and py < img_h:
				if x >= 0 and x < img_w:
					image.set_pixel(x, py, color)
				var right := x + width - 1
				if right >= 0 and right < img_w and width > 1:
					image.set_pixel(right, py, color)

	_commit_image_change(image, "Draw Rectangle")
	return {"success": true, "data": {"x": x, "y": y, "width": width, "height": height, "filled": filled}}


func _cmd_draw_line(params: Dictionary) -> Dictionary:
	var x1: int = params.get("x1", 0)
	var y1: int = params.get("y1", 0)
	var x2: int = params.get("x2", 0)
	var y2: int = params.get("y2", 0)
	var color := _parse_color(params)

	var image := _get_current_image()
	if image == null:
		return {"success": false, "error": "No active pixel cel"}

	var pixel_count := _draw_line_on_image(image, x1, y1, x2, y2, color)
	_commit_image_change(image, "Draw Line")
	return {"success": true, "data": {"x1": x1, "y1": y1, "x2": x2, "y2": y2, "pixels": pixel_count}}

func _draw_line_on_image(image: Image, x1: int, y1: int, x2: int, y2: int, color: Color) -> int:
	var dx := absi(x2 - x1)
	var dy := -absi(y2 - y1)
	var sx := 1 if x1 < x2 else -1
	var sy := 1 if y1 < y2 else -1
	var err := dx + dy
	var cx := x1
	var cy := y1
	var pixel_count := 0

	while true:
		if cx >= 0 and cx < image.get_width() and cy >= 0 and cy < image.get_height():
			image.set_pixel(cx, cy, color)
			pixel_count += 1
		if cx == x2 and cy == y2:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			cx += sx
		if e2 <= dx:
			err += dx
			cy += sy
	return pixel_count


func _cmd_draw_path(params: Dictionary) -> Dictionary:
	var points: Array = params.get("points", [])
	if points.size() < 2:
		return {"success": false, "error": "Path requires at least 2 points"}
	var closed: bool = params.get("closed", false)
	var color := _parse_color(params)

	var image := _get_current_image()
	if image == null:
		return {"success": false, "error": "No active pixel cel"}

	var pixel_count := 0
	for i in range(points.size() - 1):
		pixel_count += _draw_line_on_image(image, points[i].x, points[i].y, points[i+1].x, points[i+1].y, color)
	
	if closed and points.size() > 2:
		pixel_count += _draw_line_on_image(image, points[-1].x, points[-1].y, points[0].x, points[0].y, color)

	_commit_image_change(image, "Draw Path")
	return {"success": true, "data": {"points": points.size(), "closed": closed, "pixels": pixel_count}}


func _cmd_draw_polygon(params: Dictionary) -> Dictionary:
	var points_array: Array = params.get("points", [])
	if points_array.size() < 3:
		return {"success": false, "error": "Polygon requires at least 3 points"}
	
	var points := PackedVector2Array()
	var min_x := 999999
	var max_x := -999999
	var min_y := 999999
	var max_y := -999999
	for p in points_array:
		var x = p.get("x", 0)
		var y = p.get("y", 0)
		points.append(Vector2(x, y))
		min_x = mini(min_x, x)
		max_x = maxi(max_x, x)
		min_y = mini(min_y, y)
		max_y = maxi(max_y, y)

	var filled: bool = params.get("filled", true)
	var color := _parse_color(params)

	var image := _get_current_image()
	if image == null:
		return {"success": false, "error": "No active pixel cel"}

	var pixel_count := 0
	var w := image.get_width()
	var h := image.get_height()

	if filled:
		min_x = clampi(min_x, 0, w - 1)
		max_x = clampi(max_x, 0, w - 1)
		min_y = clampi(min_y, 0, h - 1)
		max_y = clampi(max_y, 0, h - 1)
		
		for py in range(min_y, max_y + 1):
			for px in range(min_x, max_x + 1):
				if Geometry2D.is_point_in_polygon(Vector2(px, py), points):
					image.set_pixel(px, py, color)
					pixel_count += 1
	else:
		for i in range(points.size() - 1):
			pixel_count += _draw_line_on_image(image, points[i].x, points[i].y, points[i+1].x, points[i+1].y, color)
		pixel_count += _draw_line_on_image(image, points[-1].x, points[-1].y, points[0].x, points[0].y, color)

	_commit_image_change(image, "Draw Polygon")
	return {"success": true, "data": {"points": points.size(), "filled": filled, "pixels": pixel_count}}


func _cmd_draw_ellipse(params: Dictionary) -> Dictionary:
	var cx: int = params.get("cx", 0)
	var cy: int = params.get("cy", 0)
	var rx: int = params.get("rx", 1)
	var ry: int = params.get("ry", 1)
	var filled: bool = params.get("filled", true)
	var color := _parse_color(params)

	var image := _get_current_image()
	if image == null:
		return {"success": false, "error": "No active pixel cel"}

	var img_w := image.get_width()
	var img_h := image.get_height()
	var pixel_count := 0

	if filled:
		for py in range(cy - ry, cy + ry + 1):
			if py < 0 or py >= img_h:
				continue
			for px in range(cx - rx, cx + rx + 1):
				if px < 0 or px >= img_w:
					continue
				var nx: float = float(px - cx) / float(rx) if rx > 0 else 0.0
				var ny: float = float(py - cy) / float(ry) if ry > 0 else 0.0
				if nx * nx + ny * ny <= 1.0:
					image.set_pixel(px, py, color)
					pixel_count += 1
	else:
		# Draw outline using parametric approach with enough steps for clean pixels
		var steps := maxi(maxi(rx, ry) * 8, 32)
		for i in range(steps):
			var angle := (float(i) / float(steps)) * TAU
			var px := cx + roundi(float(rx) * cos(angle))
			var py := cy + roundi(float(ry) * sin(angle))
			if px >= 0 and px < img_w and py >= 0 and py < img_h:
				image.set_pixel(px, py, color)
				pixel_count += 1

	_commit_image_change(image, "Draw Ellipse")
	return {"success": true, "data": {"cx": cx, "cy": cy, "rx": rx, "ry": ry, "filled": filled, "pixels": pixel_count}}


func _cmd_fill_area(params: Dictionary) -> Dictionary:
	var x: int = params.get("x", 0)
	var y: int = params.get("y", 0)
	var color := _parse_color(params)

	var image := _get_current_image()
	if image == null:
		return {"success": false, "error": "No active pixel cel"}

	var w := image.get_width()
	var h := image.get_height()

	if x < 0 or x >= w or y < 0 or y >= h:
		return {"success": false, "error": "Seed point (%d, %d) out of bounds (%dx%d)" % [x, y, w, h]}

	var target_color := image.get_pixel(x, y)
	if target_color.is_equal_approx(color):
		return {"success": true, "data": {"message": "Fill color same as target, no change", "pixels_filled": 0}}

	# Scanline flood fill — much faster than naive stack-based approach
	# and avoids the visited-dict key collision bug
	var filled_count := 0
	var stack: Array[Vector2i] = [Vector2i(x, y)]
	# Use a flat boolean array for visited tracking (no hash collisions)
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
			# Add pixels above and below to stack
			if py > 0:
				var up_idx: int = (py - 1) * w + fill_x
				if visited[up_idx] == 0:
					stack.append(Vector2i(fill_x, py - 1))
			if py < h - 1:
				var down_idx: int = (py + 1) * w + fill_x
				if visited[down_idx] == 0:
					stack.append(Vector2i(fill_x, py + 1))

	_commit_image_change(image, "Fill Area")
	return {"success": true, "data": {"x": x, "y": y, "pixels_filled": filled_count}}


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

	# Build a deep copy of the source frame's images into a new frame
	var src_frame = project.frames[src_index]
	var new_cels: Array = []
	for i in range(src_frame.cels.size()):
		var cel = src_frame.cels[i]
		if cel.get_class_name() == "PixelCel":
			var new_image := Image.create(int(project.size.x), int(project.size.y), false, Image.FORMAT_RGBA8)
			new_image.blit_rect(cel.get_image(), Rect2i(0, 0, int(project.size.x), int(project.size.y)), Vector2i.ZERO)
			new_cels.append(cel.get_script().new(new_image))
		else:
			var layer = project.layers[i]
			if layer.has_method("new_empty_cel"):
				new_cels.append(layer.new_empty_cel())
			else:
				new_cels.append(cel.get_script().new())

	var new_frame = Frame.new(new_cels, src_frame.duration)
	var insert_at := src_index + 1
	project.add_frames([new_frame], PackedInt32Array([insert_at]))
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
	if cel.get_class_name() != "PixelCel":
		return {"success": false, "error": "Target cel is not a PixelCel"}

	var image: Image = cel.get_image()
	image.fill(Color.TRANSPARENT)
	_api.project.set_pixelcel_image(image, frame_index, layer_index)
	return {"success": true, "data": {"frame": frame_index, "layer": layer_index}}


func _cmd_export_animation(params: Dictionary) -> Dictionary:
	var project = _api.project.current_project
	if project == null:
		return {"success": false, "error": "No active project"}

	var dir_path: String = params.get("path", "")
	if dir_path.is_empty():
		return {"success": false, "error": "Missing 'path' directory parameter"}

	var prefix: String = params.get("prefix", "frame")
	var mode: String = params.get("mode", "frames")  # "frames" or "spritesheet"
	var drawing_algos = _api.general.get_drawing_algos()
	var w := int(project.size.x)
	var h := int(project.size.y)
	var exported: Array = []

	if mode == "spritesheet":
		var cols: int = params.get("columns", project.frames.size())
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
			return {"success": false, "error": "Failed to save spritesheet: %s" % error_string(err)}
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
