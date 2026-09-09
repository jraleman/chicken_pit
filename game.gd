extends RefCounted

## Chicken Pit manifest — a barnyard tug-of-war for two coops.
##
## [GameCatalog] discovers this file automatically; nothing in the framework
## refers to Chicken Pit by name.
##
## The 3D farm is game-owned; countdowns, pause, results and sharing stay in the shell.

const GAME_ID := "chicken_pit"


static func manifest() -> GameManifest:
	var game := GameManifest.new()
	game.id = GAME_ID
	game.title = "Chicken Pit"
	game.tagline = "Two coops. One rope. Absolutely no dignity."
	game.gameplay_scene_path = "res://games/chicken_pit/gameplay.tscn"
	game.tutorial_video_path = "res://assets/video/tutorial_chicken_pit.ogv"
	game.tutorial_poster_path = (
		"res://assets/video/tutorial_chicken_pit_poster.webp"
	)
	# The story the pit is named after, told once before the menu. Only a build
	# that ships this game alone ever reaches it — a collection has not chosen a
	# game yet when the opening runs.
	game.intro_scene_path = "res://games/chicken_pit/intro.tscn"
	game.menu_order = 3
	# A rope needs two ends, and one of them is happy to be a bird. There is no
	# solo shape of this game to offer, so the player-count step is dropped and
	# mode select asks the only real question: who holds the other end.
	game.supports_multiplayer = true
	game.supports_cpu_opponent = true
	game.supports_single_player = false
	# Timer rounds bank ground held; Lives rounds are a first-to-N-pins match.
	game.default_lives_mode = false
	# Nothing here is a highlighted target: a coop pulls, and the rope answers.
	# This is the style that renders manifest copy instead of the target cards.
	game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	game.tunables = ChickenPitOptions.TUNABLES
	game.control_bindings = ChickenPitOptions.CONTROL_BINDINGS
	game.copy = {
		# No `mode_select_intro`, `mode_select_hint`, `single_player_description`
		# or `multiplayer_description`: those belong to the player-count step,
		# and a two-seat-only game never renders it.
		"cpu_opponent_description": (
			"A rival bird holds the other end. Choose Chick, Hen or Rooster "
			+ "in Settings → Game; changes apply next round."
		),
		"player_one_control_description": "Pull the rope for the red coop.",
		"player_two_control_description": "Pull the rope for the blue coop.",
		# The framework's "solo" confirmation card is this game's CPU card: with
		# no player-count step, that key describes the bird on the other end.
		"solo_confirm_title": "A bird holds the other end",
		"solo_confirm_description": (
			"Hammer your pull keys to drag the rope your way. Strength drains "
			+ "between pulls, so a steady rhythm beats one wild burst."
		),
		"versus_confirm_title": "Two coops, one rope",
		"versus_confirm_description": (
			"Both coops pull on the same rope at the same keyboard. Whoever "
			+ "hauls it past their goal line owns the pit."
		),
		"instructions_headline": "Out-pull the other coop",
		"instructions_rules": (
			"Alternate your pull keys  ·  Strength drains between pulls  ·  "
			+ "Pin a coop or bank the most ground  ·  Esc pauses"
		),
		"instructions_demo_prompt": "ROLL YOUR KEYS. HOLD YOUR GROUND.",
		"instructions_solo_summary": (
			"You hold one end of the rope and a rival bird holds the other. "
			+ "Alternate your three pull keys to build strength; whichever coop "
			+ "has more of it drags the rope its way."
		),
		"instructions_versus_summary": (
			"Both coops share one keyboard and one rope. The rope follows "
			+ "whichever side is pulling harder, so let up and you lose ground."
		),
		# The framework's versus card would offer a mouse and the arrow keys,
		# and this game uses neither.
		"instructions_player_one_controls": (
			"Alternate your three keys. Holding a key only pulls once.\n"
			+ "Rebind either coop: Settings → Controls"
		),
	}
	game.stats_url = "https://deskcansaw.com/stats/cp"
	game.share_art_scene_path = "res://games/chicken_pit/ui/share_art.tscn"
	game.theme = _theme()
	game.credits = [
		{
			"heading": "Game Design & Code",
			"lines": ["DeskCanSaw"],
		},
		{
			"heading": "Opening Narration",
			"lines": [
				"\"The chicken pit\" story — a clip from Painkiller Already",
				"Transcribed on screen, so the opening is never sound-only",
			],
		},
		{
			"heading": "Music",
			"lines": [
				"\"The Great Pull-Off\" — original county-fair jig",
				"Beat-locked danger percussion and countermelody",
				"DeskCanSaw — offline-authored, included under the MIT licence",
			],
		},
		{
			"heading": "Sound",
			"lines": [
				"Original clucks, rope creak, crowd and pin cues — DeskCanSaw",
				"Menu notch, cluck and gate latch from the same sound bank",
				"Reproducible PCM sound bank; no external samples",
			],
		},
		{
			"heading": "Models",
			"lines": [
				"Original vertex-painted chickens and toy-farm models — DeskCanSaw",
				"Tall combs, tied bonnets and a miniature Cluck County fair",
				"Barn-board menu plaque and fairground backdrop — DeskCanSaw",
				"Cover portrait rendered from the original toy-farm models",
			],
		},
		{
			"heading": "Accessibility",
			"lines": [
				"Rebindable pull keys for both coops",
				"Audio captions, reduced motion and player labels",
			],
		},
	]
	game.achievements = {
		"pit_first_match": {
			"title": "Chicken Run",
			"description": "Finish your first Chicken Pit match.",
			"badge": "RUN",
		},
		"pit_clean_sweep": {
			"title": "Clean Coop",
			"description": "Win without the rope ever crossing your own centre line.",
			"badge": "0",
		},
		"pit_comeback": {
			"title": "Fowl Play",
			"description": "Win a match after the rope reached your last notch.",
			"badge": "REV",
		},
	}
	return game


## The pit's own palette, one stop below the round it introduces.
##
## Menus wear it in standalone builds; scorecards use it in collections too.
##
## Every colour here is lifted from the farm rather than invented: the gold is
## the tug meter's, the plaque is the barn, the light is the pit's sun and the
## gradient is the tug meter's ink deepened into turf shadow. The menus are the
## same fairground, at the value the shell's light-on-dark labels need — see
## DESIGN.md §6.1.
static func _theme() -> GameTheme:
	var theme := GameTheme.new()
	theme.style_share_card = true
	theme.logo_texture_path = "res://games/chicken_pit/assets/menu-cover.png"
	# Preserve the full-colour cover; the old silhouette used a cream tint.
	theme.logo_color = Color.WHITE
	## scenery.gd's barn red exactly. assets/ui/plaque.svg is authored in the
	## midtones so the menu's warm key and gold fill land the lit face here
	## rather than clipping it to orange.
	theme.plaque_color = Color("e8453c")
	theme.accent = Color("ffd45c")
	theme.light = Color("fff1d1")
	theme.background_top = Color("16241f")
	theme.background_bottom = Color("070d0a")
	theme.background_material = preload("res://games/chicken_pit/ui/menu_background.tres")
	theme.plaque_material = preload("res://games/chicken_pit/ui/menu_plaque.tres")
	theme.ui_theme = preload("res://games/chicken_pit/ui/menu_skin.tres")
	theme.ui_sounds = preload("res://games/chicken_pit/ui/menu_sounds.tres")
	theme.menu_motion = GameTheme.MenuMotion.SPRING
	return theme
