extends SceneTree

func _init():
	var pck_path = "/home/abido/Downloads/Pixelorama-Linux-64bit/Pixelorama.pck"
	var success = ProjectSettings.load_resource_pack(pck_path)
	if not success:
		print("Failed to load PCK: ", pck_path)
		quit(1)
		return
	
	print("PCK loaded successfully!")
	
	# Let's find files in res:// that might handle extensions.
	var files = []
	scan_dir("res://", files)
	
	print("Found ", files.size(), " files in PCK.")
	
	# Let's search inside all gd scripts for the error string "Error loading extension"
	var target_phrase = "Error loading extension"
	var found_file = ""
	for f in files:
		if f.ends_with(".gd") and not "read_pck.gd" in f:
			var file = FileAccess.open(f, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				if target_phrase in content:
					print("Target phrase found in: ", f)
					found_file = f
					break
	
	if found_file != "":
		# Read and print the file content
		var file = FileAccess.open(found_file, FileAccess.READ)
		if file:
			print("--- CONTENT OF ", found_file, " ---")
			print(file.get_as_text())
			print("-----------------------------------")
	else:
		print("Target phrase not found in any GDScript.")
		# Print all GDC files
		for f in files:
			if f.ends_with(".gdc") and "extension" in f.to_lower():
				print("GDC file: ", f)
				
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
