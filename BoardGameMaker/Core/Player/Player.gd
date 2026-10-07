class_name Player extends Resource


@export var ID: int
@export var name: String
@export var score: int

#@export var is_connected: bool  # Maybe later


func setup(_name: String) -> Player:
	ID = ResourceUID.create_id()
	name = _name
	return self
