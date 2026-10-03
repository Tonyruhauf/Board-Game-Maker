@tool
extends EditorPlugin

var hub_path := "C:/Users/georg/Documents/GodotProjects/⭐⭐ Scripts et Fonctionnalités Utiles ⭐⭐/Useful-Scripts-and-Godot-Modules/Modules/"
var import_dialog

func _enter_tree():
	# Add menu item in "Project" menu
	add_tool_menu_item("Import Module", _show_import_dialog)

func _exit_tree():
	remove_tool_menu_item("Import Module")

func _show_import_dialog():
	if not import_dialog:
		import_dialog = preload("res://addons/module_importer/ui/module_import_dialog.tscn").instantiate()
		get_editor_interface().get_base_control().add_child(import_dialog)
		import_dialog.connect("module_selected", _import_module)
	import_dialog.popup_centered()

func _import_module(module_name: String):
	var src := hub_path + module_name
	var dst := "res://modules/" + module_name

	if DirAccess.dir_exists_absolute(dst):
		push_error("Module already exists: " + module_name)
		return
	
	if DirAccess.dir_exists_absolute(src):
		_copy_dir(src, dst)
	elif FileAccess.file_exists(src):
		DirAccess.copy_absolute(src, dst)
	
	get_editor_interface().get_resource_filesystem().scan()
	
	print("✅ Imported module: " + module_name)

func _copy_dir(src: String, dst: String):
	var dir := DirAccess.open(src)
	if not dir:
		push_error("Could not open hub path: " + src)
		return
	DirAccess.make_dir_recursive_absolute(dst)

	for file_name in dir.get_files():
		DirAccess.copy_absolute(src + "/" + file_name, dst + "/" + file_name)

	for subdir_name in dir.get_directories():
		_copy_dir(src + "/" + subdir_name, dst + "/" + subdir_name)
