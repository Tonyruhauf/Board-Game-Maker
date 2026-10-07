extends Label


var board_game: TestGame


func _ready() -> void:
	board_game = owner
	await board_game.game_ready
	
	EventsBus.connect_event(PlayerScoredEvent, _on_player_scored)
	
	_update_display()


func _on_player_scored(_event: PlayerScoredEvent):
	_update_display()


func _update_display():
	text = ""
	
	for player in board_game.game_state.players:
		var score: int = board_game.game_state.get_player_score(player.ID)
		text += "%s: %d points\n" % [player.name, score]
