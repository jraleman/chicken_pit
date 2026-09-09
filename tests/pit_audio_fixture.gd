extends "res://games/chicken_pit/tests/pit_round_fixture.gd"

## Explicitly exercise real PCM playback while the graphics view stays headless.


func _activate_round() -> void:
	super()
	_pit_music.start(true)
