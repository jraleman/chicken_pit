extends SceneTree

## The authored models stay batched, retain their paint, and expose rigid-part tags.

const Scenery = preload("res://games/chicken_pit/pit/scenery.gd")
const ChickenRig = preload("res://games/chicken_pit/pit/chicken_rig.gd")
const ToyMesh = preload("res://games/chicken_pit/pit/toy_mesh.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var colors: Array[Color] = [Color("ff6b57"), Color("4da3ff")]
	var barn := Scenery.barn_mesh()
	_expect(barn.get_surface_count() == 1, "The barn must use one batched surface.")
	var nested := ToyMesh.new()
	nested.append(barn, Transform3D.IDENTITY, Color.WHITE)
	var painted := nested.finish()
	var paint: PackedColorArray = painted.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	_expect(_contains_color(paint, Color("e8453c"))
		and _contains_color(paint, Color("fff8e7")),
		"Batching the barn into scenery must preserve red walls and white trim.")
	for coop in 2:
		var mesh := ChickenRig.build_mesh(colors[coop], coop == 1)
		_expect(mesh.get_surface_count() == 1, "Each rig must remain one draw surface.")
		var arrays := mesh.surface_get_arrays(0)
		var tags: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		for part in range(1, 6):
			var found := false
			for tag in tags:
				if is_equal_approx(tag.x, float(part)):
					found = true
					break
			_expect(found, "Both wings, the head and both feet need independent rigid tags.")
		var body_paint: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		_expect(_contains_color(body_paint, colors[coop]),
			"Coop paint must come from the supplied scene colour.")
		_expect(mesh.get_aabb().size.y > 1.6, "The chicken must include its headwear silhouette.")
		_test_chicken_animation(mesh)
	var short_farm := Scenery.build(6, colors)
	var long_farm := Scenery.build(18, colors)
	_expect(short_farm.get_surface_count() == 1 and long_farm.get_surface_count() == 1,
		"Changing rope length must not increase the static scenery draw calls.")
	_expect(is_equal_approx(long_farm.get_aabb().size.x - short_farm.get_aabb().size.x, 13.2),
		"The farm must expand with both sets of 0.55-metre notches.")
	for farm in [short_farm, Scenery.build(10, colors), long_farm]:
		_test_pit_opening(farm)
	_expect(ChickenRig.spectator_mesh().get_surface_count() == 1,
		"The shared spectator mesh must fit a single MultiMesh draw.")
	if _failures.is_empty():
		print("Chicken Pit geometry tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_pit_opening(mesh: ArrayMesh) -> void:
	for point: Vector2 in [Vector2.ZERO, Vector2(0.8, 0.6), Vector2(-0.8, -0.6),
		Vector2(0.8, -0.6), Vector2(-0.8, 0.6)]:
		var height := _surface_height(mesh, point)
		_expect(height >= Scenery.PIT_FLOOR_Y - 0.001
			and height <= Scenery.PIT_FLOOR_Y + 0.02,
			"The central hole must expose its recessed floor, not a grass, dirt or wooden lid.")
	for side in [-1.0, 1.0]:
		var height := _surface_height(mesh, Vector2(side * (Scenery.PIT_RADIUS + 0.35), 0.0))
		_expect(height > 0.03 and height < 0.07,
			"The playing ground on both sides of the hole must remain intact.")
	for extent: float in [0.0, 1.7, 1.9, 2.05, 2.12, 2.4]:
		for direction: Vector2 in [Vector2.RIGHT, Vector2(1.0, 1.0).normalized()]:
			var point := direction * extent
			var sampled := Scenery.pit_surface_height(Vector3(point.x, 0.0, point.y))
			_expect(absf(_surface_height(mesh, point) - sampled) < 0.02,
				"Rope support heights must match the actual floor, walls, rim and field.")


func _test_chicken_animation(mesh: ArrayMesh) -> void:
	var bird := ChickenRig.new()
	get_root().add_child(bird)
	bird.configure(mesh, 0.37, 1.0)
	bird.pose(0.0, 0.0, 0.0, false, 0, false)
	var material := bird.get("_material") as ShaderMaterial
	var idle_head := float(material.get_shader_parameter("head_dip"))
	bird.pose(0.5, 0.5, 0.0, false, 0, false)
	_expect(not is_equal_approx(idle_head, float(material.get_shader_parameter("head_dip"))),
		"Idle chickens must peck, not merely hold a fixed head pose.")
	bird.pull(10.35)
	bird.pose(0.5, 1.0 / 60.0, 70.0, true, 0, false)
	var dip := float(material.get_shader_parameter("head_dip"))
	var expected := bird.to_global(ChickenRig.HEAD_HINGE
		+ (ChickenRig.BEAK_GRIP - ChickenRig.HEAD_HINGE).rotated(Vector3.BACK, dip))
	_expect(bird.beak_position().is_equal_approx(expected),
		"The rope grip must include the head rotation sent to the vertex shader.")
	bird.fall_pose(Vector3(0.0, -0.4, 0.0), 0.62, 0.52)
	_expect(absf(float(material.get_shader_parameter("flap_skew"))) > 0.01
		and float(material.get_shader_parameter("foot_kick")) > 1.0,
		"Falling chickens need independently flailing wings and kicking feet.")
	bird.fall_pose(Vector3(0.0, -1.325, 0.0), 0.95, 0.52)
	_expect(bird.scale.y < bird.scale.x,
		"A landing must briefly squash the body instead of stopping rigidly.")
	bird.fall_pose(Vector3(0.0, -1.325, 0.0), 1.0, 0.52)
	_expect(bird.position.is_equal_approx(Vector3(0.0, -1.325, 0.0))
		and bird.scale.is_equal_approx(Vector3.ONE * 0.52),
		"The tumble and squash must finish exactly on the resting pose.")
	bird.reset_pose()
	bird.pose(0.5, 0.0, 70.0, true, 0, true)
	_expect(is_zero_approx(float(material.get_shader_parameter("head_dip")))
		and is_zero_approx(float(material.get_shader_parameter("flap_skew")))
		and is_zero_approx(float(material.get_shader_parameter("foot_kick"))),
		"Reduced motion must clear the decorative head, wing and foot animation.")
	bird.free()


func _surface_height(mesh: ArrayMesh, point: Vector2) -> float:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var height := -INF
	var origin := Vector3(point.x, 6.0, point.y)
	for offset in range(0, indices.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(origin, Vector3.DOWN,
			vertices[indices[offset]], vertices[indices[offset + 1]], vertices[indices[offset + 2]])
		if hit is Vector3:
			height = maxf(height, hit.y)
	return height


func _contains_color(colors: PackedColorArray, expected: Color) -> bool:
	for color in colors:
		if color.is_equal_approx(expected):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
