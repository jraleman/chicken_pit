extends SceneTree

## Graphics-only smoke test: real input, all rope lengths, live assists and a draw budget.
## Optional --pit-capture-dir=<absolute path> saves screenshots after a rendered frame.

const PitState = preload("res://games/chicken_pit/pit/pit_state.gd")
const PitHistory = preload("res://games/chicken_pit/pit/pit_history.gd")
const Scenery = preload("res://games/chicken_pit/pit/scenery.gd")
const ChickenRig = preload("res://games/chicken_pit/pit/chicken_rig.gd")
const RopeView = preload("res://games/chicken_pit/pit/rope_view.gd")
const PitCamera = preload("res://games/chicken_pit/pit/pit_camera.gd")
const PitLighting = preload("res://games/chicken_pit/pit/pit_lighting.gd")
var _failures := PackedStringArray()
var _capture_dir := ""
var _poster_path := ""
var _settings: Node
var _original_values: Dictionary


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("pit_view_test.gd needs a graphics window, not --headless.")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pit-capture-dir="):
			_capture_dir = argument.trim_prefix("--pit-capture-dir=")
		if argument.begins_with("--pit-poster="):
			_poster_path = argument.trim_prefix("--pit-poster=")
	if not _capture_dir.is_empty():
		var error := DirAccess.make_dir_recursive_absolute(_capture_dir)
		if error != OK:
			push_error("Could not create the screenshot directory: %s" % error)
			quit(1)
			return
	Engine.max_fps = 60
	_settings = get_root().get_node("Settings")
	_original_values = (_settings.get("_values") as Dictionary).duplicate(true)
	var save_timer := _settings.get("_save_timer") as Timer
	var save_mode := save_timer.process_mode
	save_timer.process_mode = Node.PROCESS_MODE_DISABLED
	var original_game := GameCatalog.current_id()
	GameCatalog.select(ChickenPitOptions.GAME_ID)
	get_root().get_node("GameSession").call(
		"configure_multiplayer", GameSession.PlayerTwoController.HUMAN)
	_settings.call("reset_controls_to_defaults", ChickenPitOptions.GAME_ID)
	_settings.call("set_value", Settings.ROUND_MODE_KEY, Settings.RoundMode.TIMER)
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	_settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, true)
	_settings.call("set_value", ChickenPitOptions.ROUND_LENGTH_KEY, 45.0)
	_settings.call("set_value", ChickenPitOptions.ROPE_LENGTH_KEY, 10.0)
	_settings.call("set_value", ChickenPitOptions.PULL_POWER_KEY, 1.0)
	_settings.call("set_value", ChickenPitOptions.STRENGTH_DECAY_KEY, 1.0)
	_settings.call("set_value", Settings.GAMEPLAY_SPEED_KEY, 1.0)

	var packed := load("res://games/chicken_pit/gameplay.tscn") as PackedScene
	var fixture := load("res://games/chicken_pit/tests/pit_round_fixture.gd") as Script
	if packed == null or fixture == null or not fixture.can_instantiate():
		push_error("The shipped Chicken Pit scene and render fixture must compile.")
		quit(1)
		return
	var game := packed.instantiate()
	var red: Color = game.get("player_one_color")
	var blue: Color = game.get("player_two_color")
	game.set_script(fixture)
	game.set("player_one_color", red)
	game.set("player_two_color", blue)
	var history_path: String = game.get("history_path")
	get_root().add_child(game)
	await process_frame
	(game.get_node("%RoundTimer") as Timer).start(45.0)
	for frame in 240:
		if frame % 8 == 0:
			_dispatch(ChickenPitOptions.pull_actions(0)[(frame / 8) % 3])
		if frame % 12 == 0:
			_dispatch(ChickenPitOptions.pull_actions(1)[(frame / 12) % 3])
		await process_frame
	await RenderingServer.frame_post_draw
	_check_world(game, 10)
	_capture("pit-gameplay.png")
	if not _poster_path.is_empty():
		var poster := get_root().get_texture().get_image()
		poster.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
		_expect(poster.save_png(_poster_path) == OK, "The game poster must save successfully.")

	game.set_process(false)
	await _test_store_hats(game)
	await _test_pull_animation(game)
	await _test_cinematics(game)
	var history: PitHistory = game.get("_pit_history")
	var view := game.get("_view") as Node
	var flock := view.get("_pit_flock") as MultiMeshInstance3D
	_expect(history.completed_matches == 0 and flock.multimesh.visible_instance_count == 0,
		"The rendered first game must have an actual empty hole.")
	_settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, false)
	_expect(await _pit_chicken_pixels(game) == 0,
		"The first match must not render remembered chickens.")
	for completed in range(1, 6):
		game.call("_on_round_timer_timeout")
		game.call("_start_round")
		(game.get_node("%RoundTimer") as Timer).stop()
		_expect(history.completed_matches == completed
			and flock.multimesh.visible_instance_count == mini(completed * 6, 24),
			"Every replay must add six saved chickens, stopping at 24.")
		_expect(view.get("_pit_flock") == flock,
			"Replaying at the same rope length must reuse the fixed-size flock pool.")
		await _render_frame()
		if completed == 1:
			_expect(await _pit_chicken_pixels(game) > 32,
				"The six remembered chickens must actually be visible inside the rendered hole.")
			_capture("pit-returning-player.png")
			var before := flock.multimesh.get_instance_transform(0)
			view.set_process(false)
			await _advance_view(view, 0.2)
			_expect(not flock.multimesh.get_instance_transform(0).is_equal_approx(before),
				"Chickens already in the hole must have gentle idle movement.")
			view.set_process(true)
	_capture("pit-full-flock.png")
	_check_budget(game, "full flock")
	_settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, true)
	for length in [6, 18]:
		_settings.call("set_value", ChickenPitOptions.ROPE_LENGTH_KEY, length)
		game.call("_start_round")
		for frame in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		_check_world(game, length)
		_capture("pit-length-%d.png" % length)

	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	var camera := view.get("camera") as Camera3D
	var transform := camera.transform
	flock = view.get("_pit_flock") as MultiMeshInstance3D
	var parked_flock := flock.multimesh.get_instance_transform(0)
	var state: PitState = game.get("_state")
	state.rope = state.L * 0.8
	view.call("present", state)
	(game.get("_tug_meter") as Control).call("present", state)
	for frame in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	_expect(camera.transform.is_equal_approx(transform),
		"The reduced-motion camera must remain fixed as the knot moves.")
	_expect(not bool((view.get("rope_view") as Node).call("simulation_enabled")),
		"The reduced-motion path must disable Verlet, not just damp it.")
	_expect(flock.multimesh.get_instance_transform(0).is_equal_approx(parked_flock),
		"Reduced motion must also stop the resident flock's idle pecking and bobbing.")
	for emitter in view.find_children("*", "GPUParticles3D", true, false):
		_expect(not (emitter as GPUParticles3D).visible,
			"Reduced motion must immediately suppress all existing particles.")
	_capture("pit-reduced-motion.png")
	state.rope = -state.L + 0.01
	state.strength[1] = 100.0
	game.call("_update_round", 0.10, 45.0)
	(game.get("_pin_timer") as Timer).stop()
	for index in 6:
		var bird: Node3D = view.get("_birds")[index]
		_expect(not bird.visible and bird.global_position.y < 0.0,
			"Reduced motion must show the landed coop immediately, without a tumble.")
	_expect(int(view.call("diagnostics")["pit_chickens"]) == 24,
		"Reduced motion must preserve the same capped flock outcome.")
	_check_rope(game, "reduced-motion pin", true)
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	view.call("_process", 0.1)
	for index in 6:
		_expect(not (view.get("_birds")[index] as Node3D).visible,
			"Disabling reduced motion after a pin must not rewind the fall.")
	_settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, false)
	for emitter in view.find_children("*", "GPUParticles3D", true, false):
		_expect(not (emitter as GPUParticles3D).visible,
			"Disabling intense effects must suppress the particle pool.")

	_settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, true)
	for length in [6, 10, 18]:
		for winner in 2:
			await _test_pin_fall(game, winner, length)
	for completed in [0, 1]:
		for winner in 2:
			await _test_pin_fall(game, winner, 10, completed)

	await _test_sunset(game)
	game.set("_round_active", false)
	game.queue_free()
	await process_frame
	if FileAccess.file_exists(history_path):
		_expect(DirAccess.remove_absolute(history_path) == OK,
			"The rendered fixture must remove its isolated saved history.")
	var values := _settings.get("_values") as Dictionary
	values.clear()
	values.merge(_original_values, true)
	save_timer.stop()
	save_timer.process_mode = save_mode
	GameCatalog.select(original_game)
	await create_timer(0.85).timeout
	for child in get_root().get_node("AudioManager").find_children(
		"*", "AudioStreamPlayer", true, false):
		var player := child as AudioStreamPlayer
		player.stop()
		player.stream = null
	await create_timer(0.1).timeout
	if _failures.is_empty():
		print("Chicken Pit rendered view tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _dispatch(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	get_root().push_input(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	get_root().push_input(release)


func _check_world(game: Node, length: int) -> void:
	var view := game.get("_view") as Node
	var diagnostics: Dictionary = view.call("diagnostics")
	_expect(not bool(diagnostics["inert"]) and int(diagnostics["birds"]) == 12,
		"The rendered world must contain both six-bird coops.")
	_expect(int(diagnostics["notch_count"]) == length * 2,
		"All legal rope lengths must have exactly one marker per notch.")
	_expect(int(diagnostics["pit_capacity"]) == 24 and int(diagnostics["pit_chickens"]) <= 24,
		"The resident flock must use a fixed, capped 24-instance batch.")
	_expect(bool(diagnostics["rope_simulation"])
		and int(diagnostics["particle_emitters"]) > 0,
		"The graphics path must build the cosmetic rope and reusable emitters.")
	var camera := view.get("camera") as Camera3D
	var viewport := game.get("_pit_viewport") as SubViewport
	var rect := Rect2(Vector2.ZERO, Vector2(viewport.size))
	for side in [-1.0, 1.0]:
		var goal := Vector3(side * length * 0.55, 0.5, 0.0)
		_expect(not camera.is_position_behind(goal) and rect.has_point(camera.unproject_position(goal)),
			"Both goals must fit the camera at rope length %d." % length)
	for bird: Node3D in view.get("_birds"):
		var rear := bird.to_global(Vector3(-1.0, 0.7, 0.0))
		_expect(rect.has_point(camera.unproject_position(rear)),
			"The full coops, not just the goals, must fit at rope length %d." % length)
	_check_budget(game, "length %d" % length)


func _test_store_hats(game: Node) -> void:
	var view := game.get("_view") as Node
	var state: PitState = game.get("_state")
	var colors: Array[Color] = [game.get("player_one_color"), game.get("player_two_color")]
	var original_hats: PackedStringArray = view.get("_hats")
	var was_processing := view.is_processing()
	view.set_process(false)
	var preview := preload("res://games/chicken_pit/ui/hat_preview.tscn").instantiate() as Control
	get_root().add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	preview.position = Vector2(-300.0, -300.0)
	preview.size = Vector2(236.0, 176.0)
	var portrait_body := ChickenRig.hat_ready_mesh(colors[0], false)
	var body_count: int = portrait_body.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	for item: Dictionary in ChickenPitOptions.STORE_ITEMS:
		var hat := str(item["id"])
		view.call("reset_round", state, colors, 0, PackedStringArray([hat, hat]))
		preview.call("configure", item)
		for coop in 2:
			var expected := ChickenRig.build_mesh(colors[coop], coop == 1, hat)
			var birds: Array = view.get("_birds")
			var lead: Node3D = birds[coop * 6]
			var worn := (lead.get_child(0) as MeshInstance3D).mesh
			_expect(worn.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				== expected.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],
				"Every coop must wear the actual '%s' store mesh." % hat)
			for index in 6:
				var bird: Node3D = birds[coop * 6 + index]
				_expect((bird.get_child(0) as MeshInstance3D).mesh == worn,
					"All six birds in a coop must share the '%s' mesh." % hat)
			view.call("accepted_pull", coop, 10.35, true)
		await _advance_view(view, 0.1)
		_check_budget(game, hat)
		var portrait := preview.get("_model") as MeshInstance3D
		var viewport := preview.get("_viewport") as SubViewport
		var camera := viewport.get_node("Lens") as Camera3D
		var rect := Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(-2.0)
		var vertices: PackedVector3Array = portrait.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var fits := true
		for index in range(body_count, vertices.size()):
			var point := portrait.to_global(vertices[index])
			fits = fits and not camera.is_position_behind(point) \
				and rect.has_point(camera.unproject_position(point))
		_expect(fits, "The store portrait must show all of '%s', including its top and brim." % hat)
		_expect(viewport.get_render_info(
			Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME) > 0,
			"The '%s' store preview must actually render." % hat)
		_capture("store-%s.png" % hat, viewport)
		_capture("pit-%s.png" % hat)
	preview.queue_free()
	view.call("reset_round", state, colors, 0, original_hats)
	view.set_process(was_processing)
	await _render_frame()


func _test_pull_animation(game: Node) -> void:
	var view := game.get("_view") as Node
	var rope := view.get("rope_view") as Node
	view.set_process(false)
	var before := _rope_points(rope).duplicate()
	var previous: PackedVector3Array = rope.get("_previous")
	previous = previous.duplicate()
	view.call("accepted_pull", 0, 10.35, true)
	_expect(rope.get("_previous") != previous,
		"Accepted pulls must inject a rope impulse, not rely only on moving beak anchors.")
	await _advance_view(view, 0.1)
	_expect(_rope_points(rope) != before,
		"An accepted pull must kick and ripple the visible rope.")
	var frozen := _rope_points(rope).duplicate()
	for tick in 4:
		view.call("_process", 0.0)
	_expect(_rope_points(rope) == frozen,
		"Zero elapsed time must not keep integrating residual rope velocity.")
	_check_rope(game, "pull")
	view.set_process(true)


func _test_cinematics(game: Node) -> void:
	var view := game.get("_view") as Node
	var camera := view.get("camera") as PitCamera
	var size := get_root().size
	view.set_process(false)
	for length: int in [6, 10, 18]:
		_settings.call("set_value", ChickenPitOptions.ROPE_LENGTH_KEY, length)
		game.call("_start_round")
		(game.get_node("%RoundTimer") as Timer).stop()
		var state: PitState = game.get("_state")
		state.strength = [30.0, 18.0]
		var yaw_range := Vector2(INF, -INF)
		var fov_range := Vector2(INF, -INF)
		for shot in 4:
			_step_view(view, 8.0)
			_check_cinematic_frame(game, "shot %d, L=%d" % [shot, length])
			var yaw := atan2(camera.basis.z.x, camera.basis.z.z)
			yaw_range = Vector2(minf(yaw_range.x, yaw), maxf(yaw_range.y, yaw))
			fov_range = Vector2(minf(fov_range.x, camera.fov), maxf(fov_range.y, camera.fov))
			await _render_frame()
			if length == 10:
				_capture("pit-camera-shot-%d.png" % shot)
				_check_budget(game, "camera shot %d" % shot)
		_expect(yaw_range.y - yaw_range.x > deg_to_rad(35.0) and fov_range.y - fov_range.x > 5.0,
			"Rendered automatic coverage must vary both angle and zoom at every rope length.")
		var colors: Array[Color] = [game.get("player_one_color"), game.get("player_two_color")]
		for loser in 2:
			state.rope = 0.0
			view.call("reset_round", state, colors)
			_step_view(view, 6.0)
			var wide_height := _coop_screen_height(view, loser)
			var wide_lens := camera.fov
			view.call("reset_round", state, colors)
			state.rope = (-1.0 if loser == 0 else 1.0) * length * 0.8
			view.call("present", state)
			_step_view(view, 6.0)
			var close_height := _coop_screen_height(view, loser)
			print("Rendered L=%d coop %d zoom: %.2fx" % [length, loser, close_height / wide_height])
			_expect(camera.focused_coop == loser and close_height > wide_height * 1.5
				and camera.fov < wide_lens - 10.0,
				"Action close-up must enlarge the lead by at least 50%%: L=%d, coop=%d, zoom=%.3fx, FOV=%.1f, distance=%.2f." %
				[length, loser, close_height / wide_height, camera.fov, camera._distance])
			_check_cinematic_frame(game, "losing coop %d, L=%d" % [loser, length])
			await _render_frame()
			_capture("pit-camera-losing-%d-%d.png" % [length, loser])
			_check_budget(game, "losing coop %d, L=%d" % [loser, length])
			for window_size in [Vector2i(1024, 768), Vector2i(1280, 540)]:
				get_root().size = window_size
				await _render_frame()
				view.call("_process", 0.0)
				_check_cinematic_frame(game, "resized %s, L=%d" % [window_size, length])
			get_root().size = size
			await _render_frame()
			state.rope = 0.0
			_step_view(view, 4.0)
			_expect(camera._closeup < 0.001,
				"Recovering ground must smoothly restore the full-arena framing.")
			_check_cinematic_frame(game, "recovered L=%d" % length)
	var transform := camera.transform
	var lens := camera.fov
	var sun := view.get_node("Sun") as DirectionalLight3D
	var lighting := view.get("lighting") as PitLighting
	var sun_transform := sun.transform
	var light_clock := lighting._clock
	for frame in 5:
		view.call("_process", 0.0)
	_expect(camera.transform.is_equal_approx(transform) and camera.fov == lens
		and sun.transform.is_equal_approx(sun_transform) and lighting._clock == light_clock,
		"Zero-time world redraws must not drift the camera or advance the sunset.")
	_settings.call("set_value", ChickenPitOptions.ROPE_LENGTH_KEY, 10)
	game.call("_start_round")
	(game.get_node("%RoundTimer") as Timer).stop()
	view.set_process(true)
	await _render_frame()


func _test_sunset(game: Node) -> void:
	game.call("_start_round")
	(game.get_node("%RoundTimer") as Timer).stop()
	var view := game.get("_view") as Node
	view.set_process(false)
	var camera := view.get("camera") as Camera3D
	var lighting := view.get("lighting") as PitLighting
	var sun := view.get_node("Sun") as DirectionalLight3D
	var fill := view.get_node("Bounce") as OmniLight3D
	var environment := (view.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sky := (view.get_node("SkyDome") as MeshInstance3D).material_override as ShaderMaterial
	var early_sun := sun.transform
	var early_color := sun.light_color
	var early_sky: Color = sky.get_shader_parameter("zenith_color")
	var early_ambient := environment.ambient_light_color
	await _render_frame()
	_capture("pit-sunset-golden.png")
	lighting.update_lighting(PitLighting.CYCLE_SECONDS * 0.5, 0.8, 0.9)
	await _render_frame()
	_expect(not sun.transform.is_equal_approx(early_sun) and sun.light_color != early_color
		and sky.get_shader_parameter("zenith_color") != early_sky
		and environment.ambient_light_color != early_ambient,
		"Sun angle, key colour, ambient fill and the painted sky must evolve together.")
	_expect(sun.light_color.r > sun.light_color.b * 1.3 and environment.ambient_light_energy >= 0.38,
		"Sunset must retain a warm key and enough cool fill to read the coops.")
	_expect(sun.shadow_enabled and not fill.shadow_enabled,
		"Dynamic lighting must keep the existing one-shadow-light budget.")
	_expect(await _pit_chicken_pixels(game) > 32,
		"The remembered flock must remain visibly distinct at the deepest sunset.")
	_capture("pit-sunset-deep.png")
	_check_budget(game, "deep sunset")
	var other := (load("res://games/chicken_pit/pit/pit.tscn") as PackedScene).instantiate()
	var other_environment := (other.get_node("WorldEnvironment") as WorldEnvironment).environment
	var other_sky := (other.get_node("SkyDome") as MeshInstance3D).material_override as ShaderMaterial
	_expect(other_environment != environment and other_sky != sky
		and other_environment.ambient_light_color != environment.ambient_light_color,
		"Animated environment and sky resources must be private to each pit instance.")
	other.free()
	var state: PitState = game.get("_state")
	var clock := lighting._clock
	view.call("reset_exchange", state)
	_expect(lighting._clock == clock,
		"A Lives exchange must not restart the match's sunset cycle.")
	var transform := camera.transform
	var sun_transform := sun.transform
	paused = true
	view.set_process(true)
	await create_timer(0.08, true).timeout
	_expect(camera.transform.is_equal_approx(transform) and sun.transform.is_equal_approx(sun_transform)
		and lighting._clock == clock, "Pause must freeze the camera and the sunset together.")
	view.set_process(false)
	paused = false
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	transform = camera.transform
	sun_transform = sun.transform
	var fixed_color: Color = sky.get_shader_parameter("zenith_color")
	_step_view(view, 4.0)
	_expect(camera.transform.is_equal_approx(transform) and sun.transform.is_equal_approx(sun_transform)
		and sky.get_shader_parameter("zenith_color") == fixed_color and lighting._clock == clock,
		"Reduced motion must select a steady sunset and freeze its entire cycle.")
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	_settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, false)
	view.call("accepted_pull", 0, 10.35, true)
	_step_view(view, 0.2)
	_expect(lighting._accent == 0.0 and (camera as PitCamera)._kick == 0.0,
		"Intense effects off must suppress both light accents and pull shake.")
	view.call("settle")
	transform = camera.transform
	sun_transform = sun.transform
	clock = lighting._clock
	_step_view(view, 0.5)
	_expect(camera.transform.is_equal_approx(transform) and sun.transform.is_equal_approx(sun_transform)
		and lighting._clock == clock, "Results must hold the last camera and lighting pose.")
	_settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, true)


func _step_view(view: Node, seconds: float) -> void:
	for frame in roundi(seconds * 60.0):
		view.call("_process", 1.0 / 60.0)


func _coop_screen_height(view: Node, coop: int) -> float:
	var camera := view.get("camera") as Camera3D
	var bird: Node3D = view.get("_birds")[coop * 6]
	return camera.unproject_position(bird.to_global(Vector3(0.0, 0.1, 0.0))).distance_to(
		camera.unproject_position(bird.to_global(Vector3(0.0, 1.7, 0.0))))


func _pit_screen_width(view: Node) -> float:
	var camera := view.get("camera") as Camera3D
	return camera.unproject_position(Vector3(-Scenery.PIT_RADIUS, Scenery.PIT_RIM_Y, 0.0)).distance_to(
		camera.unproject_position(Vector3(Scenery.PIT_RADIUS, Scenery.PIT_RIM_Y, 0.0)))


func _check_cinematic_frame(game: Node, label: String) -> void:
	var view := game.get("_view") as Node
	var camera := view.get("camera") as PitCamera
	var size := Vector2((game.get("_pit_viewport") as SubViewport).size)
	var rect := Rect2(PitCamera.SAFE_FRAME.position * size, PitCamera.SAFE_FRAME.size * size).grow(0.2)
	var subjects: PackedVector4Array = view.get(
		"_camera_action_subjects" if camera._closeup >= 0.001 else "_camera_subjects")
	for sphere in subjects:
		var at := Vector3(sphere.x, sphere.y, sphere.z)
		for direction in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT,
			Vector3.FORWARD, Vector3.BACK]:
			var point: Vector3 = at + direction * sphere.w
			_expect(not camera.is_position_behind(point)
				and rect.has_point(camera.unproject_position(point)),
				"The essential birds, rope and pit must stay clear of the HUD at %s." % label)
	var rope := view.get("rope_view") as Node
	for point in _rope_points(rope):
		_expect(not camera.is_position_behind(point) and rect.has_point(camera.unproject_position(point)),
			"The actual rope curve, not only its endpoints, must remain in the action shot at %s." % label)


func _test_pin_fall(game: Node, winner: int, length: int, completed_matches := 4) -> void:
	_settings.call("set_value", ChickenPitOptions.ROPE_LENGTH_KEY, length)
	game.call("_start_round")
	(game.get_node("%RoundTimer") as Timer).stop()
	var view := game.get("_view") as Node
	view.set_process(false)
	var state: PitState = game.get("_state")
	var colors: Array[Color] = [game.get("player_one_color"), game.get("player_two_color")]
	view.call("reset_round", state, colors, completed_matches)
	var wide_pit := _pit_screen_width(view)
	var expected_count := mini((completed_matches + 1) * 6, 24)
	var frame_name := "%d-%d-%d" % [length, winner, completed_matches]
	state.rope = (1.0 if winner == 0 else -1.0) * (state.L - 0.01)
	state.strength[winner] = 100.0
	game.call("_update_round", 0.10, 45.0)
	(game.get("_pin_timer") as Timer).stop()
	var frozen_rope := state.rope
	var frozen_scores := state.scores.duplicate()
	var rope := view.get("rope_view") as Node
	var initial_length := _chain_length(_rope_points(rope))
	await _advance_view(view, 0.26, game)
	await _render_frame()
	_capture("pit-skid-%s.png" % frame_name)
	await _advance_view(view, 0.12, game)
	await _render_frame()
	_capture("pit-teeter-%s.png" % frame_name)
	_check_rope(game, "teeter %d/%d" % [length, winner])
	var paused_points := _rope_points(rope).duplicate()
	var paused_time: float = view.get("_pin_time")
	var camera := view.get("camera") as PitCamera
	var paused_camera := camera.transform
	var lighting := view.get("lighting") as PitLighting
	var paused_light_time := lighting._clock
	paused = true
	view.set_process(true)
	await create_timer(0.08, true).timeout
	_expect(is_equal_approx(float(view.get("_pin_time")), paused_time)
		and _rope_points(rope) == paused_points and camera.transform.is_equal_approx(paused_camera)
		and lighting._clock == paused_light_time,
		"Pausing must freeze the falling chickens, rope, camera and sunset.")
	view.set_process(false)
	paused = false
	await _advance_view(view, 0.20, game)
	await _render_frame()
	_capture("pit-tumble-%s.png" % frame_name)
	_check_rope(game, "tumble %d/%d" % [length, winner])
	await _advance_view(view, 0.12, game)
	var loser := 1 - winner
	var lead: Node3D = view.get("_birds")[loser * 6]
	_expect(lead.visible and lead.global_position.y < 0.0
		and absf(lead.global_position.x) < Scenery.PIT_RADIUS
		and absf(lead.global_position.z) < Scenery.PIT_RADIUS,
		"Either losing coop must visibly drop below ground inside the central opening.")
	var focus: Vector3 = view.get("_camera_coop_centres")[loser]
	_expect(camera.focused_coop == loser and absf(focus.x) < length * 0.55
		and is_equal_approx(camera._pin_time, float(view.get("_pin_time"))),
		"The pin camera must track the actual falling flock on the same animation clock.")
	await _render_frame()
	_capture("pit-fall-%s.png" % frame_name)
	_check_budget(game, "fall %d/%d" % [length, winner])
	_check_rope(game, "fall %d/%d" % [length, winner])
	await _advance_view(view, 0.40, game)
	for index in 6:
		var bird: Node3D = view.get("_birds")[loser * 6 + index]
		_expect(not bird.visible
			and is_equal_approx(bird.global_position.y, Scenery.PIT_FLOOR_Y + 0.025),
			"All six falling rigs must land before the 1.1-second pin hold finishes.")
	_expect(int(view.call("diagnostics")["pit_chickens"]) == expected_count,
		"A pin must add one flock, or replace slots when the pit is full.")
	_expect(state.rope == frozen_rope and state.scores == frozen_scores,
		"Falling transforms must never feed back into the rope or score.")
	_expect(_pit_screen_width(view) > wide_pit * 1.25,
		"The pin shot must enlarge the hole, not pull out to frame the winning rear birds.")
	var final_length := _chain_length(_rope_points(rope))
	print("Pit rope %s: %.2f m pulling -> %.2f m landed" % [frame_name, initial_length, final_length])
	_expect(final_length < initial_length * 0.97,
		"The rope must shorten with the fallen coop rather than retaining its full arena span.")
	_check_rope(game, "landed %d/%d" % [length, winner], true)
	var batch := (view.get("_pit_flock") as MultiMeshInstance3D).multimesh
	var slot: int = view.get("_landing_start")
	var resting_beak := (view.get("_pit_flock") as Node3D).to_global(
		batch.get_instance_transform(slot) * ChickenRig.SPECTATOR_GRIP)
	var end: Vector3 = rope.get("_right" if winner == 0 else "_left")
	_expect(end.is_equal_approx(resting_beak),
		"The rope must attach to the visible resident after the falling rig is hidden.")
	await _render_frame()
	_capture("pit-landed-%s.png" % frame_name)
	_check_budget(game, "landed %d/%d" % [length, winner])
	view.call("reset_exchange", state)
	view.call("play_pin", winner)
	view.call("_process", 1.2)
	_check_rope(game, "hitched pin %d/%d" % [length, winner], true)
	var flock := view.get("_pit_flock") as MultiMeshInstance3D
	state.recentre()
	view.call("reset_exchange", state)
	_expect(flock.multimesh.visible_instance_count == expected_count,
		"A lives re-centre must keep the landed flock.")
	for bird: Node3D in view.get("_birds"):
		_expect(bird.visible and absf(bird.position.y) < 0.03 and is_zero_approx(bird.rotation.x),
			"Re-centring must restore the pulling birds, not leave them underground or hidden.")
	_expect(is_equal_approx(float(rope.get("_left_scale")), 1.0)
		and is_equal_approx(float(rope.get("_right_scale")), 1.0),
		"A fresh exchange must restore the pulling rope's width and beak attachments.")
	view.set_process(true)


func _advance_view(view: Node, seconds: float, game: Node = null) -> void:
	var remaining := seconds
	while remaining > 0.000001:
		var step := minf(remaining, 1.0 / 60.0)
		view.call("_process", step)
		if game != null:
			var state: PitState = game.get("_state")
			_check_rope(game, "pin %d/%d frame %.3f" %
				[state.L, int(view.get("_pin_winner")), float(view.get("_pin_time"))])
			_check_cinematic_frame(game, "pin L=%d, winner=%d" %
				[state.L, int(view.get("_pin_winner"))])
		remaining -= step
		await process_frame


func _rope_points(rope: Node) -> PackedVector3Array:
	var points: PackedVector3Array = rope.get("_guides" if bool(rope.get("reduced_motion")) else "_points")
	return points


func _chain_length(points: PackedVector3Array) -> float:
	var length := 0.0
	for index in range(1, points.size()):
		length += points[index].distance_to(points[index - 1])
	return length


func _check_rope(game: Node, label: String, landed := false) -> void:
	var view := game.get("_view") as Node
	var rope := view.get("rope_view") as Node
	var points := _rope_points(rope)
	_expect(points.size() == RopeView.POINT_COUNT,
		"The rope must use its fixed-size tessellation at %s." % label)
	if points.size() != RopeView.POINT_COUNT:
		return
	var left: Vector3 = rope.get("_left")
	var right: Vector3 = rope.get("_right")
	var knot: Vector3 = rope.get("_knot")
	_expect(points[0].is_equal_approx(left) and points[-1].is_equal_approx(right)
		and points[RopeView.KNOT_POINT].is_equal_approx(knot),
		"Both beaks and the knot must remain attached at %s." % label)
	var lowest_clearance := INF
	var lowest_segment := 1
	var lowest_point := Vector3.ZERO
	var below_ground := 0
	for index in points.size():
		_expect(points[index].is_finite(), "The rope must remain finite at %s." % label)
		if points[index].y < 0.0:
			below_ground += 1
		if index == 0:
			continue
		for sample in range(5):
			var point := points[index - 1].lerp(points[index], sample / 4.0)
			var clearance := point.y - Scenery.pit_surface_height(point)
			if clearance < lowest_clearance:
				lowest_clearance = clearance
				lowest_segment = index
				lowest_point = point
	_expect(lowest_clearance >= 0.025,
		"Rope must clear the field, rim and walls at %s (clearance %.3f at %s, segment %d: %s -> %s)." %
		[label, lowest_clearance, lowest_point, lowest_segment,
			points[lowest_segment - 1], points[lowest_segment]])
	if landed:
		_expect(below_ground >= 4 and knot.y < 0.0 and Scenery.pit_extent(knot) < Scenery.PIT_RADIUS,
			"The knot and a visible length of rope must descend into the hole at %s." % label)


func _render_frame() -> void:
	# The parent viewport can sample the previous SubViewport texture for one frame.
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _pit_chicken_pixels(game: Node) -> int:
	var view := game.get("_view") as Node
	var was_processing := view.is_processing()
	view.set_process(false)
	var flock := view.get("_pit_flock") as MultiMeshInstance3D
	var camera := view.get("camera") as Camera3D
	var viewport := game.get("_pit_viewport") as SubViewport
	await _render_frame()
	var image := viewport.get_texture().get_image()
	var bounds := Rect2(camera.unproject_position(Vector3(0.0, Scenery.PIT_FLOOR_Y, 0.0)),
		Vector2.ZERO)
	for x in [-1.4, 1.4]:
		for z in [-1.4, 1.4]:
			for height in [0.12, 1.0]:
				bounds = bounds.expand(camera.unproject_position(
					Vector3(x, Scenery.PIT_FLOOR_Y + height, z)))
	var pixels := Rect2i(Vector2i(bounds.position.floor()), Vector2i(bounds.size.ceil()))
	pixels = pixels.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	# Compare identical poses with/without the flock; sunset invalidates fixed noon RGB thresholds.
	flock.visible = false
	await _render_frame()
	var empty := viewport.get_texture().get_image()
	var count := 0
	for y in range(pixels.position.y, pixels.end.y):
		for x in range(pixels.position.x, pixels.end.x):
			var color := image.get_pixel(x, y)
			var background := empty.get_pixel(x, y)
			if maxf(absf(color.r - background.r),
				maxf(absf(color.g - background.g), absf(color.b - background.b))) > 0.04:
				count += 1
	flock.visible = true
	await _render_frame()
	view.set_process(was_processing)
	return count


func _check_budget(game: Node, label: String) -> void:
	var viewport := game.get("_pit_viewport") as SubViewport
	var visible := viewport.get_render_info(
		Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var shadows := viewport.get_render_info(
		Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	print("Pit %s draw calls: %d visible + %d shadow = %d" % [
		label, visible, shadows, visible + shadows])
	_expect(visible > 0 and visible + shadows < 60,
		"The pit's measured draw calls, including shadows, must stay below 60.")


func _capture(name: String, viewport: Viewport = null) -> void:
	if not _capture_dir.is_empty():
		var source := get_root() if viewport == null else viewport
		_expect(source.get_texture().get_image().save_png(_capture_dir.path_join(name)) == OK,
			"Could not save screenshot %s." % name)


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
