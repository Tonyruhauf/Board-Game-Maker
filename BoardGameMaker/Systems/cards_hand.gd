class_name CardHand extends Control


@onready var entry_area: Control = $EntryArea
@onready var cards_container: ImprovedBoxContainer = $CardsContainer

var id: int = GameService.create_id(self)

var card_list: Array[Card]

var is_hovered: bool = false:
	set(value):
		is_hovered = value
		update_display()


func try_accept(card: Card) -> bool:
	if not is_hovered:
		return false
	
	add_card(card)
	return true


func add_card(card: Card, index: int = -1) -> void:
	if not card: return
	
	card_list.append(card)
	
	card.reparent(cards_container)
	cards_container.move_child(card, index)
	
	card.set_selected(false)
	card.set_locked(true)
	
	card.gui_input.connect(_on_card_gui_input.bind(card))


func remove_card(card: Card) -> void:
	if not card: return
	
	card_list.erase(card)
	
	card.reparent(GameService.board)
	card.set_locked(false)
	
	if card.gui_input.is_connected(_on_card_gui_input):
		card.gui_input.disconnect(_on_card_gui_input)


func pickup_card(card: Card) -> void:
	remove_card(card)


func has_card(card: Card) -> bool:
	return card_list.has(card)


func _on_card_gui_input(event: InputEvent, card: Card) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pickup_card(card)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		is_hovered = (entry_area.get_rect().has_point(event.global_position))


func update_display() -> void:
	entry_area.visible = is_hovered
