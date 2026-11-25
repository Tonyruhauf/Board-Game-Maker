class_name BoardObjectStack extends StackableBoardObject


var objects: Array[StackableBoardObject] = []

var _bottom_center: Vector2 = Vector2.ZERO  # Bottom object's center, in stack-local space
var _has_layout: bool = false
var _is_mouse_down: bool = false
var _dissolving: bool = false
var active_type: Script = null
var objects_rotation: float 

const OBJECTS_SEPARATION: float = 5.0


func setup(_objects: Array[StackableBoardObject]) -> BoardObjectStack:
	assert(_objects.size() >= 2, "Can't create a BoardObjectStack with less than two StackableBoardObjects!")
	
	var first := _objects[0]
	var anchor_global: Vector2 = first.get_global_transform() * (first.size / 2.0)
	
	for object in _objects:
		add_object(object)
	
	# Put the bottom object's center back where the first object's center was
	global_position += anchor_global - (get_global_transform() * _bottom_center)
	
	return self


func _ready() -> void:
	super()
	
	texture = PlaceholderTexture2D.new()
	# Don't let the texture dictate our minimum size, so `size` applies immediately.
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	self_modulate.a = 0.0
	
	if objects.is_empty():
		for obj in get_children():
			if obj is BoardObject:
				objects.append(obj)
	
	update_display()


func _exit_tree() -> void:
	# Never leave a dead stack in the hover list.
	if hovered:
		hovered = false
		GameService.remove_object_from_hover_list(self)


func _stack_with(other_object: StackableBoardObject) -> void:
	if _dissolving or other_object == self:
		return
	
	# Work out whether we are merging into another stack, or just adding a single object.
	var target_stack: BoardObjectStack = null
	if other_object is BoardObjectStack:
		target_stack = other_object
	elif other_object.is_in_stack():
		target_stack = other_object.stack
	
	if target_stack:
		if target_stack == self or target_stack.active_type != active_type:
			return
		# Move everything (bottom -> top) onto the other stack, then remove ourselves.
		for obj in objects.duplicate():
			objects.erase(obj)
			target_stack.add_object(obj)
		_free_self()
		return
	
	if not is_instance_of(other_object, active_type):
		return
	
	# Single object goes to the bottom of this stack. We are NOT freed here.
	add_object(other_object, 0)


func _can_stack_with(other: StackableBoardObject) -> bool:
	if other is BoardObjectStack:
		if other.active_type != active_type: return false
	elif other.is_in_stack():
		if other.stack.active_type != active_type: return false
	elif not is_instance_of(other, active_type):
		return false
	return super(other)


func update_display() -> void:
	if objects.is_empty():
		return
	
	if shadow.get_parent() == self:
		move_child(shadow, 0)
	for obj in objects:
		move_child(obj, -1)
	
	var new_rise: float = (objects.size() - 1) * OBJECTS_SEPARATION
	shadow.source = objects[0]
	shadow.show_edge = false
	shadow.object_thickness = new_rise + objects.back().shadow.object_thickness
	
	_layout()


func _layout() -> void:
	if objects.is_empty():
		return
	
	# Layout space: bottom object's center is the origin, higher objects go up.
	var bounds: Rect2
	for i in objects.size():
		var obj := objects[i]
		obj.pivot_offset = obj.size / 2.0
		var half := _rotated_half_extents(obj.size, objects_rotation)
		var center := Vector2(0.0, -i * OBJECTS_SEPARATION)
		var rect := Rect2(center - half, half * 2.0)
		bounds = rect if i == 0 else bounds.merge(rect)
	
	for i in objects.size():
		var obj := objects[i]
		var center := Vector2(0.0, -i * OBJECTS_SEPARATION)
		# position is the unrotated top-left; rotation happens around the object's center
		obj.position = center - bounds.position - obj.size / 2.0
	
	# Keep the bottom object's center where it was while bounds change
	var new_bottom_center: Vector2 = -bounds.position
	if _has_layout:
		position += _bottom_center - new_bottom_center
	_bottom_center = new_bottom_center
	_has_layout = true
	
	size = bounds.size
	pivot_offset = size / 2.0
	queue_redraw()


func _rotated_half_extents(rect_size: Vector2, angle: float) -> Vector2:
	var c: float = absf(cos(angle))
	var s: float = absf(sin(angle))
	return Vector2(rect_size.x * c + rect_size.y * s, rect_size.x * s + rect_size.y * c) / 2.0


func _gui_input(event: InputEvent) -> void:
	if not can_interact():
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_is_mouse_down = event.pressed
		
		if event.pressed:
			if event.double_click:
				set_selected(true)
			
			if selected:
				if event.is_command_or_control_pressed():
					_start_rotate()
				else:
					_start_drag()
	
	if event is InputEventMouseMotion:
		if _is_mouse_down and not selected:
			_is_mouse_down = false
			request_pickup_objects(1)


func can_interact() -> bool:
	return not (locked or _dissolving)


func _get_visual_rotation() -> float:
	return objects_rotation


func _set_visual_rotation(value: float) -> void:
	objects_rotation = value
	shadow.rotation = value
	for obj in objects:
		obj.rotation = value
	_layout()


func _get_center() -> Vector2:
	# Rotate around the bottom object, which is what actually spins
	return get_global_transform() * _bottom_center


func _contains_local_point(point: Vector2) -> bool:
	for obj in objects:
		var local: Vector2 = obj.get_transform().affine_inverse() * point
		if Rect2(Vector2.ZERO, obj.size).has_point(local):
			return true
	return false


func _has_point(point: Vector2) -> bool:
	return _contains_local_point(point)


func set_locked(value: bool) -> void:
	super(value)
	
	for obj in objects:
		obj.set_locked(value)


func add_object(object: StackableBoardObject, index: int = -1) -> void:
	if objects.has(object):
		return
	
	if objects.is_empty():
		active_type = object.get_script()
		objects_rotation = object.rotation
		shadow.rotation = object.rotation
	
	if not is_instance_of(object, active_type):
		push_warning("BoardObjectStack: rejected object of a different type.")
		return
	
	# Steal the object from its previous stack, if any.
	var previous: BoardObjectStack = object.stack
	if previous and previous != self:
		previous.objects.erase(object)
		object.stack = null
		object.stack_id = -1
		previous._after_removal.call_deferred()
	
	if index == -1:
		objects.append(object)
	else:
		objects.insert(index, object)
	
	object.rotation = objects_rotation
	object.set_hovered(false)
	object.set_dragging(false)
	object.set_selected(false)
	
	object.reparent(self)
	
	object.stack_id = id
	object.stack = self
	object.set_locked(true)
	
	update_display()


func remove_object(object: StackableBoardObject) -> void:
	if not objects.has(object):
		return
	
	_release_object(object)
	_after_removal()


func request_pickup_objects(amount: int) -> void:
	var action = TakeFromStackAction.new(
		GameService.local_player.ID,
		id,
		amount
	)
	game.request_action(action)


func _pickup_objects(amount: int) -> void:
	amount = mini(amount, objects.size())
	if amount <= 0:
		return
	
	var mouse := get_global_mouse_position()
	
	for i in amount:
		var obj: StackableBoardObject = objects.back()
		_release_object(obj)
		obj._start_drag()
	
	_after_removal()


# Detaches one object from the stack without deciding what happens to the stack itself.
func _release_object(object: StackableBoardObject) -> void:
	objects.erase(object)

	object.stack_id = -1
	object.stack = null
	object.rotation = objects_rotation
	object.reparent(GameService.get_board())
	object.set_locked(false)


# A stack with fewer than two objects is not a stack.
func _after_removal() -> void:
	if objects.size() <= 1:
		for obj in objects.duplicate():
			_release_object(obj)  # last card stays exactly where it visually is
		_free_self()
	else:
		update_display()


func _free_self() -> void:
	if _dissolving:
		return
	_dissolving = true
	
	# queue_free() is deferred: make sure the dying stack can't be hovered or clicked this frame.
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(false)
	set_selected(false)
	
	if hovered:
		hovered = false
		GameService.remove_object_from_hover_list(self)
	
	queue_free()
