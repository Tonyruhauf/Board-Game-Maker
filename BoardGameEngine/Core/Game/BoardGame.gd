class_name BoardGame extends RefCounted


var turn_manager: TurnManager = TurnManager.new()
var match_state: MatchState
var game_state: GameState

enum GameMode {
	SINGLEPLAYER,
	HOTSEAT,
	LAN,
	ONLINE
}

var game_mode: GameMode = GameMode.SINGLEPLAYER

signal setup_finished


func setup(_match_state: MatchState) -> void:
	match_state = _match_state

	turn_manager.players = match_state.joined_players

	_create_game_state()

	setup_finished.emit()


func get_match_room() -> String:
	return "match-game-%s" % match_state.match_id


func is_game_mode(mode: GameMode) -> bool:
	return game_mode == mode


func is_hosting_match() -> bool:
	if is_game_mode(GameMode.HOTSEAT): return true
	return match_state.host_id == GameService.local_player.ID


func _create_game_state() -> void:
	game_state = GameState.new()


func start() -> void:
	if game_state.players.is_empty(): return
	
	start_first_turn()


func end() -> void:
	pass


func reset() -> void:
	pass


func start_first_turn() -> void:
	await turn_manager.start_turn(turn_manager.players[0])
	_update_local_player()


func end_turn() -> void:
	await turn_manager.end_turn()
	_update_local_player()


func _update_local_player() -> void:
	if is_game_mode(GameMode.HOTSEAT):
		GameService.set_local_player(turn_manager.current_player)


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
	
	# Adding to Bag
	var hovered_obj: BoardObject = GameService.get_hovered_object()
	if hovered_obj and hovered_obj is Bag:
		if hovered_obj.try_adding_object(object): return
	
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
		false,
		object.global_position
	)
	if request_action(action): return
	
	# Rejected: fall back
	object.return_to_origin()


func request_action(action: GameAction) -> bool:
	if not validate_action(action):
		return false
	
	execute_action(action)
	return true


func validate_action(action: GameAction) -> bool:
	if not turn_manager.is_current_player(action.player_id):
		return false
	
	if action is MoveObjectAction:
		return true
	
	elif action is RotateObjectAction:
		return true
	
	elif action is FlipCardAction:
		return true
	
	elif action is StackWithObjectAction:
		return true
	
	elif action is TakeFromStackAction:
		return true
	
	elif action is TakeFromBagAction:
		return true
	
	elif action is AddObjectToHandAction:
		return true
	
	elif action is AddObjectToBagAction:
		return true
	
	elif action is RollDieAction:
		return true
	
	elif action is FlipDieAction:
		return true
	
	elif action is FlipStackAction:
		return true
	
	return false


func execute_action(action: GameAction) -> void:
	if not action.default_behavior_prevented:
		_execute_default_action(action)
	
	EventBus.emit_action_event(action)


func _execute_default_action(action) -> void:
	if action is EndTurnAction:
		end_turn()
	
	elif action is MoveObjectAction:
		if not action.is_drag_start:
			var object: BoardObject = GameService.get_object(action.object_id)
			if object:
				object.global_position = action.new_pos
				object.original_pos = action.new_pos
	
	elif action is RotateObjectAction:
		if not action.is_rotation_starting:
			var object: BoardObject = GameService.get_object(action.object_id)
			if object:
				object._set_visual_rotation(action.new_rotation)
	
	elif action is FlipCardAction:
		var card: Card = GameService.get_object(action.card_id)
		if card:
			card._flip(true, action.new_side)
	
	elif action is StackWithObjectAction:
		var first_object: StackableBoardObject =\
			GameService.get_object(action.first_object_id)
		var second_object:StackableBoardObject =\
			GameService.get_object(action.second_object_id)
		
		if first_object:
			first_object._stack_with(second_object)
	
	elif action is TakeFromStackAction:
		var stack: BoardObjectStack = GameService.get_object(action.stack_id)
		if stack:
			stack._pickup_objects(action.take_amount)
	
	elif action is TakeFromBagAction:
		var bag: Bag = GameService.get_object(action.bag_id)
		if bag:
			bag._pickup_object()
	
	elif action is AddObjectToHandAction:
		var hand: Hand = GameService.get_object(action.hand_id)
		var object: BoardObject = GameService.get_object(action.object_id)
		if hand and object:
			hand.try_accept(object, action.index)
	
	elif action is AddObjectToBagAction:
		var bag: Bag = GameService.get_object(action.bag_id)
		var object: BoardObject = GameService.get_object(action.object_id)
		if bag and object:
			bag._add_object(object)
	
	elif action is RollDieAction:
		var die: Die = GameService.get_object(action.die_id)
		if die:
			die.roll()
	
	elif action is FlipDieAction:
		var die: Die = GameService.get_object(action.die_id)
		if die:
			die.flip_side()
	
	elif action is FlipStackAction:
		var stack: BoardObjectStack = GameService.get_object(action.stack_id)
		if stack:
			stack._flip()
