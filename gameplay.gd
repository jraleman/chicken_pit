extends GameShell

## Two coops, one deterministic rope, and a toy farm inside the shared 2D shell.

const GAME_ID := "chicken_pit"
const PitState = preload("res://games/chicken_pit/pit/pit_state.gd")
const PitHistory = preload("res://games/chicken_pit/pit/pit_history.gd")
const PitMusic = preload("res://games/chicken_pit/pit/pit_music.gd")
const CpuBird = preload("res://games/chicken_pit/pit/cpu_bird.gd")
const PitView = preload("res://games/chicken_pit/pit/pit_view.gd")
const TugMeter = preload("res://games/chicken_pit/ui/tug_meter.gd")
const PIT_SCENE := preload("res://games/chicken_pit/pit/pit.tscn")
const PULL_SOUND := preload("res://games/chicken_pit/assets/audio/pull.wav")
const NOTCH_SOUND := preload("res://games/chicken_pit/assets/audio/notch.wav")
const PIN_SOUND := preload("res://games/chicken_pit/assets/audio/pin.wav")
const CREAK_LOOP := preload("res://games/chicken_pit/assets/audio/rope-creak.wav")
const CROWD_LOOP := preload("res://games/chicken_pit/assets/audio/crowd.wav")
const PIN_CAMERA_SECONDS := 1.1
const RENDER_SCALE := 1.0

var _round_length := ChickenPitOptions.DEFAULT_ROUND_LENGTH
var _round_pull_power := ChickenPitOptions.DEFAULT_PULL_POWER
var _round_strength_decay := ChickenPitOptions.DEFAULT_STRENGTH_DECAY
var _round_rope_length := ChickenPitOptions.DEFAULT_ROPE_LENGTH
var _round_cpu_difficulty := ChickenPitOptions.DEFAULT_CPU_DIFFICULTY
## The hats each coop wears this round, read once so a purchase made from the
## pause menu dresses the birds at the next countdown rather than mid-pull.
var _round_hats := PackedStringArray(["", ""])

var _state: PitState
var _pit_history: PitHistory
var _recorded_round_id := -1
var _cpu_bird: CpuBird
var _cpu_enabled := true
var _view: PitView
var _pit_container: SubViewportContainer
var _pit_viewport: SubViewport
var _tug_meter: TugMeter
var _pin_timer: Timer
var _pin_pending := false
var _pin_round_id := -1
var _ended_on_pin := false
var _last_pin_winner := -1
var _last_captures: Array[int] = [0, 0]
var _last_grunt: Array[float] = [-INF, -INF]
var _last_creak_caption := -INF
var _near_pin := false
var _creak: AudioStreamPlayer
var _crowd: AudioStreamPlayer
var _pit_music: PitMusic
var _leaving := false
var _entering_transition := false
var _completed_round_id := -1


func _ready() -> void:
	_entering_transition = Router.is_transitioning()
	if _entering_transition:
		Router.transition_finished.connect(_on_entry_transition_finished, CONNECT_ONE_SHOT)
	# Gameplay music belongs to this scene, not the always-processing menu players.
	music = null
	AudioManager.stop_music(0.0)
	super()


func _on_entry_transition_finished(_path: String) -> void:
	_entering_transition = false


func _process(delta: float) -> void:
	if _abort_if_exiting():
		return
	super(delta)


func _exit_tree() -> void:
	_abandon_round()


func _start_round() -> void:
	if not _abort_if_exiting():
		super()


func _end_round() -> void:
	if _abort_if_exiting() or not _round_active:
		return
	_completed_round_id = _round_id
	super()


func _on_exit_to_main_menu_pressed() -> void:
	_abandon_round()
	if Router.is_transitioning():
		await Router.transition_finished
	if is_inside_tree():
		Router.goto(main_menu_scene)


func _abort_if_exiting() -> bool:
	if not _leaving and Router.is_transitioning() and not _entering_transition:
		_abandon_round()
	return _leaving


func _abandon_round() -> void:
	_leaving = true
	_round_active = false
	if _round_timer != null:
		_round_timer.stop()
	_finish_round()


func game_id() -> String:
	return GAME_ID


func _load_round_settings() -> void:
	super()
	_round_length = Settings.tunable(ChickenPitOptions.ROUND_LENGTH_KEY)
	_round_pull_power = Settings.tunable(ChickenPitOptions.PULL_POWER_KEY)
	_round_strength_decay = Settings.tunable(ChickenPitOptions.STRENGTH_DECAY_KEY)
	_round_rope_length = int(Settings.tunable(ChickenPitOptions.ROPE_LENGTH_KEY))
	_round_cpu_difficulty = Settings.tunable_choice(
		ChickenPitOptions.CPU_DIFFICULTY_KEY
	)
	_active_round_duration = _round_length + Settings.extra_round_time()
	_round_hats = PackedStringArray([
		Store.equipped_id(GAME_ID, ChickenPitOptions.hat_slot(0)),
		Store.equipped_id(GAME_ID, ChickenPitOptions.hat_slot(1)),
	])


func _prepare_session() -> void:
	super()
	_cpu_enabled = not GameSession.player_two_enabled() or GameSession.player_two_is_cpu()
	# The named, game-specific Settings choice wins over the shell's generic CPU preset.
	_cpu_bird = CpuBird.new(_round_cpu_difficulty, _rng.randi())


func _build_playfield() -> void:
	_load_pit_history()
	_pit_container = SubViewportContainer.new()
	_pit_container.name = "PitView"
	_pit_container.stretch = true
	_pit_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playfield.add_child(_pit_container)
	_pit_viewport = SubViewport.new()
	_pit_viewport.name = "PitViewport"
	_pit_viewport.transparent_bg = true
	_pit_viewport.own_world_3d = true
	_pit_viewport.gui_disable_input = true
	_pit_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_pit_viewport.msaa_3d = Viewport.MSAA_2X
	_pit_viewport.scaling_3d_scale = RENDER_SCALE
	_pit_container.add_child(_pit_viewport)
	_view = PIT_SCENE.instantiate() as PitView
	_pit_viewport.add_child(_view)
	_view.set_reduced_motion(_reduced_motion_enabled)
	_view.set_intense_effects(_intense_effects_enabled)
	_tug_meter = TugMeter.new()
	_tug_meter.name = "TugMeter"
	_hud.get_node("Overlay").add_child(_tug_meter)
	_pin_timer = Timer.new()
	_pin_timer.name = "PinHold"
	_pin_timer.one_shot = true
	_pin_timer.wait_time = PIN_CAMERA_SECONDS
	_pin_timer.timeout.connect(_complete_pin)
	add_child(_pin_timer)
	_creak = _make_loop(CREAK_LOOP)
	_crowd = _make_loop(CROWD_LOOP)
	_pit_music = PitMusic.new()
	_pit_music.name = "PitMusic"
	add_child(_pit_music)
	get_viewport().size_changed.connect(_resize_pit)
	_resize_pit()
	_configure_mode_ui()


func _load_pit_history() -> void:
	_pit_history = PitHistory.new()
	if _pit_history.load_history(AchievementManager.is_unlocked("pit_first_match")) != OK:
		AudioManager.request_caption("Chicken Pit history could not be loaded")


func _reset_round_state() -> void:
	_pin_timer.stop()
	_pin_pending = false
	_ended_on_pin = false
	_last_pin_winner = -1
	_last_captures = [0, 0]
	_last_grunt = [-INF, -INF]
	_last_creak_caption = -INF
	_near_pin = false
	_prepare_session()
	_state = PitState.new(
		_round_rope_length, _round_pull_power, _round_strength_decay, _round_gameplay_speed
	)
	_view.reset_round(_state, [player_one_color, player_two_color],
		_pit_history.completed_matches, _round_hats)
	_tug_meter.reset()
	_tug_meter.present(_state)


func _activate_round() -> void:
	super()
	_pit_music.start(DisplayServer.get_name() != "headless")
	_creak.volume_db = -60.0
	_crowd.volume_db = -36.0
	if DisplayServer.get_name() != "headless":
		_creak.play()
		_crowd.play()


func _handle_gameplay_input(event: InputEvent) -> void:
	if _pin_pending or not _round_active or event.is_echo() or not event.is_pressed():
		return
	for coop in PLAYER_COUNT:
		if coop == PLAYER_TWO and _cpu_enabled:
			continue
		for action in ChickenPitOptions.pull_actions(coop):
			if event.is_action_pressed(action):
				get_viewport().set_input_as_handled()
				_register_pull(coop, action)
				return


func _register_pull(coop: int, action: StringName) -> float:
	if _abort_if_exiting() or _pin_pending or not _round_active:
		return 0.0
	var gain := _state.register_pull(coop, action, _state.clock)
	if gain > 0.0:
		_present_pull(coop, action, gain)
	else:
		_view.rejected_pull(coop)
	return gain


func _present_pull(coop: int, action: StringName, gain: float) -> void:
	var alternating := _state.last_alternation[coop] > 0.5
	_view.accepted_pull(coop, gain, alternating)
	_tug_meter.accepted_pull(coop, action, alternating)
	if _state.clock - _last_grunt[coop] >= 0.08:
		_last_grunt[coop] = _state.clock
		_play_pit_sound(PULL_SOUND,
			-12.0 if alternating else -19.0, 0.85 + minf(gain / 25.0, 0.5))
	_tug_meter.present(_state)


func _update_round(delta: float, time_left: float) -> void:
	if _abort_if_exiting() or _pin_pending:
		return
	var active_delta := delta if _lives_mode else minf(delta, maxf(time_left, 0.0))
	if active_delta <= 0.0:
		return
	if _cpu_enabled:
		var gain := _cpu_bird.update(_state)
		if gain > 0.0:
			_present_pull(PLAYER_TWO, _state.last_action[PLAYER_TWO], gain)
	var pin := _state.step(active_delta)
	_sync_totals()
	_view.present(_state)
	_tug_meter.present(_state)
	_update_pit_audio()
	if pin >= 0:
		_begin_pin(pin)


func _sync_totals() -> void:
	var score_changed := false
	var streak_changed := false
	for coop in PLAYER_COUNT:
		var score := floori(_state.scores[coop])
		score_changed = score_changed or _scores[coop] != score
		streak_changed = streak_changed or _streaks[coop] != _state.streaks[coop]
		_scores[coop] = score
		_streaks[coop] = _state.streaks[coop]
		_best_streaks[coop] = _state.best_streaks[coop]
		if _state.captures[coop] > _last_captures[coop]:
			_view.captured_notch(coop)
			_play_pit_sound(NOTCH_SOUND, -11.0, 1.0 + _streaks[coop] * 0.018)
			AudioManager.request_caption("%s gains ground" % _player_name(coop))
			_last_captures[coop] = _state.captures[coop]
	if score_changed:
		_update_scores()
	if streak_changed:
		_update_streaks()


func _begin_pin(winner: int) -> void:
	if _pin_pending:
		return
	_pin_pending = true
	_pin_round_id = _round_id
	_ended_on_pin = true
	_last_pin_winner = winner
	# A pin at the buzzer wins its full hold; the clock cannot end it halfway through.
	_round_timer.stop()
	_view.play_pin(winner)
	var headline := "RED COOP PINS BLUE!" if winner == PLAYER_ONE else "BLUE COOP PINS RED!"
	_show_announcement(headline, _player_color(winner), PIN_CAMERA_SECONDS * 0.7)
	AudioManager.request_caption(headline)
	_play_pit_sound(PIN_SOUND, -6.0)
	_flash_screen(_player_color(winner), 0.18)
	_add_screen_shake(7.0)
	_pin_timer.start()


## A pausable, scene-owned timer completes outside GameShell._process's stale HUD writes.
func _complete_pin() -> void:
	if _abort_if_exiting() or not _round_active or not _pin_pending \
			or _pin_round_id != _round_id:
		return
	_pin_pending = false
	if _lives_mode:
		_lose_life(1 - _last_pin_winner)
		if _round_active:
			_ended_on_pin = false
			_state.recentre()
			_cpu_bird.reset(_state.clock)
			_sync_totals()
			_view.reset_exchange(_state)
			_tug_meter.present(_state)
			_update_pit_audio()
			_configure_mode_ui()
			_show_announcement("BACK TO THE ROPE!", Color("fff8e7"))
		return
	_end_round()


func _on_round_timer_timeout() -> void:
	if not _abort_if_exiting() and _round_active and not _pin_pending:
		super()


func _finish_round() -> void:
	if _state != null:
		_state.freeze()
	if _pin_timer != null:
		_pin_timer.stop()
	_pin_pending = false
	if _creak != null:
		_creak.stop()
	if _crowd != null:
		_crowd.stop()
	if _pit_music != null:
		_pit_music.stop()
	# Exit cleanup also runs after the SubViewport has left the tree.
	if _view != null and _view.is_inside_tree():
		_view.settle()
	if not _leaving and _completed_round_id == _round_id \
			and _recorded_round_id != _round_id:
		_recorded_round_id = _round_id
		if _pit_history.record_match() != OK:
			_show_announcement("COULD NOT SAVE PIT FLOCK", Color("fff8e7"))
			AudioManager.request_caption("Chicken Pit flock could not be saved")


## A tug-of-war ends when either coop is out, not when both have been eliminated.
## Keep the shell's life pool; only specialize its elimination predicate and gauge.
func _every_player_is_out() -> bool:
	return _lives_mode and (_player_is_out(PLAYER_ONE) or _player_is_out(PLAYER_TWO))


func _remaining_lives() -> int:
	return mini(int(_lives[PLAYER_ONE]), int(_lives[PLAYER_TWO]))


func _active_player_indices() -> Array[int]:
	# Single-seat framework entry points still need a real rival and a chargeable life pool.
	return [PLAYER_ONE, PLAYER_TWO]


func _round_length_seconds() -> float:
	return _round_elapsed


func _lives_rule_note() -> String:
	return "First to %d pins wins" % _starting_lives if _lives_mode else ""


func _round_mode_summary() -> String:
	var mode := "Red vs %s" % CpuBird.bird_name(_round_cpu_difficulty) if _cpu_enabled \
		else "Local versus"
	return "%s - %d Lives" % [mode, _starting_lives] if _lives_mode else mode


func _describe_round_outcome(player_one_total: int, player_two_total: int) -> Dictionary:
	if player_one_total == player_two_total:
		return {
			"result": "DEAD EVEN",
			"subtitle": "Neither coop owns the pit. Time for a rematch.",
			"color": Color("fff8e7"),
		}
	var winner := PLAYER_ONE if player_one_total > player_two_total else PLAYER_TWO
	var coop := "RED" if winner == PLAYER_ONE else "BLUE"
	var headline := "%s COOP HOLDS THE PIT" % coop
	if _ended_on_pin:
		headline = "%s COOP PINS %s!" % [coop, "BLUE" if winner == PLAYER_ONE else "RED"]
	return {
		"result": headline,
		"subtitle": "%s wins by %d points after %d seconds." % [
			_player_name(winner), absi(player_one_total - player_two_total),
			roundi(_round_length_seconds()),
		],
		"color": _player_color(winner),
	}


func _round_totals() -> Dictionary:
	return {
		"hits": _state.captures[0] + _state.captures[1],
		"attempts": _state.accepted_pulls[0] + _state.accepted_pulls[1],
	}


func _share_payload() -> Dictionary:
	var data := super()
	# Even a single-seat framework entry is a duel against a CPU coop.
	data["score"] = "%d - %d" % [_scores[PLAYER_ONE], _scores[PLAYER_TWO]]
	data["score_values"] = [_scores[PLAYER_ONE], _scores[PLAYER_TWO]]
	data["score_caption"] = "RED COOP - BLUE COOP"
	data["challenge"] = "WHO RULES THE ROOST NEXT?"
	# Display game-native stats; retain the shell's numeric analytics fields.
	data["accuracy_caption"] = "PULLS"
	data["accuracy"] = str(_state.accepted_pulls[0] + _state.accepted_pulls[1])
	data["hits_caption"] = "NOTCHES TAKEN"
	data["combo_caption"] = "BEST NOTCH RUN"
	data["cta"] = "GRAB THE ROPE"
	data["qr_copy"] = "Study the tug, challenge a rival, and take the pit."
	data["rematch_title"] = "TWO COOPS. ONE ROPE."
	data["rematch_copy"] = "The pit is ready for a rematch. Bring your best pulling rhythm."
	return data


func _player_stats(player_index: int) -> Dictionary:
	return {
		"score": _scores[player_index],
		"hits": _state.captures[player_index],
		"misses": _state.losses[player_index],
		"accuracy": _accuracy_percent(
			_state.captures[player_index], _state.accepted_pulls[player_index]
		),
		"streak": _best_streaks[player_index],
	}


func _update_streaks() -> void:
	for coop in PLAYER_COUNT:
		_streak_label(coop).text = "NOTCH RUN x%d" % _streaks[coop] if _streaks[coop] > 0 \
			else "GROUND HELD"


func _best_combo_summary() -> String:
	return "%d pulls / %d notches / best run x%d" % [
		_state.accepted_pulls[0] + _state.accepted_pulls[1],
		_state.captures[0] + _state.captures[1],
		maxi(_best_streaks[0], _best_streaks[1]),
	]


func _round_highlight_summary() -> String:
	var time := "%d:%02d" % [int(_state.clock) / 60, int(_state.clock) % 60]
	return "%s at %s | %s" % ["Pinned" if _ended_on_pin else "Judged", time, super()]


func _award_round_achievements(player_one_total: int, player_two_total: int) -> void:
	_unlock_round_achievement("pit_first_match")
	if player_one_total == player_two_total:
		return
	var winner := PLAYER_ONE if player_one_total > player_two_total else PLAYER_TWO
	if winner == PLAYER_TWO and _cpu_enabled:
		return
	var opponent := 1 - winner
	if _state.extreme[opponent] <= 0.0:
		_unlock_round_achievement("pit_clean_sweep")
	if _state.extreme[opponent] >= _round_rope_length - 1:
		_unlock_round_achievement("pit_comeback")


func _configure_mode_ui() -> void:
	super()
	var labels := Settings.player_labels_enabled()
	_player_one_caption.text = "P1 / RED COOP" if labels else "RED COOP"
	_player_two_caption.text = "BLUE COOP / %s" % CpuBird.bird_name(
		_round_cpu_difficulty).to_upper() if _cpu_enabled else (
		"P2 / BLUE COOP" if labels else "BLUE COOP")
	_player_one_caption.add_theme_color_override("font_color", player_one_color.lightened(0.25))
	_player_two_caption.add_theme_color_override("font_color", player_two_color.lightened(0.25))
	_round_player_two_caption.text = _player_two_caption.text
	_player_two_stats_title.text = _player_two_caption.text
	var red_result_caption := _round_player_one_score.get_parent().get_node("Caption") as Label
	red_result_caption.text = _player_one_caption.text
	(_player_one_stats_score.get_parent().get_node("Title") as Label).text = _player_one_caption.text
	_callout.hide()
	_hint.text = "RED: %s  |  BLUE: %s  |  Alternate, don't hold  |  Esc pauses" % [
		_key_summary(PLAYER_ONE),
		CpuBird.bird_name(_round_cpu_difficulty) + " (CPU)" if _cpu_enabled
			else _key_summary(PLAYER_TWO),
	]
	for coop in PLAYER_COUNT:
		var card := _player_one_card if coop == PLAYER_ONE else _player_two_card
		var color := _player_color(coop)
		var result_score := _round_player_one_score if coop == 0 else _round_player_two_score
		var stats_score := _player_one_stats_score if coop == 0 else _player_two_stats_score
		result_score.add_theme_color_override("font_color", color)
		stats_score.add_theme_color_override("font_color", color)
		var result_card := result_score.get_parent().get_parent() as PanelContainer
		for panel: PanelContainer in [card, result_card]:
			var style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
			style.bg_color = Color(color.darkened(0.84), 0.96)
			style.border_color = Color(color, 0.65)
			style.shadow_color = Color(color.darkened(0.65), 0.25)
			panel.add_theme_stylebox_override("panel", style)
	if _tug_meter != null:
		var cpu_name := CpuBird.bird_name(_round_cpu_difficulty) if _cpu_enabled else ""
		if _cpu_enabled and _lives_mode:
			cpu_name += " / %d LIVES" % int(_lives[PLAYER_TWO])
		_tug_meter.configure([player_one_color, player_two_color],
			PackedStringArray([_player_one_caption.text,
				"P2 / BLUE COOP" if labels else "BLUE COOP"]), cpu_name,
			"FIRST TO %d PINS" % _starting_lives if _lives_mode else "GROUND HELD WINS")
		_refresh_key_hints()


func _player_name(player_index: int) -> String:
	if player_index == PLAYER_ONE:
		return "Red coop"
	return "%s (Blue coop)" % CpuBird.bird_name(_round_cpu_difficulty) if _cpu_enabled \
		else "Blue coop"


func _key_summary(coop: int) -> String:
	return " ".join(_key_labels(coop))


func _key_labels(coop: int) -> PackedStringArray:
	var keys := PackedStringArray()
	for action in ChickenPitOptions.pull_actions(coop):
		keys.append(Settings.control_key_label(action))
	return keys


func _refresh_key_hints() -> void:
	for coop in PLAYER_COUNT:
		_tug_meter.set_keys(coop, _key_labels(coop), ChickenPitOptions.pull_actions(coop))


func _set_reduced_motion_enabled(value: bool) -> void:
	super(value)
	if _view != null:
		_view.set_reduced_motion(value)


func _set_intense_effects_enabled(value: bool) -> void:
	super(value)
	if _view != null:
		_view.set_intense_effects(value)


func _spawn_round_confetti(color: Color) -> void:
	if _intense_effects_enabled:
		super(color)


func _resize_pit() -> void:
	var bounds := _playfield_bounds()
	_pit_container.position = bounds.position
	_pit_container.size = bounds.size
	_tug_meter.position = bounds.position + Vector2(16.0, 32.0)
	_tug_meter.size = Vector2(maxf(bounds.size.x - 32.0, 0.0), 174.0)
	if _view != null and _state != null:
		_view.camera.update_camera(0.0, _state.rope,
			_state.strength[0] - _state.strength[1])


func _update_pit_audio() -> void:
	_pit_music.set_pressure(_state.rope, _state.L)
	var tension := clampf((_state.strength[0] + _state.strength[1]) / 80.0, 0.0, 1.0)
	_creak.volume_db = lerpf(-52.0, -24.0, tension)
	_crowd.volume_db = lerpf(-36.0, -19.0, absf(_state.rope) / _state.L)
	if tension > 0.6 and _state.clock - _last_creak_caption > 6.0:
		AudioManager.request_caption("rope creaking")
		_last_creak_caption = _state.clock
	var close := absf(_state.rope) >= _state.L - 2.0
	if close and not _near_pin:
		AudioManager.request_caption("crowd roars, music intensifies - close to a pin")
	_near_pin = close


func _make_loop(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = AudioManager.BUS_SFX
	player.stream = PitMusic.looping_stream(stream)
	add_child(player)
	return player


func _play_pit_sound(stream: AudioStream, volume: float, pitch := 1.0) -> void:
	if DisplayServer.get_name() != "headless":
		AudioManager.play_sfx(stream, volume, pitch)


## Kept as the options seam; the model scales gain, decay and travel together.
func _pull_strength() -> float:
	return _round_pull_power * _round_gameplay_speed


func _rope_length() -> int:
	return _round_rope_length


func _cpu_difficulty() -> int:
	return _round_cpu_difficulty
