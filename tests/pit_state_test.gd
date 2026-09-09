extends SceneTree

## Pure-rule regressions, including real-frame cadence and exact motion primitives.

const PitState = preload("res://games/chicken_pit/pit/pit_state.gd")
const Options = preload("res://games/chicken_pit/chicken_pit_options.gd")
const FRAME := 1.0 / 60.0
const EPSILON := 0.00000001
const EQUILIBRIUM_SECONDS := 20.0

var _failures := PackedStringArray()
var _red: Array[StringName] = Options.pull_actions(0)
var _blue: Array[StringName] = Options.pull_actions(1)


class Cycle:
	var mean: float = 0.0
	var peak: float = 0.0
	var trough: float = INF
	var frequency: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var checks: Array[Callable] = [
		_test_pull_gates, _test_cadence, _test_strength, _test_deadzone_and_hold,
		_test_notches, _test_pins_and_recentering, _test_partitioning, _test_equilibria,
	]
	for check in checks:
		_expect(check.call() == true, "State check aborted: %s." % check.get_method())
	if _failures.is_empty():
		print("Chicken Pit state tests passed: gates, analytic motion, scoring and equilibria.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_pull_gates() -> bool:
	var state := PitState.new()
	_expect(state.last_pull_time == [-INF, -INF], "Both first-pull clocks start at -INF.")
	_near(state.register_pull(0, _red[0]), 10.35, EPSILON, "The first pull is in-groove.")
	var before := _snapshot(state)
	_expect(state.register_pull(0, _red[1], state.clock) == 0.0
		and state.register_pull(0, _red[2], state.clock) == 0.0,
		"A three-action chord accepts only its first non-echo action.")
	_expect(_snapshot(state) == before, "A rejected chord cannot change any model history.")
	_near(state.register_pull(1, _blue[0]), 10.35, EPSILON, "Coop gates are independent.")
	state.step(0.09999)
	before = _snapshot(state)
	_expect(state.register_pull(0, _red[1]) == 0.0, "The ceiling rejects, not scales, fast input.")
	_expect(_snapshot(state) == before, "Rejected pulls cannot restart the rate clock.")
	state.step(0.00001)
	var expected := 9.0 * (1.0 - state.strength[0] / 100.0)
	_near(state.register_pull(0, _red[1], state.clock), expected, EPSILON,
		"The exactly 0.10-second boundary accepts a new action.")
	_expect(state.accepted_pulls == [2, 1] and state.last_action[0] == _red[1],
		"Only accepted actions update counts and alternation history.")
	_near(state.last_pull_time[0], state.clock, 0.0, "Accepted time is always the model clock.")
	var exact_frames := PitState.new()
	exact_frames.register_pull(0, _red[0])
	for frame in 3:
		exact_frames.step(1.0 / 30.0)
	_expect(exact_frames.register_pull(0, _red[1]) > 0.0,
		"Three true 30-Hz frames are 0.10 seconds, not the design's rounded 0.0999.")
	var ceiling := PitState.new()
	for frame in 1000:
		ceiling.register_pull(0, _red[ceiling.accepted_pulls[0] % 3])
		ceiling.register_pull(1, _blue[ceiling.accepted_pulls[1] % 3])
		ceiling.step(0.001)
	_expect(ceiling.accepted_pulls == [10, 10], "A 1000-Hz source still accepts only 10 Hz.")
	var implicit_clock := PitState.new()
	implicit_clock.step(0.3)
	implicit_clock.register_pull(0, _red[0], -2.0)
	_near(implicit_clock.last_pull_time[0], implicit_clock.clock, 0.0,
		"A negative timestamp is the current-clock sentinel, not an earlier pull.")
	return true


func _test_cadence() -> bool:
	_near(_second_gain(0.09999), 0.0, 0.0, "Just before the hard ceiling is rejected.")
	_near(_second_gain(0.10), 9.0, EPSILON, "Cadence starts at 1.00 at 0.10 seconds.")
	_near(_second_gain(0.11), 9.0 * 1.075, EPSILON, "The cadence ramp is linear.")
	_near(_second_gain(0.11999), 9.0 * 1.149925, EPSILON, "The ramp's upper edge is open.")
	_near(_second_gain(0.12), 10.35, EPSILON, "The 0.12-second boundary enters the groove.")
	_near(_second_gain(0.44999), 10.35, EPSILON, "The groove extends up to 0.45 seconds.")
	_near(_second_gain(0.45), 9.0, EPSILON, "Exactly 0.45 seconds leaves the groove.")
	_near(_second_gain(0.6), 9.0, EPSILON, "Slow input is accepted without a groove bonus.")
	_near(_second_gain(0.2, true), _second_gain(0.2) * 0.35, EPSILON,
		"Repeating one action gives exactly 35% of an otherwise identical pull.")
	var repeated := PitState.new()
	repeated.register_pull(0, _red[0])
	repeated.step(0.2)
	repeated.register_pull(0, _red[0])
	_near(repeated.last_alternation[0], 0.35, 0.0, "The view can read accepted alternation.")
	repeated.step(0.2)
	repeated.register_pull(0, _red[2])
	_near(repeated.last_alternation[0], 1.0, 0.0, "Any different coop action alternates.")
	return true


func _second_gain(interval: float, repeat: bool = false) -> float:
	var state := PitState.new()
	state.register_pull(0, _red[0])
	state.step(interval)
	var taper := 1.0 - state.strength[0] / 100.0
	return state.register_pull(0, _red[0] if repeat else _red[1]) / taper


func _test_strength() -> bool:
	var state := PitState.new(18, 2.0, 0.5)
	for frame in 1800:
		for coop in 2:
			var actions := _red if coop == 0 else _blue
			state.register_pull(coop, actions[state.accepted_pulls[coop] % 3])
		state.step(FRAME)
		if state.strength[0] < 0.0 or state.strength[0] > PitState.MAX_STRENGTH:
			_expect(false, "Sustained maximum-power input must remain in the strength range.")
			break
	state.recentre()
	state.strength[0] = 99.9
	_expect(state.register_pull(0, _red[0]) > 0.0 and state.strength[0] <= 100.0,
		"Diminishing returns approach the cap without crossing it.")
	var hitch := PitState.new(18, 1.0, 2.0)
	hitch.strength = [43.0, 59.0]
	hitch.step(1.0)
	_near(hitch.strength[0], 43.0 * exp(-2.4), EPSILON, "A long hitch uses exponential decay.")
	_near(hitch.strength[1], 59.0 * exp(-2.4), EPSILON, "Both coops share the decay law.")
	_expect(hitch.strength[0] > 0.0 and hitch.strength[1] > 0.0,
		"A one-second frame at decay 2 cannot make strength zero or negative.")
	var assisted := PitState.new(12, 1.5, 1.5, 0.6)
	_expect(assisted.L == 12 and assisted.pull_power == 1.5
		and assisted.strength_decay == 1.5 and assisted.gameplay_speed == 0.6,
		"The constructor retains all supplied configuration.")
	_near(assisted.register_pull(0, _red[0]), 9.0 * 1.5 * 0.6 * 1.15, EPSILON,
		"Gameplay-speed assistance scales pull gain along with motion and decay.")
	return true


func _test_deadzone_and_hold() -> bool:
	var equal := PitState.new()
	equal.rope = 0.125
	equal.strength = [50.0, 50.0]
	equal.step(0.03)
	_near(equal.rope, 0.125, 0.0, "Equal strength cannot move the knot.")
	_near(equal.scores[0], 0.075, EPSILON, "Fractional held-ground points must not truncate.")
	_near(equal.scores[1], 0.0, 0.0, "Only the coop holding favourable ground scores.")
	for difference in [0.0, 1.49999, 1.5]:
		var tied := PitState.new()
		tied.strength = [20.0 + difference, 20.0]
		tied.step(5.0)
		_near(tied.rope, 0.0, 0.0, "Deadzone-bound decay cannot creep (%s)." % difference)
	var stopping := PitState.new()
	stopping.strength[0] = 2.0
	var stop_time := log(2.0 / 1.5) / 1.2
	var velocity := 2.2 * 2.0 / 40.0
	var destination := velocity * (1.0 - exp(-1.2 * stop_time)) / 1.2
	var moving_area := velocity * (stop_time - (1.0 - exp(-1.2 * stop_time)) / 1.2) / 1.2
	stopping.step(10.0)
	_near(stopping.rope, destination, EPSILON, "Decay stops motion at the deadzone crossing.")
	_near(stopping.scores[0], 20.0 * (moving_area + destination * (10.0 - stop_time)),
		EPSILON, "Held ground continues scoring after motion enters the deadzone.")
	var crossing := PitState.new()
	crossing.rope = -0.1
	crossing.strength[0] = 100.0
	crossing.step(0.1)
	var centre_time := 0.1 / 2.2
	_near(crossing.scores[1], 20.0 * 0.1 * centre_time / 2.0, EPSILON,
		"The old leader banks only its pre-centre triangle of held ground.")
	_near(crossing.scores[0], 20.0 * 0.12 * (0.1 - centre_time) / 2.0, EPSILON,
		"The new leader banks only its post-centre triangle of held ground.")
	return true


func _test_notches() -> bool:
	var state := PitState.new(18)
	state.strength[0] = 100.0
	state.step(1.5)
	_expect(state.captures == [3, 0] and state.deepest == [3, 0]
		and state.streaks == [3, 0] and state.best_streaks == [3, 0],
		"A hitch crossing three notches must process all three captures.")
	_expect(state.scores[0] > 3.0 * PitState.NOTCH_POINTS and state.extreme[1] == 0.0,
		"Capture bonuses supplement hold points; the other coop has no favourable extreme.")
	var banked := state.scores[0]
	var high_water := state.extreme[0]
	state.strength = [0.0, 100.0]
	state.step(0.45)
	_expect(state.losses == [1, 0] and state.streaks == [0, 0]
		and state.best_streaks[0] == 3 and state.deepest[0] == 3,
		"Retreat across owned ground resets the streak, not its records.")
	_expect(state.scores[0] > banked and state.extreme[0] == high_water,
		"Retreat cannot erase banked points or the deepest favourable position.")
	banked = state.scores[0]
	var previous := state.rope
	state.strength = [100.0, 0.0]
	state.step(0.45)
	var held_points := 20.0 * (previous + state.rope) * 0.45 / 2.0
	_near(state.scores[0] - banked, held_points, EPSILON,
		"Recapture never pays the global deepest-notch bonus twice.")
	_expect(state.captures[0] == 4 and state.streaks[0] == 1
		and state.best_streaks[0] == 3 and state.deepest[0] == 3,
		"Recapture is still a capture and starts a new consecutive streak.")
	var blue := PitState.new(18)
	blue.strength[1] = 100.0
	blue.step(1.5)
	_expect(blue.captures == [0, 3] and blue.streaks == [0, 3],
		"Negative rope crossings belong to the blue coop.")
	_near(blue.extreme[1], -blue.rope, EPSILON,
		"Blue's extreme is a positive favourable magnitude, not signed rope.")
	_near(blue.extreme[0], 0.0, 0.0, "A losing coop cannot inherit its opponent's extreme.")
	return true


func _test_pins_and_recentering() -> bool:
	for length in range(6, 19):
		for coop in 2:
			var state := PitState.new(length)
			state.rope = (float(length) - 0.1) * (1.0 if coop == 0 else -1.0)
			state.strength[coop] = 100.0
			state.scores[1 - coop] = 50000.0
			_expect(state.step(100.0) == coop, "Both goal lines pin at L=%d." % length)
			_near(absf(state.rope), float(length), 0.0, "A pin clamps exactly to its goal.")
			_near(state.scores[coop], 52000.0, 0.0,
				"Pin ordering uses max(winner, loser) plus the bonus once.")
			var before := _snapshot(state)
			_expect(state.step(2.0) == -1 and state.register_pull(coop,
				_red[0] if coop == 0 else _blue[0]) == 0.0,
				"A pinned exchange cannot report another win or accept a pull.")
			_expect(_snapshot(state) == before, "Pin locking freezes every model field.")
	var pin := PitState.new(6)
	pin.rope = 5.5
	pin.strength[0] = 100.0
	var pin_speed := 2.2 * sqrt(0.6)
	var pin_time := 0.5 / pin_speed
	pin.step(20.0)
	_near(pin.clock, pin_time, EPSILON, "A long frame stops the model clock at the actual pin.")
	_near(pin.scores[0], 20.0 * (5.5 + 6.0) * pin_time / 2.0 + 100.0 + 2000.0,
		EPSILON, "Hold scoring ends at the pin, not at the end of a long frame.")
	var saved := _snapshot(pin)
	pin.recentre()
	_expect(pin.rope == 0.0 and pin.strength == [0.0, 0.0]
		and pin.streaks == [0, 0] and pin.pin_winner == -1,
		"Recentering clears only the exchange's live pulling state.")
	_expect(pin.last_action == [&"", &""] and pin.last_pull_time == [-INF, -INF]
		and pin.last_alternation == [1.0, 1.0],
		"Recentering restores first-pull and alternation history.")
	for field in ["clock", "scores", "captures", "losses", "accepted_pulls",
		"deepest", "extreme", "best_streaks"]:
		_expect(_snapshot(pin)[field] == saved[field], "Recentering preserves %s." % field)
	_near(pin.register_pull(0, _red[0]), 10.35, EPSILON,
		"A new life accepts an in-groove first pull without resetting the match clock.")
	pin.rope = -5.9
	pin.strength = [0.0, 100.0]
	_expect(pin.step(1.0) == 1 and pin.scores[1] > pin.scores[0],
		"The other coop can win a later life and receives the same pin ordering.")
	var frozen := PitState.new()
	frozen.register_pull(0, _red[0])
	frozen.freeze()
	saved = _snapshot(frozen)
	_expect(frozen.step(5.0) == -1 and frozen.register_pull(1, _blue[0]) == 0.0,
		"Timeout freezing rejects all further simulation input.")
	_expect(_snapshot(frozen) == saved, "A finished round's clock and scores are immutable.")
	frozen.recentre()
	_expect(frozen.finished and frozen.register_pull(0, _red[0]) == 0.0,
		"Recentering must not accidentally reopen a finished round.")
	return true


func _test_partitioning() -> bool:
	var whole := PitState.new(18)
	var split := PitState.new(18)
	var states: Array[PitState] = [whole, split]
	for state in states:
		state.rope = -0.04
		state.strength = [18.0, 4.0]
	whole.step(0.1)
	for frame in 6:
		split.step(0.1 / 6.0)
	_states_near(whole, split, "0.1 seconds versus six equal slices")
	var baseline := _partition_fixture()
	baseline.step(7.0)
	for frequency in [30, 60, 144]:
		var state := _partition_fixture()
		for frame in 7 * frequency:
			state.step(1.0 / float(frequency))
		_states_near(baseline, state, "%d Hz through clamp, centre and deadzone" % frequency)
	var irregular := _partition_fixture()
	for duration in [0.000000001, 0.033, 0.017, 0.85, 2.8, 3.299999999]:
		irregular.step(duration)
	_states_near(baseline, irregular, "Irregular hitch partition")
	var pin_whole := PitState.new(6)
	pin_whole.rope = 5.5
	pin_whole.strength[0] = 100.0
	pin_whole.step(5.0)
	for frequency in [30, 60, 144]:
		var pin_split := PitState.new(6)
		pin_split.rope = 5.5
		pin_split.strength[0] = 100.0
		for frame in 5 * frequency:
			pin_split.step(1.0 / float(frequency))
		_states_near(pin_whole, pin_split, "%d-Hz pin time and banked score" % frequency)
	var inert := _partition_fixture()
	var before := _snapshot(inert)
	_expect(inert.step(0.0) == -1 and _snapshot(inert) == before,
		"A zero-duration step is strictly inert.")
	inert.rope = float(inert.L)
	before = _snapshot(inert)
	_expect(inert.step(0.0) == -1 and _snapshot(inert) == before,
		"Zero delta cannot even detect a newly supplied goal-line position.")
	return true


func _partition_fixture() -> PitState:
	var state := PitState.new(18, 1.0, 1.3, 0.8)
	state.rope = -2.35
	state.strength = [93.0, 3.0]
	return state


func _test_equilibria() -> bool:
	var table: Array[Array] = [
		[2.0, 13.52, 17.98, 9.87],
		[3.0, 21.38, 25.94, 17.39],
		[4.0, 26.62, 30.82, 22.83],
		[6.0, 35.26, 38.91, 31.86],
		[8.0, 42.08, 45.32, 39.01],
		[10.0, 43.97, 46.66, 41.38],
	]
	for row in table:
		var frequency: float = row[0]
		var measured := _measure_cycle(frequency)
		var slow := _ideal_cycle(60.0 / ceil(60.0 / frequency))
		var fast := _ideal_cycle(60.0 / floor(60.0 / frequency))
		# A periodic source lands on either neighbouring whole-frame interval.
		# Their equilibria bound quantization; 0.02 covers the printed table's rounding.
		_near(measured.mean, row[1],
			maxf(absf(slow.mean - row[1]), absf(fast.mean - row[1])) + 0.02,
			"%.2f-Hz real-frame mean matches the quantized table." % frequency)
		_near(measured.peak, row[2],
			maxf(absf(slow.peak - row[2]), absf(fast.peak - row[2])) + 0.02,
			"%.2f-Hz real-frame peak matches the quantized table." % frequency)
		_near(measured.trough, row[3],
			maxf(absf(slow.trough - row[3]), absf(fast.trough - row[3])) + 0.02,
			"%.2f-Hz real-frame trough matches the quantized table." % frequency)
		_near(measured.frequency, frequency, EPSILON, "Frame scheduling preserves average rate.")
	var previous := 0.0
	for index in 161:
		var frequency := 2.0 + float(index) * 0.05
		var measured := _measure_cycle(frequency)
		_expect(measured.mean + EPSILON >= previous,
			"Real-frame mean cannot fall while accelerating to %.2f Hz." % frequency)
		_near(measured.frequency, frequency, EPSILON,
			"Fractional frequency %.2f Hz must not truncate to an integer frame rate." % frequency)
		previous = measured.mean
	var clean := _measure_cycle(3.0)
	var mash := _measure_cycle(10.0, true)
	_near(mash.mean, 21.05, 0.02, "A single-key 10-Hz mash matches its own equilibrium.")
	_expect(clean.mean > mash.mean, "Comfortable clean 3-Hz alternation beats one-key 10-Hz mashing.")
	var assisted := _measure_cycle(10.0, false, 0.6)
	var normal := _measure_cycle(10.0)
	_near(assisted.mean, _ideal_cycle(10.0, false, 0.6).mean, EPSILON,
		"Assisted discrete equilibrium agrees with its own closed form.")
	_expect(normal.mean > assisted.mean + 0.4,
		"Discrete pull gain/decay scaling is not exact equilibrium invariance.")
	print("60-Hz equilibrium: clean 3 Hz %.5f > single-key 10 Hz %.5f; "
		% [clean.mean, mash.mean]
		+ "8-Hz quantization is bounded by neighbouring frame intervals.")
	print("Discrete 10-Hz mean: speed 1.0 %.5f; speed 0.6 %.5f (approximately invariant)."
		% [normal.mean, assisted.mean])
	return true


func _measure_cycle(frequency: float, single: bool = false, speed: float = 1.0) -> Cycle:
	var state := PitState.new(10, 1.0, 1.0, speed)
	var result := Cycle.new()
	var pull_index := 0
	var measured_pulls := 0
	var settling_frames := int(EQUILIBRIUM_SECONDS * 60.0)
	var rate := 1.2 * speed
	var frame_area_factor := (1.0 - exp(-rate * FRAME)) / rate
	for frame in 2 * settling_frames:
		if state.clock + PitState.TIME_EPSILON >= float(pull_index) / frequency:
			if frame >= settling_frames:
				result.trough = minf(result.trough, state.strength[0])
			var action_index := 0 if single else pull_index % 3
			var gain := state.register_pull(0, _red[action_index])
			state.register_pull(1, _blue[action_index])
			if frame >= settling_frames and gain > 0.0:
				result.peak = maxf(result.peak, state.strength[0])
				measured_pulls += 1
			pull_index += 1
		if frame >= settling_frames:
			result.mean += state.strength[0] * frame_area_factor
		state.step(FRAME)
	result.mean /= EQUILIBRIUM_SECONDS
	result.frequency = float(measured_pulls) / EQUILIBRIUM_SECONDS
	return result


func _ideal_cycle(frequency: float, single: bool = false, speed: float = 1.0) -> Cycle:
	var interval := 1.0 / frequency
	var cadence := 1.0
	if interval < 0.12:
		cadence = 1.0 + 0.15 * (interval - 0.10) / 0.02
	elif interval < 0.45:
		cadence = 1.15
	var gain := 9.0 * cadence * (0.35 if single else 1.0) * speed
	var rate := 1.2 * speed
	var decay := exp(-rate * interval)
	var result := Cycle.new()
	result.peak = gain / (1.0 - decay + gain * decay / 100.0)
	result.trough = result.peak * decay
	result.mean = result.peak * (1.0 - decay) / (rate * interval)
	return result


func _snapshot(state: PitState) -> Dictionary:
	return {
		"clock": state.clock, "rope": state.rope, "strength": state.strength.duplicate(),
		"scores": state.scores.duplicate(), "streaks": state.streaks.duplicate(),
		"best_streaks": state.best_streaks.duplicate(), "captures": state.captures.duplicate(),
		"losses": state.losses.duplicate(), "accepted_pulls": state.accepted_pulls.duplicate(),
		"deepest": state.deepest.duplicate(), "extreme": state.extreme.duplicate(),
		"last_action": state.last_action.duplicate(), "last_pull_time": state.last_pull_time.duplicate(),
		"last_alternation": state.last_alternation.duplicate(),
		"pin_winner": state.pin_winner, "finished": state.finished,
	}


func _states_near(expected: PitState, actual: PitState, label: String) -> void:
	_near(actual.clock, expected.clock, EPSILON, label + ": clock")
	_near(actual.rope, expected.rope, EPSILON, label + ": rope")
	for coop in 2:
		_near(actual.strength[coop], expected.strength[coop], EPSILON, label + ": strength")
		_near(actual.scores[coop], expected.scores[coop], EPSILON, label + ": integrated points")
		_near(actual.extreme[coop], expected.extreme[coop], EPSILON, label + ": favourable extreme")
	_expect(actual.captures == expected.captures and actual.losses == expected.losses
		and actual.deepest == expected.deepest and actual.streaks == expected.streaks
		and actual.best_streaks == expected.best_streaks
		and actual.pin_winner == expected.pin_winner, label + ": discrete events")


func _near(actual: float, expected: float, tolerance: float, message: String) -> void:
	_expect(absf(actual - expected) <= tolerance,
		"%s Expected %.12f, got %.12f (tolerance %.12f)." % [message, expected, actual, tolerance])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
