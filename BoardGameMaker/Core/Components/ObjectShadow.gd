@tool
class_name ObjectShadow
extends TextureRect
## Add this as a CHILD of a TextureRect (your card). It draws a drop shadow
## behind the card, outside the card's rect, without touching the card itself.
##
## - Follows the card's texture, size, position, rotation and scale automatically.
## - `elevation` scales offset + blur: tween it up when a card is picked up.
## - `object_thickness` makes the object a slab instead of a sheet of paper.
## - Keeps the light direction fixed in world space while the card rotates.

const SHADER := preload("res://BoardGameMaker/Resources/shaders/drop_shadow.gdshader")

@export_group("Shadow")
@export var shadow_color := Color(0.0, 0.0, 0.0, 0.45):
	set(v):
		shadow_color = v
		_apply()
## Shadow offset in px at elevation 1.0, in WORLD space (x right, y down).
@export var light_offset := Vector2(3.0, 5.0):
	set(v):
		light_offset = v
		_layout()
## Blur radius in px at elevation 1.0.
@export var blur := 4.0:
	set(v):
		blur = v
		_layout()
## 0 = card lying flat, higher = lifted. Tween this for pick-up / drop.
@export_range(0.0, 8.0, 0.01) var elevation := 0.0:
	set(v):
		elevation = v
		_apply()
## Highest elevation you will use. Decides how much room the shadow node reserves.
@export_range(1.0, 8.0, 0.1) var max_elevation := 4.0:
	set(v):
		max_elevation = v
		_layout()
@export_range(0.0, 4.0, 0.01) var strength := 1.0:
	set(v):
		strength = v
		_apply()
@export var keep_light_direction := true

@export_group("Thickness")
## Thickness of the object in px. 0 = perfectly flat sheet. A playing card is ~1-2 px,
## a chunky token or tile ~4-10 px. Not scaled by elevation (it's a physical property).
@export_range(0.0, 64.0, 0.1) var object_thickness := 4.0:
	set(v):
		object_thickness = v
		_layout()
## Draw a visible side/edge for the thickness, extruded from the card's silhouette.
@export var show_edge := false:
	set(v):
		show_edge = v
		_apply()
@export var edge_color := Color(0.12, 0.12, 0.12, 1.0):
	set(v):
		edge_color = v
		_apply()
## Direction (world space) in which the side of the object is visible, e.g. (0, 1) = bottom edge.
@export var edge_direction := Vector2(0.0, 1.0):
	set(v):
		edge_direction = v
		_apply()

var _card: TextureRect
var _margin := 0.0


func _ready() -> void:
	show_behind_parent = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE

	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material = mat

	_card = get_parent() as TextureRect
	if _card:
		_card.resized.connect(_layout)
	_layout()


func _process(_delta: float) -> void:
	if _card == null:
		_card = get_parent() as TextureRect
		if _card == null:
			return
		_card.resized.connect(_layout)
		_layout()
	if texture != _card.texture:
		texture = _card.texture
	_apply() # cheap; keeps the light direction correct while the card rotates


func _layout() -> void:
	if _card == null:
		return
	# Room for the largest shadow (offset + blur at max elevation) plus the thickness sweep.
	_margin = ceil((light_offset.length() + blur) * max_elevation + object_thickness)
	position = Vector2(-_margin, -_margin)
	size = _card.size + Vector2(_margin, _margin) * 2.0
	# Rotate/scale around the same point as the card does.
	pivot_offset = _card.pivot_offset + Vector2(_margin, _margin)
	texture = _card.texture
	_apply()


func _apply() -> void:
	var mat := material as ShaderMaterial
	if mat == null or _card == null:
		return
	var e := clampf(elevation, 0.0, max_elevation)

	# World-space light -> the card's local space, so the shadow doesn't spin with the card.
	var world_to_local = -_card.get_global_transform().get_rotation() if keep_light_direction else 0.0
	var off := (light_offset * e).rotated(world_to_local)

	# Thickness sweeps the shadow further along the light direction.
	var light_dir := light_offset.normalized() if light_offset.length() > 0.001 else Vector2(0.0, 1.0)
	var shadow_dir := light_dir.rotated(world_to_local)

	var edge_dir := edge_direction.normalized() if edge_direction.length() > 0.001 else Vector2(0.0, 1.0)
	edge_dir = edge_dir.rotated(world_to_local)

	var ec := edge_color
	if not show_edge:
		ec.a = 0.0

	mat.set_shader_parameter("shadow_color", shadow_color)
	mat.set_shader_parameter("card_size", _card.size)
	mat.set_shader_parameter("margin", _margin)
	mat.set_shader_parameter("shadow_offset", off)
	mat.set_shader_parameter("shadow_blur", blur * e)
	mat.set_shader_parameter("shadow_strength", strength)
	mat.set_shader_parameter("object_thickness", object_thickness)
	mat.set_shader_parameter("shadow_dir", shadow_dir)
	mat.set_shader_parameter("edge_color", ec)
	mat.set_shader_parameter("edge_dir", edge_dir)
