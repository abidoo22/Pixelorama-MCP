extends SceneTree

func _init():
	var packer = PCKPacker.new()
	var err = packer.pck_start("PixMcpBridge.pck")
	if err != OK:
		print("Error starting PCK")
		quit(1)
		return

	var prefix = "res://src/Extensions/PixMcpBridge/"
	var plugin_dir = "pixelorama-plugin/"

	packer.add_file(prefix + "extension.json", plugin_dir + "extension.json")
	packer.add_file(prefix + "Main.tscn", plugin_dir + "Main.tscn")
	packer.add_file(prefix + "Main.gd", plugin_dir + "Main.gd")
	packer.add_file(prefix + "command_handler.gd", plugin_dir + "command_handler.gd")

	err = packer.flush(true)
	if err != OK:
		print("Error flushing PCK")
		quit(1)
		return

	print("Successfully packed PixMcpBridge.pck")
	quit(0)
