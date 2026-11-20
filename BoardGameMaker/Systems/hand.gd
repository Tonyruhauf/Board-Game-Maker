class_name Hand extends Control


@onready var entry_area: Control = $EntryArea
@onready var objects_container: ImprovedBoxContainer = $ObjectsContainer
@onready var visual_container: ImprovedBoxContainer = $VisualContainer
@onready var spacer: Control = $VisualContainer/Spacer

var id: int = GameService.create_id(self)

var objects_list: Array[BoardObject]

var hovered_object: BoardObject = null
var is_hovered: bool = false:
	set(value):
		is_hovered = value
		update_display()
var insert_index: int = -1
var entry_area_base_rect: Rect2

const DEBUG_MODE: bool = false


func _ready() -> void:
	if not DEBUG_MODE:
		objects_container.modulate.a = 0.0
	
	if DEBUG_MODE:
		visual_container.position.y = 800
	
	entry_area_base_rect = entry_area.get_rect()


func try_accept(object: BoardObject, index: int = -1) -> bool:
	if can_accept(object, index):
		add_object(object, index)
		return true
	else:
		return false


func can_accept(object: BoardObject, _index: int = -1) -> bool:
	if object == null:
		return false
	
	if object is BoardObjectStack:
		return false
	
	return true


func is_focused() -> bool:
	return is_hovered and visible


func add_object(object: BoardObject, index: int = -1) -> void:
	if not object: return
	
	objects_list.append(object)
	
	object.reparent(objects_container)
	
	var target_index: int = insert_index if index == -1 else index
	
	if objects_container.get_child_count() > 0:
		var first_object: BoardObject = objects_container.get_child(0)
		if first_object and get_global_mouse_position().x < first_object.global_position.x:
			target_index = 0
	
	objects_container.move_child(object, target_index)
	
	object.set_selected(false)
	object.set_locked(true)
	
	object.gui_input.connect(_on_object_gui_input.bind(object))
	object.mouse_entered.connect(_on_object_mouse_entered.bind(object))
	object.mouse_exited.connect(_on_object_mouse_exited.bind(object))
	
	add_fake_object(object)


func add_fake_object(object: BoardObject) -> void:
	var copy: BoardObject = object.duplicate()
	
	visual_container.add_child(copy)
	visual_container.move_child(spacer, -1)
	visual_container.move_child(copy, object.get_index())
	
	copy.id = object.id
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.set_locked(true)


func remove_fake_object(object: BoardObject) -> void:
	var fake_object: BoardObject = get_fake_object(object)
	if fake_object:
		fake_object.queue_free()


func get_fake_object(object: BoardObject) -> BoardObject:
	for child in visual_container.get_children():
		if child is BoardObject:
			if child.id == object.id:
				return child
	return null


func _on_object_mouse_entered(object: BoardObject):
	hovered_object = object
	
	update_insert_index()


func _on_object_mouse_exited(object: BoardObject):
	if hovered_object == object:
		hovered_object = null
		
		insert_index = -1
		update_visual_container()


func update_insert_index():
	if not hovered_object or not is_hovered:
		spacer.hide()
		update_visual_container()
		return
	
	if not (GameService.get_held_object() is BoardObject):
		spacer.hide()
		update_visual_container()
		return
	
	var hovered_object_index: int = hovered_object.get_index()
	if hovered_object_index == 0:
		var object_middle_pos: Vector2 = hovered_object.global_position + (hovered_object.size / 2)
		if get_global_mouse_position().x < object_middle_pos.x:
			insert_index = 0
		else:
			insert_index = 1
	elif hovered_object_index == objects_list.size() - 1:
		insert_index = -1
	else:
		insert_index = hovered_object_index + 1
	
	update_visual_container()


func update_visual_container():
	if insert_index == -1:
		spacer.hide()
		return
	
	visual_container.move_child(spacer, insert_index)
	spacer.show()


func remove_object(object: BoardObject) -> void:
	if not object: return
	
	objects_list.erase(object)
	
	object.reparent(GameService.board)
	object.set_selected(true)
	object.set_dragging(true)
	
	if object.gui_input.is_connected(_on_object_gui_input):
		object.gui_input.disconnect(_on_object_gui_input)
	
	if object.mouse_entered.is_connected(_on_object_mouse_entered):
		object.mouse_entered.disconnect(_on_object_mouse_entered)
	
	if object.mouse_exited.is_connected(_on_object_mouse_exited):
		object.mouse_exited.disconnect(_on_object_mouse_exited)
	
	remove_fake_object(object)
	
	await get_tree().process_frame
	object.set_locked(false)


func pickup_object(object: BoardObject) -> void:
	remove_object(object)


func has_object(object: BoardObject) -> bool:
	return objects_list.has(object)


func _on_object_gui_input(event: InputEvent, object: BoardObject) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pickup_object(object)


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("toggle_hand_visibility"):
		visible = !visible # TODO: Add a smooth animation instead
	
	if event is InputEventMouseMotion:
		if entry_area.get_rect().has_point(event.global_position):
			is_hovered = can_accept(GameService.get_held_object())
			_expand_entry_rect()
		else:
			is_hovered = false
			_restore_entry_rect()
		
		if hovered_object:
			update_insert_index()


func _expand_entry_rect() -> void:
	var scale_factor: int = 3
	entry_area.size.y = entry_area_base_rect.size.y * scale_factor
	var height_change: float = entry_area.size.y - entry_area_base_rect.size.y
	entry_area.position.y = entry_area_base_rect.position.y - height_change


func _restore_entry_rect() -> void:
	entry_area.size = entry_area_base_rect.size
	entry_area.position = entry_area_base_rect.position


func update_display() -> void:
	entry_area.visible = is_hovered
	update_visual_container()
