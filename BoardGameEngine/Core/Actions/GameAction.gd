class_name GameAction extends Resource
## A base class representing any game action (ending turn, placing a card, drawing a card, etc...).
##[br][br]
##IMPORTANT: Every variable should have the "@exported" prefix.

@export var action_id: int = GameService.create_id(self)

@export var player_id: String

var default_behavior_prevented: bool = false


func _init(_player_id: String = "") -> void:
	player_id = _player_id


func prevent_default_behavior() -> void:
	default_behavior_prevented = true
