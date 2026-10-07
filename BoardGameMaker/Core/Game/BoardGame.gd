class_name BoardGame extends Node


var turn_manager: TurnManager = TurnManager.new()
var game_state: GameState = GameState.new()
var session_state: GameSession.SessionState


func setup() -> void:
	pass


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
	return false


func execute_action(action: GameAction) -> void:
	pass


func emit_action_event(action) -> void:
	pass
