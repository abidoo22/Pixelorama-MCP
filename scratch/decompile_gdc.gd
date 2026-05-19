extends SceneTree

func _init():
	var pck_path = "/home/abido/Downloads/Pixelorama-Linux-64bit/Pixelorama.pck"
	var success = ProjectSettings.load_resource_pack(pck_path)
	if not success:
		print("Failed to load PCK")
		quit(1)
		return
	
	var path = "res://src/Autoload/ExtensionsApi.gdc"
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("Failed to open GDC file: ", path)
		quit(1)
		return
		
	var bytes = file.get_buffer(file.get_length())
	print("GDC file size: ", bytes.size())
	
	# Extract all strings
	var strings = []
	var current_str = PackedByteArray()
	for b in bytes:
		if b >= 32 and b <= 126:
			current_str.append(b)
		else:
			if current_str.size() >= 3:
				var s = current_str.get_string_from_ascii()
				if s.is_valid_identifier() or "(" in s or "/" in s or "_" in s:
					strings.append(s)
			current_str.clear()
			
	print("Extracted strings from GDC:")
	var unique = []
	for s in strings:
		if not s in unique:
			unique.append(s)
			
	for s in unique:
		if "pixelcel" in s.to_lower() or "canvas" in s.to_lower() or "draw" in s.to_lower() or "image" in s.to_lower() or "update" in s.to_lower() or "refresh" in s.to_lower():
			print("  ", s)
			
	quit(0)
