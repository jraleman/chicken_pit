extends Control

## A card-sized portrait of a hen wearing the hat a store card is selling.
##
## The store asks for this by path (`GameManifest.store_preview_scene_path`) and
## hands it the item, so the framework never learns what a chicken looks like.
## It renders the same [ChickenRig] mesh the pit builds, which is the point: the
## hat on the shelf is literally the hat that goes into the match, so a portrait
## cannot drift from what a purchase actually buys.
##
## The portrait is deliberately still. A shop full of turning models is a shop
## full of animation nobody asked for, and a hat reads from one angle — so the
## viewport draws a single frame, which also keeps a seven-card shelf cheap and
## means reduced motion has nothing to switch off.

const ChickenRig = preload("res://games/chicken_pit/pit/chicken_rig.gd")
const ToyMesh = preload("res://games/chicken_pit/pit/toy_mesh.gd")

## What the lens is pointed at, in the rig's own coordinates: between the head
## and the top of the tallest hat, so every item is framed the same way.
const FRAMING := Vector3(0.35, 1.52, 0.0)
## Far enough back for a crown's points, close enough for a bare comb to fill
## the card. Three-quarter view, because a brim needs depth to read as a brim.
const LENS := Vector3(2.5, 0.42, 1.05)
## The red coop's colour. A portrait has to pick a side, and the comb — not the
## bonnet — is the silhouette a hat has to leave standing.
const PORTRAIT_TEAM := Color("e8453c")

var _viewport: SubViewport
var _model: MeshInstance3D
var _inert := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inert = DisplayServer.get_name() == "headless"
	if _inert:
		return
	_build_stage()


## Draws [param item] — a `Store.describe()` result. Only the id matters; the
## mesh brings its own colours.
func configure(item: Dictionary) -> void:
	if _inert or _model == null:
		return
	_model.mesh = ChickenRig.build_mesh(
		PORTRAIT_TEAM, false, str(item.get("id", ""))
	)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Part of the store card's preview contract. Nothing here moves, so this only
## asks for a redraw when a parked card comes back.
func set_preview_running(_running: bool) -> void:
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _build_stage() -> void:
	var container := SubViewportContainer.new()
	container.name = "Stage"
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)

	_viewport = SubViewport.new()
	_viewport.name = "Portrait"
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
	environment.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.name = "Light"
	world.environment = environment
	_viewport.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.1
	sun.light_color = Color("fff1d1")
	sun.rotation = Vector3(-0.72, -0.85, 0.0)
	sun.shadow_enabled = false
	_viewport.add_child(sun)

	_model = MeshInstance3D.new()
	_model.name = "Bird"
	# The rig is authored standing on a floor, so the model hangs back down by
	# the framing offset and leaves the point of interest at the origin.
	_model.position = -FRAMING
	_model.material_override = ToyMesh.material()
	_viewport.add_child(_model)

	var camera := Camera3D.new()
	camera.name = "Lens"
	camera.fov = 42.0
	# `look_at` needs a node already in the tree; a transform does not.
	camera.transform = Transform3D(Basis.IDENTITY, LENS).looking_at(Vector3.ZERO)
	_viewport.add_child(camera)
