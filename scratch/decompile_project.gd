extends SceneTree

func _init():
	var pck_path = "/home/abido/Downloads/Pixelorama-Linux-64bit/Pixelorama.pck"
	var success = ProjectSettings.load_resource_pack(pck_path)
	if not success:
		print("Failed to load PCK")
		quit(1)
		return
	
	print("Loading Project class...")
	var script = load("res://src/Classes/Project.gd")
	if not script:
		print("Failed to load Project script!")
		quit(1)
		return
		
	print("Project script loaded successfully!")
	print("--- METHODS ---")
	for method in script.get_script_method_list():
		if "update" in method.name.to_lower() or "canvas" in method.name.to_lower() or "change" in method.name.to_lower() or "texture" in method.name.to_lower() or "cel" in method.name.to_lower() or "image" in method.name.to_lower():
			print(method.name)
		
	quit(0)
