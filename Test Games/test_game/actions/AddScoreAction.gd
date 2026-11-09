class_name AddScoreAction extends GameAction


@export var value: int


func _init(_player_id: String = "", _value: int = 0) -> void:
	player_id = _player_id
	value = _value
