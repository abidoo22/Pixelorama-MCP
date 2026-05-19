extends SceneTree

func _init():
	var pck_path = "/home/abido/Downloads/Pixelorama-Linux-64bit/Pixelorama.pck"
	var success = ProjectSettings.load_resource_pack(pck_path)
	if not success:
		print("Failed to load PCK")
		quit(1)
		return
	
	var files = []
	scan_dir("res://", files)
	
	print("Files in PCK:")
	for f in files:
		print("  ", f)
					
	quit(0)

func scan_dir(path: String, files: Array):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					scan_dir(path + file_name + "/", files)
			else:
				files.append(path + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
