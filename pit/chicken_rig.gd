extends Node3D

## Rigid, vertex-painted toy parts, animated in a single draw call per bird.
## Bare birds keep their combs; store hats use the same rig without a comb.

const ToyMesh = preload("res://games/chicken_pit/pit/toy_mesh.gd")
const BIRD_SHADER := preload("res://games/chicken_pit/pit/chicken.gdshader")
const CREAM := Color("fff8e7")
const BEAK := Color("ffbc45")
const INK := Color("282a35")
const HEAD_HINGE := Vector3(0.20, 1.02, 0.0)
const BEAK_GRIP := Vector3(0.94, 1.19, 0.0)
const SPECTATOR_GRIP := Vector3(0.0, 1.05, 0.49)
const FALL_SLIDE_END := 0.34
const FALL_DROP_START := 0.48
const FALL_LAND_START := 0.86

## The comb-free variant lets both coops wear centred hats against the head.
const HAT_BASE := 1.58
const HAT_CENTRE_X := 0.35
const HAT_PART := 3.0

var phase := 0.0
var _material: ShaderMaterial
var _pull := 0.0
var _size := 1.0
var _head_dip := 0.0


func configure(mesh: ArrayMesh, phase_offset: float, size_scale: float) -> void:
	phase = phase_offset
	_size = size_scale
	scale = Vector3.ONE * _size
	var bird := MeshInstance3D.new()
	bird.mesh = mesh
	bird.extra_cull_margin = 0.6
	_material = ShaderMaterial.new()
	_material.shader = BIRD_SHADER
	bird.material_override = _material
	add_child(bird)


## Only accepted strength produces a lurch; the penalty is visible.
func pull(gain: float) -> void:
	_pull = minf(gain / 10.35, 1.4)


func reset_pose() -> void:
	_pull = 0.0
	rotation = Vector3.ZERO
	position.y = 0.0
	scale = Vector3.ONE * _size
	_set_parts(0.0, 0.0, 0.0, 0.0)
	show()


func fall_pose(at: Vector3, progress: float, resting_scale: float, resting_yaw := 0.0) -> void:
	var tip := smoothstep(FALL_SLIDE_END, FALL_DROP_START, progress)
	var tumble := smoothstep(FALL_DROP_START, FALL_LAND_START, progress)
	var land := smoothstep(FALL_LAND_START, 1.0, progress)
	var flutter := sin(progress * TAU * 7.0 + phase)
	var impact := sin(land * PI)
	var size_scale := lerpf(_size, resting_scale,
		smoothstep(FALL_DROP_START + 0.06, FALL_LAND_START, progress))
	scale = Vector3(1.0 + impact * 0.16, 1.0 - impact * 0.14, 1.0 + impact * 0.16) * size_scale
	rotation = Vector3(flutter * 0.12 * sin(tumble * PI), resting_yaw * land,
		lerpf(lerpf(-0.12, -PI * 0.65, tip), -TAU, tumble) + impact * 0.09)
	# Somersault around the body, not the feet, so tipping does not swing the bird underground.
	var pivot := Vector3(0.0, 0.78 * scale.y, 0.0)
	position = at + pivot - Basis.from_euler(rotation) * pivot
	_set_parts(
		(0.35 + tip * 0.8 + flutter * 0.35) * (1.0 - land),
		cos(progress * TAU * 6.0 + phase) * tip * 0.38 * (1.0 - land),
		(-tip * 0.35 + flutter * tumble * 0.12) * (1.0 - land),
		sin(progress * TAU * 8.0 + phase) * 0.18 * (1.0 - land), 2.6
	)


func pose(
	clock: float, delta: float, strength: float,
	losing: bool, result: int, reduced: bool
) -> void:
	if _material == null:
		return
	var strain := strength / 100.0
	rotation = Vector3.ZERO
	if reduced:
		position.y = 0.0
		_set_parts(0.18 + strain * 0.4, 0.0, 0.0, 0.0)
		_pull = 0.0
		return

	_pull *= exp(-delta * 13.0)
	var bob := sin(clock * 5.0 + phase)
	var idle := maxf(1.0 - strain * 3.0, 0.0)
	var peck := pow(maxf(sin(clock * 1.5 + phase * 2.0), 0.0), 10.0) * idle
	var stretch := pow(maxf(sin(clock * 1.2 + phase * 1.7), 0.0), 14.0) * idle
	var flap := 0.10 + strain * 0.55 + _pull * 1.1 + stretch * 0.35
	var skew := sin(clock * 5.0 + phase) * 0.06
	var head := -strain * 0.12 - _pull * 0.10 - peck * 0.28
	var feet := bob * strain * 0.045
	var kick := 0.0
	rotation.z = strain * 0.34 + _pull * 0.18
	position.y = maxf(bob, 0.0) * (0.024 + strain * 0.02)
	if losing:
		flap += (sin(clock * 21.0 + phase) + 1.0) * 0.22
		rotation.z -= 0.13
		feet = sin(clock * 18.0 + phase) * 0.14
		kick = 0.6
	if result == 1:
		position.y = maxf(sin(clock * 10.0 + phase), 0.0) * 0.45
		flap = 0.9 + sin(clock * 20.0 + phase) * 0.6
		head = 0.06
		feet = sin(clock * 20.0 + phase) * 0.12
		kick = 1.4
	elif result == -1:
		rotation.z = -1.0 + sin(clock * 8.0 + phase) * 0.2
		position.y = 0.14
		flap = 1.2 + bob * 0.5
	_set_parts(flap, skew, head, feet, kick)


func _set_parts(flap: float, skew: float, head: float, feet: float, kick := 0.0) -> void:
	_head_dip = head
	if _material != null:
		_material.set_shader_parameter("flap", flap)
		_material.set_shader_parameter("flap_skew", skew)
		_material.set_shader_parameter("head_dip", head)
		_material.set_shader_parameter("foot_step", feet)
		_material.set_shader_parameter("foot_kick", kick)


func beak_position() -> Vector3:
	return to_global(HEAD_HINGE + (BEAK_GRIP - HEAD_HINGE).rotated(Vector3.BACK, _head_dip))


## This is the model source: no downloaded mesh or external rig is required.
##
## [param hat] is a store item id; an unknown or empty one simply leaves the
## bird bare, so the pit never depends on a purchase having happened.
static func build_mesh(team: Color, bonnet: bool, hat := "") -> ArrayMesh:
	var hat_ready := _is_store_hat(hat)
	var toy := ToyMesh.new()
	_add_bird(toy, team, bonnet, hat_ready)
	if hat_ready:
		_add_hat(toy, hat, team)
	return toy.finish()


## The shared body under a store hat, without comb geometry to clip through it.
static func hat_ready_mesh(team: Color, bonnet: bool) -> ArrayMesh:
	var toy := ToyMesh.new()
	_add_bird(toy, team, bonnet, true)
	return toy.finish()


static func _is_store_hat(hat: String) -> bool:
	for item: Dictionary in ChickenPitOptions.STORE_ITEMS:
		if str(item["id"]) == hat:
			return str(item["kind"]) == ChickenPitOptions.HAT_KIND \
				and not bool(item.get("default", false))
	return false


static func _add_bird(toy: ToyMesh, team: Color, bonnet: bool, hat_ready: bool) -> void:
	toy.ellipsoid(Vector3(-0.17, 0.77, 0.0), Vector3(1.20, 1.08, 0.86), CREAM)
	toy.ellipsoid(Vector3(0.10, 0.96, 0.0), Vector3(0.66, 0.77, 0.66), CREAM)
	for side in [-1.0, 1.0]:
		var part := 1.0 if side > 0.0 else 2.0
		toy.ellipsoid(
			Vector3(-0.26, 0.82, side * 0.40), Vector3(0.74, 0.62, 0.20),
			team.lerp(CREAM, 0.24), Vector3(0.0, 0.0, -0.22), part
		)
		for feather in 3:
			toy.ellipsoid(
				Vector3(-0.49 + feather * 0.14, 0.66, side * 0.46),
				Vector3(0.13, 0.27, 0.12), team,
				Vector3(0.0, 0.0, -0.38), part, 6, 3
			)
		var leg_part := 4.0 if side > 0.0 else 5.0
		toy.cylinder(
			Vector3(-0.08, 0.25, side * 0.22), 0.055, 0.37, BEAK,
			Vector3(0.0, 0.0, -0.16), -1.0, leg_part
		)
		toy.box(
			Vector3(0.06, 0.07, side * 0.22), Vector3(0.38, 0.10, 0.17),
			BEAK, Vector3.ZERO, leg_part
		)
		for toe in 3:
			toy.box(
				Vector3(0.24, 0.045, side * 0.22 + (toe - 1) * 0.072),
				Vector3(0.20, 0.055, 0.047), BEAK, Vector3.ZERO, leg_part
			)
	for feather in 3:
		toy.ellipsoid(
			Vector3(-0.69, 1.03, (feather - 1) * 0.15),
			Vector3(0.25, 0.66, 0.18), CREAM.darkened(feather * 0.045),
			Vector3(0.0, 0.0, 0.62), 0.0, 8, 4
		)
	toy.ellipsoid(
		Vector3(0.37, 1.26, 0.0), Vector3(0.69, 0.72, 0.65),
		CREAM, Vector3.ZERO, 3.0
	)
	toy.cylinder(
		Vector3(0.80, 1.19, 0.0), 0.16, 0.36, BEAK,
		Vector3(0.0, 0.0, -PI * 0.5), 0.025, 3.0
	)
	toy.ellipsoid(
		Vector3(0.59, 0.98, 0.0), Vector3(0.18, 0.27, 0.20),
		team, Vector3.ZERO, 3.0, 8, 4
	)
	for side in [-1.0, 1.0]:
		toy.ellipsoid(
			Vector3(0.51, 1.34, side * 0.283), Vector3(0.20, 0.23, 0.095),
			Color.WHITE, Vector3.ZERO, 3.0, 8, 4
		)
		toy.ellipsoid(
			Vector3(0.54, 1.34, side * 0.327), Vector3(0.09, 0.12, 0.035),
			INK, Vector3.ZERO, 3.0, 8, 4
		)
		toy.ellipsoid(
			Vector3(0.56, 1.375, side * 0.345), Vector3(0.028, 0.035, 0.018),
			Color.WHITE, Vector3.ZERO, 3.0, 6, 3
		)
	if bonnet:
		toy.cylinder(
			Vector3(0.36, 1.56, 0.0), 0.43, 0.09,
			team, Vector3.ZERO, -1.0, 3.0
		)
		toy.ellipsoid(
			Vector3(0.34, 1.65, 0.0), Vector3(0.63, 0.33, 0.60),
			team.lightened(0.18), Vector3.ZERO, 3.0
		)
		for side in [-1.0, 1.0]:
			toy.box(
				Vector3(0.20, 1.12, side * 0.29), Vector3(0.11, 0.55, 0.045),
				team, Vector3(0.0, 0.0, -0.2), 3.0
			)
	elif not hat_ready:
		for lobe in 3:
			toy.ellipsoid(
				Vector3(0.16 + lobe * 0.18, 1.64 + lobe * 0.035, 0.0),
				Vector3(0.21, 0.39, 0.13), team,
				Vector3(0.0, 0.0, -0.22), 3.0, 8, 4
			)


## Trim carries the team colour; every piece joins the head's single surface.
static func _add_hat(toy: ToyMesh, hat: String, team: Color) -> void:
	var base := HAT_BASE
	var centre_x := HAT_CENTRE_X
	match hat:
		ChickenPitOptions.HAT_STRAW:
			var straw := Color("e8c46a")
			toy.cylinder(
				Vector3(centre_x, base + 0.02, 0.0), 0.52, 0.05, straw.darkened(0.12),
				Vector3.ZERO, -1.0, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.20, 0.0), 0.33, 0.34, straw,
				Vector3.ZERO, -1.0, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.09, 0.0), 0.345, 0.08, team,
				Vector3.ZERO, -1.0, HAT_PART
			)
		ChickenPitOptions.HAT_BERET:
			var cloth := Color("a94d66")
			toy.ellipsoid(
				Vector3(centre_x - 0.03, base + 0.17, 0.0), Vector3(0.82, 0.34, 0.72),
				cloth, Vector3(0.0, 0.0, 0.10), HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.025, 0.0), 0.34, 0.09, team,
				Vector3.ZERO, -1.0, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.355, 0.0), 0.035, 0.12, cloth.darkened(0.3),
				Vector3(0.0, 0.0, -0.25), -1.0, HAT_PART
			)
		ChickenPitOptions.HAT_PARTY:
			var party := Color("ff6fae")
			toy.cylinder(
				Vector3(centre_x, base + 0.30, 0.0), 0.30, 0.58, party,
				Vector3.ZERO, 0.02, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.06, 0.0), 0.305, 0.09, team,
				Vector3.ZERO, -1.0, HAT_PART
			)
			toy.ellipsoid(
				Vector3(centre_x, base + 0.62, 0.0), Vector3(0.17, 0.17, 0.17),
				CREAM, Vector3.ZERO, HAT_PART, 8, 4
			)
		ChickenPitOptions.HAT_BEANIE:
			var wool := Color("8b78b8")
			toy.ellipsoid(
				Vector3(centre_x, base + 0.16, 0.0), Vector3(0.70, 0.40, 0.66),
				wool, Vector3.ZERO, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.04, 0.0), 0.36, 0.12, team,
				Vector3.ZERO, -1.0, HAT_PART
			)
			toy.ellipsoid(
				Vector3(centre_x, base + 0.40, 0.0), Vector3(0.19, 0.19, 0.19),
				CREAM, Vector3.ZERO, HAT_PART, 8, 4
			)
		ChickenPitOptions.HAT_COWBOY:
			var leather := Color("8a5a33")
			toy.cylinder(
				Vector3(centre_x, base + 0.03, 0.0), 0.62, 0.06, leather,
				Vector3.ZERO, -1.0, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.22, 0.0), 0.31, 0.36, leather.lightened(0.12),
				Vector3.ZERO, 0.27, HAT_PART
			)
			toy.box(
				Vector3(centre_x, base + 0.39, 0.0), Vector3(0.34, 0.10, 0.12),
				leather.darkened(0.28), Vector3.ZERO, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.09, 0.0), 0.325, 0.09, team,
				Vector3.ZERO, -1.0, HAT_PART
			)
		ChickenPitOptions.HAT_RAIN:
			var oilskin := Color("f6c84f")
			toy.cylinder(
				Vector3(centre_x, base + 0.035, 0.0), 0.54, 0.14, oilskin,
				Vector3.ZERO, 0.34, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.18, 0.0), 0.31, 0.30, oilskin.lightened(0.12),
				Vector3.ZERO, 0.28, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.095, 0.0), 0.325, 0.08, team,
				Vector3.ZERO, 0.31, HAT_PART
			)
		ChickenPitOptions.HAT_PROPELLER:
			toy.ellipsoid(
				Vector3(centre_x, base + 0.13, 0.0), Vector3(0.72, 0.34, 0.70),
				Color("59ac9c"), Vector3.ZERO, HAT_PART
			)
			toy.ellipsoid(
				Vector3(centre_x + 0.31, base + 0.025, 0.0), Vector3(0.48, 0.06, 0.62),
				team, Vector3.ZERO, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.02, 0.0), 0.365, 0.08, team,
				Vector3.ZERO, -1.0, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.37, 0.0), 0.035, 0.20, Color("9aa6b5"),
				Vector3.ZERO, -1.0, HAT_PART
			)
			for blade in 2:
				toy.box(
					Vector3(centre_x, base + 0.475, 0.0), Vector3(0.66, 0.04, 0.11),
					BEAK if blade == 0 else CREAM,
					Vector3(0.0, PI * (0.25 + float(blade) * 0.5), 0.0), HAT_PART
				)
			toy.ellipsoid(
				Vector3(centre_x, base + 0.49, 0.0), Vector3(0.11, 0.10, 0.11),
				BEAK, Vector3.ZERO, HAT_PART, 8, 4
			)
		ChickenPitOptions.HAT_VIKING:
			var steel := Color("9aa6b5")
			toy.ellipsoid(
				Vector3(centre_x, base + 0.16, 0.0), Vector3(0.68, 0.40, 0.64),
				steel, Vector3.ZERO, HAT_PART, 10, 5
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.02, 0.0), 0.36, 0.09, team,
				Vector3.ZERO, -1.0, HAT_PART
			)
			toy.box(
				Vector3(centre_x + 0.27, base + 0.03, 0.0), Vector3(0.09, 0.18, 0.11),
				steel.lightened(0.1), Vector3.ZERO, HAT_PART
			)
			for side in [-1.0, 1.0]:
				toy.cylinder(
					Vector3(centre_x, base + 0.24, side * 0.30), 0.11, 0.36,
					Color("efe6d2"), Vector3(side * 0.72, 0.0, 0.0), 0.02, HAT_PART
				)
		ChickenPitOptions.HAT_EXPLORER:
			var pith := Color("c8b078")
			toy.ellipsoid(
				Vector3(centre_x, base + 0.015, 0.0), Vector3(1.04, 0.08, 0.88),
				pith.darkened(0.12), Vector3.ZERO, HAT_PART
			)
			toy.ellipsoid(
				Vector3(centre_x, base + 0.15, 0.0), Vector3(0.78, 0.40, 0.70),
				pith, Vector3.ZERO, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.045, 0.0), 0.375, 0.07, team,
				Vector3.ZERO, -1.0, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.385, 0.0), 0.08, 0.08, pith.darkened(0.2),
				Vector3.ZERO, 0.055, HAT_PART
			)
		ChickenPitOptions.HAT_CHEF:
			toy.cylinder(
				Vector3(centre_x, base + 0.25, 0.0), 0.29, 0.34, CREAM,
				Vector3.ZERO, 0.34, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.08, 0.0), 0.31, 0.18, team,
				Vector3.ZERO, -1.0, HAT_PART
			)
			for puff in 4:
				var angle := float(puff) / 4.0 * TAU
				toy.ellipsoid(
					Vector3(centre_x + cos(angle) * 0.18, base + 0.45, sin(angle) * 0.18),
					Vector3(0.40, 0.36, 0.40), CREAM, Vector3.ZERO, HAT_PART, 8, 4
				)
			toy.ellipsoid(
				Vector3(centre_x, base + 0.51, 0.0), Vector3(0.47, 0.38, 0.47),
				CREAM, Vector3.ZERO, HAT_PART, 8, 4
			)
		ChickenPitOptions.HAT_TOP:
			var silk := Color("3a3d4c")
			toy.cylinder(
				Vector3(centre_x, base + 0.02, 0.0), 0.55, 0.06, silk,
				Vector3.ZERO, -1.0, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.34, 0.0), 0.34, 0.62, silk.lightened(0.08),
				Vector3.ZERO, -1.0, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.10, 0.0), 0.355, 0.11, team,
				Vector3.ZERO, -1.0, HAT_PART
			)
		ChickenPitOptions.HAT_PIRATE:
			var felt := Color("34333f")
			var centre := Vector3(centre_x, base + 0.025, 0.0)
			var corners := PackedVector3Array()
			for corner in 3:
				var angle := float(corner) / 3.0 * TAU
				corners.append(Vector3(
					centre_x + cos(angle) * 0.58, base + 0.12, sin(angle) * 0.58))
				angle += PI / 3.0
				corners.append(Vector3(
					centre_x + cos(angle) * 0.43, base + 0.34, sin(angle) * 0.43))
			for edge in corners.size():
				var a := corners[edge]
				var b := corners[(edge + 1) % corners.size()]
				var low_a := a - Vector3.UP * 0.045
				var low_b := b - Vector3.UP * 0.045
				toy.triangle(centre, b, a, felt, HAT_PART)
				toy.triangle(centre - Vector3.UP * 0.045, low_a, low_b,
					felt.darkened(0.2), HAT_PART)
				toy.triangle(a, b, low_a, team, HAT_PART)
				toy.triangle(b, low_b, low_a, team, HAT_PART)
			toy.ellipsoid(
				Vector3(centre_x, base + 0.14, 0.0), Vector3(0.70, 0.37, 0.65),
				felt.lightened(0.08), Vector3.ZERO, HAT_PART
			)
			toy.ellipsoid(
				Vector3(centre_x + 0.31, base + 0.21, 0.0), Vector3(0.08, 0.13, 0.12),
				CREAM, Vector3.ZERO, HAT_PART, 8, 4
			)
		ChickenPitOptions.HAT_MUSHROOM:
			toy.cylinder(
				Vector3(centre_x, base + 0.015, 0.0), 0.315, 0.075, team,
				Vector3.ZERO, -1.0, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.075, 0.0), 0.50, 0.075, CREAM,
				Vector3.ZERO, -1.0, HAT_PART
			)
			var cap := SphereMesh.new()
			cap.radius = 0.5
			cap.height = 0.5
			cap.is_hemisphere = true
			cap.radial_segments = 12
			cap.rings = 6
			toy.append(cap, Transform3D(
				Basis.IDENTITY.scaled(Vector3(1.0, 0.62, 1.0)),
				Vector3(centre_x, base + 0.10, 0.0)), Color("db595f"), HAT_PART)
			toy.ellipsoid(
				Vector3(centre_x, base + 0.405, 0.0), Vector3(0.18, 0.05, 0.18),
				CREAM, Vector3.ZERO, HAT_PART, 8, 4
			)
			for spot in 4:
				var angle := float(spot) / 4.0 * TAU
				var rise := 0.31 * sqrt(1.0 - pow(0.33 / 0.5, 2.0))
				var normal := Vector3(cos(angle) * 0.33 / 0.25,
					rise / (0.31 * 0.31), sin(angle) * 0.33 / 0.25).normalized()
				var at := Vector3(centre_x + cos(angle) * 0.33,
					base + 0.10 + rise, sin(angle) * 0.33)
				toy.ellipsoid(
					at - normal * 0.015, Vector3(0.17, 0.06, 0.17), CREAM,
					Basis(Quaternion(Vector3.UP, normal)).get_euler(), HAT_PART, 8, 4
				)
		ChickenPitOptions.HAT_WIZARD:
			var felt := Color("6852a3")
			toy.cylinder(
				Vector3(centre_x, base + 0.015, 0.0), 0.49, 0.06, felt.darkened(0.12),
				Vector3.ZERO, -1.0, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x - 0.04, base + 0.37, 0.0), 0.31, 0.70, felt,
				Vector3(0.0, 0.0, 0.12), 0.015, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.07, 0.0), 0.32, 0.08, team,
				Vector3.ZERO, -1.0, HAT_PART
			)
			toy.box(
				Vector3(centre_x + 0.315, base + 0.08, 0.0), Vector3(0.035, 0.10, 0.13),
				Color("ffd45c"), Vector3.ZERO, HAT_PART
			)
			toy.box(
				Vector3(centre_x + 0.334, base + 0.08, 0.0), Vector3(0.012, 0.05, 0.07),
				felt.darkened(0.3), Vector3.ZERO, HAT_PART
			)
		ChickenPitOptions.HAT_SPROUT:
			var clay := Color("ba754e")
			toy.cylinder(
				Vector3(centre_x, base + 0.17, 0.0), 0.34, 0.31, clay,
				Vector3.ZERO, 0.28, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.055, 0.0), 0.385, 0.12, clay.lightened(0.12),
				Vector3.ZERO, -1.0, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.09, 0.0), 0.39, 0.035, team,
				Vector3.ZERO, -1.0, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.455, 0.0), 0.025, 0.28, Color("5a914f"),
				Vector3.ZERO, -1.0, HAT_PART
			)
			for side in [-1.0, 1.0]:
				toy.ellipsoid(
					Vector3(centre_x + side * 0.095, base + 0.49, side * 0.045),
					Vector3(0.27, 0.07, 0.13), Color("79b854"),
					Vector3(0.0, -side * 0.35, side * 0.5), HAT_PART, 8, 4
				)
			toy.ellipsoid(
				Vector3(centre_x, base + 0.60, 0.0), Vector3(0.13, 0.13, 0.13),
				BEAK, Vector3.ZERO, HAT_PART, 8, 4
			)
		ChickenPitOptions.HAT_CROWN:
			var gold := Color("ffd45c")
			toy.cylinder(
				Vector3(centre_x, base + 0.10, 0.0), 0.38, 0.20, gold,
				Vector3.ZERO, -1.0, HAT_PART
			)
			toy.cylinder(
				Vector3(centre_x, base + 0.21, 0.0), 0.40, 0.05, gold.lightened(0.25),
				Vector3.ZERO, -1.0, HAT_PART
			)
			for point in 5:
				var angle := float(point) / 5.0 * TAU
				toy.cylinder(
					Vector3(
						centre_x + cos(angle) * 0.30, base + 0.34, sin(angle) * 0.30
					),
					0.09, 0.28, gold, Vector3.ZERO, 0.01, HAT_PART
				)
				toy.ellipsoid(
					Vector3(
						centre_x + cos(angle) * 0.365, base + 0.11,
						sin(angle) * 0.365
					),
					Vector3(0.12, 0.12, 0.12), team, Vector3.ZERO, HAT_PART, 6, 3
				)
		_:
			pass


static func spectator_mesh() -> ArrayMesh:
	var toy := ToyMesh.new()
	toy.ellipsoid(Vector3(0.0, 0.55, 0.0), Vector3(0.75, 0.85, 0.65), CREAM,
		Vector3.ZERO, 0.0, 8, 4)
	toy.ellipsoid(Vector3(0.0, 1.08, 0.08), Vector3(0.48, 0.50, 0.48), CREAM,
		Vector3.ZERO, 0.0, 8, 4)
	toy.cylinder(Vector3(0.0, 1.05, 0.38), 0.12, 0.28, BEAK,
		Vector3(PI * 0.5, 0.0, 0.0), 0.0)
	toy.box(Vector3(0.0, 1.39, 0.07), Vector3(0.11, 0.23, 0.28), Color("e8453c"))
	for side in [-1.0, 1.0]:
		toy.ellipsoid(Vector3(side * 0.13, 1.17, 0.285), Vector3(0.08, 0.10, 0.045),
			INK, Vector3.ZERO, 0.0, 6, 3)
		toy.box(Vector3(side * 0.16, 0.06, 0.09), Vector3(0.12, 0.12, 0.26), BEAK)
	return toy.finish()
