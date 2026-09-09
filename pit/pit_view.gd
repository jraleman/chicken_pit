extends Node3D

## Read-only presentation of PitState. Nothing in this world can move the model.

const PitState = preload("res://games/chicken_pit/pit/pit_state.gd")
const PitHistory = preload("res://games/chicken_pit/pit/pit_history.gd")
const ToyMesh = preload("res://games/chicken_pit/pit/toy_mesh.gd")
const Scenery = preload("res://games/chicken_pit/pit/scenery.gd")
const ChickenRig = preload("res://games/chicken_pit/pit/chicken_rig.gd")
const PitCamera = preload("res://games/chicken_pit/pit/pit_camera.gd")
const PitLighting = preload("res://games/chicken_pit/pit/pit_lighting.gd")
const RopeView = preload("res://games/chicken_pit/pit/rope_view.gd")
const FEATHER := preload("res://games/chicken_pit/assets/textures/feather.svg")
const DUST := preload("res://games/chicken_pit/assets/textures/dust.svg")
const NOTCH_METRES := 0.55
const BIRDS_PER_COOP := PitHistory.CHICKENS_PER_MATCH
const CROWD_COUNT := 40
const CREAM := Color("fff8e7")
const PIT_BIRD_SCALE := 0.52
const FALL_SECONDS := 0.84
const FALL_STAGGER := 0.045

@onready var camera: PitCamera = $PitCamera
@onready var rope_view: RopeView = $Rope
@onready var lighting: PitLighting = $Lighting
@onready var _sky_dome: MeshInstance3D = $SkyDome
@onready var _fx: Node3D = $Fx

var inert := false
var reduced_motion := false
var intense_effects := true
var _state: PitState
var _farm: Node3D
var _length := -1
var _colors: Array[Color] = []
var _birds: Array[ChickenRig] = []
var _bird_origins: Array[Vector3] = []
var _coops: Array[Node3D] = []
var _camera_subjects := PackedVector4Array()
var _camera_action_subjects := PackedVector4Array()
var _camera_coop_centres := PackedVector3Array()
var _notches: MultiMeshInstance3D
var _crowd: MultiMeshInstance3D
var _crowd_origins: Array[Vector3] = []
var _pit_flock: MultiMeshInstance3D
var _round_pit_chickens := 0
var _pit_chickens := 0
var _landing_start := 0
var _ribbon: MeshInstance3D
var _clouds: MeshInstance3D
var _particles: Array[GPUParticles3D] = []
var _particle_index := 0
var _clock := 0.0
var _pin_winner := -1
var _pin_time := 0.0
var _pin_feathers_emitted := false
var _settled := false
var _cheer: Array[float] = [0.0, 0.0]
var _recoil: Array[float] = [0.0, 0.0]
var _last_notch := -999


func _ready() -> void:
	inert = DisplayServer.get_name() == "headless"
	if not inert:
		_build_particles()


func reset_round(state: PitState, colors: Array[Color], completed_matches := 0) -> void:
	_round_pit_chickens = PitHistory.chickens_for_matches(completed_matches)
	_pit_chickens = _round_pit_chickens
	if _length != state.L or _colors != colors:
		_length = state.L
		_colors = colors.duplicate()
		if not inert:
			_build_farm()
	lighting.reset_round()
	_reset_exchange(state)


func reset_exchange(state: PitState) -> void:
	_finish_fall()
	_reset_exchange(state)


func _reset_exchange(state: PitState) -> void:
	_state = state
	_clock = 0.0
	_pin_time = 0.0
	_pin_winner = -1
	_pin_feathers_emitted = false
	_settled = false
	_last_notch = -999
	_cheer = [0.0, 0.0]
	_recoil = [0.0, 0.0]
	camera.reset(state.L)
	rope_view.reset()
	for index in _birds.size():
		_birds[index].position = _bird_origins[index]
		_birds[index].reset_pose()
	_sync_pit_flock()
	present(state)
	if not inert:
		_update_world(0.0)


func present(state: PitState) -> void:
	_state = state
	if not inert:
		_update_notches()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	camera.set_reduced_motion(value)
	lighting.set_reduced_motion(value)
	rope_view.set_reduced_motion(value)
	if value:
		_clock = 0.0
		_recoil = [0.0, 0.0]
		_cheer = [0.0, 0.0]
		if _pin_winner >= 0:
			_pin_time = PitCamera.PIN_CAMERA_SECONDS
	_apply_particle_visibility()
	if not inert and _state != null:
		_update_world(0.0)


func set_intense_effects(value: bool) -> void:
	intense_effects = value
	camera.set_intense_effects(value)
	lighting.set_intense_effects(value)
	_apply_particle_visibility()


func accepted_pull(coop: int, gain: float, alternating: bool) -> void:
	if inert:
		return
	for index in BIRDS_PER_COOP:
		_birds[coop * BIRDS_PER_COOP + index].pull(gain * (1.0 - index * 0.06))
	rope_view.pull(coop, gain)
	if intense_effects:
		camera.pull(coop, gain)
	if alternating:
		_emit(coop, false)
		_emit_dust(coop)


func rejected_pull(coop: int) -> void:
	if not reduced_motion:
		_recoil[coop] = 0.028


func captured_notch(coop: int) -> void:
	if intense_effects and not reduced_motion:
		_cheer[coop] = 1.0


func play_pin(winner: int) -> void:
	if _pin_winner >= 0:
		return
	_pin_winner = winner
	_pin_time = PitCamera.PIN_CAMERA_SECONDS if reduced_motion else 0.0
	# Every lives exchange reuses this match's six slots, rather than counting as a play.
	_landing_start = mini(_round_pit_chickens, PitHistory.MAX_CHICKENS - BIRDS_PER_COOP)
	_pit_chickens = _landing_start
	camera.play_pin(winner)
	_cheer[winner] = 1.0
	if inert:
		_pit_chickens += BIRDS_PER_COOP
	else:
		_sync_pit_flock()
		_emit_dust(1 - winner)
		_update_world(0.0)


func settle() -> void:
	if _pin_winner >= 0:
		_finish_fall()
	else:
		_pit_chickens = mini(_round_pit_chickens + BIRDS_PER_COOP, PitHistory.MAX_CHICKENS)
		_sync_pit_flock()
	_settled = true
	for emitter in _particles:
		emitter.emitting = false


## Headless integration asserts this contract rather than merely hoping not to crash.
func diagnostics() -> Dictionary:
	return {
		"inert": inert,
		"birds": _birds.size(),
		"pit_chickens": _pit_chickens,
		"pit_capacity": 0 if _pit_flock == null else _pit_flock.multimesh.instance_count,
		"particle_emitters": _particles.size(),
		"rope_simulation": rope_view.simulation_enabled(),
		"notch_count": 0 if _notches == null else _notches.multimesh.instance_count - 4,
	}


func _process(delta: float) -> void:
	if inert or _state == null:
		return
	if not _settled:
		if not reduced_motion:
			_clock += delta
		if _pin_winner >= 0:
			_pin_time += delta
	_update_world(delta if not _settled else 0.0)


func _update_world(delta: float) -> void:
	var goal := _length * NOTCH_METRES
	var slide := -_state.rope / _length * 1.2
	for coop in 2:
		var side := -1.0 if coop == 0 else 1.0
		var root := _coops[coop]
		root.position.x = side * (goal + 1.45) + slide
		var result := 0
		if _pin_winner >= 0:
			result = 1 if _pin_winner == coop else -1
		var losing := _state.rope * (-1.0 if coop == 0 else 1.0) > 0.35
		for index in BIRDS_PER_COOP:
			var bird := _birds[coop * BIRDS_PER_COOP + index]
			if result == -1:
				_pose_fall(bird, coop, index)
			else:
				bird.pose(
					_clock, delta, _state.strength[coop], losing, result, reduced_motion
				)
		_cheer[coop] = maxf(_cheer[coop] - delta * 1.6, 0.0)
		_recoil[coop] *= exp(-delta * 15.0)
	if _pin_winner >= 0 and not _pin_feathers_emitted \
		and _pin_time >= FALL_SECONDS * ChickenRig.FALL_DROP_START:
		_pin_feathers_emitted = true
		if delta > 0.0:
			_emit(1 - _pin_winner, true)
	_update_pit_flock()
	_present_rope(delta)
	_update_goal_signals()
	_update_crowd()
	_clouds.position.x = 0.0 if reduced_motion else sin(_clock * 0.045) * 0.5


func _present_rope(delta: float) -> void:
	var left := _rope_anchor(0)
	var right := _rope_anchor(1)
	left.x -= _recoil[0]
	right.x += _recoil[1]
	var knot := Vector3(-_state.rope * NOTCH_METRES, 1.18, 0.0)
	var tension := clampf(
		(_state.strength[0] + _state.strength[1]) / (2.0 * PitState.REFERENCE_DIFF),
		0.0, 1.0
	)
	var difference := _state.strength[0] - _state.strength[1]
	lighting.update_lighting(delta, _state.rope / _length, tension)
	var ribbon_scale := 1.0
	if _pin_winner >= 0:
		var side := -1.0 if _pin_winner == 0 else 1.0
		var falling_end := right if _pin_winner == 0 else left
		var sink := falling_end + Vector3(side * 0.45, -0.14, -0.12)
		var reel := smoothstep(0.06, 0.62, _pin_time)
		knot = knot.lerp(sink, reel)
		knot.y = maxf(knot.y, Scenery.pit_surface_height(knot) + RopeView.GROUND_CLEARANCE)
		var release := smoothstep(0.10, 0.60, _pin_time)
		tension *= 1.0 - release
		difference *= 1.0 - release
		ribbon_scale = lerpf(1.0, PIT_BIRD_SCALE, smoothstep(0.35, FALL_SECONDS, _pin_time))
	_update_camera_subjects(left, right, knot, ribbon_scale)
	camera.update_camera(delta, _state.rope, _state.strength[0] - _state.strength[1],
		_state.strength[0] + _state.strength[1], _pin_time)
	_sky_dome.global_position = camera.global_position
	_ribbon.position = knot
	_ribbon.scale = Vector3.ONE * ribbon_scale
	_ribbon.rotation = Vector3.ZERO if reduced_motion else Vector3(
		sin(_clock * 6.0) * 0.10 * (1.0 - tension), 0.0,
		clampf((right.y - left.y) * 0.16, -0.5, 0.5) + sin(_clock * 9.0) * 0.07
	)
	rope_view.update_rope(left, right, knot, tension, difference, delta,
		_birds[0].scale.x, _birds[BIRDS_PER_COOP].scale.x)


func _rope_anchor(coop: int) -> Vector3:
	var beak := _birds[coop * BIRDS_PER_COOP].beak_position()
	if _pin_winner >= 0 and coop != _pin_winner:
		var landing := smoothstep(ChickenRig.FALL_LAND_START, 1.0, _fall_progress(0))
		var roost := _pit_flock.to_global(_pit_bird_pose(_landing_start) * ChickenRig.SPECTATOR_GRIP)
		beak = beak.lerp(roost, landing)
	return beak


func _update_camera_subjects(left: Vector3, right: Vector3, knot: Vector3, ribbon_scale: float) -> void:
	for coop in 2:
		var centre := Vector3.ZERO
		for index in BIRDS_PER_COOP:
			var slot := coop * BIRDS_PER_COOP + index
			var bird := _birds[slot]
			var at := bird.to_global(Vector3(-0.1, 0.9, 0.0))
			var radius := 1.3 * bird.scale[bird.scale.max_axis_index()]
			if not bird.visible:
				at = _pit_flock.to_global(_pit_bird_pose(_landing_start + index) * Vector3(0.0, 0.6, 0.0))
				radius = 0.0
			_camera_subjects[slot] = Vector4(at.x, at.y, at.z, radius)
			centre += at
		var lead := _camera_subjects[coop * BIRDS_PER_COOP]
		_camera_action_subjects[coop] = lead
		_camera_coop_centres[coop] = centre / BIRDS_PER_COOP \
			if _pin_winner >= 0 and coop != _pin_winner else Vector3(lead.x, lead.y, lead.z)
	for index in BIRDS_PER_COOP:
		_camera_action_subjects[2 + index] = _camera_subjects[(1 - _pin_winner) * BIRDS_PER_COOP + index] \
			if _pin_winner >= 0 else Vector4.ZERO
	var anchors := BIRDS_PER_COOP + 2
	_camera_action_subjects[anchors] = Vector4(left.x, left.y, left.z, 0.15)
	_camera_action_subjects[anchors + 1] = Vector4(right.x, right.y, right.z, 0.15)
	_camera_action_subjects[anchors + 2] = Vector4(knot.x, knot.y, knot.z, ribbon_scale * 0.55)
	var left_span := (left + knot) * 0.5
	var right_span := (right + knot) * 0.5
	_camera_action_subjects[anchors + 3] = Vector4(left_span.x, left_span.y, left_span.z, 0.7)
	_camera_action_subjects[anchors + 4] = Vector4(right_span.x, right_span.y, right_span.z, 0.7)
	camera.set_subjects(_camera_subjects, _camera_coop_centres, _camera_action_subjects)


func _build_camera_subjects() -> void:
	_camera_subjects.resize(BIRDS_PER_COOP * 2)
	_camera_coop_centres.resize(2)
	_camera_subjects.append_array(PitCamera.landmarks(_length))
	_camera_action_subjects.resize(BIRDS_PER_COOP + 7)
	_camera_action_subjects.append_array(PitCamera.pit_bounds())


func _build_farm() -> void:
	if _farm != null:
		remove_child(_farm)
		_farm.queue_free()
	_farm = Node3D.new()
	_farm.name = "Scenery"
	add_child(_farm)
	_birds.clear()
	_bird_origins.clear()
	_coops.clear()
	_crowd_origins.clear()
	_instance(Scenery.build(_length, _colors), ToyMesh.material(), _farm)
	_clouds = _instance(Scenery.clouds(), ToyMesh.material(true), _farm)
	_clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lighting.set_cloud_material(_clouds.material_override as StandardMaterial3D)
	for coop in 2:
		var root := Node3D.new()
		root.name = "RedCoop" if coop == 0 else "BlueCoop"
		root.rotation.y = 0.0 if coop == 0 else PI
		root.position.y = 0.04
		_farm.add_child(root)
		_coops.append(root)
		var mesh := ChickenRig.build_mesh(_colors[coop], coop == 1)
		for index in BIRDS_PER_COOP:
			var bird := ChickenRig.new()
			bird.name = "Chicken%d" % (index + 1)
			root.add_child(bird)
			bird.configure(mesh, index * 0.72 + coop * 1.8, 1.0 - index * 0.065)
			bird.position = Vector3(-index * 0.62, 0.0,
				0.0 if index == 0 else (0.42 if index % 2 else -0.42))
			_birds.append(bird)
			_bird_origins.append(bird.position)
	_build_notches()
	_build_crowd()
	_build_pit_flock()
	_build_ribbon()
	_build_camera_subjects()
	var barn_sign := _label("CLUCK COUNTY", Vector3(-0.36, 2.75, -6.33), 56,
		Color("923d33"), 0.0058)
	barn_sign.rotation.y = -0.08
	for coop in 2:
		var side := -1.0 if coop == 0 else 1.0
		_label("RED GOAL" if coop == 0 else "BLUE GOAL",
			Vector3(side * _length * NOTCH_METRES, 0.61, 2.87), 48, CREAM, 0.007)
		_label("THE GREAT PULL-OFF", Vector3(
			side * (_length * NOTCH_METRES * 0.56 + 2.6), 0.23, -5.25),
			42, Color("7c5a36"), 0.005)


func _build_notches() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.085, 0.30, 0.11)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = mesh
	batch.instance_count = _length * 2 + 4
	for coop in 2:
		for notch in _length:
			var side := -1.0 if coop == 0 else 1.0
			var at := Vector3(side * (notch + 1) * NOTCH_METRES, 0.20, 2.55)
			batch.set_instance_transform(coop * _length + notch,
				Transform3D(Basis.IDENTITY, at))
		for edge in 2:
			var side := -1.0 if coop == 0 else 1.0
			var at := Vector3(side * _length * NOTCH_METRES, 1.43,
				-2.72 if edge == 0 else 2.72)
			var index := _length * 2 + coop * 2 + edge
			batch.set_instance_transform(index,
				Transform3D(Basis.IDENTITY.scaled(Vector3(4.0, 0.6, 3.1)), at))
			batch.set_instance_color(index, _colors[coop])
	_notches = MultiMeshInstance3D.new()
	_notches.multimesh = batch
	_notches.material_override = ToyMesh.material(true)
	_notches.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_farm.add_child(_notches)


func _update_notches() -> void:
	var owned := int(signf(_state.rope)) * floori(absf(_state.rope))
	if owned == _last_notch or _notches == null:
		return
	_last_notch = owned
	for coop in 2:
		var count := maxi(owned if coop == 0 else -owned, 0)
		for notch in _length:
			_notches.multimesh.set_instance_color(
				coop * _length + notch, _colors[coop] if notch < count else CREAM
			)


func _update_goal_signals() -> void:
	var near_goal := absf(_state.rope) >= _length - 2.0
	var threatened := 1 if _state.rope > 0.0 else 0
	for coop in 2:
		var color := _colors[coop]
		if near_goal and coop == threatened and intense_effects and not reduced_motion:
			color = color.lerp(CREAM, (sin(_clock * 9.0) + 1.0) * 0.35)
		for edge in 2:
			_notches.multimesh.set_instance_color(_length * 2 + coop * 2 + edge, color)


func _build_crowd() -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = ChickenRig.spectator_mesh()
	batch.instance_count = CROWD_COUNT
	for index in CROWD_COUNT:
		var coop := index / 20
		var seat := index % 20
		var row := seat / 10
		var side := -1.0 if coop == 0 else 1.0
		var at := Vector3(side * (_length * NOTCH_METRES * 0.56 + 2.6)
			+ (seat % 10 - 4.5) * 0.47, 0.48 + row * 0.43, -5.8 - row * 0.72)
		_crowd_origins.append(at)
		batch.set_instance_color(index,
			CREAM.lerp(_colors[coop], 0.10 if index % 3 else 0.36))
	_crowd = MultiMeshInstance3D.new()
	_crowd.multimesh = batch
	_crowd.material_override = ToyMesh.material()
	_crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_farm.add_child(_crowd)
	_update_crowd()


func _update_crowd() -> void:
	for index in CROWD_COUNT:
		var at := _crowd_origins[index]
		if not reduced_motion:
			var cheer := _cheer[index / 20]
			at.y += sin(_clock * 3.0 + index * 2.1) * 0.017
			at.y += maxf(sin(_clock * 15.0 + index * 0.5), 0.0) * cheer * 0.35
			if camera.stalemate_active:
				at.y -= 0.06
		_crowd.multimesh.set_instance_transform(index,
			Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.34), at))


func _build_pit_flock() -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = _crowd.multimesh.mesh
	batch.instance_count = PitHistory.MAX_CHICKENS
	for index in PitHistory.MAX_CHICKENS:
		batch.set_instance_transform(index, _pit_chicken_transform(index))
		batch.set_instance_color(index, CREAM.lerp(_colors[(index / BIRDS_PER_COOP) % 2], 0.25))
	_pit_flock = MultiMeshInstance3D.new()
	_pit_flock.name = "PitFlock"
	_pit_flock.multimesh = batch
	_pit_flock.material_override = ToyMesh.material()
	_pit_flock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_farm.add_child(_pit_flock)
	_sync_pit_flock()


func _sync_pit_flock() -> void:
	if _pit_flock != null:
		_pit_flock.multimesh.visible_instance_count = _pit_chickens


static func _pit_chicken_transform(index: int) -> Transform3D:
	var angle := index * 2.399963
	var radius := sqrt((index + 0.5) / PitHistory.MAX_CHICKENS) * 1.32
	var at := Vector3(cos(angle) * radius, Scenery.PIT_FLOOR_Y + 0.025, sin(angle) * radius)
	return Transform3D(
		Basis(Vector3.UP, _pit_bird_yaw(index)).scaled(Vector3.ONE * PIT_BIRD_SCALE), at
	)


static func _pit_bird_yaw(index: int) -> float:
	return sin(index * 1.7) * 0.85


func _pit_bird_pose(index: int) -> Transform3D:
	var pose := _pit_chicken_transform(index)
	if not reduced_motion:
		var phase := index * 2.399963
		var peck := pow(maxf(sin(_clock * 1.7 + phase), 0.0), 8.0) * 0.18
		pose.basis *= Basis.from_euler(Vector3(peck,
			sin(_clock * 0.8 + phase) * 0.06, sin(_clock * 2.2 + phase) * 0.025))
		pose.origin.y += maxf(sin(_clock * 2.8 + phase), 0.0) * 0.015
	return pose


func _update_pit_flock() -> void:
	for index in _pit_chickens:
		_pit_flock.multimesh.set_instance_transform(index, _pit_bird_pose(index))


func _fall_progress(index: int) -> float:
	return clampf((_pin_time - index * FALL_STAGGER) / FALL_SECONDS, 0.0, 1.0)


func _pose_fall(bird: ChickenRig, coop: int, index: int) -> void:
	var progress := _fall_progress(index)
	var root := _coops[coop]
	var from := root.to_global(_bird_origins[coop * BIRDS_PER_COOP + index])
	var side := -1.0 if coop == 0 else 1.0
	var edge := Vector3(side * (Scenery.PIT_RADIUS + 0.12), Scenery.PIT_RIM_Y + 0.035,
		from.z * 0.6)
	var lip := Vector3(side * (Scenery.PIT_RADIUS - 0.85), edge.y, from.z * 0.35)
	var slot := _landing_start + index
	var landing := _pit_chicken_transform(slot).origin
	var at := from.lerp(edge, smoothstep(0.0, ChickenRig.FALL_SLIDE_END, progress))
	if progress > ChickenRig.FALL_SLIDE_END:
		var tip := smoothstep(ChickenRig.FALL_SLIDE_END, ChickenRig.FALL_DROP_START, progress)
		at = edge.lerp(lip, tip)
		at.y += sin(tip * PI) * 0.045
	if progress > ChickenRig.FALL_DROP_START:
		var drop := clampf((progress - ChickenRig.FALL_DROP_START)
			/ (ChickenRig.FALL_LAND_START - ChickenRig.FALL_DROP_START), 0.0, 1.0)
		at = lip.lerp(landing, smoothstep(0.0, 1.0, drop))
		at.y = lerpf(lip.y, landing.y, drop * drop)
	if progress > ChickenRig.FALL_LAND_START:
		var land := smoothstep(ChickenRig.FALL_LAND_START, 1.0, progress)
		at = landing + Vector3.UP * sin(land * PI) * 0.065 * (1.0 - land)
	var resting_yaw := wrapf(_pit_bird_yaw(slot) - PI * 0.5 - root.rotation.y, -PI, PI)
	bird.fall_pose(root.to_local(at), progress, PIT_BIRD_SCALE, resting_yaw)
	bird.visible = progress < 1.0
	if progress >= 1.0 and slot >= _pit_chickens:
		_pit_chickens = slot + 1
		_pit_flock.multimesh.set_instance_color(slot, CREAM.lerp(_colors[coop], 0.25))
		_sync_pit_flock()


func _finish_fall() -> void:
	if _pin_winner < 0:
		return
	_pin_time = PitCamera.PIN_CAMERA_SECONDS
	if not inert:
		_update_world(0.0)


func _build_ribbon() -> void:
	var toy := ToyMesh.new()
	toy.ellipsoid(Vector3.ZERO, Vector3(0.30, 0.25, 0.25), CREAM)
	for side in [-1.0, 1.0]:
		toy.ellipsoid(Vector3(0.0, 0.12, side * 0.20), Vector3(0.13, 0.22, 0.30),
			Color("9655c9"), Vector3(side * 0.55, 0.0, 0.0), 0.0, 8, 4)
		toy.box(Vector3(side * 0.13, -0.22, 0.02), Vector3(0.12, 0.42, 0.06),
			Color("9655c9"), Vector3(0.0, 0.0, side * 0.28))
	_ribbon = _instance(toy.finish(), ToyMesh.material(true), _farm)
	_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_particles() -> void:
	for index in 9:
		var dust := index >= 7
		var emitter := GPUParticles3D.new()
		emitter.name = "Feathers%d" % index
		emitter.amount = 42 if index == 6 else 5
		emitter.one_shot = true
		emitter.explosiveness = 1.0
		emitter.lifetime = 1.0 if index == 6 else 0.45 if dust else 0.55
		emitter.emitting = false
		emitter.visibility_aabb = AABB(Vector3(-5.0, -3.0, -5.0), Vector3(10, 10, 10))
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3.UP
		process.spread = 75.0
		process.initial_velocity_min = 0.15 if dust else 1.4
		process.initial_velocity_max = 0.65 if dust else 4.3 if index == 6 else 2.8
		process.gravity = Vector3(0.0, 0.4 if dust else -4.3, 0.0)
		process.angular_velocity_min = -290.0
		process.angular_velocity_max = 290.0
		process.scale_min = 0.6
		process.scale_max = 1.15
		if dust:
			var gradient := Gradient.new()
			gradient.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
			var ramp := GradientTexture1D.new()
			ramp.gradient = gradient
			process.color_ramp = ramp
		emitter.process_material = process
		var feather := QuadMesh.new()
		feather.size = Vector2(0.4, 0.4) if dust else Vector2(0.16, 0.32)
		var material := StandardMaterial3D.new()
		material.albedo_texture = DUST if dust else FEATHER
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if dust \
			else BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.vertex_color_use_as_albedo = true
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		feather.material = material
		emitter.draw_pass_1 = feather
		_fx.add_child(emitter)
		_particles.append(emitter)
	_apply_particle_visibility()


func _emit(coop: int, pin: bool) -> void:
	if reduced_motion or not intense_effects or _particles.is_empty():
		return
	var index := 6 if pin else _particle_index
	_particle_index = (_particle_index + 1) % 6
	var emitter := _particles[index]
	emitter.position = _fx.to_local(_birds[coop * BIRDS_PER_COOP].to_global(
		Vector3(0.0, 0.8, 0.0))) if pin else _coops[coop].position + Vector3(0.0, 1.1, 0.0)
	var material := emitter.process_material as ParticleProcessMaterial
	material.color = _colors[coop].lerp(CREAM, 0.25)
	emitter.restart()
	emitter.emitting = true


func _emit_dust(coop: int) -> void:
	if reduced_motion or not intense_effects or _particles.is_empty():
		return
	var emitter := _particles[7 + coop]
	emitter.position = _coops[coop].position + Vector3(0.0, 0.12, 0.0)
	(emitter.process_material as ParticleProcessMaterial).color = Color("e8b84b")
	emitter.restart()
	emitter.emitting = true


func _apply_particle_visibility() -> void:
	for emitter in _particles:
		emitter.visible = intense_effects and not reduced_motion
		if not emitter.visible:
			emitter.emitting = false


func _label(
	text: String, at: Vector3, font_size: int, color: Color, pixel_size: float
) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	_farm.add_child(label)
	return label


func _instance(mesh: Mesh, material: Material, parent: Node3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance
