class_name TestGame extends BoardGame


var state: TestGameState:
	get(): return game_state as TestGameState


func _create_game_state() -> void:
	game_state = TestGameState.new()


func start() -> void:
	if turn_manager.players.is_empty(): return
	
	start_first_turn()


func start_first_turn() -> void:
	turn_manager.start_turn([turn_manager.players[0]]) # One player at a time.
	#turn_manager.start_turn(turn_manager.players) # All players play simultaneously.
	super()


func start_next_turn() -> void:
	# One player at a time.
	var current_player_id: String = turn_manager.active_players[0].ID
	var current_index: int = turn_manager.players.find(current_player_id)
	var next_index: int = (current_index + 1) % turn_manager.players.size()
	
	turn_manager.start_turn([turn_manager.players[next_index]])
	
	super()


func end() -> void:
	pass


func reset() -> void:
	pass


func validate_action(action: GameAction) -> bool:
	if not super(action):
		return false
	
	return true


func execute_action(action: GameAction) -> void:
	super(action)
