class_name BoardObject extends TextureRect


@onready var game: BoardGame = GameService.get_board_game()

var id: int = GameService.create_id(self)

var hovered: bool = false
var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_pos: Vector2


func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	if dragging:
		global_position = get_global_mouse_position() + drag_offset


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drag()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if dragging:
			set_hovered(false)
		else:
			set_hovered(get_rect().has_point(get_global_mouse_position()))
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if dragging and not event.pressed:
			_stop_drag()


func set_hovered(value: bool) -> void:
	if hovered == value:
		return
	
	hovered = value
	
	if hovered:
		GameService.add_object_to_hover_list(self)
	else:
		GameService.remove_object_from_hover_list(self)


func _start_drag() -> void:
	if dragging:
		return
	
	var action: GameAction = StartMovingObjectAction.new(
		GameService.local_player.ID,
		id
	)
	
	if not game.validate_action(action):
		return
	
	original_pos = global_position
	drag_offset = global_position - get_global_mouse_position()
	get_parent().move_child(self, -1)  # Draw above everything else
	
	dragging = true
	set_hovered(false)


func _stop_drag() -> void:
	if not dragging:
		return
	
	dragging = false
	
	var action: GameAction = MoveObjectAction.new(
		GameService.local_player.ID,
		id,
		global_position
	)
	
	if not game.request_action(action):
		global_position = original_pos
