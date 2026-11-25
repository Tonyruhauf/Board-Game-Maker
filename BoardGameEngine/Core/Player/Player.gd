class_name Player extends Resource


@export var ID: String
@export var username: String


func set_ID(_ID: String) -> Player:
	ID = _ID
	return self


func set_username(_username: String) -> Player:
	username = _username
	return self
