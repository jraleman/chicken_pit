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


# --------------------------------------------------------------------------
# The hat store
# --------------------------------------------------------------------------

## What the pit pays out for a match, and what that money is called.
##
## Chicken Pit scores in the thousands — a hundred points a notch, twenty a
## unit-second of held ground and two thousand for a pin — so the rate converts
## a good match into a few dozen feathers rather than a fortune. The ceiling
## keeps a long rope on a slow decay from buying out the whole shelf at once.
const STORE_CURRENCY := {
	"name": "Feather",
	"plural": "Feathers",
	"points_per_score": 0.02,
	"round_bonus": 5,
	"win_bonus": 10,
	"max_per_round": 150,
}

const HAT_KIND := "hat"
const HAT_SLOT_ONE := "pit_hat_red"
const HAT_SLOT_TWO := "pit_hat_blue"

const HAT_BARE := "pit_hat_bare"
const HAT_STRAW := "pit_hat_straw"
const HAT_PARTY := "pit_hat_party"
const HAT_COWBOY := "pit_hat_cowboy"
const HAT_VIKING := "pit_hat_viking"
const HAT_TOP := "pit_hat_top"
const HAT_CROWN := "pit_hat_crown"

const HAT_HEADING := "Hats"

## One slot per coop rather than one hat for the pit, because a tug-of-war has
## two ends and both of them are somebody's birds. A hat is bought once and can
## then be worn on either side.
const STORE_SLOTS: Array[Dictionary] = [
	{
		"id": HAT_SLOT_ONE,
		"kind": HAT_KIND,
		"title": "Red coop",
		"description": "What the red coop's birds wear into the pit.",
	},
	{
		"id": HAT_SLOT_TWO,
		"kind": HAT_KIND,
		"title": "Blue coop",
		"description": "What the blue coop's birds wear into the pit.",
	},
]

## Hats sit above the comb and the bonnet rather than replacing them: those two
## silhouettes are how the coops are told apart without colour, so no purchase
## is allowed to remove them. Each hat keeps a band in the wearer's team colour
## for the same reason.
const STORE_ITEMS: Array[Dictionary] = [
	{
		"id": HAT_BARE,
		"kind": HAT_KIND,
		"price": 0,
		"default": true,
		"title": "Comb & Bonnet",
		"description": "How a bird is born. Tall comb, tied bonnet, no airs.",
		"badge": "BARE",
		"color": Color("fff8e7"),
		"heading": HAT_HEADING,
	},
	{
		"id": HAT_STRAW,
		"kind": HAT_KIND,
		"price": 40,
		"title": "Straw Boater",
		"description": "Sunday-best fairground straw with a ribbon in coop colours.",
		"badge": "STRAW",
		"color": Color("e8c46a"),
		"heading": HAT_HEADING,
	},
	{
		"id": HAT_PARTY,
		"kind": HAT_KIND,
		"price": 70,
		"title": "Party Cone",
		"description": "A pointed hat with a pom on top. Celebrate before you win.",
		"badge": "PARTY",
		"color": Color("ff6fae"),
		"heading": HAT_HEADING,
	},
	{
		"id": HAT_COWBOY,
		"kind": HAT_KIND,
		"price": 110,
		"title": "Ten-Gallon Hat",
		"description": "Wide brim, creased crown, and absolutely no cattle.",
		"badge": "RANCH",
		"color": Color("8a5a33"),
		"heading": HAT_HEADING,
	},
	{
		"id": HAT_VIKING,
		"kind": HAT_KIND,
		"price": 170,
		"title": "Horned Helm",
		"description": "Historically inaccurate. Tactically magnificent.",
		"badge": "HELM",
		"color": Color("9aa6b5"),
		"heading": HAT_HEADING,
	},
	{
		"id": HAT_TOP,
		"kind": HAT_KIND,
		"price": 240,
		"title": "Top Hat",
		"description": "For the coop that pulls a rope in formal dress.",
		"badge": "TOP",
		"color": Color("3a3d4c"),
		"heading": HAT_HEADING,
	},
	{
		"id": HAT_CROWN,
		"kind": HAT_KIND,
		"price": 360,
		"title": "Roost Crown",
		"description": "Gold points and coop-coloured jewels. Ruler of the pit.",
		"badge": "CROWN",
		"color": Color("ffd45c"),
		"requires_achievement": "pit_clean_sweep",
		"heading": HAT_HEADING,
	},
]


## The store slot a coop wears, so the gameplay scene never spells out the ids.
static func hat_slot(player_index: int) -> String:
	return HAT_SLOT_ONE if player_index == 0 else HAT_SLOT_TWO


# --------------------------------------------------------------------------
# The gallery
# --------------------------------------------------------------------------

## The coops' colours, mirroring the `player_one_color` / `player_two_color`
## exports on `gameplay.tscn`.
##
## The shell owns those during a round, but the gallery draws birds when no
## round exists and still has to get the sides right. `gallery_test.gd` asserts
## these two stay in step with the scene.
const COOP_COLORS: Array[Color] = [Color("ff6b57"), Color("4da3ff")]

const EXHIBIT_BIRD_RED := "pit_bird_red"
const EXHIBIT_BIRD_BLUE := "pit_bird_blue"
const EXHIBIT_SPECTATOR := "pit_spectator"
const EXHIBIT_BARN := "pit_barn"
const EXHIBIT_PIT := "pit_pit"
const EXHIBIT_STAND := "pit_stand"
const EXHIBIT_TREE := "pit_tree"
const EXHIBIT_BUNTING := "pit_bunting"
const EXHIBIT_SHOWGROUND := "pit_showground"

## What the gallery puts on its plinths.
##
## Every one of these is the mesh the match itself builds, not a model made for
## the display case — the birds even wear the hats currently equipped in the
## store. A gallery that showed a prettier version of the game would be an
## advert, and this is a museum.
##
## The facts are the exhibit's label card. They exist so a model is never
## carried by the picture alone, which is the same reason the intro is
## transcribed and the tug meter prints numbers.
const GALLERY_EXHIBITS: Array[Dictionary] = [
	{
		"id": EXHIBIT_BIRD_RED,
		"title": "Red Coop Puller",
		"heading": "The birds",
		"badge": "RED",
		"color": Color("ff6b57"),
		"description": (
			"Six of these hold the red end of the rope. The tall comb is how "
			+ "you tell the coops apart without relying on colour."
		),
		"facts": [
			"Rigid parts, one surface, zero skinning",
			"Wings, head and feet move in the vertex shader",
			"Wears whatever hat the red coop has equipped",
		],
	},
	{
		"id": EXHIBIT_BIRD_BLUE,
		"title": "Blue Coop Puller",
		"heading": "The birds",
		"badge": "BLUE",
		"color": Color("4da3ff"),
		"description": (
			"The same rig in the other coop's colours, wearing the tied bonnet "
			+ "that stands in for the comb."
		),
		"facts": [
			"Identical mesh, mirrored across the pit",
			"Bonnet and comb are the non-colour side signal",
			"Wears whatever hat the blue coop has equipped",
		],
	},
	{
		"id": EXHIBIT_SPECTATOR,
		"title": "Bleacher Bird",
		"heading": "The birds",
		"badge": "FAN",
		"color": Color("fff8e7"),
		"description": (
			"The crowd. Hundreds of these sit in one MultiMesh, which is why a "
			+ "full house costs a single draw call."
		),
		"facts": [
			"One shared mesh, instanced for the whole crowd",
			"Jumps on a notch; parked by reduced motion",
		],
	},
	{
		"id": EXHIBIT_BARN,
		"title": "The Barn",
		"heading": "The fairground",
		"badge": "BARN",
		"color": Color("e8453c"),
		"description": (
			"Cluck County's little red house, cross-braced doors and all. It "
			+ "stands behind the north fence and never moves."
		),
		"facts": [
			"Independently reusable: Scenery.barn_mesh()",
			"Planks, hayloft, weather vane and clock face",
			"Batched into the scenery surface at build time",
		],
	},
	{
		"id": EXHIBIT_PIT,
		"title": "The Pit",
		"heading": "The fairground",
		"badge": "PIT",
		"color": Color("966339"),
		"description": (
			"The hole itself: an octagonal cut through every ground layer, with "
			+ "sloped walls, a lip and a bed of straw at the bottom."
		),
		"facts": [
			"Cut out of the terrain, not painted on top of it",
			"Walls and floor share the scenery batch",
			"Pinned birds land on the straw and stay there",
		],
	},
	{
		"id": EXHIBIT_STAND,
		"title": "The Bleachers",
		"heading": "The fairground",
		"badge": "SEAT",
		"color": Color("bd8246"),
		"description": "Two rows of plank seating. There is one behind each coop.",
		"facts": ["Plank benches on darkened legs", "Fills with spectator birds"],
	},
	{
		"id": EXHIBIT_TREE,
		"title": "The Oak",
		"heading": "The fairground",
		"badge": "TREE",
		"color": Color("5cb238"),
		"description": (
			"Three overlapping crowns on a leaning trunk. One stands past each "
			+ "goal line, which is how you read depth across the field."
		),
		"facts": ["Three ellipsoid crowns, lightest on top", "Trunk leans; the crowns do not"],
	},
	{
		"id": EXHIBIT_BUNTING,
		"title": "The Bunting",
		"heading": "The fairground",
		"badge": "FLAG",
		"color": Color("e8b84b"),
		"description": (
			"A sagging line of triangles in both coops' colours, strung between "
			+ "two poles over the north fence."
		),
		"facts": [
			"The sag is a sine, not a simulation",
			"Every third flag is fair-day gold",
		],
	},
	{
		"id": EXHIBIT_SHOWGROUND,
		"title": "Cluck County Showground",
		"heading": "The whole show",
		"badge": "ALL",
		"color": Color("7cd44a"),
		"description": (
			"Everything at once: mown stripes, the dirt track, goal lines, "
			+ "fence, bunting, feed sacks, the water trough and the barn."
		),
		"facts": [
			"One surface, one draw call, whole fairground",
			"Built once per match from the rope length",
			"Zoom out to see how little of it the camera ever shows",
		],
		"requires_achievement": "pit_first_match",
	},
]
