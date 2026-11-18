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
	if not super(action):  # structural check first
		return false
	
	#if not turn_manager.is_current_player(action.player_id):
		#return false
	
	#if action is EndTurnAction:
		#return true
	
	return true


func execute_action(action: GameAction) -> void:
	super(action)
