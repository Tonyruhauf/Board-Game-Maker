class_name Board extends Node2D


var interface: Control
var hand: CardHand

const CARDS_HAND_SCENE: PackedScene = preload("res://BoardGameMaker/Systems/cards_hand.tscn")


func _ready() -> void:
	interface = Control.new()
	interface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interface.size = get_viewport_rect().size
	add_child(interface)
	
	hand = CARDS_HAND_SCENE.instantiate()
	interface.add_child(hand)
