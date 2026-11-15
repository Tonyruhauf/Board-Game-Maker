extends Area2D
## A card you can drag with the mouse, and flip with F while hovering it.

@export var front_texture: Texture2D
@export var back_texture: Texture2D
@export var is_front_up := false
@export var pile: CardPile = null  # the pile this card is in (null if loose)
@export var max_size := Vector2(140, 200)  # Maximum dimension limit for the card

var size := Vector2.ZERO
var dragging := false
var drag_offset := Vector2.ZERO

var texture_rect: TextureRect = TextureRect.new()
var overlay := ColorRect.new()  # orange overlay, shown when a card can be dropped on this one


# Call this before adding the card to the scene.
func setup(front: Texture2D, back: Texture2D, front_up := false) -> void:
	front_texture = front
	back_texture = back
	is_front_up = front_up


func _ready() -> void:
	_update_size()

	# Image
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.size = size
	texture_rect.position = -size / 2
	add_child(texture_rect)
	_update_texture()

	# Orange overlay (hidden by default)
	overlay.color = Color(1, 0.5, 0, 0.4)
	overlay.size = size
	overlay.position = -size / 2
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	add_child(overlay)
	
	texture_rect.gui_input.connect(_on_gui_input)


func _process(_delta: float) -> void:
	if dragging:
		global_position = get_global_mouse_position() + drag_offset


# Start dragging on left click.
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_on_top():
			_start_drag()


# Stop dragging when the left button is released, and flip when pressing F.
func _input(event: InputEvent) -> void:
	if dragging and event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = false
		CardsManager.dragged_card = null
		CardsManager.card_dropped.emit(self)  # piles listen to this

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		if is_mouse_over() and is_on_top():
			flip()


func _start_drag() -> void:
	drag_offset = global_position - get_global_mouse_position()
	if pile:
		pile.remove_card(self)
	get_parent().move_child(self, -1)  # draw above everything else
	dragging = true
	CardsManager.dragged_card = self


func flip() -> void:
	is_front_up = not is_front_up
	_update_texture()


func set_highlight(value: bool) -> void:
	overlay.visible = value


# In a pile, only the top card can be used.
func is_on_top() -> bool:
	return pile == null or pile.cards.back() == self


func is_mouse_over() -> bool:
	return Rect2(-size / 2, size).has_point(get_local_mouse_position())


func _update_size() -> void:
	# Use front_texture (or back as fallback) to determine a consistent size
	var ref_texture = front_texture if front_texture else back_texture
	if ref_texture:
		var tex_size = ref_texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			# Scale uniformly to fit within max_size while maintaining aspect ratio
			var scale_factor = min(max_size.x / tex_size.x, max_size.y / tex_size.y)
			size = tex_size * scale_factor
		else:
			size = max_size
	else:
		size = max_size


func _update_texture() -> void:
	texture_rect.texture = front_texture if is_front_up else back_texture
