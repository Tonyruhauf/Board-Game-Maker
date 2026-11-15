class_name StartMovingObjectAction extends GameAction

@export var object_ID: int


func _init(_player_id: String, _object_ID: int) -> void:
	player_id = _player_id
	object_ID = _object_ID
