class_name BoardObjectStack extends BoardObject


var objects: Array[StackableBoardObject] = []

# How much the stack currently rises above its bottom object.
var _rise: float = 0.0
var _is_mouse_down: bool = false

const OBJECTS_SEPARATION: float = 5.0


func _init(_objects: Array[StackableBoardObject]) -> void:
	assert(_objects.size() >= 2, "Can't create a BoardObjectStack with less than two StackableBoardObjects!")
	
	global_position = _objects[0].global_position
	
	for object in _objects:
		add_object(object)


func _ready() -> void:
	super()
	
	texture = PlaceholderTexture2D.new()
	#self_modulate.a = 0.0
	
	update_display()


func update_display() -> void:
	if objects.is_empty():
		return
	
	var new_rise: float = (objects.size() - 1) * OBJECTS_SEPARATION
	var stack_rect: Rect2
	
	shadow.object_thickness = 0.0
	
	for i in objects.size():
		var obj := objects[i]
		obj.position = Vector2(0.0, new_rise - i * OBJECTS_SEPARATION)
		
		shadow.object_thickness += obj.shadow.object_thickness
		
		var obj_rect := Rect2(obj.position, obj.size)
		stack_rect = obj_rect if i == 0 else stack_rect.merge(obj_rect)
	
	# Move the stack only by the *change* in rise, so the bottom object stays visually in place.
	position.y -= new_rise - _rise
	_rise = new_rise
	
	# Fit the stack to its children.
	custom_minimum_size = stack_rect.size
	size = stack_rect.size
	
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if locked:
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


func add_object(object: StackableBoardObject) -> void:
	if objects.has(object):
		return
	
	objects.append(object)
	object.reparent(self)
	
	object.stack = self
	object.set_selected(false)
	object.set_locked(true)
	
	update_display()


func remove_object(object: StackableBoardObject) -> void:
	if not objects.has(object):
		return
	
	object.stack = null
	
	objects.erase(object)
	object.reparent(GameService.get_board())
	
	object.set_locked(false)
	
	if objects.is_empty():
		queue_free()
	
	update_display()


func request_pickup_objects(amount: int) -> void:
	var action = TakeFromStackAction.new(
		GameService.local_player.ID,
		id,
		amount
	)
	game.request_action(action)


func _pickup_objects(amount: int) -> void:
	for i in amount:
		var obj = objects.back()
		
		remove_object(obj)
		obj.set_dragging(true)
