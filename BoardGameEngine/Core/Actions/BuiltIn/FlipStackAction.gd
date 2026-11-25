class_name FlipStackAction extends GameAction


@export var stack_id: int


func _init(_player_id: String, _stack_id: int) -> void:
	player_id = _player_id
	stack_id = _stack_id
