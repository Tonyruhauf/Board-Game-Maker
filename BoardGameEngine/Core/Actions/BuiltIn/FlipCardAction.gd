class_name FlipCardAction extends GameAction


@export var card_id: int
@export var new_side: CardData.Side


func _init(_player_id: String, _card_id: int, _new_side: CardData.Side) -> void:
	player_id = _player_id
	card_id = _card_id
	new_side = _new_side
