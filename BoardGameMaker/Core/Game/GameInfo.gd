class_name GameInfo extends Resource	


@export var game_scene: PackedScene

@export_multiline() var name: String
@export_multiline() var description: String
@export var thumbnail: Texture2D

@export var min_players: int
@export var max_players: int
