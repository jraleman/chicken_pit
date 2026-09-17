extends Control

## A turntable for the models the pit is built from.
##
## The gallery screen asks for this by path (`GameManifest.gallery_stage_scene_path`)
## and drives it with `configure()`, `set_view()` and `set_auto_spin()`, so the
## framework never learns what a chicken or a barn is. Everything here is the
## same geometry `pit_view.gd` puts in a match — `ChickenRig`, `Scenery` — built
## from the same builders rather than re-modelled for a display case. A gallery
## that showed a nicer version of the game would be an advert.
##
## The birds even wear the hats currently equipped in the store, which is the
## point of putting the two screens next to each other: what you bought is what
## is standing on the plinth.

const ChickenRig = preload("res://games/chicken_pit/pit/chicken_rig.gd")
const Scenery = preload("res://games/chicken_pit/pit/scenery.gd")
const ToyMesh = preload("res://games/chicken_pit/pit/toy_mesh.gd")
const Options = preload("res://games/chicken_pit/chicken_pit_options.gd")

const GAME_ID := "chicken_pit"
## The rope length the showground is built for. The real one comes from a
## tunable, but a museum piece needs one fixed size, and this is the default.
const SHOWGROUND_NOTCHES := 10

const FIELD_OF_VIEW := 40.0
## Breathing room around the exhibit, so a crown or a weather vane never touches
## the edge of the case.
const FRAMING_MARGIN := 1.08
## Kept clear of the poles: an orbit camera looking straight down cannot tell
## which way is up, and the whole view rolls.
const PITCH_LIMIT := 1.3439

## Where each exhibit is worth opening on. The birds face +X, so a
## three-quarter view needs most of a quarter turn; the barn's doors face +Z and
## look best square on; the showground and the pit read from above.
const FRAMING := {
	Options.EXHIBIT_BIRD_RED: {"yaw": 1.1345, "pitch": 0.1745},
	Options.EXHIBIT_BIRD_BLUE: {"yaw": 1.1345, "pitch": 0.1745},
	Options.EXHIBIT_SPECTATOR: {"yaw": 0.6981, "pitch": 0.1745},
	Options.EXHIBIT_BARN: {"yaw": 0.3491, "pitch": 0.2618},
	Options.EXHIBIT_PIT: {"yaw": 0.3927, "pitch": 0.6109},
	Options.EXHIBIT_STAND: {"yaw": 0.5236, "pitch": 0.3491},
	Options.EXHIBIT_TREE: {"yaw": 0.0, "pitch": 0.1745},
	Options.EXHIBIT_BUNTING: {"yaw": 0.0, "pitch": 0.1745},
	Options.EXHIBIT_SHOWGROUND: {"yaw": 0.5236, "pitch": 0.5236},
}

var _viewport: SubViewport
var _model: MeshInstance3D
var _camera: Camera3D
var _focus := Vector3.ZERO
var _base_distance := 6.0
var _base_yaw := 0.0
var _base_pitch := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _zoom := 1.0
var _inert := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inert = DisplayServer.get_name() == "headless"
	if _inert:
		return
	_build_stage()
	# A resize changes the aspect, and the aspect is half of the framing maths.
	resized.connect(_on_resized)


## Puts [param exhibit] — a `GameManifest.gallery_exhibits` entry — on the
## plinth. Only the id matters; every mesh brings its own colours.
func configure(exhibit: Dictionary) -> void:
	var id := str(exhibit.get("id", ""))
	var framing: Dictionary = FRAMING.get(id, {})
	_base_yaw = float(framing.get("yaw", 0.0))
	_base_pitch = float(framing.get("pitch", 0.1745))
	if _inert or _model == null:
		return
	var mesh := mesh_for(id)
	_model.mesh = mesh
	_model.visible = mesh != null
	_frame(mesh)
	_apply_camera()


## Orbit offsets from the exhibit's default framing, in radians, plus a
## magnification where 1.0 is that default and 2.0 is twice as close.
func set_view(yaw: float, pitch: float, zoom: float) -> void:
	_yaw = yaw
	_pitch = pitch
	_zoom = maxf(zoom, 0.01)
	_apply_camera()


## Nothing here spins on its own — the screen owns the turntable and feeds it
## through [method set_view] — so this only makes sure a parked model is drawn
## with whatever view it stopped on.
func set_auto_spin(_enabled: bool) -> void:
	_request_draw()


# --------------------------------------------------------------------------
# The case
# --------------------------------------------------------------------------


## Rendering is request-driven rather than continuous: the viewport draws one
## frame whenever the view actually changes. A gallery left open on a still
## model then costs nothing, which matters because this screen can be opened
## from the pause menu with a whole 3D match still resident behind it.
func _request_draw() -> void:
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _build_stage() -> void:
	var container := SubViewportContainer.new()
	container.name = "Case"
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)

	_viewport = SubViewport.new()
	_viewport.name = "Turntable"
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.gui_disable_input = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	container.add_child(_viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff1d1")
	environment.ambient_light_energy = 0.75
	var world := WorldEnvironment.new()
	world.name = "Light"
	world.environment = environment
	_viewport.add_child(world)

	# The pit's own sun, plus a cool fill from behind so the far side of a
	# turning model is shaded rather than black.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.15
	sun.light_color = Color("fff1d1")
	sun.rotation = Vector3(-0.72, -0.85, 0.0)
	sun.shadow_enabled = false
	_viewport.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_energy = 0.45
	fill.light_color = Color("bcd9ff")
	fill.rotation = Vector3(-0.35, 2.4, 0.0)
	fill.shadow_enabled = false
	_viewport.add_child(fill)

	_model = MeshInstance3D.new()
	_model.name = "Exhibit"
	_model.material_override = ToyMesh.material()
	_viewport.add_child(_model)

	_camera = Camera3D.new()
	_camera.name = "Lens"
	_camera.fov = FIELD_OF_VIEW
	_camera.near = 0.05
	_camera.far = 400.0
	_viewport.add_child(_camera)


## Every exhibit is built by the same code the match uses. The ids are this
## game's own, so a `match` here is a lookup table, not a framework branch.
##
## Public because it is the honest test surface: a headless run can build every
## exhibit and check the geometry without a renderer or a scene tree.
func mesh_for(id: String) -> ArrayMesh:
	var colors: Array[Color] = Options.COOP_COLORS
	match id:
		Options.EXHIBIT_BIRD_RED:
			return ChickenRig.build_mesh(
				colors[0], false, _equipped_hat(Options.hat_slot(0))
			)
		Options.EXHIBIT_BIRD_BLUE:
			return ChickenRig.build_mesh(
				colors[1], true, _equipped_hat(Options.hat_slot(1))
			)
		Options.EXHIBIT_SPECTATOR:
			return ChickenRig.spectator_mesh()
		Options.EXHIBIT_BARN:
			return Scenery.barn_mesh()
		Options.EXHIBIT_PIT:
			return Scenery.pit_mesh()
		Options.EXHIBIT_STAND:
			return Scenery.stand_mesh()
		Options.EXHIBIT_TREE:
			return Scenery.tree_mesh()
		Options.EXHIBIT_BUNTING:
			return Scenery.bunting_mesh(colors)
		Options.EXHIBIT_SHOWGROUND:
			return Scenery.build(SHOWGROUND_NOTCHES, colors)
	return null


## Resolved from the tree rather than named directly, so this script never needs
## the Store autoload to exist at compile time — the same rule every headless
## entry point in this folder follows. Outside a tree there is nothing equipped,
## which is what lets a test build every exhibit without running the game.
func _equipped_hat(slot: String) -> String:
	if not is_inside_tree():
		return ""
	var store := get_tree().root.get_node_or_null("Store")
	if store == null:
		return ""
	return str(store.call("equipped_id", GAME_ID, slot))


# --------------------------------------------------------------------------
# Framing
# --------------------------------------------------------------------------


## Fits the exhibit to whichever of the two field-of-view angles is tighter, so
## a wide fairground frames itself on a phone held upright and a tall barn frames
## itself on an ultrawide — and a new exhibit needs no hand-measured camera
## distance at all.
##
## The model is treated as the cylinder it sweeps out as it turns, not as its
## bounding box: a box would fit at one yaw and clip at the next. Horizontally
## the camera sits where that cylinder is exactly tangent to the frustum;
## vertically it also backs off by the cylinder's radius, because the near side
## of a turning model is that much closer than its middle.
func _frame(mesh: ArrayMesh) -> void:
	if mesh == null:
		return
	var bounds := mesh.get_aabb()
	_focus = bounds.get_center()
	var radius := maxf(
		Vector2(bounds.size.x, bounds.size.z).length() * 0.5, 0.01
	)
	var half_height := maxf(bounds.size.y * 0.5, 0.01)
	var vertical := deg_to_rad(FIELD_OF_VIEW)
	var horizontal := 2.0 * atan(tan(vertical * 0.5) * _aspect())
	_base_distance = (
		maxf(
			radius / sin(horizontal * 0.5),
			half_height / tan(vertical * 0.5) + radius
		)
		* FRAMING_MARGIN
	)


func _aspect() -> float:
	var box := size
	if box.x <= 0.0 or box.y <= 0.0:
		return 16.0 / 9.0
	return box.x / box.y


func _apply_camera() -> void:
	if _camera == null:
		return
	var pitch := clampf(_base_pitch + _pitch, -PITCH_LIMIT, PITCH_LIMIT)
	var offset := Vector3(0.0, sin(pitch), cos(pitch)).rotated(
		Vector3.UP, _base_yaw + _yaw
	)
	_camera.position = _focus + offset * (_base_distance / _zoom)
	_camera.look_at(_focus, Vector3.UP)
	_request_draw()


func _on_resized() -> void:
	if _model != null and _model.mesh is ArrayMesh:
		_frame(_model.mesh as ArrayMesh)
	_apply_camera()
