class_name Board extends Node2D


var interface: Control
var hand: Hand

const HAND_SCENE: PackedScene = preload("res://BoardGameMaker/Systems/hand.tscn")


func _ready() -> void:
	interface = Control.new()
	interface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interface.size = get_viewport_rect().size
	add_child(interface)
	
	hand = HAND_SCENE.instantiate()
	interface.add_child(hand)
