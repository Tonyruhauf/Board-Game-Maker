class_name CardHand extends Control


@onready var entry_area: Control = $EntryArea
@onready var cards_container: ImprovedBoxContainer = $CardsContainer
@onready var visual_container: ImprovedBoxContainer = $VisualContainer
@onready var spacer: Control = $VisualContainer/Spacer

var id: int = GameService.create_id(self)

var card_list: Array[Card]

var hovered_card: Card = null
var is_hovered: bool = false:
	set(value):
		is_hovered = value
		update_display()
var insert_index: int = -1

const DEBUG_MODE: bool = false


func _ready() -> void:
	if not DEBUG_MODE:
		cards_container.modulate.a = 0.0
	
	if DEBUG_MODE:
		visual_container.position.y = 700


func try_accept(card: Card) -> bool:
	if not is_hovered:
		return false
	
	add_card(card)
	return true


func add_card(card: Card, index: int = -1) -> void:
	if not card: return
	
	card_list.append(card)
	
	card.reparent(cards_container)
	
	var target_index: int = insert_index if index == -1 else index
	
	if cards_container.get_child_count() > 0:
		var first_card: Card = cards_container.get_child(0)
		if first_card and get_global_mouse_position().x < first_card.global_position.x:
			target_index = 0
	
	cards_container.move_child(card, target_index)
	
	card.set_selected(false)
	card.set_locked(true)
	
	card.gui_input.connect(_on_card_gui_input.bind(card))
	card.mouse_entered.connect(_on_card_mouse_entered.bind(card))
	card.mouse_exited.connect(_on_card_mouse_exited.bind(card))
	
	add_fake_card(card)


func add_fake_card(card: Card) -> void:
	var copy: Card = card.duplicate()
	
	visual_container.add_child(copy)
	visual_container.move_child(spacer, -1)
	visual_container.move_child(copy, card.get_index())
	
	copy.id = card.id
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.set_locked(true)


func remove_fake_card(card: Card) -> void:
	var fake_card: Card = get_fake_card(card)
	if fake_card:
		fake_card.queue_free()


func get_fake_card(card: Card) -> Card:
	for child in visual_container.get_children():
		if child is Card:
			if child.id == card.id:
				return child
	return null


func _on_card_mouse_entered(card: Card):
	hovered_card = card
	
	update_insert_index()


func _on_card_mouse_exited(card: Card):
	if hovered_card == card:
		hovered_card = null
		
		insert_index = -1
		update_visual_container()


func update_insert_index():
	if not hovered_card or not is_hovered:
		spacer.hide()
		update_visual_container()
		return
	
	if not (GameService.get_held_object() is Card):
		spacer.hide()
		update_visual_container()
		return
	
	var hovered_card_index: int = hovered_card.get_index()
	if hovered_card_index == 0:
		var card_middle_pos: Vector2 = hovered_card.global_position + (hovered_card.size / 2)
		if get_global_mouse_position().x < card_middle_pos.x:
			insert_index = 0
		else:
			insert_index = 1
	elif hovered_card_index == card_list.size() - 1:
		insert_index = -1
	else:
		insert_index = hovered_card_index + 1
	
	update_visual_container()


func update_visual_container():
	if insert_index == -1:
		spacer.hide()
		return
	
	visual_container.move_child(spacer, insert_index)
	spacer.show()


func remove_card(card: Card) -> void:
	if not card: return
	
	card_list.erase(card)
	
	card.reparent(GameService.board)
	card.set_locked(false)
	
	if card.gui_input.is_connected(_on_card_gui_input):
		card.gui_input.disconnect(_on_card_gui_input)
	
	if card.mouse_entered.is_connected(_on_card_mouse_entered):
		card.mouse_entered.disconnect(_on_card_mouse_entered)
	
	if card.mouse_exited.is_connected(_on_card_mouse_exited):
		card.mouse_exited.disconnect(_on_card_mouse_exited)
	
	remove_fake_card(card)


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
		
		if hovered_card:
			update_insert_index()


func update_display() -> void:
	entry_area.visible = is_hovered
	update_visual_container()
