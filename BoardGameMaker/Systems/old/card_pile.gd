class_name CardPile
extends Node2D
## Holds cards stacked on top of each other. The last card in the array is the top one.

const CARD_OFFSET := 0.5  # vertical pixels between each card, for the "stack" look
const MIN_CARDS_OFFSET := 4.0

@export var cards: Array[Card] = []


func _ready() -> void:
	CardsManager.card_dropped.connect(_on_card_dropped)


func _process(_delta: float) -> void:
	# Orange overlay on the top card while a card is being dragged over it.
	if not cards.is_empty():
		var dragging_over_top: bool = CardsManager.dragged_card != null and cards.back().is_mouse_over()
		cards.back().set_highlight(dragging_over_top)


func add_card(card: Card) -> void:
	if not cards.is_empty():
		cards.back().set_highlight(false)

	card.pile = self
	cards.append(card)
	if card.get_parent():
		card.reparent(self)  # keeps its position on screen
	else:
		add_child(card)
	_arrange()


func remove_card(card: Card) -> void:
	card.set_highlight(false)
	cards.erase(card)
	card.pile = null
	card.reparent(get_parent())  # card is now free, outside of the pile
	_arrange()
	if cards.is_empty():
		queue_free()


func _arrange() -> void:
	var prev_card_pos: Vector2
	
	for i in cards.size():
		if i != 0 and prev_card_pos.y > -MIN_CARDS_OFFSET:
			prev_card_pos.y = -MIN_CARDS_OFFSET
		
		cards[i].position = Vector2(0, prev_card_pos.y - CARD_OFFSET)
		prev_card_pos = cards[i].position
		
		if cards.size() >= 2 and i < cards.size() - 1:
			cards[i].modulate = Color(0.0, 0.0, 0.0, 0.686)
		else:
			cards[i].modulate = Color.WHITE


# A card was released: if the mouse is over our top card, put it on the pile.
func _on_card_dropped(card: Card) -> void:
	if card.pile == null and not cards.is_empty() and cards.back().is_mouse_over():
		add_card(card)
