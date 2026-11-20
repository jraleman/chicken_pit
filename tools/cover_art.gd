extends RefCounted

## A close tug, photographed with the actual coop rigs, pit and rope.
const Helpers = preload("res://tools/cover_art_helpers.gd")
const Bird = preload("res://games/chicken_pit/pit/chicken_rig.gd")
const Rope = preload("res://games/chicken_pit/pit/rope_view.gd")
const Scenery = preload("res://games/chicken_pit/pit/scenery.gd")


## A fairground pull-off poster with the competitors, not the barn, as the focal point.
static func design() -> Dictionary:
	return {
		"paper": Color("f8d463"), "ink": Color("3e3432"), "accent": Color("e67d52"),
		"motif": "rays", "camera": Vector3(0, 20, -7),
		"photo": Rect2(-28, 185, 1080, 650),
		"lettering": [
			{"text": "CHICKEN PIT", "at": Vector2(52, 159), "size": 165},
			{"text": "THE GREAT PULL-OFF", "at": Vector2(54, 915), "size": 78},
			{"text": "ONE ROPE. ZERO DIGNITY.", "at": Vector2(55, 983), "size": 38, "font": "round"},
		],
	}


## Authored coop colours are read from the inherited scene, not invented for the cover.
static func build(parent: Node) -> Node:
	var root := Helpers.group(parent)
	var authored := (load("res://games/chicken_pit/gameplay.tscn") as PackedScene).get_state()
	var colors: Array[Color] = []
	for property in [&"player_one_color", &"player_two_color"]:
		for index in authored.get_node_property_count(0):
			if authored.get_node_property_name(0, index) == property:
				colors.append(authored.get_node_property_value(0, index))
	assert(colors.size() == 2, "Cover requires both actual coop colours.")
	var birds: Array[Bird] = []
	for index in 2:
		var bird := Bird.new()
		root.add_child(bird)
		bird.configure(Bird.build_mesh(colors[index], index == 1), index * 0.8, 1.4)
		bird.pose(0.7, 0, 80, index == 1, 0, false)
		bird.position.x = -2.0 if index == 0 else 2.0
		if index == 1:
			bird.rotation.y = PI
		birds.append(bird)
	var pit := Helpers.mesh(root, Scenery.pit_mesh(), Helpers.paint())
	pit.scale = Vector3.ONE * 0.68
	var rope := Rope.new()
	root.add_child(rope)
	rope.set_reduced_motion(true)
	rope.update_rope(birds[0].beak_position(), birds[1].beak_position(),
		Vector3(0, 1.5, 0), 1, 0, 0)
	return root
