class_name AddScoreAction extends GameAction


var value: int


func _init(_player_id: int, _value: int) -> void:
	player_id = _player_id
	value = _value
