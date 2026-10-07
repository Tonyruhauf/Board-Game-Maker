class_name GameState extends Resource


@export var players: Array[Player]


func get_player(ID: int) -> Player:
	for player in players:
		if player.ID == ID:
			return player
	return null
