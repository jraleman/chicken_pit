extends RefCounted

## A vertex-painted, miniature county fair. All solid scenery shares one surface.

const ToyMesh = preload("res://games/chicken_pit/pit/toy_mesh.gd")
const CREAM := Color("fff8e7")
const GRASS := Color("7cd44a")
const DARK_GRASS := Color("5cb238")
const DIRT := Color("e8b84b")
const WOOD := Color("bd8246")
const INK := Color("343344")
const PIT_RADIUS := 2.0
const PIT_FLOOR_RADIUS := 1.65
const PIT_FLOOR_Y := -1.35
const PIT_RIM_WIDTH := 0.18
const PIT_RIM_Y := 0.10
const PIT_EDGE_Y := 0.06


static func pit_extent(at: Vector3) -> float:
	return maxf(maxf(absf(at.x), absf(at.z)), (absf(at.x) + absf(at.z)) / sqrt(2.0))


## The cosmetic rope uses the same octagonal walls and lip as the authored mesh.
static func pit_surface_height(at: Vector3) -> float:
	var extent := pit_extent(at)
	if extent <= PIT_FLOOR_RADIUS:
		return PIT_FLOOR_Y
	if extent <= PIT_RADIUS:
		return lerpf(PIT_FLOOR_Y, PIT_EDGE_Y,
			(extent - PIT_FLOOR_RADIUS) / (PIT_RADIUS - PIT_FLOOR_RADIUS))
	if extent <= PIT_RADIUS + PIT_RIM_WIDTH:
		return lerpf(PIT_EDGE_Y, PIT_RIM_Y, (extent - PIT_RADIUS) / PIT_RIM_WIDTH)
	return 0.05


static func build(length: int, colors: Array[Color]) -> ArrayMesh:
	var toy := ToyMesh.new()
	var goal := length * 0.55
	var width := goal * 2.0 + 12.0
	var opening := _pit_outline(PIT_RADIUS)
	toy.plinth(Vector3(0.0, -0.78, -3.0), Vector3(width, 1.5, 19.0), 0.8, WOOD,
		opening)
	toy.plinth(Vector3(0.0, -0.035, -3.0), Vector3(width, 0.16, 19.0), 0.8, GRASS,
		opening)
	for stripe in range(-ceili(width / 4.0) + 1, ceili(width / 4.0)):
		var x := stripe * 2.0
		if absf(x) - 0.48 < goal + 1.8:
			toy.box(Vector3(x, 0.052, -7.3), Vector3(0.96, 0.015, 9.0), DARK_GRASS)
			toy.box(Vector3(x, 0.052, 4.3), Vector3(0.96, 0.015, 3.0), DARK_GRASS)
		else:
			toy.box(Vector3(x, 0.052, -3.0), Vector3(0.96, 0.015, 17.6), DARK_GRASS)
	toy.plinth(
		Vector3(0.0, -0.015, 0.0), Vector3(goal * 2.0 + 3.6, 0.12, 5.4), 0.65,
		Color("c58b40"), opening
	)
	toy.plinth(
		Vector3(0.0, 0.04, 0.0), Vector3(goal * 2.0 + 3.3, 0.02, 5.15), 0.60, DIRT,
		opening
	)
	_pit(toy)
	for side in [-1.0, 1.0]:
		toy.box(Vector3(0.0, 0.057, side * (PIT_RADIUS + 2.45) * 0.5),
			Vector3(0.10, 0.008, 2.45 - PIT_RADIUS), CREAM)
	for coop in 2:
		var side := -1.0 if coop == 0 else 1.0
		toy.box(Vector3(side * goal, 0.06, 0.0), Vector3(0.16, 0.012, 4.9),
			colors[coop])
		for edge in [-1.0, 1.0]:
			toy.cylinder(Vector3(side * goal, 0.76, edge * 2.72), 0.105, 1.38,
				CREAM)
		toy.box(Vector3(side * goal, 0.59, 2.79), Vector3(1.95, 0.50, 0.12),
			colors[coop].darkened(0.32))
		_stand(toy, Vector3(side * (goal * 0.56 + 2.6), 0.05, -5.8))
		_tree(toy, Vector3(side * (goal + 3.75), 0.05, -8.8))

	var barn_transform := Transform3D(
		Basis.from_euler(Vector3(0.0, -0.08, 0.0)), Vector3(-0.5, 0.07, -8.2)
	)
	toy.append(barn_mesh(), barn_transform, Color.WHITE)
	_fence(toy, goal)
	_bunting(toy, goal, colors)

	toy.ellipsoid(Vector3(-goal - 1.5, 0.25, -10.8), Vector3(9.0, 2.0, 3.3),
		DARK_GRASS, Vector3.ZERO, 0.0, 12, 4)
	toy.ellipsoid(Vector3(goal + 0.5, 0.3, -11.3), Vector3(9.0, 2.4, 3.1),
		GRASS, Vector3.ZERO, 0.0, 12, 4)

	var trough := Vector3(-goal - 3.0, 0.0, 2.5)
	toy.box(trough + Vector3(0.0, 0.38, 0.0), Vector3(1.35, 0.65, 0.86),
		Color("8eacaf"), Vector3(0.0, -0.18, 0.0))
	toy.box(trough + Vector3(0.0, 0.72, 0.0), Vector3(1.2, 0.035, 0.69),
		Color("74d8ef"), Vector3(0.0, -0.18, 0.0))
	for sack in 3:
		var at := Vector3(goal + 2.7 + sack * 0.33, 0.38, 2.2 + sack * 0.30)
		toy.ellipsoid(at, Vector3(0.65, 0.82, 0.52), Color("f0d08e"),
			Vector3(0.0, 0.2, -0.16 + sack * 0.18), 0.0, 10, 5)
		toy.cylinder(at + Vector3(0.0, 0.40, 0.0), 0.14, 0.12, WOOD)
	toy.torus(Vector3(goal + 3.3, 0.74, -2.9), 0.38, 0.74, INK,
		Vector3(PI * 0.5, 0.0, -0.25))
	toy.cylinder(Vector3(goal + 2.3, 0.53, -3.0), 0.49, 1.0, Color("f0cc68"))
	for band in [0.23, 0.8]:
		toy.torus(Vector3(goal + 2.3, band, -3.0), 0.48, 0.505, WOOD)

	var random := RandomNumberGenerator.new()
	random.seed = 8247
	for tuft in 42:
		var at := Vector3(random.randf_range(-goal - 4.9, goal + 4.9), 0.1,
			random.randf_range(3.0, 5.5))
		for blade in 3:
			toy.triangle(
				at + Vector3(-0.10 + blade * 0.08, 0.0, 0.0),
				at + Vector3(0.05 + blade * 0.08, 0.0, 0.06),
				at + Vector3(blade * 0.055, random.randf_range(0.15, 0.33), 0.0),
				DARK_GRASS
			)
		if tuft % 4 == 0:
			toy.ellipsoid(at + Vector3(0.0, 0.20, 0.0), Vector3(0.19, 0.08, 0.19),
				CREAM, Vector3.ZERO, 0.0, 6, 3)
			toy.ellipsoid(at + Vector3(0.0, 0.245, 0.0), Vector3(0.07, 0.06, 0.07),
				DIRT, Vector3.ZERO, 0.0, 6, 3)
	return toy.finish()


static func _pit_outline(radius: float) -> PackedVector2Array:
	return ToyMesh.plinth_outline(Vector2.ONE * radius * 2.0, radius * (2.0 - sqrt(2.0)))


static func _pit(toy: ToyMesh) -> void:
	var rim := _pit_outline(PIT_RADIUS + PIT_RIM_WIDTH)
	var opening := _pit_outline(PIT_RADIUS)
	var floor_outline := _pit_outline(PIT_FLOOR_RADIUS)
	var earth := Color("966339")
	var bedding := Color("9c783e")
	for index in opening.size():
		var next := (index + 1) % opening.size()
		var outer_a := Vector3(rim[index].x, PIT_RIM_Y, rim[index].y)
		var outer_b := Vector3(rim[next].x, PIT_RIM_Y, rim[next].y)
		var top_a := Vector3(opening[index].x, PIT_EDGE_Y, opening[index].y)
		var top_b := Vector3(opening[next].x, PIT_EDGE_Y, opening[next].y)
		var low_a := Vector3(floor_outline[index].x, PIT_FLOOR_Y, floor_outline[index].y)
		var low_b := Vector3(floor_outline[next].x, PIT_FLOOR_Y, floor_outline[next].y)
		var lip := DIRT.lerp(CREAM, 0.30 if index % 2 else 0.50)
		toy.triangle(outer_a, top_a, top_b, lip)
		toy.triangle(outer_a, top_b, outer_b, lip)
		toy.triangle(top_a, low_a, low_b, earth)
		toy.triangle(top_a, low_b, top_b, earth.darkened(0.08))
		toy.triangle(Vector3(0.0, PIT_FLOOR_Y, 0.0), low_b, low_a, bedding)
	for straw in 18:
		var angle := straw * 2.399963
		var radius := sqrt((straw + 0.5) / 18.0) * 1.4
		toy.box(Vector3(cos(angle) * radius, PIT_FLOOR_Y + 0.008, sin(angle) * radius),
			Vector3(0.26, 0.012, 0.035), DIRT, Vector3(0.0, angle, 0.0))


## The barn is independently reusable, including its white cross-braced doors.
static func barn_mesh() -> ArrayMesh:
	var toy := ToyMesh.new()
	var red := Color("e8453c")
	toy.box(Vector3(0.0, 1.58, 0.0), Vector3(4.5, 3.1, 3.25), red)
	for plank in range(-7, 8):
		toy.box(Vector3(plank * 0.29, 1.65, 1.64), Vector3(0.045, 2.9, 0.04),
			red.darkened(0.16))
	toy.triangle(Vector3(-2.25, 3.10, 1.65), Vector3(2.25, 3.10, 1.65),
		Vector3(0.0, 4.55, 1.65), red)
	for side in [-1.0, 1.0]:
		toy.box(Vector3(side * 1.18, 3.85, 0.0), Vector3(2.85, 0.20, 3.9),
			INK, Vector3(0.0, 0.0, -side * 0.57))
		toy.box(Vector3(side * 2.25, 1.60, 1.70), Vector3(0.15, 3.25, 0.16), CREAM)
		toy.box(Vector3(side * 0.68, 1.00, 1.72), Vector3(1.24, 1.95, 0.16),
			red.darkened(0.22))
		toy.beam(Vector3(side * 1.28, 0.10, 1.83),
			Vector3(0.0, 1.94, 1.83), 0.07, CREAM)
		toy.beam(Vector3(side * 1.28, 1.94, 1.83),
			Vector3(0.0, 0.10, 1.83), 0.07, CREAM)
	toy.box(Vector3(0.0, 2.03, 1.82), Vector3(2.82, 0.16, 0.16), CREAM)
	toy.box(Vector3(0.0, 1.02, 1.82), Vector3(0.12, 2.1, 0.16), CREAM)
	toy.box(Vector3(0.0, 2.68, 1.78), Vector3(3.7, 0.69, 0.12), CREAM)
	toy.ellipsoid(Vector3(0.0, 3.58, 1.72), Vector3(0.67, 0.67, 0.10), CREAM)
	toy.ellipsoid(Vector3(0.0, 3.58, 1.80), Vector3(0.48, 0.48, 0.08), INK)
	toy.box(Vector3(0.0, 3.58, 1.86), Vector3(0.06, 0.48, 0.05), CREAM)
	toy.box(Vector3(0.0, 3.58, 1.86), Vector3(0.48, 0.06, 0.05), CREAM)
	toy.cylinder(Vector3(1.0, 4.7, -0.5), 0.055, 1.0, WOOD)
	toy.box(Vector3(1.0, 5.08, -0.5), Vector3(1.05, 0.055, 0.06), DIRT)
	toy.triangle(Vector3(1.58, 5.08, -0.5), Vector3(1.26, 5.27, -0.5),
		Vector3(1.26, 4.89, -0.5), DIRT)
	return toy.finish()


static func clouds() -> ArrayMesh:
	var toy := ToyMesh.new()
	for cloud in 7:
		var x := -17.0 + cloud * 5.3
		var y := 6.1 + sin(cloud * 2.1) * 1.3
		for puff in 3:
			toy.ellipsoid(
				Vector3(x + puff * 0.72, y + sin(puff * 1.5) * 0.3, -15.5),
				Vector3(2.0, 0.82 + puff * 0.16, 0.9), CREAM,
				Vector3.ZERO, 0.0, 10, 5
			)
	return toy.finish()


static func _stand(toy: ToyMesh, at: Vector3) -> void:
	for row in 2:
		toy.box(at + Vector3(0.0, 0.33 + row * 0.43, -row * 0.72),
			Vector3(5.25, 0.17, 0.85), WOOD)
		for side in [-1.0, 1.0]:
			toy.box(at + Vector3(side * 2.15, 0.19 + row * 0.2, -row * 0.72),
				Vector3(0.15, 0.44 + row * 0.4, 0.65), WOOD.darkened(0.18))
	toy.box(at + Vector3(0.0, 0.18, 0.49), Vector3(5.25, 0.37, 0.10),
		CREAM)


static func _tree(toy: ToyMesh, at: Vector3) -> void:
	toy.cylinder(at + Vector3.UP, 0.20, 2.0, WOOD, Vector3.ZERO, 0.13)
	for crown in 3:
		toy.ellipsoid(
			at + Vector3(sin(crown * 2.5) * 0.65, 2.5 + crown * 0.40, 0.0),
			Vector3(2.7 - crown * 0.2, 2.1, 2.5),
			DARK_GRASS.lerp(GRASS, crown * 0.4), Vector3.ZERO, 0.0, 10, 5
		)


static func _fence(toy: ToyMesh, goal: float) -> void:
	var count := ceili((goal + 4.4) / 1.5)
	for index in range(-count, count + 1):
		var x := index * 1.5
		toy.box(Vector3(x, 0.62, -3.85), Vector3(0.12, 1.1, 0.14), CREAM)
		if index < count:
			for height in [0.44, 0.91]:
				toy.box(Vector3(x + 0.75, height, -3.85), Vector3(1.5, 0.12, 0.10),
					CREAM.darkened(0.06))


static func _bunting(toy: ToyMesh, goal: float, colors: Array[Color]) -> void:
	var width := goal + 3.5
	for side in [-1.0, 1.0]:
		toy.cylinder(Vector3(side * width, 1.65, -3.65), 0.065, 3.2, WOOD)
	var count := ceili(width * 2.0 / 0.70)
	for index in count:
		var t := float(index) / count
		var t_next := float(index + 1) / count
		var a := Vector3(lerpf(-width, width, t), 3.20 - sin(t * PI) * 0.58, -3.65)
		var b := Vector3(lerpf(-width, width, t_next),
			3.20 - sin(t_next * PI) * 0.58, -3.65)
		toy.beam(a, b, 0.018, WOOD)
		var color := colors[index % 2] if index % 3 != 2 else DIRT
		toy.triangle(a + Vector3(0.10, -0.03, 0.0), b - Vector3(0.10, 0.03, 0.0),
			(a + b) * 0.5 - Vector3(0.0, 0.45, 0.0), color)
