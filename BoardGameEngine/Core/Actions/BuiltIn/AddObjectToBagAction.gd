class_name AddObjectToBagAction extends GameAction


@export var object_id: int
@export var bag_id: int


func _init(_player_id: String, _object_id: int, _bag_id: int) -> void:
	player_id = _player_id
	object_id = _object_id
	bag_id = _bag_id
