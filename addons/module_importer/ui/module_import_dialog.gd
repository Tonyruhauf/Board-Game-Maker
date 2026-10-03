@tool
extends Window


var hub_path := "C:/Users/georg/Documents/GodotProjects/⭐⭐ Scripts et Fonctionnalités Utiles ⭐⭐/Useful-Scripts-and-Godot-Modules/Modules/"

@onready var item_list: ItemList = $VBoxContainer/ItemList
@onready var import_button: Button = $VBoxContainer/HBoxContainer/ImportButton
@onready var cancel_button: Button = $VBoxContainer/HBoxContainer/CancelButton

signal module_selected(module_name: String)


func _ready() -> void:
	title = "Import Module"
	_populate_list()
	import_button.connect("pressed", _on_import_pressed)
	cancel_button.connect("pressed", _on_cancel_pressed)
	if !item_list.is_connected("item_clicked", _on_item_list_item_clicked):
		item_list.connect("item_clicked", _on_item_list_item_clicked)
	import_button.disabled = true


func _populate_list() -> void:
	item_list.clear()
	var dir := DirAccess.open(hub_path)
	if not dir:
		item_list.add_item("[ERROR] Hub path not found.")
		item_list.disabled = true
		return

	for module_name in dir.get_directories():
		item_list.add_item(module_name)
	
	for module_name in dir.get_files():
		item_list.add_item(module_name)


func _on_item_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_LEFT:
		import_button.disabled = false


func _on_import_pressed() -> void:
	var selected_index := item_list.get_selected_items()
	if selected_index.size() == 0:
		return
	var module_name := item_list.get_item_text(selected_index[0])
	module_selected.emit(module_name)
	hide()


func _on_cancel_pressed() -> void:
	hide()
