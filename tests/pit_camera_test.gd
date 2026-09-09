extends SceneTree

## Camera geometry and deterministic motion; actual lighting is covered by pit_view_test.

const PitCamera = preload("res://games/chicken_pit/pit/pit_camera.gd")
const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(720, 960), Vector2i(1920, 720),
	Vector2i(1844, 776),
]
var _failures := PackedStringArray()
var _viewport: SubViewport
var _camera: PitCamera


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.size = SIZES[0]
	get_root().add_child(_viewport)
	_camera = PitCamera.new()
	_camera.current = true
	_viewport.add_child(_camera)
	_test_shots()
	_test_framing()
	_test_losing_zoom()
	_test_zoom_transitions()
	_test_time_and_accessibility()
	_viewport.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("Chicken Pit camera tests passed.")
	quit(0 if _failures.is_empty() else 1)


func _test_shots() -> void:
	_camera.reset(10)
	var yaw_range := Vector2(INF, -INF)
	var pitch_range := Vector2(INF, -INF)
	var fov_range := Vector2(INF, -INF)
	var distance_range := Vector2(INF, -INF)
	var previous := _camera.transform
	for frame in 32 * 60:
		_camera.update_camera(1.0 / 60.0, 0.0, 0.0)
		var yaw := rad_to_deg(atan2(_camera.basis.z.x, _camera.basis.z.z))
		var pitch := rad_to_deg(asin(_camera.basis.z.y))
		yaw_range = Vector2(minf(yaw_range.x, yaw), maxf(yaw_range.y, yaw))
		pitch_range = Vector2(minf(pitch_range.x, pitch), maxf(pitch_range.y, pitch))
		fov_range = Vector2(minf(fov_range.x, _camera.fov), maxf(fov_range.y, _camera.fov))
		distance_range = Vector2(minf(distance_range.x, _camera._distance),
			maxf(distance_range.y, _camera._distance))
		_expect(absf(yaw) < 45.0, "Automatic shots must not swap the coops' screen orientation.")
		_expect(previous.basis.z.angle_to(_camera.basis.z) < deg_to_rad(0.3)
			and previous.origin.distance_to(_camera.position) < 0.2,
			"Shot transitions and the cycle wrap must not cut or jump.")
		previous = _camera.transform
	_expect(yaw_range.y - yaw_range.x > 40.0 and pitch_range.y - pitch_range.x > 7.0,
		"Automatic coverage must visit distinct horizontal and elevated camera angles.")
	_expect(fov_range.y - fov_range.x > 5.0 and distance_range.y - distance_range.x > 1.0,
		"The shot cycle must vary both lens zoom and camera distance.")


func _test_framing() -> void:
	for size in SIZES:
		_viewport.size = size
		for length: int in [6, 10, 18]:
			_camera.reset(length)
			for frame in 180:
				var rope := sin(frame * TAU / 180.0) * length * 0.98
				_supply_subjects(length, rope)
				if frame % 9 == 0:
					_camera.pull(frame % 2, 10.35)
				_camera.update_camera(1.0 / 30.0, rope, rope * 5.0, 70.0)
				_check_frame(_camera._action_subjects, "action %s, L=%d" % [size, length])
				if _camera._closeup < 0.001:
					_check_frame(_camera._subjects, "wide %s, L=%d" % [size, length])
			_camera.set_reduced_motion(true)
			_check_frame(_camera._wide_subjects, "fixed %s, L=%d" % [size, length])
			_camera.set_reduced_motion(false)


func _test_losing_zoom() -> void:
	_viewport.size = Vector2i(1844, 776)
	for length: int in [6, 10, 18]:
		for coop in 2:
			var side := -1.0 if coop == 0 else 1.0
			var at := Vector3(side * (length * 0.55 + 1.55), 0.3, 0.0)
			_camera.reset(length)
			_supply_subjects(length, 0.0)
			for frame in 360:
				_camera.update_camera(1.0 / 60.0, 0.0, 12.0, 60.0)
			var wide_height := _projected_height(at)
			var wide_fov := _camera.fov
			_camera.reset(length)
			_supply_subjects(length, side * length * 0.8)
			for frame in 360:
				_camera.update_camera(1.0 / 60.0, side * length * 0.8, side * 30.0, 60.0)
			var close_height := _projected_height(at - Vector3(side * 0.96, 0.0, 0.0))
			print("L=%d coop %d action zoom: %.2fx" % [length, coop, close_height / wide_height])
			_expect(_camera.focused_coop == coop and _camera.position.x * side > 0.0,
				"Pressure must focus the losing coop, not the winning end of the knot.")
			_expect(close_height > wide_height * 1.5 and _camera.fov < wide_fov - 10.0,
				"Action close-ups must enlarge either lead bird by at least 50%, with a real lens push.")
			_check_frame(_camera._action_subjects, "losing coop %d, L=%d" % [coop, length])


func _test_zoom_transitions() -> void:
	_camera.reset(10)
	_supply_subjects(10, 0.0)
	for frame in 240:
		_camera.update_camera(1.0 / 60.0, 0.0, 20.0, 60.0)
	var previous := _camera.transform
	var lens := _camera.fov
	for frame in 180:
		var rope := minf(frame / 120.0, 1.0) * 8.5
		_supply_subjects(10, rope)
		_camera.update_camera(1.0 / 60.0, rope, 20.0, 60.0)
		_expect(previous.origin.distance_to(_camera.position) < 0.65
			and absf(lens - _camera.fov) < 0.6,
			"Entering a close-up must ease the dolly and lens, not jump between framings.")
		_check_frame(_camera._action_subjects, "zoom transition")
		previous = _camera.transform
		lens = _camera.fov
	_supply_subjects(10, 0.0)
	_camera.update_camera(1.0 / 60.0, 0.0, 20.0, 60.0)
	_expect(_camera._closeup > 0.8 and absf(lens - _camera.fov) < 0.6,
		"A recovered coop must not snap the lens back to a wide shot.")
	for frame in 240:
		_camera.update_camera(1.0 / 60.0, 0.0, 20.0, 60.0)
	_expect(_camera._closeup < 0.001, "After recovery, the full-arena shot must return.")
	_check_frame(_camera._subjects, "recovered wide shot")


func _test_time_and_accessibility() -> void:
	var subjects := _camera._wide_subjects.duplicate()
	var action := _camera._action_subjects.duplicate()
	var centres := PackedVector3Array([Vector3(-7.0, 0.9, 0.0), Vector3(7.0, 0.9, 0.0)])
	_camera.set_subjects(subjects, centres, action)
	_camera.reset(10)
	_expect(not subjects.is_empty() and not action.is_empty() and centres.size() == 2,
		"Reset must not clear the view's shared subject arrays.")
	_camera.set_subjects(subjects, centres)
	for frame in 90:
		_camera.update_camera(1.0 / 60.0, 8.0, 30.0, 60.0)
	var transform := _camera.transform
	var lens := _camera.fov
	var clock := _camera._clock
	for frame in 12:
		_camera.update_camera(0.0, 8.0, 30.0, 60.0)
	_expect(_camera.transform.is_equal_approx(transform)
		and is_equal_approx(_camera.fov, lens) and _camera._clock == clock,
		"Zero-time redraws must not advance or drift the camera.")
	_viewport.size = Vector2i(640, 960)
	_camera.update_camera(0.0, 8.0, 30.0, 60.0)
	_check_frame(subjects, "immediate portrait resize")
	_expect(_camera.basis.is_equal_approx(transform.basis) and _camera._clock == clock,
		"Resize must safely reframe without advancing the automatic shot.")
	_camera.play_pin(0)
	_camera.update_camera(0.5, 10.0, 100.0, 100.0, 0.5)
	var pin_yaw := _camera._pin_start_yaw
	_camera.play_pin(0)
	_expect(_camera._pin_time == 0.5 and _camera._pin_start_yaw == pin_yaw,
		"A repeated pin notification must not restart its camera move.")
	_camera.set_reduced_motion(true)
	transform = _camera.transform
	lens = _camera.fov
	for frame in 30:
		centres[1] = Vector3(frame * 0.1, -1.0, 0.0)
		_camera.set_subjects(subjects, centres)
		_camera.pull(1, 10.35)
		_camera.update_camera(1.0 / 60.0, -8.0, -30.0, 60.0, 1.1)
	_expect(_camera.transform.is_equal_approx(transform) and _camera.fov == lens,
		"Reduced motion must ignore changing subjects, pressure, pulls and a pin.")
	_camera.set_reduced_motion(false)
	_camera.update_camera(1.0 / 60.0, 10.0, 100.0, 100.0, 1.1)
	_expect(_camera._pin_time >= 1.1 and _camera.focused_coop == 1,
		"Re-enabling motion must use the authoritative fall time without replaying the pin.")
	_camera.set_intense_effects(false)
	_camera.pull(0, 10.35)
	_expect(_camera._kick == 0.0, "Disabling intense effects must also suppress pull shake.")
	_camera.set_intense_effects(true)


func _projected_height(at: Vector3) -> float:
	return _camera.unproject_position(at).distance_to(
		_camera.unproject_position(at + Vector3.UP * 1.5))


func _supply_subjects(length: int, rope: float) -> void:
	var subjects := PackedVector4Array()
	var action := PackedVector4Array()
	var centres := PackedVector3Array()
	for coop in 2:
		var side := -1.0 if coop == 0 else 1.0
		for index in 6:
			var size := 1.0 - index * 0.065
			var at := Vector3(side * (length * 0.55 + 1.45 + index * 0.62 + size * 0.1)
				- rope / length * 1.2, 0.04 + size * 0.9,
				0.0 if index == 0 else -side * (0.42 if index % 2 else -0.42))
			var sphere := Vector4(at.x, at.y, at.z, size * 1.3)
			subjects.append(sphere)
			if index == 0:
				centres.append(at)
				action.append(sphere)
	var knot := Vector3(-rope * 0.55, 1.18, 0.0)
	action.append(Vector4(knot.x, knot.y, knot.z, 0.55))
	for coop in 2:
		var middle := (centres[coop] + knot) * 0.5
		action.append(Vector4(middle.x, middle.y, middle.z, 0.7))
	action.append_array(PitCamera.pit_bounds())
	subjects.append_array(PitCamera.landmarks(length))
	_camera.set_subjects(subjects, centres, action)


func _check_frame(subjects: PackedVector4Array, label: String) -> void:
	var size := Vector2(_viewport.size)
	var rect := Rect2(PitCamera.SAFE_FRAME.position * size, PitCamera.SAFE_FRAME.size * size).grow(0.1)
	for sphere in subjects:
		var at := Vector3(sphere.x, sphere.y, sphere.z)
		for direction in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT,
			Vector3.FORWARD, Vector3.BACK]:
			var point: Vector3 = at + direction * sphere.w
			_expect(not _camera.is_position_behind(point)
				and rect.has_point(_camera.unproject_position(point)),
				"The shot's essential subjects must remain inside the safe frame: %s." % label)


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
