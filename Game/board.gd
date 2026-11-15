class_name TestGame extends BoardGame


var state: TestGameState:
	get(): return game_state as TestGameState


func _create_game_state() -> void:
	game_state = TestGameState.new()


func start() -> void:
	if turn_manager.players.is_empty(): return
	
	start_first_turn()


func end() -> void:
	pass


func reset() -> void:
	pass


func validate_action(action: GameAction) -> bool:
	#if not turn_manager.is_current_player(action.player_id):
		#return false
	
	if action is EndTurnAction:
		return true
	
	if action is StartMovingObjectAction:
		return true
	
	if action is MoveObjectAction:
		return true
	
	return false


func execute_action(action: GameAction) -> void:
	if action is EndTurnAction:
		turn_manager.end_turn()
	
	EventBus.emit_action_event(action)
