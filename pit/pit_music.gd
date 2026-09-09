extends Node

## Beat-locked original stems; scene ownership makes pause and teardown automatic.

const JIG := preload("res://games/chicken_pit/assets/audio/pit-jig.wav")
const DANGER := preload("res://games/chicken_pit/assets/audio/pit-jig-danger.wav")
# The host owns this bus; a literal keeps standalone scripts loadable before autoloads.
const BUS_MUSIC := "Music"
const SILENT_DB := -80.0
const ATTACK_SECONDS := 0.35
const RELEASE_SECONDS := 1.25

var _player: AudioStreamPlayer
var _stems: AudioStreamSynchronized
var _pressure := 0.0
var _intensity := 0.0


func _ready() -> void:
	_stems = AudioStreamSynchronized.new()
	_stems.stream_count = 2
	_stems.set_sync_stream(0, looping_stream(JIG))
	_stems.set_sync_stream(1, looping_stream(DANGER))
	_stems.set_sync_stream_volume(1, SILENT_DB)
	_player = AudioStreamPlayer.new()
	_player.name = "Music"
	_player.bus = BUS_MUSIC
	_player.stream = _stems
	add_child(_player)
	set_process(false)


## Starting a new match resets the playhead once, never on a lives re-centre.
func start(playback_enabled: bool) -> void:
	stop()
	if playback_enabled:
		_player.play()
		set_process(true)


func stop() -> void:
	if _player != null:
		_player.stop()
		_stems.set_sync_stream_volume(1, SILENT_DB)
	_pressure = 0.0
	_intensity = 0.0
	set_process(false)


## Either end of the rope is dangerous; signed model position is the only input.
func set_pressure(rope: float, rope_length: float) -> void:
	var proximity := absf(rope) / maxf(rope_length, 1.0)
	_pressure = smoothstep(0.60, 0.95, proximity)


func _process(delta: float) -> void:
	var seconds := ATTACK_SECONDS if _pressure > _intensity else RELEASE_SECONDS
	_intensity = lerpf(_intensity, _pressure, 1.0 - exp(-maxf(delta, 0.0) / seconds))
	_stems.set_sync_stream_volume(1, linear_to_db(maxf(_intensity, 0.0001)))


static func looping_stream(source: AudioStreamWAV) -> AudioStreamWAV:
	var stream := source.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	return stream
