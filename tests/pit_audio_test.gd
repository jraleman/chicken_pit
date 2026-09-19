extends SceneTree

## Real Music-bus capture plus the shipped shell's completion/exit lifecycle.

const PitMusic = preload("res://games/chicken_pit/pit/pit_music.gd")
const PitState = preload("res://games/chicken_pit/pit/pit_state.gd")
const PitHistory = preload("res://games/chicken_pit/pit/pit_history.gd")
const GAME_PATH := "res://games/chicken_pit/gameplay.tscn"
const FIXTURE_PATH := "res://games/chicken_pit/tests/pit_audio_fixture.gd"
const ENTRY_PATH := "res://games/chicken_pit/tests/pit_audio_entry.tscn"
const MENU_PATH := "res://scenes/menus/main_menu.tscn"

var _failures := PackedStringArray()
var _settings: Node
var _audio: Node
var _router: Node
var _capture: AudioEffectCapture
var _history_paths := PackedStringArray()
var _original_values: Dictionary
var _original_game := ""
var _completed_sections := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_settings = root.get_node("Settings")
	_audio = root.get_node("AudioManager")
	_router = root.get_node("Router")
	_original_values = (_settings.get("_values") as Dictionary).duplicate(true)
	_original_game = GameCatalog.current_id()
	(_settings.get("_save_timer") as Timer).process_mode = Node.PROCESS_MODE_DISABLED
	GameCatalog.select(ChickenPitOptions.GAME_ID)
	_settings.call("set_value", Settings.ROUND_MODE_KEY, Settings.RoundMode.TIMER)
	_settings.call("set_value", Settings.STARTING_LIVES_KEY, 2)
	_settings.call("set_value", "audio/master", 1.0)
	_settings.call("set_value", "audio/music", 1.0)
	_settings.call("set_value", "audio/sfx", 0.0)
	_settings.call("set_value", "audio/muted", false)
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 2.0
	AudioServer.add_bus_effect(0, _capture)

	await _test_global_stop()
	await _test_adaptive_output()
	await _test_results_replay_and_lives()
	await _test_exits()
	_expect(_completed_sections == 4, "All audio sections must finish without script errors.")

	paused = false
	_audio.call("stop_music", 0.0)
	await create_timer(0.90).timeout
	for child in _audio.find_children("*", "AudioStreamPlayer", true, false):
		var player := child as AudioStreamPlayer
		player.stop()
		player.stream = null
	await create_timer(0.10).timeout
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	for path in _history_paths:
		if FileAccess.file_exists(path):
			_expect(DirAccess.remove_absolute(path) == OK, "Fixture history must be cleaned.")
	var values := _settings.get("_values") as Dictionary
	values.clear()
	values.merge(_original_values, true)
	(_settings.get("_save_timer") as Timer).stop()
	_audio.call("_apply_all_volumes")
	GameCatalog.select(_original_game)
	if _failures.is_empty():
		print("Chicken Pit audio tests passed (captured mixed PCM, driver: %s)." %
			AudioServer.get_driver_name())
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_global_stop() -> void:
	var first := PitMusic.JIG.duplicate() as AudioStreamWAV
	var second := PitMusic.DANGER.duplicate() as AudioStreamWAV
	_audio.call("stop_music", 0.0)
	_audio.call("play_music", first, 0.30)
	_expect(bool(_audio.call("is_music_playing")),
		"Incoming startup music must count as playing before the crossfade swap.")
	_audio.call("stop_music", 0.0)
	_expect(_global_voices() == 0, "Immediate stop must stop an initial fade synchronously.")
	await create_timer(0.35).timeout
	_expect(_global_voices() == 0, "A cancelled startup swap must not resurrect music.")

	_audio.call("play_music", first, 0.0)
	await create_timer(0.08).timeout
	_audio.call("play_music", second, 0.30)
	_expect(_global_voices() == 2, "The regression must exercise two real crossfade voices.")
	_audio.call("stop_music", 0.0)
	_expect(_global_voices() == 0, "Immediate stop must silence both crossfade voices.")
	await create_timer(0.35).timeout
	_expect(_global_voices() == 0, "No crossfade callback may revive stopped music.")

	for crossfade in [false, true]:
		_audio.call("play_music", first, 0.0 if crossfade else 0.30)
		if crossfade:
			await create_timer(0.08).timeout
			_audio.call("play_music", second, 0.30)
		_audio.call("stop_music", 0.10)
		await create_timer(0.20).timeout
		_expect(_global_voices() == 0,
			"Faded stop must stop every voice during startup and an established crossfade.")
	_audio.call("play_music", first, 0.30)
	_audio.call("stop_music", 0.10)
	_audio.call("play_music", second, 0.0)
	await create_timer(0.20).timeout
	_expect(_global_voices() == 1,
		"New music must survive cancellation of a preceding stop fade.")
	_audio.call("stop_music", 0.0)
	_completed_sections += 1


func _global_voices() -> int:
	var count := 0
	for key in ["_music", "_music_next"]:
		if (_audio.get(key) as AudioStreamPlayer).playing:
			count += 1
	return count


func _test_adaptive_output() -> void:
	var bed := PitMusic.new()
	root.add_child(bed)
	bed.start(false)
	_expect(not bed._player.playing, "Ordinary headless invocation must not start a voice.")
	_expect(PitMusic.JIG.mix_rate == PitMusic.DANGER.mix_rate
		and is_equal_approx(PitMusic.JIG.get_length(), PitMusic.DANGER.get_length()),
		"Both original stems must have identical sample rate and loop length.")
	bed.start(true)
	_expect(bed._player.playing and bed._player.bus == "Music",
		"Adaptive music must be a scene-owned, playing Music-bus voice.")
	var calm := await _rms()
	_expect(calm > 0.003, "The base jig must produce real mixed PCM.")
	# Isolate the danger layer to prove live synchronized-stream volume reaches playback.
	bed._stems.set_sync_stream_volume(0, PitMusic.SILENT_DB)
	var silent := await _rms()
	_expect(silent < 0.0001, "The danger stem must be inaudible at the centre.")
	bed.set_pressure(9.5, 10.0)
	await create_timer(1.4).timeout
	var red := await _rms()
	_expect(red > 0.006 and red > silent * 20.0,
		"Live pressure must audibly introduce the synchronized percussion/countermelody.")
	bed.set_pressure(-9.5, 10.0)
	var blue := await _rms()
	_expect(blue > 0.006 and bed._pressure == 1.0,
		"A threatened red coop must receive the same danger music as a threatened blue coop.")

	_settings.call("set_value", "audio/music", 0.25)
	var quiet := await _rms()
	_expect(quiet < blue * 0.55 and quiet > blue * 0.08,
		"The shared Music slider must attenuate actual output, not merely player metadata.")
	_settings.call("set_value", "audio/music", 0.0)
	_expect(await _rms() < 0.000001, "Music mute must silence both stems in the final mix.")
	_settings.call("set_value", "audio/music", 1.0)
	_settings.call("set_value", "audio/muted", true)
	# Master effects are before the Master fader; inspect the actual master mute contract.
	_expect(AudioServer.is_bus_mute(0), "The global mute must apply to the Music bus output.")
	_settings.call("set_value", "audio/muted", false)

	paused = true
	await create_timer(0.10, true).timeout
	var parked := bed._player.get_playback_position()
	var held_intensity := bed._intensity
	_expect(await _rms() < 0.000001, "Scene pause must silence the mixed music.")
	_expect(is_equal_approx(parked, bed._player.get_playback_position())
		and held_intensity == bed._intensity, "Pause must hold both playhead and danger envelope.")
	paused = false
	_expect(await _rms() > 0.006, "Unpause must resume the existing stems.")
	bed.set_pressure(0.0, 10.0)
	await create_timer(0.25).timeout
	_expect(bed._intensity > 0.65 and bed._intensity < 0.95,
		"Recovery must release gradually instead of snapping or chattering.")
	await create_timer(3.8).timeout
	_expect(await _rms() < red * 0.08, "Recovering centre ground must audibly ease the danger.")
	bed.stop()
	_expect(not bed._player.playing, "Stop must end the synchronized playback immediately.")
	_expect(await _rms() < 0.000001, "Stopped adaptive music must leave no mixed output.")
	bed.queue_free()
	await process_frame
	print("Captured stem RMS: calm %.5f, red %.5f, blue %.5f, 25%% %.5f." %
		[calm, red, blue, quiet])
	_completed_sections += 1


func _rms() -> float:
	await create_timer(0.10, true).timeout
	_capture.clear_buffer()
	await create_timer(0.45, true).timeout
	var frames := _capture.get_buffer(_capture.get_frames_available())
	_expect(not frames.is_empty(), "The audio driver must actually mix capturable PCM frames.")
	var energy := 0.0
	for frame in frames:
		energy += frame.length_squared() * 0.5
	return sqrt(energy / maxi(frames.size(), 1))


func _new_game() -> Node:
	root.get_node("GameSession").call("configure_multiplayer",
		GameSession.PlayerTwoController.HUMAN)
	var packed := load(GAME_PATH) as PackedScene
	var fixture := load(FIXTURE_PATH) as Script
	var game := packed.instantiate()
	var red: Color = game.get("player_one_color")
	var blue: Color = game.get("player_two_color")
	game.set_script(fixture)
	game.set("player_one_color", red)
	game.set("player_two_color", blue)
	var path := "user://chicken_pit_audio_%d_%d.cfg" % [
		OS.get_process_id(), Time.get_ticks_usec()]
	_history_paths.append(path)
	game.set("history_path", path)
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	(game.get_node("%RoundTimer") as Timer).stop()
	return game


func _test_results_replay_and_lives() -> void:
	var game := _new_game()
	var bed := game.get("_pit_music") as PitMusic
	var history := game.get("_pit_history") as PitHistory
	_expect(bed._player.playing and _global_voices() == 0,
		"Round activation must start exactly one owned player without autoload duplication.")
	var state := game.get("_state") as PitState
	state.rope = state.L * 0.95
	game.call("_update_pit_audio")
	_expect(bed._pressure == 1.0, "Gameplay must send actual rope proximity to the music.")
	await create_timer(0.20).timeout
	game.call("_on_round_timer_timeout")
	_expect(not bed._player.playing and history.completed_matches == 1,
		"A Timer draw must stop music and count exactly one completed match.")
	_expect(await _rms() < 0.000001, "Results must have no lingering gameplay music output.")
	game.call("_end_round")
	game.call("_finish_round")
	_expect(history.completed_matches == 1, "Duplicate completion must not count twice.")
	game.call("_on_play_again_pressed")
	(game.get_node("%RoundTimer") as Timer).stop()
	_expect(bed._player.playing and bed._player.get_playback_position() < 0.10
		and bed._intensity == 0.0 and bed.get_child_count() == 1,
		"Replay must reset the one owned playhead and danger layer, not create another voice.")
	state = game.get("_state") as PitState
	state.scores[0] = 20.0
	game.call("_sync_totals")
	game.call("_on_round_timer_timeout")
	_expect(not bed._player.playing and history.completed_matches == 2,
		"A scored Timer win must also stop music and count once.")
	await _free_game(game)

	game = _new_game()
	bed = game.get("_pit_music") as PitMusic
	history = game.get("_pit_history") as PitHistory
	_force_pin(game)
	var hold := game.get("_pin_timer") as Timer
	hold.start()
	paused = true
	await create_timer(0.20, true).timeout
	_expect(bed._player.stream_paused and bool(game.get("_pin_pending"))
		and history.completed_matches == 0,
		"A paused pin hold must pause owned music without completing the match.")
	paused = false
	await create_timer(1.20).timeout
	_expect(not bed._player.playing and history.completed_matches == 1,
		"The real terminal Timer pin callback must stop music after its pausable hold.")
	await _free_game(game)

	_settings.call("set_value", Settings.ROUND_MODE_KEY, Settings.RoundMode.LIVES)
	game = _new_game()
	bed = game.get("_pit_music") as PitMusic
	history = game.get("_pit_history") as PitHistory
	_force_pin(game)
	_expect(bed._player.playing, "A pin presentation must retain the music until resolution.")
	await create_timer(0.35).timeout
	var before := bed._player.get_playback_position()
	game.call("_complete_pin")
	_expect(bed._player.playing and bed._pressure == 0.0
		and bed._player.get_playback_position() >= before
		and history.completed_matches == 0,
		"A nonterminal Lives pin must ease pressure without restarting or recording a match.")
	_force_pin(game)
	game.call("_complete_pin")
	_expect(not bed._player.playing and history.completed_matches == 1,
		"The terminal Lives pin must stop music and record the actual match once.")
	await _free_game(game)
	_settings.call("set_value", Settings.ROUND_MODE_KEY, Settings.RoundMode.TIMER)
	_completed_sections += 1


func _force_pin(game: Node) -> void:
	var state := game.get("_state") as PitState
	state.rope = state.L - 0.015
	state.strength[0] = 100.0
	game.call("_update_round", 0.10, 0.04)
	(game.get("_pin_timer") as Timer).stop()


func _test_exits() -> void:
	# A menu fade-in still pending when the game arrives must not leave its incoming voice.
	_audio.call("play_music", PitMusic.JIG, 0.80)
	var game := _new_game()
	_expect(_global_voices() == 0, "Game entry must cancel menu music's initial fade.")
	var bed := game.get("_pit_music") as PitMusic
	var owned := bed._player
	var path := str(game.get("history_path"))
	game.call("_on_exit_to_main_menu_pressed")
	_expect(not owned.playing and not FileAccess.file_exists(path),
		"Direct menu exit must stop immediately without saving an unfinished match.")
	await _router.transition_finished
	_expect(not is_instance_valid(game) and not is_instance_valid(owned),
		"Actual Router exit must free the old scene and its music player.")
	await _free_current_scene()

	game = _new_game()
	path = str(game.get("history_path"))
	_force_pin(game)
	owned = (game.get("_pit_music") as PitMusic)._player
	# Real pause-menu callback unpauses and routes directly, bypassing _finish_round.
	game.call("open_pause_menu")
	var pause_menu := game.get("_pause_menu") as Node
	pause_menu.call("_on_exit_to_main_menu_pressed")
	game.call("_complete_pin")
	_expect(not owned.playing and not FileAccess.file_exists(path),
		"Exit during a pending pin must cancel completion even before the next process tick.")
	await _router.transition_finished
	_expect(not is_instance_valid(owned), "The paused game's music must not survive menu exit.")
	await _free_current_scene()

	game = _new_game()
	path = str(game.get("history_path"))
	owned = (game.get("_pit_music") as PitMusic)._player
	game.set_process(true)
	_router.call("goto", MENU_PATH)
	await process_frame
	await process_frame
	_expect(not owned.playing and not bool(game.get("_round_active"))
		and not FileAccess.file_exists(path),
		"A plain Router/menu exit must stop music at fade start without a completion callback.")
	await _router.transition_finished
	await _free_current_scene()

	game = _new_game()
	path = str(game.get("history_path"))
	game.set_process(true)
	_router.call("goto", MENU_PATH)
	game.call("_on_round_timer_timeout")
	_expect(not FileAccess.file_exists(path),
		"A buzzer racing a Router fade must not count an abandoned match.")
	await _router.transition_finished
	await _free_current_scene()

	_router.call("goto", ENTRY_PATH)
	await scene_changed
	game = current_scene
	_expect(game != null, "Router must mount the startup scene before testing its early exit.")
	if game == null:
		return
	path = str(game.get("history_path"))
	_history_paths.append(path)
	_expect(bool(_router.call("is_transitioning")) and game.get("_state") == null,
		"The startup regression must enter before the incoming Router fade has finished.")
	bed = game.get("_pit_music") as PitMusic
	owned = bed._player
	game.call("_on_exit_to_main_menu_pressed")
	await _router.transition_finished
	await _router.transition_finished
	_expect(not is_instance_valid(game) and not is_instance_valid(owned)
		and not FileAccess.file_exists(path) and current_scene.scene_file_path == MENU_PATH,
		"A startup exit must defer its route, never activate music, and save no unfinished match.")
	await _free_current_scene()

	_router.call("goto", ENTRY_PATH)
	await scene_changed
	game = current_scene
	path = str(game.get("history_path"))
	_history_paths.append(path)
	bed = game.get("_pit_music") as PitMusic
	_expect(not bed._player.playing, "Normal scene entry must wait for its incoming fade.")
	await _router.transition_finished
	_expect(bed._player.playing and bool(game.get("_round_active")),
		"The entry fade must activate one live match, not be mistaken for a menu exit.")
	game.call("_on_exit_to_main_menu_pressed")
	await _router.transition_finished
	_expect(not FileAccess.file_exists(path), "Leaving the just-entered round must not record it.")
	await _free_current_scene()

	game = _new_game()
	bed = game.get("_pit_music") as PitMusic
	# Incoming scene music must survive old-scene cleanup: teardown stops only owned players.
	_audio.call("play_music", PitMusic.DANGER, 0.0)
	await create_timer(0.08).timeout
	await _free_game(game)
	_expect(not is_instance_valid(bed) and _global_voices() == 1,
		"Old-scene teardown must not stop an incoming menu's globally owned music.")
	_audio.call("stop_music", 0.0)
	_completed_sections += 1


func _free_current_scene() -> void:
	if current_scene != null:
		current_scene.queue_free()
		await process_frame
	_audio.call("stop_music", 0.0)


func _free_game(game: Node) -> void:
	game.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
