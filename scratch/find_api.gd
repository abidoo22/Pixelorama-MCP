extends SceneTree

func _init():
	var pck_path = "/home/abido/Downloads/Pixelorama-Linux-64bit/Pixelorama.pck"
	var success = ProjectSettings.load_resource_pack(pck_path)
	if not success:
		print("Failed to load PCK: ", pck_path)
		quit(1)
		return
	
	print("PCK loaded successfully!")
	var files = []
	scan_dir("res://", files)
	print("Found ", files.size(), " files in PCK.")
	
	# Let's search inside all gd scripts for the definition of set_pixelcel_image
	var target_phrase = "set_pixelcel_image"
	var found_files = []
	for f in files:
		if f.ends_with(".gd"):
			var file = FileAccess.open(f, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				if target_phrase in content:
					print("Found set_pixelcel_image in: ", f)
					found_files.append(f)
					
	for f in found_files:
		var file = FileAccess.open(f, FileAccess.READ)
		if file:
			print("=== CONTENT OF ", f, " ===")
			var content = file.get_as_text()
			# Print lines around set_pixelcel_image
			var lines = content.split("\n")
			for i in range(lines.size()):
				if target_phrase in lines[i]:
					var start = max(0, i - 15)
					var end = min(lines.size() - 1, i + 15)
					for j in range(start, end + 1):
						print(j + 1, ": ", lines[j])
			print("-----------------------------------")
			
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
