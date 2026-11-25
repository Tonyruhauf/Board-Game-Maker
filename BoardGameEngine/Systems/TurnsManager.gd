class_name TurnManager extends RefCounted


var players: Array[String]
var current_player: Player


func start_turn(player_id: String) -> void:
	current_player = await GameService.get_player(player_id)


func end_turn() -> void:
	if players.is_empty() or current_player == null:
		return

	var current_index: int = players.find(current_player.ID)
	if current_index == -1:
		return

	var next_index: int = (current_index + 1) % players.size()
	await start_turn(players[next_index])


func is_current_player(player_id: String) -> bool:
	return current_player != null and player_id == current_player.ID
