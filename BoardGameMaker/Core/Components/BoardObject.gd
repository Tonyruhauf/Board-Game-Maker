class_name BoardObject extends TextureRect


@onready var game: BoardGame = GameService.get_board_game()

var shadow: ObjectShadow = ObjectShadow.new()
var _selection_border: SelectionBorder

var id: int = GameService.create_id(self)

var drop_shadow_enabled: bool = true
var selected: bool = false
var hovered: bool = false
var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_pos: Vector2

var locked: bool = false

signal released(object: BoardObject)


func _ready() -> void:
	released.connect(GameService.game._on_object_released)
	
	_selection_border = SelectionBorder.new()
	add_child(_selection_border)
	
	add_child(shadow)


func _process(_delta: float) -> void:
	if dragging:
		global_position = get_global_mouse_position() + drag_offset


func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			set_selected(true)
			_start_drag()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if dragging:
			set_hovered(false)
		else:
			set_hovered(get_global_rect().has_point(get_global_mouse_position()))
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if selected and event.pressed:
			if not get_global_rect().has_point(get_global_mouse_position()):
				set_selected(false)
		
		if dragging and not event.pressed:
			_on_drag_ended()


func set_hovered(value: bool) -> void:
	if locked:
		return
	
	if hovered == value:
		return
	
	hovered = value
	
	if hovered:
		GameService.add_object_to_hover_list(self)
	else:
		GameService.remove_object_from_hover_list(self)


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func set_dragging(value: bool) -> void:
	dragging = value
	queue_redraw()


func _start_drag() -> void:
	if locked: return
	if dragging: return
	
	var action: GameAction = StartMovingObjectAction.new(
		GameService.local_player.ID,
		id
	)
	
	if not game.validate_action(action):
		return
	
	original_pos = global_position
	drag_offset = global_position - get_global_mouse_position()
	get_parent().move_child(self, -1)  # Draw above everything else
	
	set_dragging(true)
	set_hovered(false)


func _on_drag_ended() -> void:
	set_dragging(false)
	released.emit(self)


func return_to_origin():
	global_position = original_pos


func set_locked(value: bool) -> void:
	locked = value


func _update_border() -> void:
	if _selection_border:
		_selection_border.visible = (selected and not dragging)
		_selection_border.queue_redraw()


func _draw() -> void:
	_update_border()
