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

var interface: Control
var hand: Hand
var camera: BoardCamera

const HAND_SCENE: PackedScene = preload("res://BoardGameMaker/Systems/hand.tscn")


func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	var canva_layer = CanvasLayer.new()
	
	interface = Control.new()
	interface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interface.size = get_viewport_rect().size
	
	canva_layer.add_child(interface)
	add_child(canva_layer)
	
	hand = HAND_SCENE.instantiate()
	interface.add_child(hand)
	
	camera = BoardCamera.new()
	camera.board = self
	add_child(camera)


func _draw() -> void:
	if Engine.is_editor_hint() and show_bounds_in_editor:
		draw_rect(bounds, Color(0.2, 0.8, 1.0, 0.8), false, 8.0)
