extends Camera3D

## Automatic broadcast shots, with closer coverage of the coop losing ground.
## Establish the arena, then protect the lead birds, rope and pit in close-ups.

const Scenery = preload("res://games/chicken_pit/pit/scenery.gd")
const NOTCH_METRES := 0.55
const PIN_CAMERA_SECONDS := 1.1
const SHOT_SECONDS := 8.0
const SHOTS: Array[Vector3] = [
	Vector3(-16.0, 34.0, 50.0),
	Vector3(14.0, 39.0, 46.0),
	Vector3(27.0, 30.0, 53.0),
	Vector3(-24.0, 37.0, 48.0),
]
const REST_TARGET := Vector3(0.0, 1.0, -0.65)
const SAFE_FRAME := Rect2(0.055, 0.19, 0.89, 0.74)
const MIN_DISTANCE := 10.5
const CLOSEUP_START := 0.30
const CLOSEUP_FULL := 0.78
const CLOSEUP_HEADROOM := 0.4
const PIN_HEADROOM := 1.0

var reduced_motion := false
var intense_effects := true
var stalemate_active := false
var focused_coop := -1
var _length := 10
var _target := REST_TARGET
var _kick := 0.0
var _stalemate := 0.0
var _clock := 0.0
var _yaw := 0.0
var _elevation := deg_to_rad(34.0)
var _distance := 0.0
var _motion_ready := false
var _closeup := 0.0
var _pin_winner := -1
var _pin_time := 0.0
var _pin_start_yaw := 0.0
var _pin_start_elevation := 0.0
var _pin_start_fov := 50.0
var _subjects := PackedVector4Array()
var _action_subjects := PackedVector4Array()
var _coop_centres := PackedVector3Array()
var _wide_subjects := PackedVector4Array()


func reset(rope_length: int) -> void:
	_length = rope_length
	_target = REST_TARGET
	_kick = 0.0
	_stalemate = 0.0
	_clock = 0.0
	_yaw = deg_to_rad(SHOTS[0].x)
	_elevation = deg_to_rad(SHOTS[0].y)
	_distance = 0.0
	_motion_ready = false
	_closeup = 0.0
	stalemate_active = false
	focused_coop = -1
	_pin_winner = -1
	_pin_time = 0.0
	_subjects = PackedVector4Array()
	_action_subjects = PackedVector4Array()
	_coop_centres = PackedVector3Array()
	_build_wide_subjects()
	fov = SHOTS[0].z
	update_camera(0.0, 0.0, 0.0)


## xyz is a world-space centre, w a conservative radius; zero-radius entries are landmarks.
## Action bounds exclude rear birds/scenery, but must include both grips and the visible knot.
func set_subjects(
	subjects: PackedVector4Array, coop_centres: PackedVector3Array,
	action_subjects := PackedVector4Array()
) -> void:
	_subjects = subjects
	_coop_centres = coop_centres
	_action_subjects = action_subjects


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	_kick = 0.0
	update_camera(0.0, 0.0, 0.0)


func set_intense_effects(value: bool) -> void:
	intense_effects = value
	if not value:
		_kick = 0.0


func pull(coop: int, gain: float) -> void:
	if not reduced_motion and intense_effects:
		_kick = clampf(_kick + (-1.0 if coop == 0 else 1.0)
			* minf(gain / 10.35, 1.0) * 0.06, -0.12, 0.12)


func play_pin(winner: int) -> void:
	if _pin_winner >= 0:
		return
	_pin_winner = winner
	_pin_time = 0.0
	_pin_start_yaw = _yaw
	_pin_start_elevation = _elevation
	_pin_start_fov = fov


func update_camera(
	delta: float, rope: float, difference: float, total_strength := 0.0,
	pin_elapsed := -1.0
) -> void:
	if _wide_subjects.is_empty():
		_build_wide_subjects()
	var view_size := get_viewport().get_visible_rect().size
	var aspect := maxf(view_size.x / maxf(view_size.y, 1.0), 0.3)
	if _pin_winner >= 0:
		_pin_time = maxf(_pin_time, pin_elapsed) if pin_elapsed >= 0.0 else _pin_time + maxf(delta, 0.0)
	if reduced_motion:
		focused_coop = -1
		_target = REST_TARGET
		_yaw = 0.0
		_elevation = deg_to_rad(36.0)
		_closeup = 0.0
		fov = 54.0
		var fixed_basis := _view_basis(_yaw, _elevation)
		_distance = _fit_distance(_wide_subjects, fixed_basis, aspect) * 1.06
		position = _target + fixed_basis.z * _distance
		basis = fixed_basis
		_motion_ready = true
		return

	var dt := maxf(delta, 0.0)
	if dt > 0.0:
		_clock += dt
		_kick *= exp(-dt / 0.15)
		_stalemate = _stalemate + dt if absf(difference) < 1.5 and total_strength > 15.0 \
			else 0.0
		stalemate_active = _stalemate > 0.8
	var index := floori(_clock / SHOT_SECONDS) % SHOTS.size()
	var blend := smoothstep(0.0, 1.0, fmod(_clock, SHOT_SECONDS) / SHOT_SECONDS)
	var shot := SHOTS[index].lerp(SHOTS[(index + 1) % SHOTS.size()], blend)
	var ground_loss := absf(rope) / _length
	var pressure := smoothstep(0.08, 0.85, ground_loss)
	var desired_closeup := 1.0 if _pin_winner >= 0 else smoothstep(CLOSEUP_START, CLOSEUP_FULL, ground_loss)
	var response := 1.0 - exp(-dt * (7.0 if _pin_winner >= 0 else 2.8)) if _motion_ready else 1.0
	_closeup = lerpf(_closeup, desired_closeup, response)
	var loser := 1 if rope > 0.0 else 0
	var side := 1.0 if loser == 1 else -1.0
	focused_coop = loser if pressure > 0.05 else -1
	var target := REST_TARGET.lerp(_coop_centre(loser, rope), pressure * 0.18 + _closeup * 0.28)
	var desired_yaw := lerpf(deg_to_rad(shot.x), side * deg_to_rad(42.0), pressure * 0.88)
	var desired_elevation := lerpf(deg_to_rad(shot.y), deg_to_rad(22.0), _closeup)
	var desired_fov := clampf(shot.z - _closeup * 17.0 - (2.0 if stalemate_active else 0.0), 30.0, 54.0)
	if _pin_winner >= 0:
		var amount := smoothstep(0.0, PIN_CAMERA_SECONDS, _pin_time)
		loser = 1 - _pin_winner
		side = 1.0 if loser == 1 else -1.0
		focused_coop = loser
		target = REST_TARGET.lerp(_coop_centre(loser, rope), 0.60)
		# Arc back toward the pit's front: a side-on fall shot makes the far
		# grip force a pull-back just when the audience needs to see the hole.
		desired_yaw = lerpf(_pin_start_yaw, side * deg_to_rad(12.0), amount)
		desired_elevation = lerpf(_pin_start_elevation, deg_to_rad(42.0), amount)
		desired_fov = lerpf(_pin_start_fov, 28.0, amount)
	# Leave HUD headroom for the more distant bird instead of defeating zoom with a dolly out.
	target.y += _closeup * (PIN_HEADROOM if _pin_winner >= 0 else CLOSEUP_HEADROOM)
	_target = _target.lerp(target, response)
	_yaw = lerp_angle(_yaw, desired_yaw, response)
	_elevation = lerpf(_elevation, desired_elevation, response)
	var lens_response := 1.0 - exp(-dt * (7.0 if _pin_winner >= 0 else 2.2)) if _motion_ready else 1.0
	if lens_response > 0.0:
		var focal_length := lerpf(1.0 / tan(deg_to_rad(fov * 0.5)),
			1.0 / tan(deg_to_rad(desired_fov * 0.5)), lens_response)
		fov = rad_to_deg(2.0 * atan(1.0 / focal_length))
	var view_basis := _view_basis(_yaw, _elevation)
	var subjects := _subjects if not _subjects.is_empty() else _wide_subjects
	var action := _action_subjects if not _action_subjects.is_empty() else subjects
	var wide_distance := _fit_distance(subjects, view_basis, aspect)
	var action_distance := _fit_distance(action, view_basis, aspect)
	var wanted := lerpf(wide_distance * 1.22, action_distance * 1.035, _closeup)
	var dolly_speed := 7.0 if _pin_winner >= 0 else (3.8 if wanted > _distance else 2.4)
	var dolly_response := 1.0 - exp(-dt * dolly_speed)
	_distance = lerpf(_distance, wanted, dolly_response) if _motion_ready else wanted
	var required := wide_distance if _closeup < 0.001 else action_distance
	_distance = maxf(_distance, required + 0.15 + absf(_kick))
	position = _target + view_basis.z * _distance + view_basis.x * _kick
	basis = view_basis
	_motion_ready = true


func _coop_centre(coop: int, rope: float) -> Vector3:
	if _coop_centres.size() == 2:
		return _coop_centres[coop]
	var side := -1.0 if coop == 0 else 1.0
	var centre := Vector3(side * (_length * NOTCH_METRES + 2.8) - rope / _length * 1.2, 0.9, 0.0)
	if _pin_winner >= 0:
		centre = centre.lerp(Vector3(0.0, 0.3, 0.0), smoothstep(0.0, 0.85, _pin_time))
	return centre


static func _view_basis(yaw: float, elevation: float) -> Basis:
	var back := Vector3(sin(yaw) * cos(elevation), sin(elevation), cos(yaw) * cos(elevation))
	return Basis.looking_at(-back, Vector3.UP)


func _fit_distance(subjects: PackedVector4Array, view_basis: Basis, aspect: float) -> float:
	var tangent := tan(deg_to_rad(fov * 0.5))
	var horizontal := tangent * aspect * (1.0 - SAFE_FRAME.position.x * 2.0)
	var top := tangent * (1.0 - SAFE_FRAME.position.y * 2.0)
	var bottom := tangent * (SAFE_FRAME.end.y * 2.0 - 1.0)
	var horizontal_radius := sqrt(1.0 + horizontal * horizontal)
	var top_radius := sqrt(1.0 + top * top)
	var bottom_radius := sqrt(1.0 + bottom * bottom)
	var required := MIN_DISTANCE
	for sphere in subjects:
		var relative := Vector3(sphere.x, sphere.y, sphere.z) - _target
		var depth := view_basis.z.dot(relative)
		var x := view_basis.x.dot(relative) - _kick
		var y := view_basis.y.dot(relative)
		required = maxf(required, depth + sphere.w + near + 0.1)
		required = maxf(required, depth
			+ (absf(x) + sphere.w * horizontal_radius) / horizontal)
		required = maxf(required, depth
			+ (y + sphere.w * top_radius) / top)
		required = maxf(required, depth
			+ (-y + sphere.w * bottom_radius) / bottom)
	return required


func _build_wide_subjects() -> void:
	_wide_subjects.clear()
	var goal := _length * NOTCH_METRES
	for x: float in [-goal - 6.6, goal + 6.6]:
		for y: float in [-0.1, 3.1]:
			for z: float in [-1.3, 1.3]:
				_wide_subjects.append(Vector4(x, y, z, 0.0))
	_wide_subjects.append_array(landmarks(_length))


static func landmarks(rope_length: int) -> PackedVector4Array:
	var subjects := PackedVector4Array()
	var goal := rope_length * NOTCH_METRES
	for side: float in [-1.0, 1.0]:
		# Thin signs need box bounds: a sign-width sphere invents ground below
		# the arena and unnecessarily prevents the losing-coop close-up.
		for x: float in [-1.05, 1.05]:
			for y: float in [0.05, 1.6]:
				for z: float in [2.5, 2.95]:
					subjects.append(Vector4(side * goal + x, y, z, 0.0))
		subjects.append(Vector4(side * goal, 1.4, -2.72, 0.35))
	subjects.append_array(pit_bounds())
	return subjects


static func pit_bounds() -> PackedVector4Array:
	var subjects := PackedVector4Array()
	for x: float in [-Scenery.PIT_RADIUS, Scenery.PIT_RADIUS]:
		for z: float in [-Scenery.PIT_RADIUS, Scenery.PIT_RADIUS]:
			for y: float in [Scenery.PIT_FLOOR_Y, Scenery.PIT_RIM_Y + 0.2]:
				subjects.append(Vector4(x, y, z, 0.0))
	return subjects
