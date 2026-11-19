class_name SelectionBorder extends Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size).grow(2), Color.HOT_PINK, false, 4.0)
