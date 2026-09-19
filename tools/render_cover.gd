extends SceneTree

## Offline cover photography using the game's original models, not a gameplay capture.
## Run with a graphics display; the resulting PNG is the only runtime dependency.

const PitView = preload("res://games/chicken_pit/pit/pit_view.gd")
const PitState = preload("res://games/chicken_pit/pit/pit_state.gd")
const ChickenRig = preload("res://games/chicken_pit/pit/chicken_rig.gd")
const SIZE := 1536
const OUTPUT := "res://games/chicken_pit/assets/menu-cover.png"
const CREAM := Color("fff8e7")
const GOLD := Color("ffd45c")
const INK := Color("25342f")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Cover photography requires a graphics display, not --headless.")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var pit := (load("res://games/chicken_pit/pit/pit.tscn") as PackedScene).instantiate() as PitView
	viewport.add_child(pit)
	# Read the authored team colours without instantiating the shared game shell.
	var scene := (load("res://games/chicken_pit/gameplay.tscn") as PackedScene).get_state()
	var colors: Array[Color] = []
	for property in [&"player_one_color", &"player_two_color"]:
		for index in scene.get_node_property_count(0):
			if scene.get_node_property_name(0, index) == property:
				colors.append(scene.get_node_property_value(0, index))
	if colors.size() != 2:
		push_error("The cover requires both authored coop colours.")
		quit(1)
		return
	var state := PitState.new(6)
	pit.set_reduced_motion(true)
	pit.set_intense_effects(false)
	pit.reset_round(state, colors)
	pit.set_process(false)

	# Move the lead birds toward the lens: this is a staged box-art portrait,
	# while the unmodified gameplay model, arena and tutorial poster stay intact.
	var leads: Array[ChickenRig] = []
	for coop in 2:
		var group := pit.get_node("Scenery/RedCoop" if coop == 0 else "Scenery/BlueCoop") as Node3D
		var side := -1.0 if coop == 0 else 1.0
		group.position = Vector3(side * 3.3, 0.04, 2.8)
		for index in group.get_child_count():
			var bird := group.get_child(index) as ChickenRig
			if index == 0:
				bird.scale = Vector3.ONE * 1.85
				bird.pose(0.7, 0.0, 52.0, coop == 1, 0, false)
				leads.append(bird)
			else:
				bird.position = Vector3(-0.8 - index * 0.42, 0.0, side * (1.5 + index * 0.22))
				bird.pose(0.7 + index * 0.3, 0.0, 35.0, false, 0, false)
	pit.camera.position = Vector3(0.0, 9.0, 18.0)
	pit.camera.look_at(Vector3(0.0, 2.5, -1.0))
	pit.camera.fov = 46.0
	(pit.get_node("SkyDome") as Node3D).global_position = pit.camera.global_position
	var knot := Vector3(0.0, 2.15, 2.8)
	pit.rope_view.update_rope(leads[0].beak_position(), leads[1].beak_position(), knot, 1.0, 0.0, 0.0)
	var ribbon := pit.get("_ribbon") as MeshInstance3D
	ribbon.position = knot
	ribbon.scale = Vector3.ONE * 1.5

	var artwork := Control.new()
	artwork.size = Vector2(SIZE, SIZE)
	viewport.add_child(artwork)
	_gradient(artwork, true)
	_gradient(artwork, false)
	_label(artwork, "CLUCK COUNTY PRESENTS", 52, 36, GOLD)
	_label(artwork, "CHICKEN", 90, 150, CREAM, 16)
	_label(artwork, "PIT", 235, 190, GOLD, 18)
	_label(artwork, "THE GREAT PULL-OFF", 1350, 54, CREAM, 5)
	_label(artwork, "TWO COOPS. ONE ROPE. NO DIGNITY.", 1430, 27, GOLD)
	var frame := Panel.new()
	frame.position = Vector2(22, 22)
	frame.size = Vector2(SIZE - 44, SIZE - 44)
	var border := StyleBoxFlat.new()
	border.draw_center = false
	border.border_color = GOLD
	border.set_border_width_all(3)
	frame.add_theme_stylebox_override("panel", border)
	artwork.add_child(frame)
	for tick in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var error := image.save_png(OUTPUT)
	if error != OK:
		push_error("Could not save cover: %s" % error_string(error))
		quit(1)
		return
	print("Rendered %dx%d cover: %s" % [image.get_width(), image.get_height(), OUTPUT])
	viewport.queue_free()
	await process_frame
	quit()


func _gradient(parent: Control, top: bool) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.045, 0.11, 0.13, 0.96))
	gradient.set_color(1, Color(0.045, 0.11, 0.13, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0 if top else 1.0)
	texture.fill_to = Vector2(0.0, 1.0 if top else 0.0)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.position.y = 0 if top else 1160
	rect.size = Vector2(SIZE, 560 if top else 376)
	parent.add_child(rect)


func _label(parent: Control, text: String, y: float, font_size: int, color: Color, outline: int = 0) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(48, y)
	label.size.x = SIZE - 96
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", outline)
	if font_size >= 100:
		var font := FontVariation.new()
		font.base_font = ThemeDB.fallback_font
		font.variation_embolden = 1.5
		label.add_theme_font_override("font", font)
		label.add_theme_color_override("font_shadow_color", INK)
		label.add_theme_constant_override("shadow_offset_y", 10)
	parent.add_child(label)
