extends Control


@onready var label: Label = $Label


func _ready() -> void:
	var turn_manager: TurnManager = GameService.game.turn_manager
	turn_manager.active_players_changed.connect(_on_active_players_changed)
	
	if turn_manager.current_player:
		_on_active_players_changed(turn_manager.active_players)


func _on_active_players_changed(players: Array[Player]) -> void:
	if players.size() == 1:
		label.text = "%s's Turn" % players[0].username
	else:
		label.text = ""
		for i in range(players.size()):
			var player: Player = players[i]
			if i != 0 and i < players.size() - 1:
				if i == players.size() - 2:
					label.text += " and "
				else:
					label.text += ", "
			label.text += player.username
		
		label.text += " Turn"
