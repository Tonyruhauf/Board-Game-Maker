class_name BoardObjectStack extends StackableBoardObject


var objects: Array[StackableBoardObject] = []

# How much the stack currently rises above its bottom object.
var _rise: float = 0.0
var _is_mouse_down: bool = false
var _dissolving: bool = false
var active_type: Script = null

const OBJECTS_SEPARATION: float = 5.0


func setup(_objects: Array[StackableBoardObject]) -> BoardObjectStack:
	assert(_objects.size() >= 2, "Can't create a BoardObjectStack with less than two StackableBoardObjects!")
	
	global_position = _objects[0].global_position
	
	for object in _objects:
		add_object(object)
	
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
	
	var new_rise: float = (objects.size() - 1) * OBJECTS_SEPARATION
	var stack_rect: Rect2
	
	# Keep the draw order identical to the array order (index 0 = bottom).
	if shadow.get_parent() == self:
		move_child(shadow, 0)
	
	for i in objects.size():
		var obj := objects[i]
		move_child(obj, -1)
		obj.position = Vector2(0.0, new_rise - i * OBJECTS_SEPARATION)
		
		var obj_rect := Rect2(obj.position, obj.size)
		stack_rect = obj_rect if i == 0 else stack_rect.merge(obj_rect)
	
	# Shadow = bottom object's shape, swept along the light by the stack's height.
	shadow.source = objects[0]
	shadow.show_edge = false
	shadow.object_thickness = new_rise + objects.back().shadow.object_thickness
	
	position.y -= new_rise - _rise
	_rise = new_rise
	size = stack_rect.size
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if locked or _dissolving:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_is_mouse_down = event.pressed
		
		if event.pressed:
			if (event.double_click or selected):
				set_selected(true)
				_start_drag()
	
	if event is InputEventMouseMotion:
		if _is_mouse_down and not selected:
			_is_mouse_down = false
			request_pickup_objects(1)


func set_locked(value: bool) -> void:
	super(value)
	
	for obj in objects:
		obj.set_locked(value)


func add_object(object: StackableBoardObject, index: int = -1) -> void:
	if objects.has(object):
		return
	
	if objects.is_empty():
		active_type = object.get_script()
	
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
		
		# Initialise the drag the same way _start_drag() does.
		obj.original_pos = obj.global_position
		obj.drag_offset = obj.global_position - mouse
		obj.get_parent().move_child(obj, -1)
		obj.set_dragging(true)
	
	_after_removal()


# Detaches one object from the stack without deciding what happens to the stack itself.
func _release_object(object: StackableBoardObject) -> void:
	objects.erase(object)

	object.stack_id = -1
	object.stack = null
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
