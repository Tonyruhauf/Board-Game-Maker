class_name MatchState extends RefCounted


@export var match_id: String
@export var host_id: String
@export var joined_players: Array[String]
@export var invited_players: Array[String]

enum SessionState {
	WAITING,
	RUNNING,
	ENDED
}


func to_dict() -> Dictionary:
	return {
		"id": match_id,
		"host_id": host_id,
		"joined_players": joined_players,
		"invited_players": invited_players
	}


static func from_dict(data: Dictionary) -> MatchState:
	var instance: MatchState = MatchState.new()

	# DB rows use "id" / "created_by"; broadcasts use "id" / "host_id"
	instance.match_id = str(data.get("id", data.get("match_id", "")))
	instance.host_id = str(data.get("created_by", data.get("host_id", "")))

	instance.joined_players.assign(data.get("joined_players", []))
	instance.invited_players.assign(data.get("invited_players", []))

	return instance
