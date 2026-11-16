class_name StackableBoardObject extends BoardObject


var stack: BoardObjectStack
var stack_candidate: StackableBoardObject


func _input(event: InputEvent) -> void:
	super(event)
	
	if event is InputEventMouseMotion:
		if not dragging:
			_clear_stack_candidate()
			return
		
		var hovered_object: BoardObject = GameService.get_hovered_object()
		
		if not hovered_object is StackableBoardObject or not can_stack(hovered_object):
			_clear_stack_candidate()
			return
		
		stack_candidate = hovered_object
		modulate = Color.ORANGE
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if stack_candidate:
				stack_with(stack_candidate)


func _clear_stack_candidate() -> void:
	stack_candidate = null
	modulate = Color.WHITE


func stack_with(object: StackableBoardObject):
	StackingManager.create_stack(object, self)


func can_stack(other: StackableBoardObject) -> bool:
	return other != self and _can_stack_with(other) and other._can_stack_with(self)


func _can_stack_with(other: StackableBoardObject) -> bool:
	return true
