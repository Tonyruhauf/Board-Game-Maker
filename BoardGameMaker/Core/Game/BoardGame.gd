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
				_on_requested_action_validated(action)


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
	if not is_hosting_match():
		SupabaseRealtime.send_broadcast(
			get_match_room(),
			"request_game_action",
			{"action": var_to_bytes_with_objects(action) as Array}
		)
		return false
	
	if not validate_action(action):
		return false
	
	_on_requested_action_validated(action)
	
	if not hotseat_mode:
		SupabaseRealtime.send_broadcast(
			get_match_room(),
			"execute_action",
			{"action": var_to_bytes_with_objects(action) as Array}
		)
	
	return true


func _on_requested_action_validated(action: GameAction) -> void:
	execute_action(action)
	emit_action_event(action)


func validate_action(action: GameAction) -> bool:
	return false


func execute_action(action: GameAction) -> void:
	pass


func emit_action_event(action: GameAction) -> void:
	pass
