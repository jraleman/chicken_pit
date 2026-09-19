extends SceneTree

## The authored models stay batched, retain their paint, and expose rigid-part tags.

const Scenery = preload("res://games/chicken_pit/pit/scenery.gd")
const ChickenRig = preload("res://games/chicken_pit/pit/chicken_rig.gd")
const ToyMesh = preload("res://games/chicken_pit/pit/toy_mesh.gd")
const GalleryStage = preload("res://games/chicken_pit/ui/gallery_stage.gd")
const BIRD_CHANNELS := [
	Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_INDEX,
]

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


func _test_store_hats(colors: Array[Color]) -> void:
	for coop in 2:
		var bare := ChickenRig.build_mesh(colors[coop], coop == 1)
		var bare_arrays := bare.surface_get_arrays(0)
		var bare_vertices: PackedVector3Array = bare_arrays[Mesh.ARRAY_VERTEX]
		var bare_indices: PackedInt32Array = bare_arrays[Mesh.ARRAY_INDEX]
		var body := ChickenRig.hat_ready_mesh(colors[coop], coop == 1)
		var body_arrays := body.surface_get_arrays(0)
		var body_vertices: PackedVector3Array = body_arrays[Mesh.ARRAY_VERTEX]
		var body_indices: PackedInt32Array = body_arrays[Mesh.ARRAY_INDEX]
		var body_top := body.get_aabb().end.y
		_expect(body.get_surface_count() == 1, "The hat-ready body must remain one surface.")
		for channel in BIRD_CHANNELS:
			_expect(
				bare_arrays[channel].slice(0, body_arrays[channel].size()) == body_arrays[channel],
				"The hat-ready variant must preserve the body, face and all rigid-part tags."
			)
		if coop == 0:
			var comb_only := body_vertices.size() < bare_vertices.size()
			var bare_tags: PackedVector2Array = bare_arrays[Mesh.ARRAY_TEX_UV2]
			var bare_paint: PackedColorArray = bare_arrays[Mesh.ARRAY_COLOR]
			for index in range(body_vertices.size(), bare_vertices.size()):
				comb_only = comb_only and bare_vertices[index].y > 1.40 \
					and is_equal_approx(bare_tags[index].x, ChickenRig.HAT_PART) \
					and bare_paint[index].is_equal_approx(colors[coop])
			_expect(comb_only, "Only the red comb may be omitted from the hat-ready body.")
			_expect(not is_finite(_surface_distance(
				body, Vector3(2.0, 1.76, 0.0), Vector3.LEFT)),
				"The hat-ready head must not leave a comb sticking out at the front.")
		else:
			_expect(body_vertices.size() == bare_vertices.size(),
				"The blue hat-ready body must retain the complete bonnet and its ties.")
		for fallback: String in ["", ChickenPitOptions.HAT_BARE, "pit_hat_unknown"]:
			var fallback_arrays := ChickenRig.build_mesh(
				colors[coop], coop == 1, fallback).surface_get_arrays(0)
			for channel in BIRD_CHANNELS:
				_expect(fallback_arrays[channel] == bare_arrays[channel],
					"Empty, bare and unknown hat ids must restore the complete natural bird.")
		_test_chicken_animation(body)
		for item: Dictionary in ChickenPitOptions.STORE_ITEMS:
			var hat := str(item["id"])
			var mesh := ChickenRig.build_mesh(colors[coop], coop == 1, hat)
			var label := "%s on coop %d" % [hat, coop + 1]
			_expect(
				mesh.get_surface_count() == 1,
				"Wearing %s must not cost the bird a second draw call." % label
			)
			var arrays := mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var paint: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var tags: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			var top: float = mesh.get_aabb().position.y + mesh.get_aabb().size.y
			var is_bare := bool(item.get("default", false))
			var reference := bare_arrays if is_bare else body_arrays
			for channel in BIRD_CHANNELS:
				_expect(
					arrays[channel].slice(0, reference[channel].size()) == reference[channel],
					"%s must use the correct natural or comb-free body without changing it." % label
				)
			if is_bare:
				_expect(
					vertices.size() == bare_vertices.size() and indices == bare_indices,
					"The bare look must add nothing to the bird."
				)
				continue
			_expect(
				top > body_top,
				"%s must actually show above the bird it is worn on." % label
			)
			_expect(
				vertices.size() > body_vertices.size(),
				"%s must add hat geometry to the hat-ready body." % label
			)
			var lowest := INF
			var head_tagged := true
			for index in range(body_vertices.size(), vertices.size()):
				lowest = minf(lowest, vertices[index].y)
				head_tagged = head_tagged and is_equal_approx(tags[index].x, ChickenRig.HAT_PART)
			_expect(
				lowest >= 1.50,
				"%s must leave the eyes and bonnet ties exposed." % label
			)
			_expect(
				_contains_color(paint.slice(body_vertices.size()), colors[coop]),
				"%s must add its own trim in the wearer's colour." % label
			)
			_expect(
				head_tagged,
				"All of %s must be tagged as head geometry so no trim floats during a pull." % label
			)
			if coop == 1:
				var brim_origin := Vector3(2.0, 1.53, 0.0)
				var visible_brim := _surface_distance(bare, brim_origin, Vector3.LEFT)
				_expect(
					is_finite(visible_brim) and is_equal_approx(
						visible_brim, _surface_distance(mesh, brim_origin, Vector3.LEFT)),
					"%s must leave the bonnet brim visible below the hat." % label
				)
			# Ignore the coloured crest: contact with it still leaves the hat
			# raised above the cream head the player expects it to sit on.
			for x: float in [0.29, 0.37, 0.45]:
				var point := Vector2(x, 0.0)
				var head := _surface_height(bare, point, 0, false, true)
				var underside := _surface_height(mesh, point, body_indices.size(), true)
				var overlap := head - underside
				_expect(
					overlap >= 0.005 and overlap <= 0.10,
					"%s must touch the head at x %.2f without burying it (overlap %.3f)."
					% [label, x, overlap]
				)
			if hat == ChickenPitOptions.HAT_MUSHROOM:
				for offset: Vector2 in [Vector2.ZERO, Vector2(0.33, 0.0), Vector2(-0.33, 0.0),
					Vector2(0.0, 0.33), Vector2(0.0, -0.33)]:
					var point := Vector2(ChickenRig.HAT_CENTRE_X, 0.0) + offset
					var surface := _surface_height(mesh, point, body_indices.size())
					var cream := _surface_height(mesh, point, body_indices.size(), false, true)
					_expect(is_finite(surface) and is_equal_approx(surface, cream),
						"The toadstool's cream spots must sit on its surface, not inside the cap.")


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


func _surface_height(
	mesh: ArrayMesh, point: Vector2, first_index := 0, underside := false, head_only := false
) -> float:
	return 6.0 - _surface_distance(
		mesh, Vector3(point.x, 6.0, point.y), Vector3.DOWN, first_index, underside, head_only)


func _surface_distance(
	mesh: ArrayMesh, origin: Vector3, direction: Vector3,
	first_index := 0, farthest := false, head_only := false
) -> float:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var paint: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var tags: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var distance := -INF if farthest else INF
	for offset in range(first_index, indices.size(), 3):
		var index := indices[offset]
		if head_only and (not is_equal_approx(tags[index].x, ChickenRig.HAT_PART)
			or not paint[index].is_equal_approx(ChickenRig.CREAM)):
			continue
		var hit: Variant = Geometry3D.ray_intersects_triangle(origin, direction,
			vertices[indices[offset]], vertices[indices[offset + 1]], vertices[indices[offset + 2]])
		if hit is Vector3:
			var hit_distance := origin.distance_to(hit)
			distance = maxf(distance, hit_distance) if farthest else minf(distance, hit_distance)
	return distance


func _contains_color(colors: PackedColorArray, expected: Color) -> bool:
	for color in colors:
		if color.is_equal_approx(expected):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
