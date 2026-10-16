extends PanelContainer


@onready var game_name: Label = $MarginContainer/VBoxContainer/GameName
@onready var sender: Label = $MarginContainer/VBoxContainer/Sender
@onready var accept_button: Button = $MarginContainer/VBoxContainer/AcceptButton


func popup(invite_data: Dictionary):
	#var invite_data: Dictionary = {
		#"sender": GameService.get_player_id(),
		#"recipient": found_user_profile.id,
		#"match_id": match_id
	#}
	
	var match_data = await GameService.get_match(invite_data.match_id)
	
	if not match_data.is_empty():
		var game_info: GameInfo = match_data.game_info
		game_name.text = game_info.name
		
		# TODO
