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
