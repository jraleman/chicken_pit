extends SceneTree

## End-to-end input, life pools, delayed pins and live accessibility in the real shell.

const PitState = preload("res://games/chicken_pit/pit/pit_state.gd")
const PitHistory = preload("res://games/chicken_pit/pit/pit_history.gd")
const GAME_PATH := "res://games/chicken_pit/gameplay.tscn"
const FIXTURE_PATH := "res://games/chicken_pit/tests/pit_round_fixture.gd"

var _failures := PackedStringArray()
var _settings: Node
var _session: Node
var _original_values: Dictionary
var _original_game := ""
var _save_process_mode := Node.PROCESS_MODE_INHERIT
var _history_paths := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_settings = get_root().get_node("Settings")
	_session = get_root().get_node("GameSession")
	_original_values = (_settings.get("_values") as Dictionary).duplicate(true)
	_original_game = GameCatalog.current_id()
	var save_timer := _settings.get("_save_timer") as Timer
	_save_process_mode = save_timer.process_mode
	save_timer.process_mode = Node.PROCESS_MODE_DISABLED
	GameCatalog.select(ChickenPitOptions.GAME_ID)
	_settings.call("reset_controls_to_defaults", ChickenPitOptions.GAME_ID)
	_settings.call("set_value", Settings.ROUND_MODE_KEY, Settings.RoundMode.TIMER)
	_settings.call("set_value", Settings.STARTING_LIVES_KEY, 3)
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	_settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, true)
	_settings.call("set_value", ChickenPitOptions.ROPE_LENGTH_KEY, 10)
	_settings.call("set_value", ChickenPitOptions.PULL_POWER_KEY, 1.0)
	_settings.call("set_value", ChickenPitOptions.STRENGTH_DECAY_KEY, 1.0)
	_settings.call("set_value", Settings.GAMEPLAY_SPEED_KEY, 1.0)

	_test_history_storage()
	await _test_history_lifecycle()
	await _test_parent_input_and_viewport()
	await _test_delayed_pin_and_pause()
	await _test_lives()
	await _test_single_seat_cpu()
	await _test_score_outcome_and_achievements()
	await _test_exit_during_pin()
	for path in _history_paths:
		if FileAccess.file_exists(path):
			_expect(DirAccess.remove_absolute(path) == OK,
				"An isolated flock history file must be removed after the regression.")

	var values := _settings.get("_values") as Dictionary
	values.clear()
	values.merge(_original_values, true)
	save_timer.stop()
	save_timer.process_mode = _save_process_mode
	GameCatalog.select(_original_game)
	await create_timer(0.85).timeout
	var audio := get_root().get_node("AudioManager")
	for child in audio.find_children("*", "AudioStreamPlayer", true, false):
		var player := child as AudioStreamPlayer
		player.stop()
		player.stream = null
	await create_timer(0.1).timeout
	if _failures.is_empty():
		print("Chicken Pit round tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _new_game(single := false, history_path := "") -> Node:
	if single:
		_session.call("configure_single_player")
	else:
		_session.call("configure_multiplayer", GameSession.PlayerTwoController.HUMAN)
	var packed := load(GAME_PATH) as PackedScene
	var fixture := load(FIXTURE_PATH) as Script
	if packed == null or fixture == null or not fixture.can_instantiate():
		push_error("The shipped Chicken Pit scene and round fixture must compile.")
		quit(1)
		return null
	var game := packed.instantiate()
	var red: Color = game.get("player_one_color")
	var blue: Color = game.get("player_two_color")
	# Only persistence hooks are replaced; instantiate the shipped inherited scene.
	game.set_script(fixture)
	game.set("player_one_color", red)
	game.set("player_two_color", blue)
	var path := _new_history_path() if history_path.is_empty() else history_path
	game.set("history_path", path)
	get_root().add_child(game)
	game.set_process(false)
	await process_frame
	game.call("_start_round")
	(game.get_node("%RoundTimer") as Timer).stop()
	return game


func _new_history_path() -> String:
	var path := "user://chicken_pit_round_%d_%d_%d.cfg" % [
		OS.get_process_id(), Time.get_ticks_usec(), _history_paths.size(),
	]
	_history_paths.append(path)
	return path


func _test_history_storage() -> void:
	var path := _new_history_path()
	var history := PitHistory.new(path)
	_expect(history.load_history() == OK and history.completed_matches == 0,
		"A new player must start with an empty pit.")
	_expect(not FileAccess.file_exists(path),
		"Loading an unplayed game must not count or save a completed match.")
	for completed in range(1, 9):
		_expect(history.record_match() == OK, "A completed match must save its count.")
		history = PitHistory.new(path)
		_expect(history.load_history() == OK and history.completed_matches == completed,
			"The number of completed matches must survive a fresh history instance.")
		_expect(PitHistory.chickens_for_matches(history.completed_matches) == mini(completed * 6, 24),
			"The persistent flock must gain six chickens per match, never more than 24.")
	_expect(PitHistory.chickens_for_matches(-1) == 0
		and PitHistory.chickens_for_matches(PitHistory.MAX_MATCH_COUNT) == 24,
		"Invalid or enormous counts must never allocate a negative or unbounded flock.")

	var legacy := PitHistory.new(_new_history_path())
	_expect(legacy.load_history(true) == OK and legacy.completed_matches == 1,
		"The existing first-match achievement must seed a returning player's flock.")
	_expect(legacy.record_match() == OK and legacy.completed_matches == 2,
		"The first newly recorded match must add to, not replace, the migrated match.")

	var saturated_path := _new_history_path()
	var config := ConfigFile.new()
	config.set_value(PitHistory.SECTION, PitHistory.MATCHES_KEY, PitHistory.MAX_MATCH_COUNT)
	_expect(config.save(saturated_path) == OK, "The saturated-count fixture must save.")
	var saturated := PitHistory.new(saturated_path)
	_expect(saturated.load_history() == OK and saturated.record_match() == OK
		and saturated.completed_matches == PitHistory.MAX_MATCH_COUNT,
		"Even a saturated saved counter must not wrap around on the next completion.")

	var invalid_path := _new_history_path()
	config.set_value(PitHistory.SECTION, PitHistory.MATCHES_KEY, -5)
	_expect(config.save(invalid_path) == OK, "The invalid-history fixture must save.")
	var invalid := PitHistory.new(invalid_path)
	_expect(invalid.load_history() == ERR_INVALID_DATA and invalid.record_match() != OK,
		"An invalid history must be reported and must not be overwritten as a fresh game.")
	_expect(config.load(invalid_path) == OK
		and int(config.get_value(PitHistory.SECTION, PitHistory.MATCHES_KEY)) == -5,
		"Failed loading must leave the original saved data untouched.")

	var unsavable := PitHistory.new(_new_history_path().path_join("missing_directory.cfg"))
	_expect(unsavable.load_history() == OK and unsavable.record_match() != OK
		and unsavable.completed_matches == 0,
		"A failed save must be reported without claiming a persistent increment.")


func _test_history_lifecycle() -> void:
	var game := await _new_game()
	var history: PitHistory = game.get("_pit_history")
	var view := game.get("_view") as Node
	var path: String = game.get("history_path")
	_expect(int(view.call("diagnostics")["pit_chickens"]) == 0,
		"The first round must pass an empty history to the view.")
	game.call("_start_round")
	(game.get_node("%RoundTimer") as Timer).stop()
	_expect(history.completed_matches == 0 and not FileAccess.file_exists(path),
		"Starting or restarting a match must not count as finishing it.")
	game.call("_on_round_timer_timeout")
	game.call("_finish_round")
	_expect(history.completed_matches == 1,
		"A timer finish must count exactly once, even if finish is called again.")
	game.call("_start_round")
	(game.get_node("%RoundTimer") as Timer).stop()
	_expect(int(view.call("diagnostics")["pit_chickens"]) == 6,
		"Replay must immediately populate the pit from the just-completed match.")
	await _free_game(game)

	game = await _new_game(true, path)
	history = game.get("_pit_history")
	view = game.get("_view") as Node
	_expect(history.completed_matches == 1 and int(view.call("diagnostics")["pit_chickens"]) == 6,
		"A fresh scene and a CPU entry must load the same saved flock.")
	_force_pin(game, 1)
	_expect(history.completed_matches == 1,
		"A pin still in its presentation hold is not yet a completed match.")
	await _free_game(game)
	var reloaded := PitHistory.new(path)
	_expect(reloaded.load_history() == OK and reloaded.completed_matches == 1,
		"Quitting during a pin or abandoning a replay must not add chickens.")


func _free_game(game: Node) -> void:
	game.set("_round_active", false)
	game.queue_free()
	await process_frame


func _dispatch(action: StringName, pressed := true) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	get_root().push_input(event)


func _test_parent_input_and_viewport() -> void:
	var game := await _new_game()
	var state: PitState = game.get("_state")
	var view := game.get("_view") as Node
	var diagnostics: Dictionary = view.call("diagnostics")
	_expect(bool(diagnostics["inert"]), "The 3D view must identify headless execution.")
	_expect(int(diagnostics["particle_emitters"]) == 0
		and not bool(diagnostics["rope_simulation"]) and int(diagnostics["pit_capacity"]) == 0,
		"Headless scenes must allocate no emitters, flock instances or Verlet simulation.")
	var container := game.get("_pit_container") as SubViewportContainer
	var viewport := game.get("_pit_viewport") as SubViewport
	_expect(container.stretch and container.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"The render surface must stretch without intercepting the parent input.")
	_expect(viewport.own_world_3d and viewport.gui_disable_input and viewport.transparent_bg,
		"The pit must own an isolated, transparent, non-interactive 3D viewport.")

	for action in ChickenPitOptions.pull_actions(0):
		_dispatch(action)
	_expect(state.accepted_pulls[0] == 1 and state.strength[0] > 0.0,
		"Parent-viewport actions must reach the model, and a three-key chord grants one pull.")
	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_Q
	echo.pressed = true
	echo.echo = true
	state.step(0.11)
	get_root().push_input(echo)
	_expect(state.accepted_pulls[0] == 1, "OS key repeat must never generate another pull.")
	_dispatch(ChickenPitOptions.PULL_ONE_A_ACTION, false)
	_expect(state.accepted_pulls[0] == 1, "Releasing a key is not a pull.")
	game.call("_update_round", 0.2, 40.0)
	_expect(state.rope > 0.0, "The routed pull must move the real rope toward red.")
	_dispatch(ChickenPitOptions.PULL_TWO_A_ACTION)
	_expect(state.accepted_pulls[1] == 1, "The other human's keys must drive blue.")

	var original_size := get_root().size
	get_root().size = Vector2i(1420, 880)
	await process_frame
	await process_frame
	var bounds: Rect2 = game.call("_playfield_bounds")
	_expect(container.position.is_equal_approx(bounds.position)
		and container.size.is_equal_approx(bounds.size),
		"The container must follow the shell's actual bounds after a resize.")
	_expect(viewport.size.x > 2 and viewport.size.y > 2,
		"Stretch must give the 3D viewport a real render size.")
	get_root().size = original_size
	await process_frame

	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	var camera := view.get("camera") as Camera3D
	var parked := camera.transform
	camera.call("update_camera", 1.0, 8.0, 25.0)
	_expect(bool(view.get("reduced_motion")) and bool(camera.get("reduced_motion"))
		and camera.transform.is_equal_approx(parked),
		"A live reduced-motion change must hold the camera completely still.")
	_expect(bool((view.get("rope_view") as Node).get("reduced_motion")),
		"A live reduced-motion change must straighten the rope.")
	_settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, false)
	_expect(not bool(view.get("intense_effects")),
		"The visual-effects hook must reach the pit, not just the shared overlay.")
	_settings.call("set_value", ChickenPitOptions.PULL_ONE_A_KEY, KEY_Z)
	_expect(str(game.call("_key_summary", 0)).contains("Z"),
		"Live key hints must read the rebound action instead of advertising Q.")
	_settings.call("reset_controls_to_defaults", ChickenPitOptions.GAME_ID)
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	_settings.call("set_value", Settings.VISUAL_EFFECTS_KEY, true)
	await _free_game(game)


func _force_pin(game: Node, winner: int) -> void:
	var state: PitState = game.get("_state")
	state.rope = (1.0 if winner == 0 else -1.0) * (state.L - 0.015)
	state.strength[winner] = 100.0
	state.strength[1 - winner] = 0.0
	game.call("_update_round", 0.10, 0.04)


func _test_delayed_pin_and_pause() -> void:
	var game := await _new_game()
	_force_pin(game, 0)
	var state: PitState = game.get("_state")
	_expect(bool(game.get("_pin_pending")) and bool(game.get("_round_active"))
		and not (game.get_node("%RoundOver") as Control).visible,
		"A pin must start its hold, not synchronously show results.")
	var frozen_clock := state.clock
	var frozen_strength := state.strength.duplicate()
	game.call("_update_round", 0.5, 0.0)
	_dispatch(ChickenPitOptions.PULL_ONE_B_ACTION)
	_expect(state.clock == frozen_clock and state.strength == frozen_strength,
		"Model steps and human input must stay frozen throughout the pin.")
	game.call("_on_round_timer_timeout")
	_expect(bool(game.get("_round_active")), "A buzzer must not interrupt a pin in progress.")
	var timer := game.get("_pin_timer") as Timer
	var remaining := timer.time_left
	paused = true
	await create_timer(0.10, true).timeout
	_expect(is_equal_approx(timer.time_left, remaining),
		"The pin hold must pause with the game, not expire behind the pause menu.")
	paused = false
	await create_timer(0.30).timeout
	_expect(bool(game.get("_round_active")), "A pin must keep its 1.1-second presentation.")
	await create_timer(0.88).timeout
	_expect(not bool(game.get("_round_active"))
		and (game.get_node("%RoundOver") as Control).visible,
		"The scene-owned pin timer must eventually finish a timed round.")
	_expect((game.get_node("%TimeProgress") as ProgressBar).value == 0.0
		and (game.get_node("%DangerOverlay") as ColorRect).color.a == 0.0
		and (game.get_node("%TimeLabel") as Label).scale == Vector2.ONE,
		"Completing a pin must leave neither stale timer progress nor urgency motion.")
	_expect(str((game.get_node("%ResultLabel") as Label).text).begins_with("RED COOP PINS"),
		"The pin headline must name the same winner as the model.")
	var scores: Array = game.get("_scores")
	_expect(int(scores[0]) > int(scores[1]), "The pin winner must also win the scoreboard.")
	await _free_game(game)


func _test_lives() -> void:
	_settings.call("set_value", Settings.ROUND_MODE_KEY, Settings.RoundMode.LIVES)
	var game := await _new_game()
	_force_pin(game, 0)
	(game.get("_pin_timer") as Timer).stop()
	game.call("_complete_pin")
	var state: PitState = game.get("_state")
	var lives: Array = game.get("_lives")
	_expect(bool(game.get("_round_active")) and int(lives[1]) == 2,
		"The first pin must cost one life, not end a first-to-three match.")
	_expect(state.rope == 0.0 and state.strength == [0.0, 0.0] and state.pin_winner == -1,
		"A nonterminal pin must re-centre and rearm the model.")
	_expect(state.scores[0] > 0.0 and state.extreme[0] == state.L,
		"Re-centring must keep banked score and the round's signed history.")
	var history: PitHistory = game.get("_pit_history")
	_expect(history.completed_matches == 0,
		"A nonterminal lives pin must not increment the completed-match history.")
	for winner in [1, 0, 0]:
		_force_pin(game, winner)
		(game.get("_pin_timer") as Timer).stop()
		game.call("_complete_pin")
	lives = game.get("_lives")
	_expect(not bool(game.get("_round_active")) and int(lives[1]) == 0
		and int(lives[0]) == 2,
		"Lives mode ends when either coop runs out; the winner must keep its remaining lives.")
	_expect((game.get_node("%RoundOver") as Control).visible,
		"The last life must use the shared results screen.")
	_expect(history.completed_matches == 1
		and int((game.get("_view") as Node).call("diagnostics")["pit_chickens"]) == 6,
		"Multiple lives pins must still add only one match and one six-chicken flock.")
	await _free_game(game)
	_settings.call("set_value", Settings.ROUND_MODE_KEY, Settings.RoundMode.TIMER)


func _test_single_seat_cpu() -> void:
	var game := await _new_game(true)
	var state: PitState = game.get("_state")
	_expect(bool(game.get("_cpu_enabled")), "A framework solo entry must still seat a bird.")
	_dispatch(ChickenPitOptions.PULL_TWO_A_ACTION)
	_expect(state.accepted_pulls[1] == 0, "Human keys cannot take over the CPU seat.")
	for frame in 90:
		game.call("_update_round", 1.0 / 60.0, 40.0)
	_expect(state.accepted_pulls[1] > 0 and state.rope < 0.0,
		"The fallback bird must actually pull the rope, not just decorate the world.")
	var payload: Dictionary = game.call("_share_payload")
	_expect((payload["score_values"] as Array).size() == 2
		and str(payload["score"]).contains(" - "),
		"A single-seat entry must still share both coop scores.")
	await _free_game(game)

	_settings.call("set_value", Settings.ROUND_MODE_KEY, Settings.RoundMode.LIVES)
	game = await _new_game(true)
	_force_pin(game, 0)
	(game.get("_pin_timer") as Timer).stop()
	game.call("_complete_pin")
	var lives: Array = game.get("_lives")
	_expect(int(lives[1]) == 2 and bool(game.get("_round_active")),
		"The fallback bird's hidden shell seat still needs a chargeable life pool.")
	await _free_game(game)
	_settings.call("set_value", Settings.ROUND_MODE_KEY, Settings.RoundMode.TIMER)


func _test_score_outcome_and_achievements() -> void:
	var game := await _new_game()
	var state: PitState = game.get("_state")
	state.strength[0] = 100.0
	game.call("_update_round", 0.5, 0.05)
	_expect(is_equal_approx(state.clock, 0.05),
		"A hitch at the buzzer must not award time beyond the remaining round budget.")
	state.scores[0] = 3210.5
	state.scores[1] = 2800.0
	state.rope = -2.0
	state.extreme[1] = state.L - 1.0
	game.call("_sync_totals")
	game.call("_on_round_timer_timeout")
	_expect((game.get_node("%ResultLabel") as Label).text == "RED COOP HOLDS THE PIT",
		"The buzzer is judged on banked score, not the last position of the knot.")
	_expect((game.get_node("%RoundPlayerOneScore") as Label).text == "3210"
		and (game.get_node("%PlayerOneStatsScore") as Label).text == "3210",
		"Results and stats must read the same accumulated integer score.")
	var payload: Dictionary = game.call("_share_payload")
	_expect(str(payload["score"]) == "3210 - 2800"
		and str(payload["result"]) == "RED COOP HOLDS THE PIT",
		"The share card must agree with the headline and scoreboard.")
	_expect(str(payload["accuracy_caption"]) == "PULLS"
		and str(payload["accuracy"]) == str(state.accepted_pulls[0] + state.accepted_pulls[1])
		and str(payload["hits_caption"]) == "NOTCHES TAKEN"
		and str(payload["hits"]) == str(state.captures[0] + state.captures[1])
		and str(payload["combo_caption"]) == "BEST NOTCH RUN",
		"The share card must label the model's pull and notch totals honestly.")
	var awarded: PackedStringArray = game.get("observed_achievements")
	_expect(awarded.has("pit_first_match") and awarded.has("pit_comeback")
		and not awarded.has("pit_clean_sweep"),
		"Achievement rules must read signed history, including fractional lost ground.")
	await _free_game(game)

	game = await _new_game()
	state = game.get("_state")
	state.scores[0] = 10.0
	state.extreme[1] = 0.01
	game.call("_sync_totals")
	game.call("_on_round_timer_timeout")
	awarded = game.get("observed_achievements")
	_expect(not awarded.has("pit_clean_sweep"),
		"Even 0.01 notches across the centre disqualifies a clean sweep.")
	await _free_game(game)


func _test_exit_during_pin() -> void:
	var game := await _new_game()
	var path: String = game.get("history_path")
	_force_pin(game, 1)
	await _free_game(game)
	await create_timer(1.15).timeout
	_expect(not is_instance_valid(game), "Leaving during a pin must free its timer and world.")
	_expect(not FileAccess.file_exists(path), "Exiting during a pin must not save a completed play.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
