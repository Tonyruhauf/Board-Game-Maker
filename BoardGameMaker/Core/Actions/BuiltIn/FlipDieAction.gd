class_name FlipDieAction extends GameAction


@export var die_id: int


func _init(_player_id: String, _die_id: int) -> void:
	player_id = _player_id
	die_id = _die_id
