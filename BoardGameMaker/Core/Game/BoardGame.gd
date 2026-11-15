class_name BoardGame extends Node


var turn_manager: TurnManager = TurnManager.new()
var match_state: MatchState
var game_state: GameState

var hotseat_mode: bool = false

signal setup_finished


func setup(_match_state: MatchState) -> void:
	match_state = _match_state
	
	turn_manager.players = match_state.joined_players
	turn_manager.hotseat_mode = hotseat_mode
	
	if not hotseat_mode:
		SupabaseRealtime.connect_realtime(SupabaseManager.current_access_token)
		SupabaseRealtime.message_received.connect(_on_broadcast_message_received)
		
		SupabaseRealtime.join_channel(get_match_room(), false, true)
	
	_create_game_state()
	
	setup_finished.emit()


func get_match_room() -> String:
	return "match-game-%s" % match_state.match_id


func is_hosting_match() -> bool:
	if hotseat_mode: return true
	return match_state.host_id == GameService.local_player.ID


func _create_game_state() -> void:
	game_state = GameState.new()


func _on_broadcast_message_received(room: String, event: String, payload: Dictionary) -> void:
	if room != get_match_room(): return
	
	match event:
		"request_game_action":
			if is_hosting_match():
				var action: GameAction = bytes_to_var_with_objects(payload.action) as GameAction
				request_action(action)
		"execute_action":
			if not is_hosting_match():
				var action: GameAction = bytes_to_var_with_objects(payload.action) as GameAction
				execute_action(action)


func start() -> void:
	if game_state.players.is_empty(): return
	
	start_first_turn()


func end() -> void:
	pass


func reset() -> void:
	pass


func start_first_turn() -> void:
	turn_manager.start_turn(turn_manager.players[0])


func request_action(action: GameAction) -> bool:
	if not validate_action(action):
		return false
	
	execute_action(action)
	
	if not hotseat_mode:
		SupabaseRealtime.send_broadcast(
			get_match_room(),
			"execute_action",
			{"action": var_to_bytes_with_objects(action) as Array}
		)
	
	return true


func validate_action(action: GameAction) -> bool:
	if action is StartMovingObjectAction:
		return true
	
	elif action is MoveObjectAction:
		return true
	
	elif action is FlipCardAction:
		return true
	
	return false


func execute_action(action: GameAction) -> void:
	if not action.default_behavior_prevented:
		_execute_default_action(action)
	
	EventBus.emit_action_event(action)


func _execute_default_action(action) -> void:
	if action is EndTurnAction:
		turn_manager.end_turn()
	
	elif action is MoveObjectAction:
		var object: BoardObject = GameService.get_object(action.object_id)
		if object:
			object.global_position = action.new_pos
	
	elif action is FlipCardAction:
		var card: Card = GameService.get_object(action.card_id)
		if card:
			card._flip(action.new_side)
