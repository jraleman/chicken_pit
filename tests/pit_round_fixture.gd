extends "res://games/chicken_pit/gameplay.gd"

## Exercise the real round with isolated flock history and no profile achievements.

var observed_achievements := PackedStringArray()
var history_path := "user://chicken_pit_fixture_%d_%d.cfg" % [
	OS.get_process_id(), Time.get_ticks_usec(),
]
var previously_played := false


func _load_pit_history() -> void:
	_pit_history = PitHistory.new(history_path)
	if _pit_history.load_history(previously_played) != OK:
		push_error("Could not load the isolated Chicken Pit fixture history.")


func _reset_round_state() -> void:
	super()
	observed_achievements.clear()


func _unlock_round_achievement(id: String) -> void:
	observed_achievements.append(id)


func _record_round(_player_one_total: int, _player_two_total: int) -> String:
	return ""
