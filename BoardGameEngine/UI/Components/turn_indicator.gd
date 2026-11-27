extends Control


@onready var label: Label = $Label


func _ready() -> void:
	var turn_manager: TurnManager = GameService.game.turn_manager
	turn_manager.active_players_changed.connect(_on_active_players_changed)
	
	if not turn_manager.active_players.is_empty():
		_on_active_players_changed(turn_manager.active_players)


func _input(event: InputEvent) -> void:
	if event.is_action("show_hidden_ui"): # show_match_info?
		label.visible = event.is_pressed()


func _on_active_players_changed(players: Array[Player]) -> void:
	if players.size() == 1:
		label.text = "%s's Turn" % players[0].username
	else:
		label.text = ""
		for i in range(players.size()):
			var player: Player = players[i]
			if i != 0:
				if i == players.size() - 1:
					label.text += " and "
				else:
					label.text += ", "
			label.text += player.username
		
		label.text += " Turn"
	
	label.show()
	await get_tree().create_timer(1.2 * players.size()).timeout
	label.hide()
