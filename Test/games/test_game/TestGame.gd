class_name TestGame extends BoardGame


func start() -> void:
	if game_state.players.is_empty(): return
	
	turn_manager.players = game_state.players
	start_first_turn()


func end() -> void:
	pass


func reset() -> void:
	pass


func start_first_turn() -> void:
	turn_manager.start_turn(game_state.players[0])


func request_action(action: GameAction) -> bool:
	if not validate_action(action):
		return false
	
	execute_action(action)
	emit_action_event(action)
	return true


func validate_action(action: GameAction) -> bool:
	if not turn_manager.is_current_player(action.player_id):
		return false
	
	if action is EndTurnAction:
		return true
	
	elif action is AddScoreAction:
		return true
	
	return false


func execute_action(action: GameAction) -> void:
	if action is EndTurnAction:
		turn_manager.end_turn()
	
	elif action is AddScoreAction:
		var player: Player = game_state.get_player(action.player_id)
		player.score += action.value


func emit_action_event(action: GameAction) -> void:
	if action is EndTurnAction:
		EventsBus.send_event(TurnEndedEvent.new())
	
	elif action is AddScoreAction:
		EventsBus.send_event(PlayerScoredEvent.new(action.player_id))


func _on_next_turn_button_pressed() -> void:
	request_action(EndTurnAction.new(local_player.ID))


func _on_score_button_pressed() -> void:
	request_action(AddScoreAction.new(local_player.ID, 10))
