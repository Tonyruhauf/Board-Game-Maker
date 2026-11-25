class_name AddObjectToHandAction extends GameAction


@export var object_id: int
@export var hand_id: int
var index: int = -1  # -1 = append at the end


func _init(_player_id: String, _object_id: int, _hand_id: int, _index: int = -1) -> void:
	player_id = _player_id
	object_id = _object_id
	hand_id = _hand_id
	index = _index
