class_name ChickenPitOptions
extends RefCounted

## Setting keys, ranges and bindings owned by Chicken Pit.
##
## The framework stores, clamps and renders these; only this file and the
## game's own scenes decide what they mean. Everything here reaches the player
## through the Settings screen — the Game tab for the numbers, the Controls tab
## for the keys.
##
## Constants only: this class is loaded by headless test scripts before
## autoloads exist, so it must not reference [Settings] or any other singleton.

## Matches the folder name and `games/chicken_pit/game.gd`.
const GAME_ID := "chicken_pit"

const ROUND_LENGTH_KEY := "game/pit_round_length"
const PULL_POWER_KEY := "game/pit_pull_power"
const STRENGTH_DECAY_KEY := "game/pit_strength_decay"
const ROPE_LENGTH_KEY := "game/pit_rope_length"
const CPU_DIFFICULTY_KEY := "game/pit_cpu_difficulty"

## Three keys per coop rather than one, because a tug-of-war is won by
## alternating fingers: a single held key would reward an autofire pad instead
## of the player. The defaults are two three-key clusters, far enough apart that
## two people can share one keyboard.
const PULL_ONE_A_KEY := "controls/pit_pull_one_a"
const PULL_ONE_B_KEY := "controls/pit_pull_one_b"
const PULL_ONE_C_KEY := "controls/pit_pull_one_c"
const PULL_TWO_A_KEY := "controls/pit_pull_two_a"
const PULL_TWO_B_KEY := "controls/pit_pull_two_b"
const PULL_TWO_C_KEY := "controls/pit_pull_two_c"

const PULL_ONE_A_ACTION := &"pit_pull_one_a"
const PULL_ONE_B_ACTION := &"pit_pull_one_b"
const PULL_ONE_C_ACTION := &"pit_pull_one_c"
const PULL_TWO_A_ACTION := &"pit_pull_two_a"
const PULL_TWO_B_ACTION := &"pit_pull_two_b"
const PULL_TWO_C_ACTION := &"pit_pull_two_c"

const MIN_ROUND_LENGTH := 15.0
const MAX_ROUND_LENGTH := 90.0
const MIN_PULL_POWER := 0.5
const MAX_PULL_POWER := 2.0
const MIN_STRENGTH_DECAY := 0.5
const MAX_STRENGTH_DECAY := 2.0
const MIN_ROPE_LENGTH := 6
const MAX_ROPE_LENGTH := 18

const DEFAULT_ROUND_LENGTH := 45.0
const DEFAULT_PULL_POWER := 1.0
const DEFAULT_STRENGTH_DECAY := 1.0
## Ten notches to the goal line: long enough that one lucky burst cannot end a
## match, short enough to finish.
const DEFAULT_ROPE_LENGTH := 10

## Difficulty is a named opponent rather than a number, because the CPU changes
## how it plays and not just how hard it pulls.
const CPU_CHICK := 0
const CPU_HEN := 1
const CPU_ROOSTER := 2
const DEFAULT_CPU_DIFFICULTY := CPU_HEN

const ROUND_HEADING := "Chicken Pit · next round"
const COOP_ONE_HEADING := "Red coop"
const COOP_TWO_HEADING := "Blue coop"

## Declared on the manifest so [Settings] can register the keys at boot and the
## Settings → Game tab can build a row for each one.
const TUNABLES: Array[Dictionary] = [
	{
		"key": ROUND_LENGTH_KEY,
		"default": DEFAULT_ROUND_LENGTH,
		"min": MIN_ROUND_LENGTH,
		"max": MAX_ROUND_LENGTH,
		"step": 1.0,
		"title": "Round length",
		"description": (
			"Sets how long a Chicken Pit round runs before the rope is judged "
			+ "on the ground each coop held."
		),
		"format": GameManifest.FORMAT_SECONDS,
		"heading": ROUND_HEADING,
	},
	{
		"key": ROPE_LENGTH_KEY,
		"default": DEFAULT_ROPE_LENGTH,
		"min": MIN_ROPE_LENGTH,
		"max": MAX_ROPE_LENGTH,
		"step": 1.0,
		"title": "Rope length",
		"description": "Sets how far the rope has to travel to cross a goal line.",
		"format": GameManifest.FORMAT_COUNT,
		"heading": ROUND_HEADING,
	},
	{
		"key": PULL_POWER_KEY,
		"default": DEFAULT_PULL_POWER,
		"min": MIN_PULL_POWER,
		"max": MAX_PULL_POWER,
		"step": 0.05,
		"title": "Pull power",
		"description": "Sets how much strength one pull adds to a coop.",
		"format": GameManifest.FORMAT_PERCENT,
		"heading": ROUND_HEADING,
	},
	{
		"key": STRENGTH_DECAY_KEY,
		"default": DEFAULT_STRENGTH_DECAY,
		"min": MIN_STRENGTH_DECAY,
		"max": MAX_STRENGTH_DECAY,
		"step": 0.05,
		"title": "Strength decay",
		"description": (
			"Sets how quickly a coop's strength drains between pulls. Lower is "
			+ "kinder to slower hands."
		),
		"format": GameManifest.FORMAT_PERCENT,
		"heading": ROUND_HEADING,
	},
	{
		"key": CPU_DIFFICULTY_KEY,
		"type": GameManifest.OPTION_CHOICE,
		"default": DEFAULT_CPU_DIFFICULTY,
		"title": "CPU opponent",
		"description": "Chooses which bird pulls the other end in single player.",
		"heading": ROUND_HEADING,
		"choices": [
			{"value": CPU_CHICK, "title": "Chick — takes it easy"},
			{"value": CPU_HEN, "title": "Hen — pulls its weight"},
			{"value": CPU_ROOSTER, "title": "Rooster — never lets go"},
		],
	},
]

## Rebindable pull keys, rendered on the Settings → Controls tab.
##
## Marked as `movement` keys: in a tug-of-war these are the only thing that
## moves anything, so `Settings.movement_summary_for_game` describes a rebound
## coop in one line instead of the menus assuming a cluster nobody uses.
const CONTROL_BINDINGS: Array[Dictionary] = [
	{
		"key": PULL_ONE_A_KEY,
		"action": PULL_ONE_A_ACTION,
		"default": KEY_Q,
		"title": "Pull 1",
		"player": 0,
		"movement": true,
		"heading": COOP_ONE_HEADING,
	},
	{
		"key": PULL_ONE_B_KEY,
		"action": PULL_ONE_B_ACTION,
		"default": KEY_W,
		"title": "Pull 2",
		"player": 0,
		"movement": true,
		"heading": COOP_ONE_HEADING,
	},
	{
		"key": PULL_ONE_C_KEY,
		"action": PULL_ONE_C_ACTION,
		"default": KEY_E,
		"title": "Pull 3",
		"player": 0,
		"movement": true,
		"heading": COOP_ONE_HEADING,
	},
	{
		"key": PULL_TWO_A_KEY,
		"action": PULL_TWO_A_ACTION,
		"default": KEY_I,
		"title": "Pull 1",
		"player": 1,
		"movement": true,
		"heading": COOP_TWO_HEADING,
	},
	{
		"key": PULL_TWO_B_KEY,
		"action": PULL_TWO_B_ACTION,
		"default": KEY_O,
		"title": "Pull 2",
		"player": 1,
		"movement": true,
		"heading": COOP_TWO_HEADING,
	},
	{
		"key": PULL_TWO_C_KEY,
		"action": PULL_TWO_C_ACTION,
		"default": KEY_P,
		"title": "Pull 3",
		"player": 1,
		"movement": true,
		"heading": COOP_TWO_HEADING,
	},
]


## The pull actions belonging to one coop, so the gameplay scene never spells
## out which keys a player was given.
static func pull_actions(player_index: int) -> Array[StringName]:
	if player_index == 0:
		return [PULL_ONE_A_ACTION, PULL_ONE_B_ACTION, PULL_ONE_C_ACTION]
	return [PULL_TWO_A_ACTION, PULL_TWO_B_ACTION, PULL_TWO_C_ACTION]
