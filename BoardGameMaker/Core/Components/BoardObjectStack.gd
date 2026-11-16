class_name BoardObjectStack extends Node2D


var objects: Array[StackableBoardObject] = []

const OBJECTS_SEPARATION: float = 5.0


func _init(_objects: Array[StackableBoardObject]) -> void:
	assert(_objects.size() >= 2, "Can't create a BoardObjectStack with less than two StackableBoardObjects!")
	
	objects = _objects
	
	global_position = objects[0].global_position


func _ready() -> void:
	update_display()


func update_display() -> void:
	var offset: Vector2 = Vector2.ZERO
	
	for obj in objects:
		obj.global_position = position + offset
		offset.y -= OBJECTS_SEPARATION


func add_object(object: StackableBoardObject) -> void:
	if objects.has(object):
		return
	
	objects.append(object)
	object.reparent(self)
	
	update_display()


func remove_object(object: StackableBoardObject) -> void:
	if not objects.has(object):
		return
	
	objects.erase(object)
	object.reparent(GameService.get_board())
	
	update_display()
