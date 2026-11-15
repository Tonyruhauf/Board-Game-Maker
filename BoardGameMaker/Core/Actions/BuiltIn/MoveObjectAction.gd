class_name MoveObjectAction extends GameAction

@export var object_id: int
@export var new_pos: Vector2


func _init(_player_id: String, _object_id: int, _new_pos: Vector2) -> void:
	player_id = _player_id
	object_id = _object_id
	new_pos = _new_pos
