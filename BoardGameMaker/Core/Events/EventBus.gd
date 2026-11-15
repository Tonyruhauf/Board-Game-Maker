extends Node


var connections: Dictionary[Script, Array]


func connect_action_event(action_type: Script, callable: Callable) -> void:
	assert(_is_subclass_of_script(action_type, GameAction))
	
	var existing_connections: Array = connections.get(action_type, [])
	
	if existing_connections.has(callable):
		return
	
	existing_connections.append(callable)
	connections[action_type] = existing_connections


func emit_action_event(action: GameAction) -> void:
	var current: Script = action.get_script()
	
	while current != null:
		if connections.has(current):
			for callable: Callable in connections[current]:
				if callable.is_valid():
					callable.call(action)
		
		current = current.get_base_script()


func disconnect_action_event(action_type: Script, callable: Callable) -> void:
	if not connections.has(action_type):
		return
	
	connections[action_type].erase(callable)
	
	if connections[action_type].is_empty():
		connections.erase(action_type)


func _is_subclass_of_script(script: Script, base_script: Script) -> bool:
	var current: Script = script
	while current != null:
		if current == base_script:
			return true
		current = current.get_base_script()
	return false
