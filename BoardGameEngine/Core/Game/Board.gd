@tool
class_name Board extends Node2D


## Fixed world-space area the camera is allowed to see.
@export var bounds := Rect2(-1000, -1000, 2000, 2000):
	set(value):
		bounds = value
		queue_redraw()
@export var show_bounds_in_editor := true:
	set(value):
		show_bounds_in_editor = value
		queue_redraw()

var common_ui: CommonUI
var interface: Control
var hand: Hand
var camera: BoardCamera
var turn_indicator: Control

const HAND_SCENE: PackedScene = preload("res://BoardGameEngine/Systems/hand.tscn")
const TURN_INDICATOR_SCENE: PackedScene = preload("res://BoardGameEngine/UI/Components/turn_indicator.tscn")


func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	var canva_layer = CanvasLayer.new()
	
	interface = Control.new()
	interface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interface.size = get_viewport_rect().size
	
	canva_layer.add_child(interface)
	add_child(canva_layer)
	
	hand = HAND_SCENE.instantiate()
	turn_indicator = TURN_INDICATOR_SCENE.instantiate()
	interface.add_child(hand)
	interface.add_child(turn_indicator)
	
	camera = BoardCamera.new()
	camera.board = self
	add_child(camera)


func _draw() -> void:
	if Engine.is_editor_hint() and show_bounds_in_editor:
		draw_rect(bounds, Color(0.2, 0.8, 1.0, 0.8), false, 8.0)
