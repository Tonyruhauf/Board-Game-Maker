class_name BoardObject extends TextureRect


@onready var game: BoardGame = GameService.get_board_game() if not Engine.is_editor_hint() else null

var shadow: ObjectShadow = ObjectShadow.new() if not Engine.is_editor_hint() else null
var _selection_border: SelectionBorder

var id: int = GameService.create_id(self) if not Engine.is_editor_hint() else 0

var drop_shadow_enabled: bool = true
var locked: bool = false
var selected: bool = false
var hovered: bool = false
var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_pos: Vector2
var rotating: bool = false
var _rotate_start_mouse_angle: float = 0.0
var _rotate_start_rotation: float = 0.0
var _rotation_tween: Tween
var _rotation_target: float = 0.0

const ROTATE_STEP: float = PI / 2.0

signal released(object: BoardObject)


func _init() -> void:
	pass


func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	released.connect(GameService.game._on_object_released)
	resized.connect(_on_resized)
	
	pivot_offset = size / 2.0  # Rotate around the center
	original_pos = global_position
	
	_selection_border = SelectionBorder.new()
	add_child(_selection_border)
	
	add_child(shadow)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	
	if dragging:
		global_position = get_global_mouse_position() + drag_offset
	elif rotating:
		_update_rotation_from_mouse()


func _gui_input(event: InputEvent) -> void:
	if not can_interact():
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			set_selected(true)
			if event.is_command_or_control_pressed():
				_start_rotate()
			else:
				request_drag()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if dragging or rotating:
			set_hovered(false)
		else:
			set_hovered(_is_mouse_over())
	
	if not can_interact():
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if selected and event.pressed:
			if not _is_mouse_over():
				set_selected(false)
		
		if not event.pressed:
			if dragging:
				_on_drag_ended()
			elif rotating:
				_on_rotate_ended()
	
	if event is InputEventKey and event.pressed and not event.echo and selected and not rotating:
		match event.keycode:
			KEY_E:
				rotate_by_step(ROTATE_STEP)    # clockwise
			KEY_A:
				rotate_by_step(-ROTATE_STEP)   # counter-clockwise
	
	if event.is_action_pressed("flip_object") and hovered:
		request_flip()


func _on_resized() -> void:
	pivot_offset = size / 2.0


func _get_visual_rotation() -> float:
	return rotation


func _set_visual_rotation(value: float) -> void:
	rotation = value


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
	
	if dragging:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		GameService.set_held_object(self)
	else:
		mouse_filter = Control.MOUSE_FILTER_PASS
		GameService.set_held_object(null)
	
	queue_redraw()


func is_locked() -> bool:
	return locked


func can_interact() -> bool:
	return not is_locked()


func request_drag() -> void:
	if locked: return
	if dragging: return
	
	var action: GameAction = MoveObjectAction.new(
		GameService.local_player.ID,
		id,
		true
	)
	
	if not game.validate_action(action):
		return
	
	_start_drag()


func _start_drag() -> void:
	original_pos = global_position
	drag_offset = global_position - get_global_mouse_position()
	get_parent().move_child(self, -1)  # Draw above everything else
	
	set_dragging(true)
	set_hovered(false)


func _on_drag_ended() -> void:
	set_dragging(false)
	released.emit(self)


func request_flip() -> void:
	pass


func _flip() -> void:
	pass


func is_flippable() -> bool:
	return false


func _get_center() -> Vector2:
	# Global position of the pivot (works with any current rotation)
	return get_global_transform() * pivot_offset


func _contains_local_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point)


func _is_mouse_over() -> bool:
	var local_mouse: Vector2 = get_global_transform().affine_inverse() * get_global_mouse_position()
	return _contains_local_point(local_mouse)


func center_on_mouse() -> void:
	global_position = get_global_mouse_position() - size / 2


func _start_rotate() -> void:
	if locked or dragging or rotating: return
	
	var action: GameAction = RotateObjectAction.new(
		GameService.local_player.ID,
		id,
		true,
		_get_visual_rotation()
	)
	
	if not game.validate_action(action):
		return
	
	if _rotation_tween:
		_rotation_tween.kill()
	
	rotating = true
	_rotate_start_rotation = _get_visual_rotation()
	_rotate_start_mouse_angle = (get_global_mouse_position() - _get_center()).angle()
	get_parent().move_child(self, -1)
	set_hovered(false)
	queue_redraw()


func _update_rotation_from_mouse() -> void:
	var current_angle: float = (get_global_mouse_position() - _get_center()).angle()
	_set_visual_rotation(_rotate_start_rotation + (current_angle - _rotate_start_mouse_angle))


func _on_rotate_ended() -> void:
	rotating = false
	queue_redraw()
	# TODO: if rotation should sync in multiplayer, send a RotateObjectAction here


func rotate_by_step(step: float) -> void:
	if locked: return
	
	var action: GameAction = RotateObjectAction.new(
		GameService.local_player.ID,
		id,
		true,
		_get_visual_rotation()
	)
	
	if not game.validate_action(action):
		return
	
	var base: float = _rotation_target if (_rotation_tween and _rotation_tween.is_running()) \
		else _get_visual_rotation()
	_rotation_target = snappedf(base + step, ROTATE_STEP)
	
	if _rotation_tween:
		_rotation_tween.kill()
	
	_rotation_tween = create_tween()
	_rotation_tween.tween_method(_set_visual_rotation, _get_visual_rotation(), _rotation_target, 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func return_to_origin():
	global_position = original_pos


func set_locked(value: bool) -> void:
	locked = value


func copy() -> BoardObject:
	var _copy: BoardObject = self.duplicate()
	
	for property in get_property_list():
		if property.type == TYPE_OBJECT:
			continue
		
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			_copy.set(property.name, get(property.name))
	
	_copy.id = GameService.create_id(_copy)
	return _copy


func _update_border() -> void:
	if _selection_border:
		_selection_border.visible = (selected and not dragging)
		_selection_border.queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint(): return
	
	_update_border()
