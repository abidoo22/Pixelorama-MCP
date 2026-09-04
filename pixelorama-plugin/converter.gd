extends RefCounted

var _shader: Shader


func get_indexed_datas(image: Image, colors: Array) -> PackedByteArray:
	_shader = _get_shader("res://lookup_color.gdshader", "res://addons/gdgifexporter/lookup_color.gdshader")
	var res = _convert_gpu(image, colors)
	if res.is_empty():
		res = _convert_cpu(image, colors)
	return res


func get_similar_indexed_datas(image: Image, colors: Array) -> PackedByteArray:
	_shader = _get_shader("res://lookup_similar.gdshader", "res://addons/gdgifexporter/lookup_similar.gdshader")
	var res = _convert_gpu(image, colors)
	if res.is_empty():
		res = _convert_cpu(image, colors)
	return res


func _get_shader(path1: String, path2: String) -> Shader:
	if ResourceLoader.exists(path1):
		return load(path1) as Shader
	if ResourceLoader.exists(path2):
		return load(path2) as Shader
	return null


func _convert_gpu(image: Image, colors: Array) -> PackedByteArray:
	if _shader == null or DisplayServer.get_name() == "headless":
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
	RenderingServer.canvas_item_add_texture_rect(
		ci_rid, Rect2(Vector2.ZERO, image.get_size()), texture
	)

	var mat_rid := RenderingServer.material_create()
	RenderingServer.material_set_shader(mat_rid, _shader.get_rid())
	var lut := Image.create(256, 1, false, Image.FORMAT_RGB8)
	lut.fill(Color8(colors[0][0], colors[0][1], colors[0][2]))
	for i in colors.size():
		lut.set_pixel(i, 0, Color8(colors[i][0], colors[i][1], colors[i][2]))
	var lut_tex := ImageTexture.create_from_image(lut)
	RenderingServer.material_set_param(mat_rid, "lut", [lut_tex])
	RenderingServer.canvas_item_set_material(ci_rid, mat_rid)

	RenderingServer.viewport_set_update_mode(vp, RenderingServer.VIEWPORT_UPDATE_ONCE)
	RenderingServer.force_draw(false)
	var rendered_img = RenderingServer.texture_2d_get(RenderingServer.viewport_get_texture(vp))

	RenderingServer.free_rid(vp)
	RenderingServer.free_rid(canvas)
	RenderingServer.free_rid(ci_rid)
	RenderingServer.free_rid(mat_rid)

	if rendered_img != null and not rendered_img.is_empty():
		rendered_img.convert(Image.FORMAT_R8)
		return rendered_img.get_data()

	return PackedByteArray()


func _convert_cpu(image: Image, colors: Array) -> PackedByteArray:
	var w = image.get_width()
	var h = image.get_height()
	var data: PackedByteArray = image.get_data()
	var result: PackedByteArray = PackedByteArray()
	result.resize(w * h)

	var cache: Dictionary = {} # (r << 16) | (g << 8) | b -> index
	var colors_size = colors.size()
	var out_idx = 0

	for i in range(0, data.size(), 4):
		var a = data[i + 3]
		if a == 0:
			result[out_idx] = 0
			out_idx += 1
			continue

		var r = data[i]
		var g = data[i + 1]
		var b = data[i + 2]
		var key = (r << 16) | (g << 8) | b
		var cached_idx = cache.get(key, -1)
		if cached_idx != -1:
			result[out_idx] = cached_idx
		else:
			var best_idx = 0
			var best_dist = 99999999
			for ci in range(colors_size):
				var dr = r - colors[ci][0]
				var dg = g - colors[ci][1]
				var db = b - colors[ci][2]
				var dist = dr * dr + dg * dg + db * db
				if dist < best_dist:
					best_dist = dist
					best_idx = ci
					if dist == 0:
						break
			cache[key] = best_idx
			result[out_idx] = best_idx
		out_idx += 1

	return result
