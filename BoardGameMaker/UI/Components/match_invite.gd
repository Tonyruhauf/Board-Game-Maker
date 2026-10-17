extends PanelContainer


@onready var game_name: Label = $MarginContainer/VBoxContainer/GameName
@onready var sender: Label = $MarginContainer/VBoxContainer/Sender
@onready var accept_button: Button = $MarginContainer/VBoxContainer/AcceptButton

var Main: MainNode

var match_data: Dictionary
var sender_data: Dictionary


func popup(invite_data: Dictionary):
	#var invite_data: Dictionary = {
		#"sender": GameService.get_player_id(),
		#"recipient": found_user_profile.id,
		#"match_id": match_id
	#}
	
	match_data = await GameService.get_match(invite_data.match_id)
	sender_data = await GameService.get_player_profile(invite_data.sender)
	
	if not match_data.is_empty():
		var game_info: GameInfo = GameInfo.from_dict(match_data.game_info)
		game_name.text = game_info.name
	
	if not sender_data.is_empty():
		sender.text = sender_data.username
	
	show()


func _on_accept_button_pressed() -> void:
	hide()
	Main.join_match(match_data)
