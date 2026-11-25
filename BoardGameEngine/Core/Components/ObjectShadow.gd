@tool
class_name ObjectShadow
extends TextureRect
## Add this as a CHILD of a TextureRect (your object). It draws a drop shadow
## behind the object, outside the object's rect, without touching the object itself.
##
## By default the parent is the source of the silhouette. Set `source` to use a
## different TextureRect instead (it must be the parent or a sibling). This is how
## a stack uses the silhouette of its bottom object.
##
## - Follows the object's texture, size, position, rotation and scale automatically.
## - `elevation` scales offset + blur: tween it up when a object is picked up.
## - `object_thickness` makes the object a slab instead of a sheet of paper.
## - `casts_shadow = false` hides the shadow but keeps the optional edge.
## - Keeps the light direction fixed in world space while the object rotates.

const SHADER := preload("res://BoardGameEngine/Resources/shaders/drop_shadow.gdshader")

@export_group("Shadow")
## Turn the shadow off while keeping the edge (used for objects inside a stack).
@export var casts_shadow := true:
	set(v):
		casts_shadow = v
		_apply()
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
## Draw a visible side/edge for the thickness, extruded from the object's silhouette.
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

## The TextureRect whose silhouette is used. Defaults to the parent.
## Must be the parent or a sibling of this node.
var source: TextureRect:
	get:
		return _object
	set(v):
		if v == _object:
			return
		if is_instance_valid(_object) and _object.resized.is_connected(_layout):
			_object.resized.disconnect(_layout)
		_object = v
		if is_instance_valid(_object):
			_object.resized.connect(_layout)
		_layout()

var _object: TextureRect
var _margin := 0.0
var _last_pos := Vector2.INF
var _last_size := Vector2.INF


func _ready() -> void:
	show_behind_parent = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE

	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material = mat

	if not is_instance_valid(_object):
		source = get_parent() as TextureRect
	else:
		_layout()


func _process(_delta: float) -> void:
	if not is_instance_valid(_object):
		source = get_parent() as TextureRect # fall back to the parent
		if not is_instance_valid(_object):
			return
	if texture != _object.texture:
		texture = _object.texture
	# The source can move/resize inside its parent without emitting `resized`.
	if _object.position != _last_pos or _object.size != _last_size:
		_layout()
	_apply() # cheap; keeps the light direction correct while the object rotates


func _layout() -> void:
	if not is_instance_valid(_object):
		return
	# Room for the largest shadow (offset + blur at max elevation) plus the thickness sweep.
	_margin = ceil((light_offset.length() + blur) * max_elevation + object_thickness)

	# Our position lives in our parent's space. If the source IS the parent its
	# origin is (0, 0) there; if it's a sibling, it is wherever it sits.
	var origin := Vector2.ZERO if _object == get_parent() else _object.position
	position = origin - Vector2(_margin, _margin)
	size = _object.size + Vector2(_margin, _margin) * 2.0
	# Rotate/scale around the same point as the object does.
	pivot_offset = _object.pivot_offset + Vector2(_margin, _margin)
	texture = _object.texture

	_last_pos = _object.position
	_last_size = _object.size
	_apply()


func _apply() -> void:
	var mat := material as ShaderMaterial
	if mat == null or not is_instance_valid(_object):
		return
	var e := clampf(elevation, 0.0, max_elevation)

	# World-space light -> the object's local space, so the shadow doesn't spin with the object.
	var world_to_local = -_object.get_global_transform().get_rotation() if keep_light_direction else 0.0
	var off := (light_offset * e).rotated(world_to_local)

	# Thickness sweeps the shadow further along the light direction.
	var light_dir := light_offset.normalized() if light_offset.length() > 0.001 else Vector2(0.0, 1.0)
	var shadow_dir := light_dir.rotated(world_to_local)

	var edge_dir := edge_direction.normalized() if edge_direction.length() > 0.001 else Vector2(0.0, 1.0)
	edge_dir = edge_dir.rotated(world_to_local)

	var sc := shadow_color
	if not casts_shadow:
		sc.a = 0.0
	var ec := edge_color
	if not show_edge:
		ec.a = 0.0

	mat.set_shader_parameter("shadow_color", sc)
	mat.set_shader_parameter("object_size", _object.size)
	mat.set_shader_parameter("margin", _margin)
	mat.set_shader_parameter("shadow_offset", off)
	mat.set_shader_parameter("shadow_blur", blur * e)
	mat.set_shader_parameter("shadow_strength", strength)
	mat.set_shader_parameter("object_thickness", object_thickness)
	mat.set_shader_parameter("shadow_dir", shadow_dir)
	mat.set_shader_parameter("edge_color", ec)
	mat.set_shader_parameter("edge_dir", edge_dir)
