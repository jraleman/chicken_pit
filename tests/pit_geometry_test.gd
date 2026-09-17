extends SceneTree

## The authored models stay batched, retain their paint, and expose rigid-part tags.

const Scenery = preload("res://games/chicken_pit/pit/scenery.gd")
const ChickenRig = preload("res://games/chicken_pit/pit/chicken_rig.gd")
const ToyMesh = preload("res://games/chicken_pit/pit/toy_mesh.gd")
const GalleryStage = preload("res://games/chicken_pit/ui/gallery_stage.gd")

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
	_test_store_hats(colors)
	_test_gallery_exhibits(colors)
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


## Every plinth in the gallery has to have something standing on it, framed from
## somewhere worth looking. An exhibit whose id the stage does not recognise
## would show an empty case, and one with no framing entry would open on a
## default angle that nobody chose.
##
## The coop colours are checked against the same literals the rest of this test
## uses, which are in turn the `player_one_color` / `player_two_color` exports on
## `gameplay.tscn`. The gallery draws birds when no round exists, so it cannot
## read them off the shell, and this is what keeps the two in step.
func _test_gallery_exhibits(colors: Array[Color]) -> void:
	for coop in 2:
		_expect(
			ChickenPitOptions.COOP_COLORS[coop].is_equal_approx(colors[coop]),
			"The gallery's coop colours must match the ones the pit plays in."
		)
	var stage: Node = GalleryStage.new()
	for exhibit: Dictionary in ChickenPitOptions.GALLERY_EXHIBITS:
		var id := str(exhibit["id"])
		_expect(
			GalleryStage.FRAMING.has(id),
			"The gallery stage must know where to open '%s' from." % id
		)
		var mesh: ArrayMesh = stage.call("mesh_for", id)
		_expect(mesh != null, "The gallery stage must build '%s'." % id)
		if mesh == null:
			continue
		_expect(
			mesh.get_surface_count() == 1,
			"Exhibit '%s' must stay one batched surface on its plinth." % id
		)
		_expect(
			mesh.get_aabb().size.length() > 0.2,
			"Exhibit '%s' must have something to look at." % id
		)
	# The birds are the exhibits the store feeds, so they have to come out
	# wearing the coop's paint rather than the rig's default.
	for coop in 2:
		var bird_id := (
			ChickenPitOptions.EXHIBIT_BIRD_BLUE
			if coop == 1
			else ChickenPitOptions.EXHIBIT_BIRD_RED
		)
		var bird: ArrayMesh = stage.call("mesh_for", bird_id)
		if bird == null:
			continue
		var paint: PackedColorArray = bird.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		_expect(
			_contains_color(paint, colors[coop]),
			"Exhibit '%s' must wear its own coop's colour." % bird_id
		)
	_expect(
		stage.call("mesh_for", "not_an_exhibit") == null,
		"The gallery stage must not invent a model for an id it does not know."
	)
	stage.free()


## Every hat on the shelf has to be geometry the pit can actually wear: batched
## into the same surface, tagged as head parts so it dips with the head, wearing
## the coop's colour, and tall enough to be seen without burying the comb or the
## bonnet that tell the two coops apart.
func _test_store_hats(colors: Array[Color]) -> void:
	for coop in 2:
		var bare := ChickenRig.build_mesh(colors[coop], coop == 1)
		var bare_top := bare.get_aabb().position.y + bare.get_aabb().size.y
		var crest := ChickenRig.BONNET_HAT_BASE if coop == 1 else ChickenRig.COMB_HAT_BASE
		for item: Dictionary in ChickenPitOptions.STORE_ITEMS:
			var hat := str(item["id"])
			var mesh := ChickenRig.build_mesh(colors[coop], coop == 1, hat)
			_expect(
				mesh.get_surface_count() == 1,
				"Wearing '%s' must not cost the bird a second draw call." % hat
			)
			var arrays := mesh.surface_get_arrays(0)
			var top: float = mesh.get_aabb().position.y + mesh.get_aabb().size.y
			if bool(item.get("default", false)):
				_expect(
					is_equal_approx(top, bare_top),
					"The bare look must add nothing to the bird."
				)
				continue
			_expect(
				top > bare_top,
				"'%s' must actually show above the bird it is worn on." % hat
			)
			_expect(
				(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				> (bare.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
				"'%s' must add geometry rather than replace the bird's own." % hat
			)
			_expect(
				_lowest_above(arrays, crest - 0.06) >= crest - 0.06,
				"'%s' must perch above the comb or bonnet, not bury it." % hat
			)
			_expect(
				_contains_color(arrays[Mesh.ARRAY_COLOR], colors[coop]),
				"'%s' must keep a band in the wearer's colour." % hat
			)
			_expect(
				_tagged_above(arrays, crest),
				"'%s' must be tagged as head geometry so it dips with the head." % hat
			)


## The lowest vertex a hat contributes, found by ignoring everything the bare
## bird already reaches. Returns [param floor_y] when the hat adds nothing.
func _lowest_above(arrays: Array, floor_y: float) -> float:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var lowest := INF
	for vertex in vertices:
		if vertex.y >= floor_y:
			lowest = minf(lowest, vertex.y)
	return floor_y if lowest == INF else lowest


## True when the geometry above [param height] is tagged as the head, which is
## the part the vertex shader dips.
func _tagged_above(arrays: Array, height: float) -> bool:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var tags: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var found := false
	for index in vertices.size():
		if vertices[index].y <= height:
			continue
		if not is_equal_approx(tags[index].x, ChickenRig.HAT_PART):
			return false
		found = true
	return found


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
