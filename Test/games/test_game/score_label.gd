extends Label


var board_game: TestGame


func _ready() -> void:
	board_game = owner
	board_game.setup_finished.connect(_update_display)
	
	EventsBus.connect_event(PlayerScoredEvent, _on_player_scored)
	
	_update_display()


func _on_player_scored(_event: PlayerScoredEvent):
	_update_display()


func _update_display():
	text = ""
	
	for player_id in board_game.turn_manager.players:
		var player: Player = await GameService.get_player(player_id)
		var score: int = board_game.game_state.get_player_score(player.ID)
		text += "%s: %d points\n" % [player.username, score]
