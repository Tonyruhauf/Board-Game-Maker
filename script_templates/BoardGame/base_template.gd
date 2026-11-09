# meta-name: Base BoardGame Template
# meta-description: The recommended template when creating new classes extending BoardGame.
# meta-default: true
# meta-space-indent: 4
class_name _CLASS_ extends BoardGame


# TODO: You should create the _CLASS_State class, which should extends from GameState.
var state: _CLASS_State:
	get(): return game_state as _CLASS_State


func _create_game_state() -> void:
	game_state = _CLASS_State.new()


func start() -> void:
	if turn_manager.players.is_empty(): return
	
	start_first_turn()


func end() -> void:
	pass


func reset() -> void:
	pass


# This is a basic example of how you can validate actions.
# Feel free to replace it with your own validation logic.
func validate_action(action: GameAction) -> bool:
	# You probably want to keep this for turn based games.
	if not turn_manager.is_current_player(action.player_id):
		return false
	
	if action is EndTurnAction:
		return true
	
	return false


func execute_action(action: GameAction) -> void:
	# You probably want to keep this for turn based games.
	if action is EndTurnAction:
		turn_manager.end_turn()
	
	elif action is AddScoreAction: # Feel free to remove this example.
		state.increase_player_score(action.player_id, action.value)


# You should create an event for each game action, and emit it here.
func emit_action_event(action: GameAction) -> void:
	if action is EndTurnAction:
		EventsBus.send_event(TurnEndedEvent.new())
	
	elif action is AddScoreAction: # Feel free to remove this example.
		EventsBus.send_event(PlayerScoredEvent.new(action.player_id))


# --| Examples of game-specific logic. |--
# You can remove those.

func _on_next_turn_button_pressed() -> void:
	request_action(EndTurnAction.new(GameService.local_player.ID))


func _on_score_button_pressed() -> void:
	request_action(AddScoreAction.new(GameService.local_player.ID, 10))
