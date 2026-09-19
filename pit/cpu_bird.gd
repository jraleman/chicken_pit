extends RefCounted

## Seeded opponents press ordinary blue-coop actions, never add a private force.

const PitState = preload("res://games/chicken_pit/pit/pit_state.gd")
const Options = preload("res://games/chicken_pit/chicken_pit_options.gd")

const HYSTERESIS := 0.08
const TARGET_JITTER := 0.04
const TARGETS: Array[float] = [18.0, 26.0, 38.0]
const MAX_RATES: Array[float] = [5.0, 8.0, 10.0]
const COMFORTABLE_LEAD := 0.25
const BURST_SECONDS := 1.5

var target: float = 26.0
var resting: bool = false
var difficulty: int = 1

var _rng := RandomNumberGenerator.new()
var _actions: Array[StringName] = Options.pull_actions(1)
var _action_index: int = 0
var _target_jitter: float = 1.0
var _next_pull: float = 0.0
var _last_update: float = -INF
var _next_breather: float = INF
var _breather_until: float = -INF
var _burst_until: float = -INF
var _player_was_weak: bool = false
var _panicking: bool = false


func _init(difficulty: int = 1, seed_value: int = 1) -> void:
	assert(difficulty >= 0 and difficulty <= 2, "Bird difficulty must be in 0..2.")
	self.difficulty = difficulty
	_rng.seed = seed_value
	reset()


## Rebase schedules at the exchange clock without replaying missed pulls.
func reset(clock: float = 0.0) -> void:
	assert(is_finite(clock) and clock >= 0.0, "Bird reset clock must be non-negative.")
	target = TARGETS[difficulty]
	resting = false
	_action_index = 0
	_target_jitter = 1.0
	_next_pull = clock
	_last_update = -INF
	_next_breather = clock + _rng.randf_range(4.0, 7.0)
	_breather_until = -INF
	_burst_until = -INF
	_player_was_weak = false
	_panicking = false


## At most one attempt per model frame; the human rate and cadence gates still apply.
func update(state: PitState) -> float:
	if state.finished or state.pin_winner >= 0:
		return 0.0
	if state.clock + PitState.TIME_EPSILON < _last_update:
		push_error("Bird clock moved backwards; reset the bird for a new exchange.")
		return 0.0
	if state.clock <= _last_update:
		return 0.0
	_last_update = state.clock
	var base_target := _choose_target(state)
	target = base_target * _target_jitter
	if target == 0.0:
		resting = true
	elif state.strength[1] < target * (1.0 - HYSTERESIS):
		resting = false
	elif state.strength[1] > target * (1.0 + HYSTERESIS):
		resting = true
	if resting or state.clock + PitState.TIME_EPSILON < _next_pull:
		return 0.0
	var gain := state.register_pull(1, _actions[_action_index], state.clock)
	_next_pull = state.clock + 1.0 / MAX_RATES[difficulty]
	if gain > 0.0:
		_action_index = (_action_index + 1) % _actions.size()
		_target_jitter = _rng.randf_range(1.0 - TARGET_JITTER, 1.0 + TARGET_JITTER)
		target = base_target * _target_jitter
	return gain


## Names stay independent of menus and session autoloads.
static func bird_name(value: int) -> String:
	assert(value >= 0 and value <= 2, "Bird difficulty must be in 0..2.")
	return ["Chick", "Hen", "Rooster"][value]


func _choose_target(state: PitState) -> float:
	match difficulty:
		Options.CPU_CHICK:
			return 11.0 if state.rope > float(state.L) * 0.4 else TARGETS[0]
		Options.CPU_HEN:
			if state.clock >= _next_breather:
				_breather_until = state.clock + _rng.randf_range(0.6, 1.1)
				_next_breather = state.clock + _rng.randf_range(4.0, 7.0)
			if state.clock < _breather_until:
				return 0.0
			if state.rope > 0.0:
				return TARGETS[1] + 6.0
			if state.rope < -float(state.L) * COMFORTABLE_LEAD:
				return TARGETS[1] - 6.0
			return TARGETS[1]
		Options.CPU_ROOSTER:
			var player_is_weak := state.strength[0] < 15.0
			if player_is_weak and not _player_was_weak:
				_burst_until = state.clock + BURST_SECONDS
			_player_was_weak = player_is_weak
			_panicking = _panicking or state.rope >= float(state.L) - 2.0
			if _panicking or state.clock < _burst_until:
				return 46.0
			return TARGETS[2]
	return 0.0
