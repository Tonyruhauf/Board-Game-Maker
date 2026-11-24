class_name MoveObjectAction extends GameAction

@export var object_id: int
@export var is_drag_start: bool
@export var new_pos: Vector2


func _init(
	_player_id: String,
	_object_id: int,
	_is_drag_start: bool,
	_new_pos: Vector2 = Vector2.ZERO
) -> void:
	player_id = _player_id
	object_id = _object_id
	is_drag_start = _is_drag_start
	new_pos = _new_pos
