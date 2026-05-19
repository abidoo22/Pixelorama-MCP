extends SceneTree

func _init():
	var pck_path = "/home/abido/Downloads/Pixelorama-Linux-64bit/Pixelorama.pck"
	var success = ProjectSettings.load_resource_pack(pck_path)
	if not success:
		print("Failed to load PCK")
		quit(1)
		return
	
	var src_file = "res://src/HandleExtensions.gdc"
	var dest_file = "/home/abido/Downloads/pix-MCP/HandleExtensions.gdc"
	
	var file = FileAccess.open(src_file, FileAccess.READ)
	if not file:
		print("Failed to open source file: ", src_file)
		quit(1)
		return
		
	var data = file.get_buffer(file.get_length())
	file.close()
	
	var out = FileAccess.open(dest_file, FileAccess.WRITE)
	if not out:
		print("Failed to open destination file: ", dest_file)
		quit(1)
		return
		
	out.store_buffer(data)
	out.close()
	
	print("Successfully copied HandleExtensions.gdc to ", dest_file)
	quit(0)
