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
	
	var target = "set_pixelcel_image".to_utf8_buffer()
	print("Searching for set_pixelcel_image in GDC files...")
	for f in files:
		if f.ends_with(".gdc"):
			var file = FileAccess.open(f, FileAccess.READ)
			if file:
				var bytes = file.get_buffer(file.get_length())
				if find_bytes(bytes, target) != -1:
					print("Found in GDC: ", f)
					
	quit(0)

func find_bytes(source: PackedByteArray, target: PackedByteArray) -> int:
	if target.size() > source.size():
		return -1
	for i in range(source.size() - target.size() + 1):
		var found = true
		for j in range(target.size()):
			if source[i + j] != target[j]:
				found = false
				break
		if found:
			return i
	return -1

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
