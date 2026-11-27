# meta-name: Base BoardGame Template
# meta-description: The recommended template when creating new classes extending BoardGame.
# meta-default: true
# meta-space-indent: 4
class_name _CLASS_ extends BoardGame


var state: _CLASS_State:
	get(): return game_state as _CLASS_State


func _create_game_state() -> void:
	game_state = _CLASS_State.new()


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


# This is a basic example of how to validate actions.
func validate_action(action: GameAction) -> bool:
	if not super(action):
		return false
	
	# You probably want to keep this for turn based games.
	if not turn_manager.is_player_active(action.player_id):
		return false
	
	if action is EndTurnAction:
		return your_condition
	
	return true


# This is a basic example of how to execute actions.
func execute_action(action: GameAction) -> void:
	if action is CustomAction:
		# Do something cool
	
	elif action is AddScoreAction:
		state.increase_player_score(action.player_id, action.value)
		action.prevent_default_behavior()
	
	super(action)


# --| Examples of buttons logic. |--
# You can remove those.

func _on_next_turn_button_pressed() -> void:
	request_action(EndTurnAction.new(GameService.local_player.ID))


func _on_score_button_pressed() -> void:
	request_action(AddScoreAction.new(GameService.local_player.ID, 10))
