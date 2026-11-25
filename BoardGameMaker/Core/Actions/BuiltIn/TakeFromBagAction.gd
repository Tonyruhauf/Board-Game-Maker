class_name TakeFromBagAction extends GameAction


@export var bag_id: int


func _init(_player_id: String, _bag_id: int) -> void:
	player_id = _player_id
	bag_id = _bag_id
