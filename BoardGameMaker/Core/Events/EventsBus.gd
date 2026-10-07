extends Node


var connections: Dictionary[Script, Array]


func connect_event(event_type: Script, callable: Callable):
	assert(_is_subclass_of_script(event_type, GameEvent), "event_type must inherit from GameEvent")
	
	var existing_connections: Array = connections.get(event_type, [])
	existing_connections.append(callable)
	connections[event_type] = existing_connections


func send_event(event: GameEvent):
	var event_type: Script = event.get_script()
	if connections.has(event_type):
		for callable: Callable in connections[event_type]:
			callable.call(event)


func _is_subclass_of_script(script: Script, base_script: Script) -> bool:
	var current: Script = script
	while current != null:
		if current == base_script:
			return true
		current = current.get_base_script()
	return false
