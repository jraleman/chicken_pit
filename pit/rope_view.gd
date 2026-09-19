extends Node3D

## A cosmetic, refittable rope: beaks and knot are anchors, the pit lip supplies support.

const Scenery = preload("res://games/chicken_pit/pit/scenery.gd")
const POINT_COUNT := 25
const KNOT_POINT := 12
const MAX_SAG := 0.5
const HALF_WIDTH := 0.055
const GROUND_CLEARANCE := 0.075
const ROPE_TEXTURE := preload("res://games/chicken_pit/assets/textures/rope.svg")

var reduced_motion := false
var inert := false
var _points := PackedVector3Array()
var _previous := PackedVector3Array()
var _guides := PackedVector3Array()
var _old_guides := PackedVector3Array()
var _rest_points := PackedVector3Array()
var _rest_lengths := PackedFloat32Array()
var _pinned := PackedByteArray()
var _mesh: ImmediateMesh
var _left := Vector3(-6.0, 1.18, 0.0)
var _right := Vector3(6.0, 1.18, 0.0)
var _knot := Vector3(0.0, 1.18, 0.0)
var _tension := 0.0
var _left_scale := 1.0
var _right_scale := 1.0
var _last_step := 1.0 / 60.0


func _ready() -> void:
	inert = DisplayServer.get_name() == "headless"
	if inert:
		return
	_mesh = ImmediateMesh.new()
	var instance := MeshInstance3D.new()
	instance.mesh = _mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_texture = ROPE_TEXTURE
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	add_child(instance)


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	_points.clear()
	_previous.clear()
	if not inert:
		update_rope(_left, _right, _knot, _tension, 0.0, 0.0, _left_scale, _right_scale)


func reset() -> void:
	_points.clear()
	_previous.clear()
	_guides.clear()
	_old_guides.clear()
	_rest_points.clear()
	_rest_lengths.clear()
	_pinned.clear()
	_last_step = 1.0 / 60.0


func simulation_enabled() -> bool:
	return not inert and not reduced_motion


func pull(coop: int, gain: float) -> void:
	if inert or reduced_motion or _points.is_empty():
		return
	var impulse := minf(gain / 10.35, 1.4) * 0.055
	for index in range(1, POINT_COUNT - 1):
		if _pinned[index]:
			continue
		var t := float(index) / (POINT_COUNT - 1)
		var proximity := pow(1.0 - t if coop == 0 else t, 2.0)
		_previous[index] += Vector3(0.0, -impulse,
			impulse * (-0.6 if coop == 0 else 0.6)) * proximity


func update_rope(
	left: Vector3, right: Vector3, knot: Vector3,
	tension: float, difference: float, delta: float,
	left_scale := 1.0, right_scale := 1.0
) -> void:
	var unchanged := left.is_equal_approx(_left) and right.is_equal_approx(_right) \
		and knot.is_equal_approx(_knot) and is_equal_approx(tension, _tension)
	_left = left
	_right = right
	_knot = knot
	_tension = tension
	_left_scale = left_scale
	_right_scale = right_scale
	if inert or _mesh == null:
		return
	if not reduced_motion and not _points.is_empty() and delta <= 0.0 and unchanged:
		_draw_chain(_points)
		return
	_build_guides()
	if reduced_motion:
		_draw_chain(_guides)
		return
	if _points.is_empty():
		_points.resize(POINT_COUNT)
		_previous.resize(POINT_COUNT)
		for index in POINT_COUNT:
			_points[index] = _rest_points[index]
			_previous[index] = _points[index]
	else:
		# Refit before solving so a falling bird does not leave a full-arena loop behind.
		for index in POINT_COUNT:
			var shift := _guides[index] - _old_guides[index]
			_points[index] += shift
			_previous[index] += shift
	var dt := clampf(delta, 0.0, 1.0 / 30.0)
	if dt > 0.0:
		for index in range(1, POINT_COUNT - 1):
			if _pinned[index]:
				continue
			var current := _points[index]
			var velocity := (current - _previous[index]) * exp(-dt * 8.0) * dt / _last_step
			_previous[index] = current
			var acceleration := Vector3(0.0, -5.0, difference * 0.012)
			_points[index] = current + velocity + acceleration * dt * dt
		_last_step = dt
	for iteration in 8:
		_pin_anchors()
		for index in range(POINT_COUNT - 1):
			var offset := _points[index + 1] - _points[index]
			var length := offset.length()
			if length < 0.0001 or length <= _rest_lengths[index]:
				continue
			var correction := offset * (1.0 - _rest_lengths[index] / length)
			var left_fixed := bool(_pinned[index])
			var right_fixed := bool(_pinned[index + 1])
			if not left_fixed:
				_points[index] += correction * (1.0 if right_fixed else 0.5)
			if not right_fixed:
				_points[index + 1] -= correction * (1.0 if left_fixed else 0.5)
		for index in range(1, POINT_COUNT - 1):
			if not _pinned[index]:
				_points[index].y = maxf(_points[index].y,
					Scenery.pit_surface_height(_points[index]) + GROUND_CLEARANCE)
	_pin_anchors()
	if dt <= 0.0:
		for index in POINT_COUNT:
			_previous[index] = _points[index]
	_draw_chain(_points)


func _build_guides() -> void:
	if _guides.is_empty():
		_guides.resize(POINT_COUNT)
		_old_guides.resize(POINT_COUNT)
		_rest_points.resize(POINT_COUNT)
		_rest_lengths.resize(POINT_COUNT - 1)
		_pinned.resize(POINT_COUNT)
	for index in POINT_COUNT:
		_old_guides[index] = _guides[index]
	_pinned.fill(0)
	_fill_span(0, KNOT_POINT, _left, _knot)
	_fill_span(KNOT_POINT, POINT_COUNT - 1, _knot, _right)
	for index in POINT_COUNT - 1:
		_rest_lengths[index] = _rest_points[index].distance_to(_rest_points[index + 1])


func _fill_span(first: int, last: int, from: Vector3, to: Vector3) -> void:
	var from_inside := Scenery.pit_extent(from) < Scenery.PIT_RADIUS
	var to_inside := Scenery.pit_extent(to) < Scenery.PIT_RADIUS
	var span := maxf(from.distance_to(to), 0.001)
	var sag := 0.0 if reduced_motion else minf(MAX_SAG, span * 0.16) * (1.0 - _tension)
	if from_inside == to_inside:
		_fill_piece(first, last, from, to, sag)
		return
	var inside := from if from_inside else to
	var outside := to if from_inside else from
	var inner := _rim_point(inside, outside, Scenery.PIT_RADIUS)
	var outer := _rim_point(inside, outside, Scenery.PIT_RADIUS + Scenery.PIT_RIM_WIDTH)
	# A slack span can catch the lip before its beak drops below ground.
	# Keep guides on the airborne curve until the rim actually supports them.
	inner.y = maxf(inner.y - sin(from.distance_to(inner) / span * PI) * sag,
		Scenery.PIT_EDGE_Y + GROUND_CLEARANCE)
	outer.y = maxf(outer.y - sin(from.distance_to(outer) / span * PI) * sag,
		Scenery.PIT_RIM_Y + GROUND_CLEARANCE)
	var a := inner if from_inside else outer
	var b := outer if from_inside else inner
	var before := from.distance_to(a)
	var middle := a.distance_to(b)
	var after := b.distance_to(to)
	var total := maxf(before + middle + after, 0.001)
	var a_index := clampi(first + roundi((last - first) * before / total), first + 1, last - 2)
	var b_index := clampi(first + roundi((last - first) * (before + middle) / total),
		a_index + 1, last - 1)
	_fill_piece(first, a_index, from, a, sag * pow(before / total, 2.0))
	_fill_piece(a_index, b_index, a, b, sag * pow(middle / total, 2.0))
	_fill_piece(b_index, last, b, to, sag * pow(after / total, 2.0))


func _fill_piece(first: int, last: int, from: Vector3, to: Vector3, sag: float) -> void:
	for index in range(first, last + 1):
		var t := float(index - first) / (last - first)
		_guides[index] = from.lerp(to, t)
		var rest := _guides[index] - Vector3.UP * sin(t * PI) * sag
		if index != first and index != last:
			rest.y = maxf(rest.y, Scenery.pit_surface_height(rest) + GROUND_CLEARANCE)
		_rest_points[index] = rest
	_pinned[first] = 1
	_pinned[last] = 1


func _rim_point(inside: Vector3, outside: Vector3, radius: float) -> Vector3:
	var low := 0.0
	var high := 1.0
	for iteration in 14:
		var middle := (low + high) * 0.5
		if Scenery.pit_extent(inside.lerp(outside, middle)) < radius:
			low = middle
		else:
			high = middle
	return inside.lerp(outside, (low + high) * 0.5)


func _pin_anchors() -> void:
	for index in POINT_COUNT:
		if _pinned[index]:
			_points[index] = _guides[index]
			_previous[index] = _points[index]


func _draw_chain(points: PackedVector3Array) -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var total := 0.0
	for index in range(1, points.size()):
		total += points[index].distance_to(points[index - 1])
	var camera := get_viewport().get_camera_3d()
	var distance := 0.0
	for index in points.size():
		var before := points[maxi(index - 1, 0)]
		var after := points[mini(index + 1, points.size() - 1)]
		var facing := camera.global_position - points[index] if camera != null \
			else Vector3(0.0, 0.6, 0.8)
		var sideways := (after - before).cross(facing).normalized()
		if sideways.length_squared() < 0.0001:
			sideways = Vector3.RIGHT
		if index > 0:
			distance += points[index].distance_to(points[index - 1])
		var width := HALF_WIDTH * lerpf(_left_scale, _right_scale, distance / maxf(total, 0.001))
		for side in [-1.0, 1.0]:
			_mesh.surface_set_uv(Vector2(distance * 1.8, (side + 1.0) * 0.5))
			_mesh.surface_add_vertex(points[index] + sideways * side * width)
	_mesh.surface_end()
