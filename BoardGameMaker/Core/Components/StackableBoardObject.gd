class_name StackableBoardObject extends BoardObject


var stack_id: int = -1
var stack: BoardObjectStack
var stack_candidate: StackableBoardObject


func _input(event: InputEvent) -> void:
	super(event)
	
	if event is InputEventMouseMotion:
		_update_stack_candidate()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_clear_stack_candidate()


func _update_stack_candidate():
	if not dragging:
		_clear_stack_candidate()
		return
	
	var hovered_object: BoardObject = GameService.get_hovered_object()
	
	if not hovered_object:
		_clear_stack_candidate()
		return
	
	if not hovered_object is StackableBoardObject or not can_stack(hovered_object):
		_clear_stack_candidate()
		return
	
	stack_candidate = hovered_object
	modulate = Color.ORANGE


func _clear_stack_candidate() -> void:
	stack_candidate = null
	modulate = Color.WHITE


func is_in_stack() -> bool:
	return stack_id != -1


func _stack_with(object: StackableBoardObject):
	if object == self or is_in_stack():
		return
	
	if object is BoardObjectStack:
		object.add_object(self)
		return
	
	if object.is_in_stack():
		object.stack.add_object(self)
		return
	
	StackingManager.create_stack(object, self)


func can_stack(other: StackableBoardObject) -> bool:
	if is_in_stack() or other.is_in_stack(): return false
	if other == self: return false
	return _can_stack_with(other) and other._can_stack_with(self)


func _can_stack_with(other: StackableBoardObject) -> bool:
	if other is Card and GameService.board.hand.has_card(other): return false
	return true
