extends Control


@onready var player_name_edit: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/Control/PlayerNameEdit
@onready var edit_name_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/CenterContainer/EditNameButton

var Main: MainNode
var is_editing: bool = false


func _ready() -> void:
	player_name_edit.text = Main.local_player.name


func _on_edit_name_button_pressed() -> void:
	if is_editing:
		_set_editing_mode(false)
		_apply_modifications()
	else:
		_set_editing_mode(true)


func _set_editing_mode(enabled: bool) -> void:
	is_editing = enabled
	
	if is_editing:
		edit_name_button.text = "✅"
	else:
		edit_name_button.text = "✏️"
	
	player_name_edit.flat = !enabled
	player_name_edit.editable = enabled


func _apply_modifications() -> void:
	Main.local_player.name = player_name_edit.text
