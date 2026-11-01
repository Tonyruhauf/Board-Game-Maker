class_name GameAction extends Resource
## A base class representing any game action (ending turn, placing a card, picking a card, etc...).
##[br][br]
##IMPORTANT: Every variable should have the "@exported" prefix.

@export var ID: int = ResourceUID.create_id()

@export var player_id: String


func _init(_player_id: String = "") -> void:
	player_id = _player_id
