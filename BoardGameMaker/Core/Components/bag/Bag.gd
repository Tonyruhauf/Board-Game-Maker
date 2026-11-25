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
				if not objects.is_empty():
					set_dragging(false)
					request_pickup_object()


func try_adding_object(obj: BoardObject) -> bool:
	if not obj: return false
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
	if not obj: return
	if objects.has(obj): return
	
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
