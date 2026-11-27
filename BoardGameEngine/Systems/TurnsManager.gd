class_name TurnManager extends RefCounted


var players: Array[String]
var active_players: Array[Player]
var finished_players: Array[String]

signal active_players_changed(players: Array[Player])
signal turn_finished


func start_turn(player_ids: Array[String]) -> void:
	if GameService.game.is_game_mode(BoardGame.GameMode.HOTSEAT):
		assert(
			player_ids.size() == 1,
			"Hotseat mode requires exactly one active player."
		)
	
	active_players.clear()
	finished_players.clear()
	
	for player_id in player_ids:
		var player: Player = GameService.get_player(player_id)
		if player:
			active_players.append(player)
	
	active_players_changed.emit(active_players)


func finish_player_turn(player_id: String) -> void:
	if not is_player_active(player_id):
		return
	
	if finished_players.has(player_id):
		return
	
	finished_players.append(player_id)
	
	if finished_players.size() == active_players.size():
		# All active players have finished.
		# The game can now advance to the next turn.
		turn_finished.emit()


func is_player_active(player_id: String) -> bool:
	for player in active_players:
		if player.ID == player_id:
			return true

	return false
