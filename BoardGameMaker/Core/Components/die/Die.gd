@tool
@icon("res://BoardGameMaker/Shared Assets/dice-icon.png")
class_name Die extends BoardObject


@export var data: DieData:
	set(v):
		if v == null:
			if data != null and data.changed.is_connected(queue_redraw):
				data.changed.disconnect(queue_redraw)
		elif not v.changed.is_connected(queue_redraw):
			v.changed.connect(queue_redraw)
		data = v
		queue_redraw()

@export_group("Look")
## Direction the light comes from, in degrees (225 = top-left).
@export_range(0.0, 360.0) var light_angle: float = 225.0:
	set(v):
		light_angle = v
		queue_redraw()
@export var draw_shadow: bool = true:
	set(v):
		draw_shadow = v
		queue_redraw()
## Light/dark shading on the die itself (bevels, facets, gradients, rim light).
## Disable for a flat-colored die.
@export var draw_shading: bool = true:
	set(v):
		draw_shading = v
		queue_redraw()
## Pip size multiplier. 1.2 is the default size.
@export_range(0.5, 2.0, 0.05) var pip_size: float = 1.2:
	set(v):
		pip_size = v
		queue_redraw()
## Optional custom font for numbers. Leave empty for an emboldened default font.
@export var font: Font:
	set(v):
		font = v
		queue_redraw()

# Internals
# ----------------------------------------------------------------------------
var side_index: int = 0
var is_rolling: bool = false

var _die_center := Vector2.ZERO
var _unit := 1.0
var _sil := PackedVector2Array()
var _facets: Array[Dictionary] = []
var _face_poly := PackedVector2Array()
var _bold_font: FontVariation
var _bevel_mode := false

const ROLE_FACE := 0   # the main (front) face, holds the value
const ROLE_SIDE := 1   # other visible faces of a polyhedron
const ROLE_BEVEL := 2  # chamfered edge pieces (d4 / d6 / d10)

const _TL := Vector2(-1, -1)
const _TR := Vector2(1, -1)
const _BL := Vector2(-1, 1)
const _BR := Vector2(1, 1)
const _ML := Vector2(-1, 0)
const _MR := Vector2(1, 0)
const _TM := Vector2(0, -1)
const _BM := Vector2(0, 1)
const _C := Vector2(0, 0)

const PIP_LAYOUTS := {
	1: [_C],
	2: [_TL, _BR],
	3: [_TL, _C, _BR],
	4: [_TL, _TR, _BL, _BR],
	5: [_TL, _TR, _C, _BL, _BR],
	6: [_TL, _ML, _BL, _TR, _MR, _BR],
	7: [_TL, _ML, _BL, _TR, _MR, _BR, _C],
	8: [_TL, _ML, _BL, _TR, _MR, _BR, _TM, _BM],
	9: [_TL, _ML, _BL, _TR, _MR, _BR, _TM, _BM, _C],
}

const ROLL_ANIMATION_DURATION: float = 2.5
const SHAKE_STEPS: int = 50

signal shake_animation_finished
signal face_animation_finished


func _init() -> void:
	super()
	custom_minimum_size = Vector2(160, 160)


func _ready() -> void:
	super()
	resized.connect(queue_redraw)


func _input(event: InputEvent) -> void:
	super(event)
	
	if event.is_action_pressed("roll_dice") and hovered:
		request_roll()
	
	if event.is_action_pressed("flip_object") and hovered:
		request_flip()


## Rolls the die (random side) and returns its value.
func roll() -> String:
	if is_rolling:
		return ""
	is_rolling = true
	
	_play_face_animation()
	_play_shake_animation()
	
	await face_animation_finished
	await shake_animation_finished
	is_rolling = false
	return get_current_side().text


func flip_side() -> void:
	if is_rolling: return
	
	side_index = (side_index + 1) % get_sides_count()
	shake()


func get_text() -> String:
	var side: DieSide = get_current_side()
	if not side: return ""
	return side.text


func get_current_side() -> DieSide:
	if data.sides.size() <= side_index: return null
	return data.sides.get(side_index)


func get_sides_count() -> int:
	if not data: return 0
	return data.sides.size()


func request_roll() -> void:
	var action: GameAction = RollDieAction.new(
		GameService.local_player.ID,
		id
	)
	game.request_action(action)


func request_flip() -> void:
	var action: GameAction = FlipDieAction.new(
		GameService.local_player.ID,
		id
	)
	game.request_action(action)


func can_interact() -> bool:
	if not super():
		return false
	return not is_rolling


func _play_face_animation() -> void:
	var delay := 0.0
	var slowdown_speed := 0.01
	var previous_side_index := side_index
	
	for i in 24:
		await get_tree().create_timer(delay).timeout
	
		var new_side_index := randi_range(0, data.sides.size() - 2)
		if new_side_index >= previous_side_index:
			new_side_index += 1
		
		side_index = new_side_index
		previous_side_index = side_index
		
		queue_redraw()
		delay += slowdown_speed
	
	await get_tree().create_timer(maxf(0.0, ROLL_ANIMATION_DURATION - 2.76)).timeout
	face_animation_finished.emit()


func _play_shake_animation() -> void:
	for i in SHAKE_STEPS:
		await shake()
	shake_animation_finished.emit()


func shake() -> void:
	var delay: float = ROLL_ANIMATION_DURATION / SHAKE_STEPS
	
	position = original_pos + Vector2(
		randf_range(-5.0, 5.0),
		randf_range(-5.0, 5.0)
	)
	
	queue_redraw()
	await get_tree().create_timer(delay).timeout
	return_to_origin()


# Drawing
# ----------------------------------------------------------------------------
func _draw() -> void:
	super()
	if not data: return
	
	var c := size * 0.5
	_unit = minf(size.x, size.y) * 0.5 * 0.88
	_build_geometry(c, _unit)

	var light := Vector2.from_angle(deg_to_rad(light_angle))
	if draw_shadow:
		_draw_shadow(light)
	_draw_body(light)
	_draw_value()


func _draw_shadow(light: Vector2) -> void:
	for i in 6:
		var off := -light * _unit * 0.035 * (i + 1)
		draw_colored_polygon(Transform2D(0.0, off) * _sil, Color(0, 0, 0, 0.07))


func _draw_body(light: Vector2) -> void:
	var outline := data.body_color.darkened(0.7)
	outline.a = 1.0

	# Underlay so there are never hairline gaps between facets.
	draw_colored_polygon(_sil, data.body_color.darkened(0.3))

	for f in _facets:
		var pts: PackedVector2Array = f["pts"]
		var role: int = f["role"]
		var cen := _centroid(pts)

		if not draw_shading:
			draw_colored_polygon(pts, data.body_color)
		elif role == ROLE_FACE:
			# Smooth gradient across the front face (per-vertex colors).
			var reach := 1.0
			for p in pts:
				reach = maxf(reach, p.distance_to(cen))
			var cols := PackedColorArray()
			for p in pts:
				var g := clampf((p - cen).dot(light) / reach, -1.0, 1.0)
				cols.append(_shade(data.body_color, g * 0.14))
			draw_polygon(pts, cols)
		elif role == ROLE_BEVEL:
			# Per-vertex colors from smooth normals: no hard steps at the rounded corners,
			# and the bevel fades into the front face like a real rounded edge.
			var nrm: PackedVector2Array = f["normals"]
			var ka := nrm[0].dot(light)
			var kb := nrm[1].dot(light)
			var outer_k := 0.45
			var inner_k := 0.05 * 0.5
			var cols := PackedColorArray([
				_shade(data.body_color, ka * outer_k), _shade(data.body_color, kb * outer_k),
				_shade(data.body_color, kb * inner_k), _shade(data.body_color, ka * inner_k)
			])
			draw_polygon(pts, cols)
		else:
			var n := (cen - _die_center).normalized()
			var k := n.dot(light)
			draw_colored_polygon(pts, _shade(data.body_color, k * 0.3 - 0.08))

	# Thin facet edges.
	var thin := maxf(1.0, _unit * 0.012)
	for f in _facets:
		var role: int = f["role"]
		if role == ROLE_BEVEL:
			continue
		# On beveled dice the face edge is soft when shaded (the gradient does the work).
		var a := 0.55
		if _bevel_mode and draw_shading:
			a = 0.18
		_stroke_closed(f["pts"], Color(outline, a), thin)

	# Rim light on the edges that face the light.
	var w := maxf(2.0, _unit * 0.03)
	var n_sil := _sil.size()
	for i in (n_sil if draw_shading else 0):
		var a := _sil[i]
		var b := _sil[(i + 1) % n_sil]
		var nrm := ((a + b) * 0.5 - _die_center).normalized()
		var k := nrm.dot(light)
		if k > 0.15:
			draw_line(a - nrm * w * 1.1, b - nrm * w * 1.1, Color(1, 1, 1, 0.5 * k), w * 0.7, true)

	# Silhouette outline with rounded joints.
	_stroke_closed(_sil, outline, w)
	if n_sil <= 12:
		for p in _sil:
			draw_circle(p, w * 0.5, outline)


func _draw_value() -> void:
	var text: String = get_text()
	if text.is_empty(): return
	
	var center := _centroid(_face_poly)
	var fit := 1.15 if _face_poly.size() == 3 else 1.0
	var radius := _inradius(_face_poly, center) * fit

	var text_is_valid_pip = text.is_valid_int() and int(text) >= 0 and int(text) <= 9

	if text_is_valid_pip and get_current_side().use_pips:
		_draw_pips(center, radius)
	else:
		_draw_label(center, radius, text)


func _draw_pips(c: Vector2, r: float) -> void:
	var value: int = int(get_text())
	var g := r * 0.56
	var pip_r := g * 0.34 * pip_size

	if value == 0:
		# Zero: an empty face.
		return

	var layout: Array = PIP_LAYOUTS[value]
	for p in layout:
		var pt: Vector2 = p
		_draw_pip(c + pt * g, pip_r)


func _draw_pip(p: Vector2, radius: float) -> void:
	# Engraved look: lower lip highlight, dark rim, painted fill, little gloss.
	draw_circle(p + Vector2(0, radius * 0.16), radius * 1.1, Color(1, 1, 1, 0.25))
	draw_circle(p, radius * 1.1, Color(0, 0, 0, 0.4))
	draw_circle(p, radius, data.pip_color)
	draw_circle(p + Vector2(-radius * 0.28, -radius * 0.3), radius * 0.35, Color(1, 1, 1, 0.35))


func _draw_label(c: Vector2, r: float, text: String) -> void:
	var f := _get_font()
	var max_w := r * 1.55
	var max_fs := r * 1.3

	var test_size := 64
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, test_size).x
	var fs := mini(int(max_fs), int(test_size * max_w / maxf(w, 1.0)))
	fs = maxi(fs, 8)

	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# Digits sit on the baseline with cap height of about 0.72 em.
	var pos := Vector2(c.x - tw * 0.5, c.y + fs * 0.36)

	var o := maxi(2, int(fs * 0.12))
	draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, o, Color(0, 0, 0, 0.35))
	draw_string(f, pos + Vector2(0, maxf(1.0, fs * 0.04)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.3))
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, data.pip_color)


func _get_font() -> Font:
	if font != null:
		return font
	if _bold_font == null:
		_bold_font = FontVariation.new()
		_bold_font.base_font = ThemeDB.fallback_font
		_bold_font.variation_embolden = 0.5
	return _bold_font


# ----------------------------------------------------------------------------
# Geometry per die type
# ----------------------------------------------------------------------------
func _build_geometry(c: Vector2, R: float) -> void:
	_facets.clear()
	_die_center = c
	_bevel_mode = false
	match data.die_type:
		4:
			_build_bevel(_ngon(c + Vector2(0, R * 0.2), R * 1.12, 3, -90.0), R * 0.14, 0.7)
		8:
			_build_d8(c, R)
		10:
			_build_d10(c, R)
		12:
			_build_d12(c, R)
		20:
			_build_d20(c, R)
		_:
			_build_d6(c, R)


func _build_d6(c: Vector2, R: float) -> void:
	var h := R * 0.84
	var v := PackedVector2Array([
		c + Vector2(-h, -h), c + Vector2(h, -h), c + Vector2(h, h), c + Vector2(-h, h)
	])
	_build_bevel(v, R * 0.2, 0.76)


func _build_d10(c: Vector2, R: float) -> void:
	# Face-on kite, like one face of the pentagonal trapezohedron.
	var v := PackedVector2Array([
		c + Vector2(0, -R), c + Vector2(R * 0.82, -R * 0.2),
		c + Vector2(0, R), c + Vector2(-R * 0.82, -R * 0.2)
	])
	_build_bevel(v, R * 0.1, 0.72)


func _build_d8(c: Vector2, R: float) -> void:
	# Octahedron seen along a face normal: hexagon = big central triangle + 3 neighbors.
	var h := _ngon(c, R, 6, -90.0)
	_sil = h
	_face_poly = PackedVector2Array([h[0], h[2], h[4]])
	_facets.append({"pts": PackedVector2Array([h[0], h[2], h[1]]), "role": ROLE_SIDE})
	_facets.append({"pts": PackedVector2Array([h[2], h[4], h[3]]), "role": ROLE_SIDE})
	_facets.append({"pts": PackedVector2Array([h[4], h[0], h[5]]), "role": ROLE_SIDE})
	_facets.append({"pts": _face_poly, "role": ROLE_FACE})


func _build_d12(c: Vector2, R: float) -> void:
	# Dodecahedron seen along a face normal: central pentagon ringed by 5 pentagons.
	var o := _ngon(c, R, 10, -90.0)
	var v := _ngon(c, R * 0.618, 5, -90.0)
	_sil = o
	_face_poly = v
	for i in 5:
		_facets.append({
			"pts": PackedVector2Array([v[i], v[(i + 1) % 5], o[(2 * i + 2) % 10], o[2 * i + 1], o[2 * i]]),
			"role": ROLE_SIDE
		})
	_facets.append({"pts": v, "role": ROLE_FACE})


func _build_d20(c: Vector2, R: float) -> void:
	# Icosahedron seen along a face normal: hexagon, central triangle, 9 more triangles.
	var h := _ngon(c, R, 6, -90.0)
	var t := _ngon(c, R * 0.66, 3, -90.0)
	_sil = h
	_face_poly = t
	for j in 3:
		var j2 := (j + 1) % 3
		_facets.append({"pts": PackedVector2Array([t[j], t[j2], h[2 * j + 1]]), "role": ROLE_SIDE})
		_facets.append({"pts": PackedVector2Array([t[j], h[2 * j], h[2 * j + 1]]), "role": ROLE_SIDE})
		_facets.append({"pts": PackedVector2Array([t[j2], h[2 * j + 1], h[(2 * j + 2) % 6]]), "role": ROLE_SIDE})
	_facets.append({"pts": t, "role": ROLE_FACE})


## Rounded outer shape + inset front face + bevel quads in between.
func _build_bevel(verts: PackedVector2Array, corner_r: float, inset: float, seg: int = 14) -> void:
	var cen := _centroid(verts)
	var inner_verts := PackedVector2Array()
	for v in verts:
		inner_verts.append(cen + (v - cen) * inset)

	var outer := _rounded(verts, corner_r, seg)
	var inner := _rounded(inner_verts, corner_r * inset, seg)

	_sil = outer
	_die_center = cen
	_face_poly = inner_verts
	_bevel_mode = true

	var n := outer.size()
	# Smooth outward normal per outline point (averaged over neighbours).
	var normals := PackedVector2Array()
	for i in n:
		var tangent := (outer[(i + 1) % n] - outer[(i - 1 + n) % n]).normalized()
		var nrm := Vector2(tangent.y, -tangent.x)
		if nrm.dot(outer[i] - cen) < 0.0:
			nrm = -nrm
		normals.append(nrm)

	for i in n:
		var j := (i + 1) % n
		_facets.append({
			"pts": PackedVector2Array([outer[i], outer[j], inner[j], inner[i]]),
			"normals": PackedVector2Array([normals[i], normals[j]]),
			"role": ROLE_BEVEL
		})
	_facets.append({"pts": inner, "role": ROLE_FACE})


# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
func _ngon(c: Vector2, r: float, n: int, start_deg: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		out.append(c + Vector2.from_angle(deg_to_rad(start_deg + 360.0 * i / n)) * r)
	return out


## Returns a convex polygon with its corners replaced by arcs of the given radius.
func _rounded(verts: PackedVector2Array, radius: float, seg: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := verts.size()
	for i in n:
		var p := verts[i]
		var prev := verts[(i - 1 + n) % n]
		var next := verts[(i + 1) % n]
		var d1 := (prev - p).normalized()
		var d2 := (next - p).normalized()
		var half := acos(clampf(d1.dot(d2), -1.0, 1.0)) * 0.5
		var tan_h := tan(half)
		var dist := radius / tan_h
		var max_d := minf(p.distance_to(prev), p.distance_to(next)) * 0.5
		dist = minf(dist, max_d)
		var r := dist * tan_h
		var arc_c := p + (d1 + d2).normalized() * (r / sin(half))
		var a0 := (p + d1 * dist - arc_c).angle()
		var a1 := (p + d2 * dist - arc_c).angle()
		var delta := angle_difference(a0, a1)
		for s in seg + 1:
			out.append(arc_c + Vector2.from_angle(a0 + delta * float(s) / float(seg)) * r)
	return out


func _centroid(p: PackedVector2Array) -> Vector2:
	var area := 0.0
	var cx := 0.0
	var cy := 0.0
	var n := p.size()
	for i in n:
		var a := p[i]
		var b := p[(i + 1) % n]
		var cr := a.x * b.y - b.x * a.y
		area += cr
		cx += (a.x + b.x) * cr
		cy += (a.y + b.y) * cr
	if absf(area) < 0.0001:
		return p[0]
	return Vector2(cx, cy) / (3.0 * area)


## Radius of the biggest circle around `c` that fits inside the convex polygon.
func _inradius(p: PackedVector2Array, c: Vector2) -> float:
	var best := INF
	var n := p.size()
	for i in n:
		var q := Geometry2D.get_closest_point_to_segment(c, p[i], p[(i + 1) % n])
		best = minf(best, c.distance_to(q))
	return best


func _shade(c: Color, k: float) -> Color:
	return c.lightened(k) if k > 0.0 else c.darkened(-k)


func _stroke_closed(pts: PackedVector2Array, col: Color, w: float) -> void:
	var arr: PackedVector2Array = pts.duplicate()
	arr.append(pts[0])
	draw_polyline(arr, col, w, true)
