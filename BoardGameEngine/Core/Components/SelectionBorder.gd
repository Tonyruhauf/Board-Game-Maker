class_name SelectionBorder extends Control

const OUTLINE_WIDTH: float = 4.0  # In the object's local pixels, divided by its own scale
const OUTLINE_COLOR: Color = Color.HOT_PINK
const SAMPLES: int = 24

const FLAT_COLOR_SHADER: String = """
shader_type canvas_item;
uniform vec4 flat_color : source_color = vec4(1.0);
void fragment() {
	COLOR = vec4(flat_color.rgb, COLOR.a * flat_color.a);
}
"""

var _parent: BoardObject
var use_only_rect: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	show_behind_parent = true  # Draw under the parent, so only the outline shows
	
	if not use_only_rect:
		var shader := Shader.new()
		shader.code = FLAT_COLOR_SHADER
		material = ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("flat_color", OUTLINE_COLOR)


func _ready() -> void:
	_parent = get_parent() as BoardObject


func _draw() -> void:
	if not _parent:
		return
	
	if use_only_rect or not _parent.texture:
		draw_rect(Rect2(Vector2.ZERO, size).grow(2), Color.HOT_PINK, false, 4.0)
		return
	
	# Compensate only the object's own scale, so the outline looks equally thick
	var local_width: Vector2 = Vector2.ONE * OUTLINE_WIDTH / _parent.scale.abs().max(Vector2.ONE * 0.0001)
	var rect := Rect2(Vector2.ZERO, _parent.size)
	
	for i in SAMPLES:
		var angle: float = TAU * float(i) / float(SAMPLES)
		var offset := Vector2(cos(angle), sin(angle)) * local_width
		draw_texture_rect(_parent.texture, Rect2(rect.position + offset, rect.size), false)
