class_name BoardGame extends RefCounted


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


func _on_object_released(object: BoardObject) -> void:
	var action: GameAction
	
	# Adding to Hand
	var hand: Hand = GameService.board.hand
	if hand.is_focused() and hand.can_accept(object):
		action = AddObjectToHandAction.new(
			GameService.local_player.ID,
			object.id,
			hand.id
		)
		if request_action(action): return
	
	# Stacking
	if object is StackableBoardObject:
		var stack_candidate: StackableBoardObject = object.stack_candidate
		if stack_candidate:
			if object.can_stack(stack_candidate):
				action = StackWithObjectAction.new(
					GameService.local_player.ID,
					object.id,
					stack_candidate.id
				)
				if request_action(action): return
	
	# Moving
	action = MoveObjectAction.new(
		GameService.local_player.ID,
		object.id,
		object.global_position
	)
	if request_action(action): return
	
	# Rejected: fall back
	object.return_to_origin()


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
	
	elif action is StackWithObjectAction:
		return true
	
	elif action is TakeFromStackAction:
		return true
	
	elif action is AddObjectToHandAction:
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
			object.original_pos = action.new_pos
	
	elif action is FlipCardAction:
		var card: Card = GameService.get_object(action.card_id)
		if card:
			card._flip(action.new_side)
	
	elif action is StackWithObjectAction:
		var first_object: StackableBoardObject =\
			GameService.get_object(action.first_object_id)
		var second_object:StackableBoardObject =\
			GameService.get_object(action.second_object_id)
		
		if first_object:
			first_object._stack_with(second_object)
	
	elif action is TakeFromStackAction:
		var stack: BoardObjectStack = GameService.get_object(action.stack_id)
		stack._pickup_objects(action.take_amount)
	
	elif action is AddObjectToHandAction:
		var hand: Hand = GameService.get_object(action.hand_id)
		var object: BoardObject = GameService.get_object(action.object_id)
		if hand and object:
			hand.try_accept(object, action.index)
