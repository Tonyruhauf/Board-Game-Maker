class_name GameInfo extends Resource	


@export var game_scene: PackedScene
@export var game_state_class: GDScript

@export_multiline() var name: String
@export_multiline() var description: String
@export var thumbnail: Texture2D

@export var min_players: int
@export var max_players: int


func to_dict() -> Dictionary:
	return {
		"game_scene": game_scene.resource_path if game_scene != null else "",
		"game_state_class": game_state_class.resource_path if game_state_class != null else "",
		"name": name,
		"description": description,
		"thumbnail": thumbnail.resource_path if thumbnail != null else "",
		"min_players": min_players,
		"max_players": max_players
	}


static func from_dict(data: Dictionary) -> GameInfo:
	var instance: GameInfo = GameInfo.new()
	
	var scene_path = data.get("game_scene", "")
	instance.game_scene = load(scene_path) if scene_path != "" else null
	
	var state_path = data.get("game_state_class", "")
	instance.game_state_class = load(state_path) if state_path != "" else null
	
	var thumb_path = data.get("thumbnail", "")
	instance.thumbnail = load(thumb_path) if thumb_path != "" else null
	
	instance.name = data.get("name", "")
	instance.description = data.get("description", "")
	instance.min_players = data.get("min_players", 0)
	instance.max_players = data.get("max_players", 0)
	
	return instance
