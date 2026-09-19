extends SceneTree

## Regression checks for the Chicken Pit options exposed under Settings → Game
## and the pull keys under Settings → Controls.
##
## Options are stored, clamped, persisted, rendered as rows, and passed to the
## actual pulling model when a round starts.
##
## Headless `--script` runs compile this file before autoloads exist, so
## [Settings] is resolved from the tree and poked with `call`; only its
## constants are referenced directly. [ChickenPitOptions] is safe to name
## because it is constants-only.

var _failures := PackedStringArray()
var _original_values: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var settings := get_root().get_node_or_null("Settings")
	var session := get_root().get_node_or_null("GameSession")
	if settings == null or session == null:
		_failures.append("Settings and GameSession autoloads are required.")
		await _finish(settings)
		return

	_test_declarations()
	_test_defaults()
	var values := _test_values()
	for key: String in values:
		_original_values[key] = settings.call("get_value", key)
		settings.call("set_value", key, values[key])
	settings.call("save")

	_test_settings_helpers(settings)
	_test_persistence(values)
	_test_bindings(settings)
	await _test_settings_menu(settings)
	await _test_gameplay_scene(session, settings)
	await _finish(settings)


## The manifest is the only thing that tells the framework this game exists, so
## a typo here is the one mistake that silently drops the game from the build.
func _test_declarations() -> void:
	var manifest := GameCatalog.get_manifest(ChickenPitOptions.GAME_ID)
	if manifest == null:
		_failures.append("GameCatalog must discover the Chicken Pit manifest.")
		return
	_expect(
		manifest.gameplay_scene_exists(),
		"Chicken Pit must declare a gameplay scene that loads."
	)
	_expect(
		manifest.tunables.size() == ChickenPitOptions.TUNABLES.size()
		and manifest.control_bindings.size()
		== ChickenPitOptions.CONTROL_BINDINGS.size(),
		"The manifest must offer every option and binding the game declares."
	)
	_expect(
		manifest.theme != null and manifest.theme.logo_texture() != null,
		"Chicken Pit must declare a theme whose logo loads."
	)
	_expect(
		manifest.theme.style_share_card
		and ResourceLoader.exists(manifest.share_art_scene_path),
		"Chicken Pit must opt into its themed scorecard and supply original share art."
	)
	_expect(
		manifest.resolved_stats_url().to_utf8_buffer().size()
		<= ShareQrCode.MAX_URL_BYTES,
		"The Chicken Pit stats link must stay inside a scannable QR code."
	)


func _test_defaults() -> void:
	_expect_approx(
		ChickenPitOptions.DEFAULT_ROUND_LENGTH,
		45.0,
		"Chicken Pit rounds must default to 45 seconds."
	)
	_expect_approx(
		ChickenPitOptions.DEFAULT_PULL_POWER,
		1.0,
		"Pull power must default to the designed strength."
	)
	_expect_approx(
		ChickenPitOptions.DEFAULT_STRENGTH_DECAY,
		1.0,
		"Strength decay must default to the designed drain."
	)
	_expect(
		ChickenPitOptions.DEFAULT_ROPE_LENGTH == 10,
		"The rope must default to ten notches per side."
	)
	_expect(
		ChickenPitOptions.DEFAULT_CPU_DIFFICULTY == ChickenPitOptions.CPU_HEN,
		"The CPU opponent must default to the middle bird."
	)


## Deliberately not the defaults, so a value that never made it out of the
## store cannot pass by accident.
func _test_values() -> Dictionary:
	return {
		ChickenPitOptions.ROUND_LENGTH_KEY: 60.0,
		ChickenPitOptions.PULL_POWER_KEY: 1.4,
		ChickenPitOptions.STRENGTH_DECAY_KEY: 0.75,
		ChickenPitOptions.ROPE_LENGTH_KEY: 14.0,
		ChickenPitOptions.CPU_DIFFICULTY_KEY: ChickenPitOptions.CPU_ROOSTER,
		Settings.GAMEPLAY_SPEED_KEY: 1.0,
		Settings.EXTRA_ROUND_TIME_KEY: 0.0,
	}


func _test_settings_helpers(settings: Node) -> void:
	_expect_approx(
		float(settings.call("tunable", ChickenPitOptions.ROUND_LENGTH_KEY)),
		60.0,
		"The round-length option must be available through Settings."
	)
	_expect_approx(
		float(settings.call("tunable", ChickenPitOptions.PULL_POWER_KEY)),
		1.4,
		"The pull-power option must be available through Settings."
	)
	_expect_approx(
		float(settings.call("tunable", ChickenPitOptions.STRENGTH_DECAY_KEY)),
		0.75,
		"The strength-decay option must be available through Settings."
	)
	_expect_approx(
		float(settings.call("tunable", ChickenPitOptions.ROPE_LENGTH_KEY)),
		14.0,
		"The rope-length option must be available through Settings."
	)
	_expect(
		int(settings.call("tunable_choice", ChickenPitOptions.CPU_DIFFICULTY_KEY))
		== ChickenPitOptions.CPU_ROOSTER,
		"The CPU-opponent choice must be available through Settings."
	)

	settings.call("set_value", ChickenPitOptions.PULL_POWER_KEY, 9.0)
	_expect_approx(
		float(settings.call("tunable", ChickenPitOptions.PULL_POWER_KEY)),
		ChickenPitOptions.MAX_PULL_POWER,
		"Out-of-range pull power must be clamped."
	)
	settings.call("set_value", ChickenPitOptions.ROPE_LENGTH_KEY, 0.0)
	_expect_approx(
		float(settings.call("tunable", ChickenPitOptions.ROPE_LENGTH_KEY)),
		float(ChickenPitOptions.MIN_ROPE_LENGTH),
		"Out-of-range rope lengths must be clamped."
	)
	# An unknown stored choice must not strand the player on a bird that is not
	# on the list any more.
	settings.call("set_value", ChickenPitOptions.CPU_DIFFICULTY_KEY, 99)
	_expect(
		int(settings.call("tunable_choice", ChickenPitOptions.CPU_DIFFICULTY_KEY))
		== ChickenPitOptions.DEFAULT_CPU_DIFFICULTY,
		"An unknown stored CPU opponent must fall back to the declared default."
	)

	settings.call("set_value", ChickenPitOptions.PULL_POWER_KEY, 1.4)
	settings.call("set_value", ChickenPitOptions.ROPE_LENGTH_KEY, 14.0)
	settings.call(
		"set_value",
		ChickenPitOptions.CPU_DIFFICULTY_KEY,
		ChickenPitOptions.CPU_ROOSTER
	)


func _test_persistence(values: Dictionary) -> void:
	var config := ConfigFile.new()
	_expect(
		config.load(Settings.SAVE_PATH) == OK,
		"Chicken Pit options must be persisted to settings.cfg."
	)
	for key: String in values:
		var parts := key.split("/", false, 1)
		var stored: Variant = config.get_value(parts[0], parts[1], null)
		_expect(
			stored != null and is_equal_approx(float(stored), float(values[key])),
			"The persisted value for %s must match the selected option." % key
		)


## Both coops own their keys, and a conflict inside one game swaps rather than
## strands a bird with nothing to pull with.
func _test_bindings(settings: Node) -> void:
	var declared: Array = settings.call(
		"control_bindings_for_game", ChickenPitOptions.GAME_ID
	)
	_expect(
		declared.size() == ChickenPitOptions.CONTROL_BINDINGS.size(),
		"Chicken Pit must use its own pull keys, not another style's built-ins."
	)
	for definition: Dictionary in ChickenPitOptions.CONTROL_BINDINGS:
		var key := str(definition["key"])
		_original_values[key] = settings.call("get_value", key)
		_expect(
			InputMap.has_action(StringName(definition["action"])),
			"'%s' must reach the InputMap." % definition["action"]
		)
		_expect(
			int(settings.call("binding_keycode", key))
			== int(definition["default"]),
			"'%s' must start on its declared default key." % key
		)

	for player_index in 2:
		var actions := ChickenPitOptions.pull_actions(player_index)
		_expect(
			actions.size() == 3,
			"Each coop must have three pull keys to alternate between."
		)
		for action in actions:
			_expect(
				InputMap.has_action(action),
				"Pull action '%s' must exist for coop %d." % [action, player_index]
			)

	# Reusing a key inside one game swaps the two, so a coop never ends up with
	# two keys doing the same thing and a third doing nothing.
	var displaced := int(
		settings.call("binding_keycode", ChickenPitOptions.PULL_ONE_B_KEY)
	)
	settings.call(
		"set_binding_key",
		ChickenPitOptions.PULL_ONE_B_KEY,
		int(ChickenPitOptions.CONTROL_BINDINGS[0]["default"]),
		ChickenPitOptions.GAME_ID
	)
	_expect(
		int(settings.call("binding_keycode", ChickenPitOptions.PULL_ONE_A_KEY))
		== displaced,
		"Reusing a pull key inside Chicken Pit must swap the two bindings."
	)
	settings.call("reset_controls_to_defaults", ChickenPitOptions.GAME_ID)
	_expect(
		int(settings.call("binding_keycode", ChickenPitOptions.PULL_ONE_A_KEY))
		== KEY_Q
		and int(settings.call("binding_keycode", ChickenPitOptions.PULL_TWO_A_KEY))
		== KEY_I,
		"Restoring Chicken Pit's controls must put both coops back."
	)


## The rows are generated from the manifest, so the screen only has them while
## it is configuring Chicken Pit — which is what the pause menu tells it.
func _test_settings_menu(settings: Node) -> void:
	var menu := _open_settings_menu(ChickenPitOptions.GAME_ID)
	if menu == null:
		return
	await process_frame

	var controls := menu.get("_option_controls") as Dictionary
	var value_labels := menu.get("_option_values") as Dictionary
	var bindings := menu.get("_binding_buttons") as Dictionary
	_expect(
		controls.size() == ChickenPitOptions.TUNABLES.size(),
		"Every Chicken Pit option must get a row on the Game tab."
	)
	_expect(
		bindings.size() == ChickenPitOptions.CONTROL_BINDINGS.size(),
		"Every pull key must get a row on the Controls tab."
	)

	var game_list := menu.get_node_or_null(
		"Margins/Layout/Tabs/Game/Pad/List/GameOptions"
	) as VBoxContainer
	var length_slider := controls.get(
		ChickenPitOptions.ROUND_LENGTH_KEY
	) as HSlider
	var rope_slider := controls.get(ChickenPitOptions.ROPE_LENGTH_KEY) as HSlider
	var power_slider := controls.get(ChickenPitOptions.PULL_POWER_KEY) as HSlider
	var decay_slider := controls.get(
		ChickenPitOptions.STRENGTH_DECAY_KEY
	) as HSlider
	var cpu_picker := controls.get(
		ChickenPitOptions.CPU_DIFFICULTY_KEY
	) as OptionButton

	if (
		game_list == null
		or length_slider == null
		or rope_slider == null
		or power_slider == null
		or decay_slider == null
		or cpu_picker == null
	):
		_failures.append("The Game tab must expose every Chicken Pit option.")
		await _free_scene(menu)
		return

	for slider: HSlider in [length_slider, rope_slider, power_slider, decay_slider]:
		_expect(
			slider.get_parent().get_parent() == game_list,
			"Every Chicken Pit option must live on the Game tab."
		)
		_expect(
			not slider.tooltip_text.is_empty()
			and slider.accessibility_description == slider.tooltip_text,
			"Every Chicken Pit option must describe itself for assistive tech."
		)

	_expect_slider(length_slider, 60.0, "the round length")
	_expect_slider(rope_slider, 14.0, "the rope length")
	_expect_slider(power_slider, 1.4, "the pull power")
	_expect_slider(decay_slider, 0.75, "the strength decay")
	_expect_range(
		length_slider,
		ChickenPitOptions.MIN_ROUND_LENGTH,
		ChickenPitOptions.MAX_ROUND_LENGTH,
		"the round length"
	)
	_expect_range(
		rope_slider,
		float(ChickenPitOptions.MIN_ROPE_LENGTH),
		float(ChickenPitOptions.MAX_ROPE_LENGTH),
		"the rope length"
	)
	_expect_range(
		power_slider,
		ChickenPitOptions.MIN_PULL_POWER,
		ChickenPitOptions.MAX_PULL_POWER,
		"the pull power"
	)
	_expect_range(
		decay_slider,
		ChickenPitOptions.MIN_STRENGTH_DECAY,
		ChickenPitOptions.MAX_STRENGTH_DECAY,
		"the strength decay"
	)

	var length_value := value_labels.get(
		ChickenPitOptions.ROUND_LENGTH_KEY
	) as Label
	_expect(
		length_value != null and length_value.text == "60 sec",
		"The round-length option must read out in seconds."
	)
	_expect(
		cpu_picker.item_count == 3
		and cpu_picker.get_selected_id() == ChickenPitOptions.CPU_ROOSTER,
		"The CPU-opponent picker must offer every bird and show the stored one."
	)

	length_slider.value = 30.0
	_expect_approx(
		float(settings.call("tunable", ChickenPitOptions.ROUND_LENGTH_KEY)),
		30.0,
		"The round-length slider must write through to Settings."
	)
	menu.call(
		"_on_option_choice_selected",
		cpu_picker.get_item_index(ChickenPitOptions.CPU_CHICK),
		ChickenPitOptions.CPU_DIFFICULTY_KEY
	)
	_expect(
		int(settings.call("tunable_choice", ChickenPitOptions.CPU_DIFFICULTY_KEY))
		== ChickenPitOptions.CPU_CHICK,
		"Picking a CPU opponent must write through to Settings."
	)

	settings.call("set_value", ChickenPitOptions.ROUND_LENGTH_KEY, 60.0)
	settings.call(
		"set_value",
		ChickenPitOptions.CPU_DIFFICULTY_KEY,
		ChickenPitOptions.CPU_ROOSTER
	)
	await process_frame
	_expect_slider(length_slider, 60.0, "external round-length changes")
	await _free_scene(menu)


## The scene is poked with `get`/`call` rather than named as a type: it extends
## `GameShell`, which uses autoload instances, and naming it here would drag it
## into this script's compile pass before those autoloads exist.
func _test_gameplay_scene(session: Node, settings: Node) -> void:
	GameCatalog.select(ChickenPitOptions.GAME_ID)
	session.call("configure_single_player")
	var game := _instantiate_scene("res://games/chicken_pit/gameplay.tscn")
	if game == null:
		return
	await process_frame
	await process_frame

	var timer := game.get_node("%RoundTimer") as Timer
	timer.stop()

	_expect(
		str(game.call("game_id")) == ChickenPitOptions.GAME_ID,
		"The scene must report the id its manifest is registered under."
	)
	_expect_approx(
		float(game.get("_round_length")),
		60.0,
		"Chicken Pit must use the selected round length."
	)
	_expect_approx(
		float(game.get("_active_round_duration")),
		60.0,
		"The selected round length must drive the round duration."
	)
	_expect_approx(
		float(game.get("_round_pull_power")),
		1.4,
		"Chicken Pit must apply the pull-power option."
	)
	_expect_approx(
		float(game.get("_round_strength_decay")),
		0.75,
		"Chicken Pit must apply the strength-decay option."
	)
	_expect(
		int(game.get("_round_rope_length")) == 14,
		"Chicken Pit must apply the rope-length option."
	)
	_expect(
		int(game.get("_round_cpu_difficulty")) == ChickenPitOptions.CPU_ROOSTER,
		"Chicken Pit must apply the CPU-opponent option."
	)
	_expect_approx(
		float(game.call("_pull_strength")),
		1.4,
		"Pull power must combine with the shared gameplay-speed assist."
	)
	var state := game.get("_state") as RefCounted
	_expect(
		state != null and int(state.get("L")) == 14,
		"The rope-length option must reach the real model's goal lines."
	)
	_expect_approx(
		float(state.get("pull_power")), 1.4,
		"The model, not just the scene, must receive pull power."
	)
	_expect_approx(
		float(state.get("strength_decay")), 0.75,
		"The model must use the chosen proportional decay."
	)
	_expect_approx(
		float(state.get("gameplay_speed")), 1.0,
		"The model must receive the shared speed assist."
	)

	# Options are next-round settings: changing one must not rewrite the round
	# the player is in the middle of.
	settings.call("set_value", ChickenPitOptions.ROUND_LENGTH_KEY, 20.0)
	settings.call("set_value", ChickenPitOptions.ROPE_LENGTH_KEY, 6.0)
	_expect_approx(
		float(game.get("_active_round_duration")),
		60.0,
		"Chicken Pit options must not restretch a running round."
	)
	_expect(
		int(game.get("_round_rope_length")) == 14,
		"Chicken Pit options must not move the goal line mid-round."
	)
	_expect(int(state.get("L")) == 14,
		"A next-round rope change must not rewrite a live model.")

	game.call("_start_round")
	timer.stop()
	_expect_approx(
		float(game.get("_active_round_duration")),
		20.0,
		"A new round must pick up the selected round length."
	)
	_expect(
		int(game.get("_round_rope_length")) == 6,
		"A new round must pick up the selected rope length."
	)
	state = game.get("_state") as RefCounted
	_expect(int(state.get("L")) == 6,
		"A replay must construct the model with the new goal lines.")
	game.set("_round_active", false)
	await _free_scene(game)


func _expect_slider(slider: HSlider, expected: float, title: String) -> void:
	_expect(
		slider != null and is_equal_approx(slider.value, expected),
		"The Settings screen must synchronize %s." % title
	)


func _expect_range(
	slider: HSlider,
	minimum: float,
	maximum: float,
	title: String
) -> void:
	_expect(
		slider != null
		and is_equal_approx(slider.min_value, minimum)
		and is_equal_approx(slider.max_value, maximum),
		"The slider for %s must match the range Settings accepts." % title
	)


## The pause menu names the running game before the screen enters the tree,
## because `_ready` is what builds the per-game tabs.
func _open_settings_menu(game_id: String) -> Node:
	var packed := load("res://scenes/menus/settings_menu.tscn") as PackedScene
	if packed == null:
		_failures.append("Could not load the settings menu scene.")
		return null
	var menu := packed.instantiate()
	menu.set("game_context_id", game_id)
	get_root().add_child(menu)
	return menu


func _instantiate_scene(path: String) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		_failures.append("Could not load %s." % path)
		return null
	var instance := packed.instantiate()
	if instance.get_script() == null:
		_failures.append("Scene root has no valid script: %s." % path)
		instance.queue_free()
		return null
	get_root().add_child(instance)
	return instance


func _free_scene(scene: Node) -> void:
	scene.queue_free()
	await process_frame


func _expect_approx(actual: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(actual, expected), message)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(settings: Node) -> void:
	if settings != null:
		for key: String in _original_values:
			settings.call("set_value", key, _original_values[key])
		settings.call("save")

	await create_timer(0.8).timeout
	var audio_manager := get_root().get_node_or_null("AudioManager")
	if audio_manager != null:
		for child in audio_manager.find_children("*", "AudioStreamPlayer", true, false):
			var player := child as AudioStreamPlayer
			player.stop()
			player.stream = null
	await create_timer(0.1).timeout

	if _failures.is_empty():
		print("Chicken Pit option tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
