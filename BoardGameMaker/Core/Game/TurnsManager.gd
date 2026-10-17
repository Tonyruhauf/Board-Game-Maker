class_name TurnManager extends RefCounted


var players: Array[String]
var current_player: Player


func start_turn(player_id: String):
	current_player = await GameService.get_player(player_id)


func end_turn():
	var current_index: int = players.find(current_player.ID)
	var next_index: int = (current_index + 1) % players.size()
	
	start_turn(players[next_index])


func is_current_player(player_ID: String) -> bool:
	return player_ID == current_player.ID
