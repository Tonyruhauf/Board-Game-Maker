extends Node


var connections: Dictionary[GameEvent, Array]


func connect_event(event: GameEvent, callable: Callable):
	var existing_connections: Array = connections.get(event, [])
	existing_connections.append(callable)
	
	connections[event] = existing_connections


func send_event(event: GameEvent):
	for callable: Callable in connections.get(event, []):
		callable.call(event)
