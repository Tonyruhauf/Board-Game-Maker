class_name RotateObjectAction extends GameAction


@export var object_id: int
@export var is_rotation_starting: bool
@export var original_rotation: float
@export var new_rotation: float

func _init(
	_player_id: String,
	_object_id: int,
	_is_rotation_starting: bool,
	_original_rotation: float,
	_new_rotation: float = 0.0
) -> void:
	
	player_id = _player_id
	object_id = _object_id
	is_rotation_starting = _is_rotation_starting
	original_rotation = _original_rotation
	new_rotation = _new_rotation
