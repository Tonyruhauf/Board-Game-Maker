class_name BoardCamera
extends Camera2D

@export var board: Board
@export_group("Panning")
@export var keyboard_speed := 900.0
@export var smoothing := 14.0
@export_group("Zoom")
@export var min_zoom := 0.4
@export var max_zoom := 2.5
@export var zoom_step := 1.12
@export var zoom_smoothing := 12.0

var target_position: Vector2
var target_zoom := 1.0
var _dragging := false

func _ready() -> void:
	position_smoothing_enabled = false
	global_position = board.bounds.size / 2
	target_position = global_position
	target_zoom = zoom.x
	_clamp_target()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				_dragging = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed: _zoom_at_cursor(zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed: _zoom_at_cursor(1.0 / zoom_step)
	elif event is InputEventMouseMotion and _dragging:
		target_position -= event.relative / target_zoom
	elif event is InputEventScreenDrag and event.index == 0:
		target_position -= event.relative / target_zoom
	elif event is InputEventPanGesture:
		target_position += event.delta * 20.0 / target_zoom
	elif event is InputEventMagnifyGesture:
		_zoom_at_cursor(event.factor)

func _process(delta: float) -> void:
	var dir := Input.get_vector("pan_left", "pan_right", "pan_up", "pan_down")
	if dir != Vector2.ZERO:
		target_position += dir * keyboard_speed / target_zoom * delta

	# Clamping every frame also covers window resizes and zoom changes
	_clamp_target()

	var t := 1.0 - exp(-smoothing * delta)
	var tz := 1.0 - exp(-zoom_smoothing * delta)
	global_position = global_position.lerp(target_position, t)
	var z := lerpf(zoom.x, target_zoom, tz)
	zoom = Vector2(z, z)

	if global_position.distance_squared_to(target_position) < 0.01:
		global_position = target_position

func _zoom_at_cursor(factor: float) -> void:
	var new_zoom := clampf(target_zoom * factor, min_zoom, max_zoom)
	if is_equal_approx(new_zoom, target_zoom):
		return
	var vp := get_viewport()
	var mouse_offset := vp.get_mouse_position() - vp.get_visible_rect().size * 0.5
	var world_under_cursor := target_position + mouse_offset / target_zoom
	target_zoom = new_zoom
	target_position = world_under_cursor - mouse_offset / target_zoom

func _clamp_target() -> void:
	if board == null:
		return
	var rect := board.bounds
	var half_view := get_viewport_rect().size / target_zoom * 0.5
	var min_p := rect.position + half_view
	var max_p := rect.end - half_view
	var center := rect.get_center()
	target_position.x = center.x if min_p.x > max_p.x else clampf(target_position.x, min_p.x, max_p.x)
	target_position.y = center.y if min_p.y > max_p.y else clampf(target_position.y, min_p.y, max_p.y)

func focus_on(world_pos: Vector2, new_zoom: float = -1.0) -> void:
	if new_zoom > 0.0:
		target_zoom = clampf(new_zoom, min_zoom, max_zoom)
	target_position = world_pos
