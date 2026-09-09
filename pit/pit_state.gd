extends RefCounted

## Clock-driven rules; exponential motion and held ground are integrated analytically.

const Options = preload("res://games/chicken_pit/chicken_pit_options.gd")

const BASE_PULL_GAIN := 9.0
const MAX_STRENGTH := 100.0
const MIN_PULL_INTERVAL := 0.10
const DECAY_LAMBDA := 1.2
const REFERENCE_DIFF := 40.0
const CREEP_DEADZONE := 1.5
const ROPE_SPEED_BASE := 2.2
const HOLD_RATE := 20.0
const NOTCH_POINTS := 100.0
const PIN_BONUS := 2000.0
const TIME_EPSILON := 0.000000001

var L: int = 10
var pull_power: float = 1.0
var strength_decay: float = 1.0
var gameplay_speed: float = 1.0

var clock: float = 0.0
var rope: float = 0.0
var strength: Array[float] = [0.0, 0.0]
var scores: Array[float] = [0.0, 0.0]
var streaks: Array[int] = [0, 0]
var best_streaks: Array[int] = [0, 0]
var captures: Array[int] = [0, 0]
var losses: Array[int] = [0, 0]
var accepted_pulls: Array[int] = [0, 0]
var deepest: Array[int] = [0, 0]
var extreme: Array[float] = [0.0, 0.0]
var last_action: Array[StringName] = [&"", &""]
var last_pull_time: Array[float] = [-INF, -INF]
var last_alternation: Array[float] = [1.0, 1.0]
var pin_winner: int = -1
var finished: bool = false


func _init(
	rope_length: int = 10,
	power: float = 1.0,
	decay: float = 1.0,
	speed: float = 1.0
) -> void:
	assert(rope_length >= Options.MIN_ROPE_LENGTH
		and rope_length <= Options.MAX_ROPE_LENGTH, "Rope length must be in 6..18.")
	assert(is_finite(power) and power >= Options.MIN_PULL_POWER
		and power <= Options.MAX_PULL_POWER, "Pull power must be in 0.5..2.0.")
	assert(is_finite(decay) and decay >= Options.MIN_STRENGTH_DECAY
		and decay <= Options.MAX_STRENGTH_DECAY, "Strength decay must be in 0.5..2.0.")
	assert(is_finite(speed) and speed > 0.0, "Gameplay speed must be finite and positive.")
	L = rope_length
	pull_power = power
	strength_decay = decay
	gameplay_speed = speed


## A timestamp identifies this frame, never advances it; rejected chords change no history.
func register_pull(coop: int, action: StringName, at_clock: float = -1.0) -> float:
	if not _require(coop == 0 or coop == 1, "Pull coop must be 0 or 1."):
		return 0.0
	if not _require(action in Options.pull_actions(coop),
		"Pull action must be one of this coop's three actions."):
		return 0.0
	if not _require(is_finite(at_clock), "Pull timestamp must be finite."):
		return 0.0
	if not _require(at_clock < 0.0 or absf(at_clock - clock) <= TIME_EPSILON,
		"Pull timestamp must equal the model clock; advance time with step()."):
		return 0.0
	if finished or pin_winner >= 0:
		return 0.0
	var interval := clock - last_pull_time[coop]
	if interval + TIME_EPSILON < MIN_PULL_INTERVAL:
		return 0.0
	var alternation := 0.35 if action == last_action[coop] else 1.0
	var cadence := 1.0
	if last_pull_time[coop] == -INF:
		cadence = 1.15
	elif interval < 0.12 - TIME_EPSILON:
		cadence = lerpf(1.0, 1.15, clampf((interval - 0.10) / 0.02, 0.0, 1.0))
	elif interval < 0.45 - TIME_EPSILON:
		cadence = 1.15
	var before := strength[coop]
	var gain := BASE_PULL_GAIN * pull_power * gameplay_speed * alternation * cadence
	strength[coop] = clampf(before + gain * (1.0 - before / MAX_STRENGTH),
		0.0, MAX_STRENGTH)
	last_action[coop] = action
	last_pull_time[coop] = clock
	last_alternation[coop] = alternation
	accepted_pulls[coop] += 1
	return strength[coop] - before


## Stop at the physical pin instant, so hitches cannot bank post-pin hold points.
func step(delta: float) -> int:
	if not _require(is_finite(delta) and delta >= 0.0,
		"Step delta must be finite and non-negative."):
		return -1
	if delta == 0.0 or finished or pin_winner >= 0:
		return -1
	extreme[0] = maxf(extreme[0], maxf(0.0, rope))
	extreme[1] = maxf(extreme[1], maxf(0.0, -rope))
	if absf(rope) >= float(L):
		rope = clampf(rope, -float(L), float(L))
		_pin(0 if rope > 0.0 else 1)
		return pin_winner
	var rate := DECAY_LAMBDA * strength_decay * gameplay_speed
	var difference := strength[0] - strength[1]
	var magnitude := absf(difference)
	var velocity := signf(difference) * ROPE_SPEED_BASE \
		* sqrt(float(L) / float(Options.DEFAULT_ROPE_LENGTH)) * gameplay_speed
	var elapsed := 0.0
	if magnitude > CREEP_DEADZONE:
		var clamped_time := maxf(0.0, log(magnitude / REFERENCE_DIFF) / rate)
		var stopping_time := log(magnitude / CREEP_DEADZONE) / rate
		if clamped_time > 0.0:
			elapsed = _advance_segment(minf(delta, clamped_time), velocity, 0.0)
		if pin_winner < 0:
			var moving_time := minf(delta, stopping_time) - elapsed
			if moving_time > 0.0:
				var decaying_velocity := velocity * minf(1.0,
					magnitude * exp(-rate * elapsed) / REFERENCE_DIFF)
				elapsed += _advance_segment(moving_time, decaying_velocity, rate)
	if pin_winner < 0:
		_bank_hold(rope, 0.0, 0.0, maxf(0.0, delta - elapsed))
		elapsed = delta
	var decay_factor := exp(-rate * elapsed)
	strength[0] *= decay_factor
	strength[1] *= decay_factor
	clock += elapsed
	return pin_winner


## A new life clears the exchange, not its banked points or match-wide records.
func recentre() -> void:
	rope = 0.0
	for coop in 2:
		strength[coop] = 0.0
		streaks[coop] = 0
		last_action[coop] = &""
		last_pull_time[coop] = -INF
		last_alternation[coop] = 1.0
	pin_winner = -1


## Unlike the exchange's pin lock, a finished-round lock survives recentring.
func freeze() -> void:
	finished = true


func _advance_segment(duration: float, velocity: float, rate: float) -> float:
	var previous := rope
	var destination := previous + _travel(velocity, rate, duration)
	var pinned := absf(destination) >= float(L)
	if pinned:
		destination = float(L) * signf(velocity)
		duration = _travel_time(destination - previous, velocity, rate)
	_bank_hold(previous, velocity, rate, duration)
	rope = destination
	_record_ground(previous)
	if pinned:
		_pin(0 if rope > 0.0 else 1)
	return duration


func _record_ground(previous: float) -> void:
	for coop in 2:
		var direction := 1.0 if coop == 0 else -1.0
		var before := floori(maxf(0.0, previous * direction))
		var after := floori(maxf(0.0, rope * direction))
		extreme[coop] = maxf(extreme[coop], maxf(0.0, rope * direction))
		if after < before:
			losses[coop] += before - after
			streaks[coop] = 0
		for notch in range(before + 1, after + 1):
			captures[coop] += 1
			streaks[coop] += 1
			best_streaks[coop] = maxi(best_streaks[coop], streaks[coop])
			if notch > deepest[coop]:
				deepest[coop] = notch
				scores[coop] += NOTCH_POINTS


func _bank_hold(position: float, velocity: float, rate: float, duration: float) -> void:
	var destination := position + _travel(velocity, rate, duration)
	var area := _position_area(position, velocity, rate, duration)
	if position * destination < 0.0:
		var crossing := _travel_time(-position, velocity, rate)
		var first_area := _position_area(position, velocity, rate, crossing)
		_add_hold(first_area)
		_add_hold(area - first_area)
	else:
		_add_hold(area)


func _add_hold(signed_area: float) -> void:
	var coop := 0 if signed_area >= 0.0 else 1
	scores[coop] += HOLD_RATE * absf(signed_area)


func _pin(winner: int) -> void:
	pin_winner = winner
	scores[winner] = maxf(scores[winner], scores[1 - winner]) + PIN_BONUS


## Constant-speed and exponential phases have exact distance and area primitives.
func _travel(velocity: float, rate: float, duration: float) -> float:
	if rate == 0.0:
		return velocity * duration
	var x := rate * duration
	if x < 0.001:
		return velocity * duration * (1.0 - x / 2.0 + x * x / 6.0
			- x * x * x / 24.0 + x * x * x * x / 120.0)
	return velocity * (1.0 - exp(-x)) / rate


func _position_area(position: float, velocity: float, rate: float, duration: float) -> float:
	if rate == 0.0:
		return position * duration + velocity * duration * duration / 2.0
	var x := rate * duration
	if x < 0.001:
		return position * duration + velocity * duration * duration * (0.5 - x / 6.0
			+ x * x / 24.0 - x * x * x / 120.0 + x * x * x * x / 720.0)
	return position * duration + velocity * (duration - (1.0 - exp(-x)) / rate) / rate


func _travel_time(distance: float, velocity: float, rate: float) -> float:
	if rate == 0.0:
		return distance / velocity
	return -log(1.0 - distance * rate / velocity) / rate


func _require(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
	return condition
