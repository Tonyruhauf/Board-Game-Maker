class_name TurnManager extends RefCounted


var players: Array[Player]
var current_player: Player


func start_turn(player: Player):
	current_player = player


func end_turn():
	var current_index: int = players.find(current_player)
	var next_index: int = (current_index + 1) % players.size()
	
	start_turn(players[next_index])
