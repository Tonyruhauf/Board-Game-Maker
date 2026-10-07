class_name TestGameState extends GameState


@export var players_scores: Dictionary[int, int]


func set_player_score(player_id: int, value: int):
	players_scores[player_id] = value


func get_player_score(player_id: int) -> int:
	return players_scores.get(player_id, 0)


func increase_player_score(player_id: int, value: int):
	var existing_score: int = players_scores.get(player_id, 0)
	players_scores[player_id] = existing_score + value
