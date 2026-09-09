extends SceneTree

## Headless tests for Chicken Pit's opening.
##
## The opening is a port of an earlier prototype's `IntroScene`, retold as the
## cards the rest of the project's openings use. So the things asserted here are
## the things that carry that meaning — the transcript is complete, the cards
## turn over in time with the recording rather than on a guess, and the story is
## never sound-only.
##
## The scene is loaded at runtime rather than preloaded: its script uses
## autoload instances, which do not exist while a `--script` run is compiling
## this file.
##
## The timeline is stepped by hand at a fixed timestep instead of by the engine,
## so every assertion below is deterministic rather than frame-rate dependent.
##
## Run:
##   godot --headless --path godot-base \
##     --script res://games/chicken_pit/tests/chicken_pit_intro_test.gd -- --game=all

const INTRO_SCENE := "res://games/chicken_pit/intro.tscn"
const NARRATION := "res://games/chicken_pit/assets/intro-narration.mp3"
const GAME_ID := "chicken_pit"

## Fixed timestep, matching a 60 Hz frame.
const STEP := 1.0 / 60.0

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_manifest_declares_the_intro()
	_test_narration_is_told_once()
	await _test_transcript_is_complete()
	await _test_cues_fit_the_recording()
	await _test_cards_turn_over_on_their_cues()
	await _test_mismatched_cues_still_show_every_card()
	await _test_narration_starts_with_the_scene()
	await _test_reduced_motion_keeps_the_words()
	await _test_it_can_be_left_early()
	_finish()


# --------------------------------------------------------------------------
# Declaration
# --------------------------------------------------------------------------


## The opening must be reachable the way the framework reaches it: as a path on
## the manifest, not as a name the boot sequence knows.
func _test_manifest_declares_the_intro() -> void:
	var manifest := GameCatalog.get_manifest(GAME_ID)
	if manifest == null:
		_failures.append("Chicken Pit must be in the catalog.")
		return
	_expect(
		manifest.intro_scene_path == INTRO_SCENE,
		"Chicken Pit must declare its own intro on the manifest."
	)
	_expect(
		ResourceLoader.exists(manifest.intro_scene_path),
		"The declared intro scene must exist."
	)


## The web player looped the clip under a longer animation, so the narration
## restarted over its own last lines. Looping is set by the `.import`, which
## nothing else here reads, and a loop left on would run under the menu.
func _test_narration_is_told_once() -> void:
	var stream := load(NARRATION) as AudioStream
	if stream == null:
		_failures.append("The narration must import as an audio stream.")
		return
	_expect(not bool(stream.get("loop")), "The narration must not loop — it is told once.")
	_expect(
		stream.get_length() > 30.0,
		"The narration must be the full story, not a stub."
	)


# --------------------------------------------------------------------------
# The words
# --------------------------------------------------------------------------


## Every card has to reach the screen, and the closing card has to be the one
## left on it.
func _test_transcript_is_complete() -> void:
	var intro := await _open_intro()
	if intro == null:
		return
	var cards: Array = intro.get("cards")
	_expect(cards.size() >= 6, "The opening must carry the whole story.")

	var blank := 0
	for card: String in cards:
		if card.strip_edges().is_empty():
			blank += 1
	_expect(blank == 0, "No card may be blank.")

	var title: Label = intro.get_node_or_null("%Title")
	var manifest := GameCatalog.get_manifest(GAME_ID)
	_expect(
		title != null and manifest != null and title.text == manifest.title.to_upper(),
		"The title on screen must come from the manifest."
	)

	intro.queue_free()
	await process_frame


# --------------------------------------------------------------------------
# Timing
# --------------------------------------------------------------------------


## The cues are absolute offsets into one particular recording, measured from
## its pauses. Replacing the clip without re-measuring them is the one way this
## opening can silently fall out of step, so it is the thing checked hardest.
func _test_cues_fit_the_recording() -> void:
	var intro := await _open_intro()
	if intro == null:
		return
	var cards: Array = intro.get("cards")
	var cues: Array = intro.get("cue_times")
	var narration: AudioStream = intro.get("narration")

	_expect(narration != null, "The opening must carry its narration.")
	_expect(
		cues.size() == cards.size(),
		"There must be one cue per card: %d cues for %d cards." % [cues.size(), cards.size()]
	)

	var ordered := true
	var readable := true
	var minimum := float(_constant(intro, "MIN_CARD_SECONDS", 2.6))
	for i in range(1, cues.size()):
		if float(cues[i]) <= float(cues[i - 1]):
			ordered = false
		if float(cues[i]) - float(cues[i - 1]) < minimum:
			readable = false
	_expect(ordered, "The cues must run in order — the story is told once, forwards.")
	_expect(readable, "Every card must stay up long enough to be read.")

	if narration != null and not cues.is_empty():
		var length := narration.get_length()
		_expect(
			float(cues[0]) >= 0.0 and float(cues[cues.size() - 1]) < length,
			"Every cue must land inside the recording it was measured from."
		)
		_expect(
			length - float(cues[cues.size() - 1]) >= minimum,
			"The closing card must be spoken over, not cut off by the end of the clip."
		)
		var tail := float(_constant(intro, "TAIL_SECONDS", 2.2))
		_expect(
			absf(float(intro.get("_total_seconds")) - (length + tail)) < 0.01,
			"The opening must run for the recording plus its tail."
		)
		_expect(tail > 0.0, "The opening must hold after the last word.")

	intro.queue_free()
	await process_frame


## The cards are the transcript, so showing the wrong one is worse than showing
## none: it would caption the narration incorrectly.
func _test_cards_turn_over_on_their_cues() -> void:
	var intro := await _open_intro()
	if intro == null:
		return
	var cards: Array = intro.get("cards")
	var cues: Array = intro.get("_cues")

	_expect(int(intro.get("_card_index")) == -1, "The opening must start on no card.")

	var wrong := 0
	for i in cards.size():
		# A little past the cue, so the boundary itself is not what is measured.
		_advance_to(intro, float(cues[i]) + 0.05)
		if int(intro.get("_card_index")) != i:
			wrong += 1
	_expect(wrong == 0, "Each card must be showing by the time its cue has passed.")

	await _settle()
	var card: Label = intro.get_node_or_null("%Card")
	_expect(
		card != null and card.text == String(cards[cards.size() - 1]),
		"The closing line must be the one left on screen."
	)

	var fill: ColorRect = intro.get_node_or_null("%ProgressFill")
	_expect(
		fill != null and fill.anchor_right > 0.0 and fill.anchor_right < 1.0,
		"The progress bar must track how much of the story is left."
	)
	_expect(
		not bool(intro.get("_finished")),
		"The opening must still be running after the last card."
	)

	intro.queue_free()
	await process_frame


## Cards and cues are two lists that have to agree. If an edit ever leaves them
## out of step the opening must still tell the whole story, just evenly spaced —
## dropping lines of a transcript is the one outcome that is not acceptable.
func _test_mismatched_cues_still_show_every_card() -> void:
	var packed := load(INTRO_SCENE) as PackedScene
	if packed == null:
		_failures.append("The opening must load.")
		return
	var intro := packed.instantiate()
	intro.set("cue_times", [1.0, 2.0] as Array[float])
	get_root().add_child(intro)
	await process_frame
	intro.set_process(false)

	var cards: Array = intro.get("cards")
	var cues: Array = intro.get("_cues")
	_expect(
		cues.size() == cards.size(),
		"Mismatched cues must be replaced by one cue per card."
	)
	var minimum := float(_constant(intro, "MIN_CARD_SECONDS", 2.6))
	var readable := true
	for i in range(1, cues.size()):
		if float(cues[i]) - float(cues[i - 1]) < minimum - 0.001:
			readable = false
	_expect(readable, "The evenly spaced fallback must still be readable.")

	intro.queue_free()
	await process_frame


## The recording is the opening; `_start_narration()` is one line and is the
## only thing standing between the story and silence.
func _test_narration_starts_with_the_scene() -> void:
	var audio := get_root().get_node_or_null("AudioManager")
	if audio == null:
		_failures.append("AudioManager must be available to the intro test.")
		return

	var intro := await _open_intro()
	if intro == null:
		return
	await _settle()

	var playing: Array[AudioStream] = []
	for child in audio.get_children():
		var player := child as AudioStreamPlayer
		if player != null and player.playing and player.stream != null:
			playing.append(player.stream)
	# Membership, not "something is playing": the manager's SFX pool lives in
	# the same list and would otherwise answer for the narration.
	_expect(
		playing.has(intro.get("narration")),
		"The opening must start the narration with the scene."
	)

	audio.call("stop_music", 0.05)
	intro.queue_free()
	await process_frame


# --------------------------------------------------------------------------
# Accessibility and leaving early
# --------------------------------------------------------------------------


## The cards are the transcript, so reduced motion may quiet the presentation
## but must never cost a word or a cue.
func _test_reduced_motion_keeps_the_words() -> void:
	var settings := get_root().get_node_or_null("Settings")
	if settings == null:
		_failures.append("Settings must be available to the intro test.")
		return
	var key := _string_constant(settings, "REDUCED_MOTION_KEY", "accessibility/reduced_motion")
	var original: bool = settings.call("get_value", key, false)
	settings.call("set_value", key, true)

	var intro := await _open_intro()
	if intro != null:
		_expect(
			bool(intro.get("_reduced_motion")),
			"The opening must read the reduced-motion setting."
		)
		var cards: Array = intro.get("cards")
		var cues: Array = intro.get("_cues")
		var card: Label = intro.get_node_or_null("%Card")
		var title: Label = intro.get_node_or_null("%Title")

		_advance_to(intro, float(cues[2]) + 0.05)
		_expect(
			int(intro.get("_card_index")) == 2,
			"Reduced motion must keep every card and every cue."
		)
		await _settle()
		_expect(
			card != null and card.text == String(cards[2]),
			"And the card on screen must still be the one the narration is on."
		)
		_expect(
			card != null and card.scale.is_equal_approx(Vector2.ONE),
			"Reduced motion must drop the card's scale-in and fade only."
		)
		_expect(
			title != null and title.scale.is_equal_approx(Vector2.ONE),
			"And the title must arrive without one too."
		)

		intro.queue_free()
		await process_frame

	settings.call("set_value", key, original)


## The framework intro's contract: skippable, and it hands over to a scene that
## exists. Checked here as well as in `single_game_test.gd` because this is the
## opening a player is most likely to want out of on the second run.
func _test_it_can_be_left_early() -> void:
	var intro := await _open_intro()
	if intro == null:
		return
	_expect(intro.has_method("_on_skip_pressed"), "The opening must be skippable.")
	var button: Button = intro.get_node_or_null("%SkipButton")
	_expect(
		button != null and button.pressed.is_connected(Callable(intro, "_on_skip_pressed")),
		"The skip button must be wired to the skip handler."
	)
	_expect(
		ResourceLoader.exists(str(intro.get("next_scene"))),
		"The opening must hand over to a scene that exists."
	)
	_expect(
		not bool(intro.get("_finished")),
		"The opening must still be running when it opens."
	)
	intro.queue_free()
	await process_frame


# --------------------------------------------------------------------------
# Harness
# --------------------------------------------------------------------------


## Opens the opening and takes the timeline off the engine's hands, so the tests
## above step it themselves.
func _open_intro() -> Node:
	var packed := load(INTRO_SCENE) as PackedScene
	if packed == null:
		_failures.append("The opening must load.")
		return null
	var intro := packed.instantiate()
	get_root().add_child(intro)
	await process_frame
	intro.set_process(false)
	return intro


## Steps the timeline forward to [param seconds], stopping short of the closing
## cue, which would hand the scene to `Router`.
func _advance_to(intro: Node, seconds: float) -> void:
	var limit := float(intro.get("_total_seconds")) - STEP
	var target := minf(seconds, limit)
	var guard := 0
	while float(intro.get("_elapsed")) < target and guard < 100000:
		if bool(intro.get("_finished")):
			return
		intro.call("_process", STEP)
		guard += 1


## Lets the tweens — which run on real time, not on the stepped timeline —
## catch up before their results are read.
func _settle() -> void:
	var deadline := Time.get_ticks_msec() + 900
	while Time.get_ticks_msec() < deadline:
		await process_frame


## Reads a constant off a script without naming it, which a headless run
## compiles before autoloads exist.
func _constant(node: Node, name: String, fallback: float) -> float:
	var map: Dictionary = node.get_script().get_script_constant_map()
	return float(map.get(name, fallback))


func _string_constant(node: Node, name: String, fallback: String) -> String:
	var map: Dictionary = node.get_script().get_script_constant_map()
	return str(map.get(name, fallback))


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Chicken Pit intro tests passed (%d checks)." % _checks)
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	quit(1)
