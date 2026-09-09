extends Control

## Chicken Pit's opening: the story the game is named after, told in cards that
## turn over in time with the recording that tells it.
##
## This is a port of an earlier prototype's `IntroScene`: the same recording and
## the same words. That version crawled them past in one block; here they are
## cards like `scenes/boot/intro.tscn` and Dead Metal Jam's opening use, so the
## three openings in this project read as the same product.
##
## Only a build that ships this game alone plays it: `studio_logo.gd` asks
## [method GameCatalog.intro_scene_path], which returns
## [member GameManifest.intro_scene_path] when the catalog holds one game. The
## contract is the framework intro's — stay skippable, and eventually call
## `Router.goto(next_scene)`.
##
## Accessibility: the cards are the transcript of the narration, so the story is
## never sound-only and it still lands with the music bus at zero.

## Identity comes from the manifest so the title on screen cannot disagree with
## the title in the menu.
const MANIFEST := preload("res://games/chicken_pit/game.gd")

@export_file("*.tscn") var next_scene := "res://scenes/menus/main_menu.tscn"

## The narration, imported with `loop = false` — it is told once.
##
## It plays on the music bus, which is where `scenes/boot/intro.gd` and Dead
## Metal Jam's opening keep theirs, so it inherits the crossfade in and the fade
## out when the menu takes over. Speech on a music bus would normally be a
## mistake, but every word is already on screen: turning music down loses the
## voice, not the story.
@export var narration: AudioStream = preload(
	"res://games/chicken_pit/assets/intro-narration.mp3"
)

## The narration, transcribed, one entry per card.
@export var cards: Array[String] = [
	"My first wife was a ER nurse and in Athens, Georgia.",
	"And there's a lot of chicken and poultry stuff around there.\n"
	+ "And they had a lady come in one night.",
	"She didn't speak English, but she had, they had a similar chicken pit "
	+ "at this chicken processing place.",
	"And she somehow fell in the pit and was there for like hours "
	+ "before somebody found her.",
	"And of course, they found her and got her out and like hauled her into the ER.",
	"And of course, as you can imagine, the smell was just overwhelming.",
	"But she had some sort of like psychological breakdown of over that apparently.",
	"Like it was like life changing to be stuck in the chicken pit with all that.",
	"So like, I can't imagine she's in there for like hours.",
	"Like when you're on a smoke break or something, I don't know how she fell in, "
	+ "nobody could figure that out.",
	"But yeah, I went in the chicken pit, which is about the worst thing "
	+ "I could think of.",
]

## When each card is due, in seconds into [member narration].
##
## Not a guess: the recording's own pauses were measured, and every time below
## is the middle of one, so a card never turns over mid-word. They are absolute
## offsets into *this* recording — replacing the clip means measuring it again,
## which is why `chicken_pit_intro_test.gd` fails if the cues stop fitting
## inside the stream.
@export var cue_times: Array[float] = [
	0.23, 4.38, 8.75, 12.62, 16.21, 20.00, 24.87, 29.19, 34.84, 37.58, 41.70,
]

## How long the opening holds after the last word, so the closing card is read
## rather than cut off by the fade to the menu.
const TAIL_SECONDS := 2.2

## Used only if the recording is missing or unreadable; an opening with no clock
## would never hand over.
const FALLBACK_SECONDS := 47.6

## Guards against a stream that decodes to nothing being taken at its word.
const MIN_NARRATION_SECONDS := 6.0

## Shortest a card may stay up and still be readable. Only reached when the cues
## and the cards disagree and the opening has to space them itself.
const MIN_CARD_SECONDS := 2.6

const FADE_OUT := 0.22
const FADE_IN := 0.36

## Cards are anchored, so they are animated with scale around their own centre —
## moving `position` would bake in offsets and break on the next resize.
const CARD_POP := 0.97

@onready var _frame: MarginContainer = %Frame
@onready var _title: Label = %Title
@onready var _card: Label = %Card
@onready var _hint: Label = %Hint
@onready var _progress: ColorRect = %ProgressFill

var _cues: Array[float] = []
var _total_seconds := FALLBACK_SECONDS
var _elapsed := 0.0
var _next_cue := 0
var _card_index := -1
var _finished := false
var _reduced_motion := false

var _card_tween: Tween
var _title_tween: Tween
var _hint_tween: Tween


func _ready() -> void:
	_reduced_motion = Settings.reduced_motion_enabled()
	_total_seconds = _narration_seconds() + TAIL_SECONDS
	_cues = _build_cues()

	var manifest := GameCatalog.get_manifest(MANIFEST.GAME_ID)
	_title.text = (manifest.title if manifest else "Chicken Pit").to_upper()
	_hint.text = (
		"Tap to skip"
		if DisplayServer.is_touchscreen_available()
		else "Press any key to skip"
	)

	_title.modulate.a = 0.0
	_card.modulate.a = 0.0
	_card.text = ""
	_progress.anchor_right = 0.0

	get_viewport().size_changed.connect(_refresh_layout)
	_card.resized.connect(_center_pivot)
	_refresh_layout()
	_center_pivot()

	_pulse_hint()
	_start_narration()
	_show_title()


## The runtime comes from the recording rather than from a number typed next to
## it, so the opening cannot drift out of step with the clip it is reading.
func _narration_seconds() -> float:
	if narration == null:
		return FALLBACK_SECONDS - TAIL_SECONDS
	var length := narration.get_length()
	if length <= MIN_NARRATION_SECONDS:
		return FALLBACK_SECONDS - TAIL_SECONDS
	return length


## When each card is due. The measured cues are used as-is when there is one per
## card; any other count is a mistake in the data, and spacing the cards evenly
## is a better answer than showing the wrong line — or none at all.
func _build_cues() -> Array[float]:
	if cards.is_empty():
		return []
	if cue_times.size() == cards.size():
		return cue_times.duplicate()

	push_warning(
		"Chicken Pit intro: %d cue times for %d cards — spacing them evenly."
		% [cue_times.size(), cards.size()]
	)
	var spaced: Array[float] = []
	var share := maxf(_total_seconds / float(cards.size()), MIN_CARD_SECONDS)
	for index in cards.size():
		spaced.append(float(index) * share)
	return spaced


func _start_narration() -> void:
	if narration == null:
		return
	AudioManager.play_music(narration, 0.9)


## The title arrives on its own, ahead of the first card, so the opening says
## whose story this is before it tells it.
func _show_title() -> void:
	if _title_tween and _title_tween.is_valid():
		_title_tween.kill()
	_title_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _reduced_motion:
		_title.scale = Vector2.ONE
		_title_tween.tween_property(_title, "modulate:a", 1.0, 0.5)
		return
	_title.scale = Vector2(CARD_POP, CARD_POP)
	_title_tween.tween_property(_title, "modulate:a", 1.0, 0.5)
	_title_tween.parallel().tween_property(_title, "scale", Vector2.ONE, 0.9)


func _process(delta: float) -> void:
	_elapsed += delta
	_run_due_cues()
	_progress.anchor_right = clampf(_elapsed / _total_seconds, 0.0, 1.0)
	if _elapsed >= _total_seconds:
		_finish()


func _run_due_cues() -> void:
	while _next_cue < _cues.size() and _elapsed >= _cues[_next_cue]:
		var index := _next_cue
		_next_cue += 1
		_show_card(index)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skip") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish()


## Each card replaces the one before it. Opacity carries the change, so the
## transition is the one reduced motion would have asked for anyway; only the
## small scale-in is dropped.
func _show_card(index: int) -> void:
	if index < 0 or index >= cards.size():
		return
	if _card_tween and _card_tween.is_valid():
		_card_tween.kill()

	var first := _card_index < 0
	_card_index = index
	var text := cards[index]

	_card_tween = create_tween().set_trans(Tween.TRANS_SINE)
	if not first:
		_card_tween.tween_property(_card, "modulate:a", 0.0, FADE_OUT)
	_card_tween.tween_callback(func() -> void:
		_card.text = text
		if not _reduced_motion:
			_card.scale = Vector2(CARD_POP, CARD_POP)
	)
	_card_tween.tween_property(_card, "modulate:a", 1.0, FADE_IN)
	if not _reduced_motion:
		_card_tween.parallel().tween_property(
			_card, "scale", Vector2.ONE, FADE_IN + 0.4
		).set_ease(Tween.EASE_OUT)


func _refresh_layout() -> void:
	var size := get_viewport_rect().size
	var portrait := Responsive.is_portrait(size)
	Responsive.apply_margins(
		_frame, size, Vector2(0.09, 0.07), Vector2(32, 24), Vector2(320, 140)
	)
	_title.add_theme_font_size_override("font_size", 34 if portrait else 46)
	# The cards carry whole sentences of speech rather than a slogan, so they
	# run smaller than the framework intro's.
	_card.add_theme_font_size_override("font_size", 32 if portrait else 42)


## The card and title are anchored to fill their areas, so they are animated
## with scale around their own centres.
func _center_pivot() -> void:
	_card.pivot_offset = _card.size * 0.5
	_title.pivot_offset = _title.size * 0.5


func _pulse_hint() -> void:
	if _reduced_motion:
		_hint.modulate.a = 1.0
		return
	_hint_tween = create_tween().set_loops()
	_hint_tween.tween_property(_hint, "modulate:a", 0.35, 1.1).set_trans(Tween.TRANS_SINE)
	_hint_tween.tween_property(_hint, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)


func _on_skip_pressed() -> void:
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	for tween in [_card_tween, _title_tween, _hint_tween]:
		if tween and tween.is_valid():
			tween.kill()
	# The narration is on the music bus, and the menu's own music is optional,
	# so the opening has to clear its own bed or the story would run on
	# underneath the main menu.
	AudioManager.stop_music(0.5)
	Router.goto(next_scene)
