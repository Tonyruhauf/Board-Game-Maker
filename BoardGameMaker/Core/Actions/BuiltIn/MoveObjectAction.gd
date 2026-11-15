class_name MoveObjectAction extends GameAction

@export var object_ID: int
@export var new_pos: Vector2


func _init(_player_id: String, _object_ID: int, _new_pos: Vector2) -> void:
	player_id = _player_id
	object_ID = _object_ID
	new_pos = _new_pos
