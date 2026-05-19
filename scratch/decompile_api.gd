extends SceneTree

func _init():
	var pck_path = "/home/abido/Downloads/Pixelorama-Linux-64bit/Pixelorama.pck"
	var success = ProjectSettings.load_resource_pack(pck_path)
	if not success:
		print("Failed to load PCK")
		quit(1)
		return
	
	print("Loading ExtensionsApi script...")
	var script = load("res://src/Autoload/ExtensionsApi.gd")
	if not script:
		print("Failed to load ExtensionsApi script!")
		quit(1)
		return
		
	print("ExtensionsApi script loaded successfully!")
	print("--- METHODS ---")
	for method in script.get_script_method_list():
		print(method.name, " -> ", method.args)
		
	print("--- PROPERTIES ---")
	for prop in script.get_script_property_list():
		print(prop.name, " (", prop.type, ")")
		
	quit(0)
