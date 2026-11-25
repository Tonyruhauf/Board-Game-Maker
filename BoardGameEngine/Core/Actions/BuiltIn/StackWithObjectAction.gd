class_name StackWithObjectAction extends GameAction


@export var first_object_id: int
@export var second_object_id: int


func _init(_player_id: String, _first_object_id: int, _second_object_id: int) -> void:
	player_id = _player_id
	first_object_id = _first_object_id
	second_object_id = _second_object_id
