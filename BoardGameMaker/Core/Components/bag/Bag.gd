@tool
@icon("res://BoardGameMaker/Shared Assets/sack-icon.png")
class_name Bag extends BoardObject


var objects: Array[BoardObject]


func _init() -> void:
	super()
	
	texture = preload("res://BoardGameMaker/Shared Assets/Bag.png")
	scale = Vector2(0.35, 0.35)


func _gui_input(event: InputEvent) -> void:
	super(event)
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.shift_pressed: return
				if objects.is_empty(): return
				set_dragging(false)
				set_selected(false)
				request_pickup_object()


func try_adding_object(obj: BoardObject) -> bool:
	if not obj: return false
	if objects.has(obj): return false
	if obj is BoardObjectStack: return false
	
	request_adding_object(obj)
	return true


func request_adding_object(obj: BoardObject) -> void:
	var action: GameAction = AddObjectToBagAction.new(
		GameService.local_player.ID,
		obj.id,
		id
	)
	game.request_action(action)


func request_pickup_object() -> void:
	var action: GameAction = TakeFromBagAction.new(
		GameService.local_player.ID,
		id
	)
	game.request_action(action)


func _add_object(obj: BoardObject) -> void:
	objects.append(obj.copy())
	obj.queue_free()


func _pickup_object() -> BoardObject:
	if objects.is_empty(): return
	
	var obj: BoardObject = objects.pick_random()
	if not obj: return
	
	objects.erase(obj)
	GameService.get_board().add_child(obj)
	obj.center_on_mouse()
	obj._start_drag()
	
	return obj
