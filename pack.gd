extends SceneTree

func _init():
	var packer = PCKPacker.new()
	var err = packer.pck_start("PixMcpBridge.pck")
	if err != OK:
		print("Error starting PCK: %s" % err)
		quit(1)
		return

	var prefix = "res://src/Extensions/PixMcpBridge/"
	var plugin_dir = "pixelorama-plugin/"
	if not FileAccess.file_exists(plugin_dir + "extension.json"):
		if FileAccess.file_exists("res://pixelorama-plugin/extension.json"):
			plugin_dir = "res://pixelorama-plugin/"

	packer.add_file(prefix + "extension.json", plugin_dir + "extension.json")
	packer.add_file(prefix + "Main.tscn", plugin_dir + "Main.tscn")
	packer.add_file(prefix + "Main.gd", plugin_dir + "Main.gd")
	packer.add_file(prefix + "command_handler.gd", plugin_dir + "command_handler.gd")

	# Package GIF exporter shaders to fix root/relative load resolution in Godot 4
	var similar_shader = "pixelorama-source/addons/gdgifexporter/lookup_similar.gdshader"
	var color_shader = "pixelorama-source/addons/gdgifexporter/lookup_color.gdshader"
	if FileAccess.file_exists(similar_shader):
		packer.add_file("res://lookup_similar.gdshader", similar_shader)
		packer.add_file("res://addons/gdgifexporter/lookup_similar.gdshader", similar_shader)
	if FileAccess.file_exists(color_shader):
		packer.add_file("res://lookup_color.gdshader", color_shader)
		packer.add_file("res://addons/gdgifexporter/lookup_color.gdshader", color_shader)
	if FileAccess.file_exists(plugin_dir + "converter.gd"):
		packer.add_file("res://addons/gdgifexporter/converter.gd", plugin_dir + "converter.gd")

	err = packer.flush(true)
	if err != OK:
		print("Error flushing PCK: %s" % err)
		quit(1)
		return

	print("Successfully packed PixMcpBridge.pck")

	# Also copy to pixelorama-plugin/PixMcpBridge.pck
	var src = FileAccess.open("PixMcpBridge.pck", FileAccess.READ)
	if src:
		var bytes = src.get_buffer(src.get_length())
		src.close()
		var dst = FileAccess.open("pixelorama-plugin/PixMcpBridge.pck", FileAccess.WRITE)
		if dst:
			dst.store_buffer(bytes)
			dst.close()
			print("Copied to pixelorama-plugin/PixMcpBridge.pck")

	quit(0)
