class_name BoardGame extends Node


func setup() -> void:
	pass


func start() -> void:
	pass


func end() -> void:
	pass


func reset() -> void:
	pass


func request_action(action: GameAction) -> bool:
	if not validate_action(action):
		return false
	
	execute_action(action)
	return true


func validate_action(action: GameAction) -> bool:
	return false


func execute_action(action: GameAction) -> void:
	pass
