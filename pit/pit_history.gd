extends RefCounted

## Only completed matches grow the flock; the saved counter never allocates birds.

const SAVE_PATH := "user://chicken_pit_history.cfg"
const CHICKENS_PER_MATCH := 6
const MAX_CHICKENS := 24
const MAX_MATCH_COUNT := 9223372036854775807
const SECTION := "pit"
const MATCHES_KEY := "completed_matches"

var completed_matches := 0
var _save_path: String
var _loaded := false


func _init(save_path := SAVE_PATH) -> void:
	_save_path = save_path


func load_history(previously_played := false) -> Error:
	_loaded = false
	var config := ConfigFile.new()
	var error := config.load(_save_path)
	if error == ERR_FILE_NOT_FOUND:
		# Older builds recorded the first-match achievement, but no numeric history.
		completed_matches = 1 if previously_played else 0
		_loaded = true
		return OK
	if error != OK:
		return _failure("load", error)
	var count: Variant = config.get_value(SECTION, MATCHES_KEY, null)
	if not count is int or int(count) < 0:
		return _failure("load", ERR_INVALID_DATA)
	completed_matches = maxi(int(count), 1 if previously_played else 0)
	_loaded = true
	return OK


func record_match() -> Error:
	if not _loaded:
		return _failure("save unread", ERR_UNCONFIGURED)
	var next := completed_matches
	if next < MAX_MATCH_COUNT:
		next += 1
	var config := ConfigFile.new()
	config.set_value(SECTION, MATCHES_KEY, next)
	var temporary := "%s.%d.tmp" % [_save_path, OS.get_process_id()]
	var error := config.save(temporary)
	if error == OK:
		error = DirAccess.rename_absolute(temporary, _save_path)
	if error != OK:
		if FileAccess.file_exists(temporary):
			var cleanup_error := DirAccess.remove_absolute(temporary)
			if cleanup_error != OK:
				push_warning("Could not remove temporary pit history: %s" %
					error_string(cleanup_error))
		return _failure("save", error)
	completed_matches = next
	return OK


static func chickens_for_matches(matches: int) -> int:
	# Clamp before multiplication so even a saturated 64-bit counter is safe.
	return clampi(matches, 0, MAX_CHICKENS / CHICKENS_PER_MATCH) * CHICKENS_PER_MATCH


func _failure(operation: String, error: Error) -> Error:
	push_warning("Could not %s Chicken Pit history at %s: %s. Saved flock unchanged." %
		[operation, _save_path, error_string(error)])
	return error
