class_name TakeFromStackAction extends GameAction


@export var stack_id: int
@export var take_amount: int


func _init(_player_id: String, _stack_id: int, _take_amount: int) -> void:
	player_id = _player_id
	stack_id = _stack_id
	take_amount = _take_amount
