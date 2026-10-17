class_name MatchState extends RefCounted


@export var match_id: String
@export var joined_players: Array[String]
@export var invited_players: Array[String]

enum SessionState {
	WAITING,
	RUNNING,
	ENDED
}


func to_dict() -> Dictionary:
	var base: Dictionary = {
		"match_id": match_id,
		"joined_players": joined_players,
		"invited_players": invited_players
	}
	
	return base


static func from_dict(data: Dictionary) -> MatchState:
	var instance: MatchState = MatchState.new()
	
	instance.match_id = data.get("match_id", "")
	instance.joined_players.assign(data.get("joined_players", []))
	instance.invited_players.assign(data.get("invited_players", []))
	
	return instance
