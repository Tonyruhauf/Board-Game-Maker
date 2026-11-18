class_name AddCardToHandAction extends GameAction


@export var card_id: int
@export var hand_id: int
var index: int = -1  # -1 = append at the end


func _init(_player_id: String, _card_id: int, _hand_id: int, _index: int = -1) -> void:
	player_id = _player_id
	card_id = _card_id
	hand_id = _hand_id
	index = _index
