extends SceneTree

## Legal option corners and named birds must stay playable through the ordinary pull gates.

const PitState = preload("res://games/chicken_pit/pit/pit_state.gd")
const CpuBird = preload("res://games/chicken_pit/pit/cpu_bird.gd")
const Options = preload("res://games/chicken_pit/chicken_pit_options.gd")
const FRAME := 1.0 / 60.0
const EPSILON := 0.00000001
const POWERS: Array[float] = [0.5, 1.0, 2.0]
const DECAYS: Array[float] = [0.5, 1.0, 2.0]
const SPEEDS: Array[float] = [0.6, 0.8, 1.0]

var _failures := PackedStringArray()
var _red: Array[StringName] = Options.pull_actions(0)
var _blue: Array[StringName] = Options.pull_actions(1)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var checks: Array[Callable] = [
		_test_option_matrix, _test_cpu_hysteresis, _test_hen_breathers,
		_test_rooster_bursts, _test_cpu_determinism_and_gates, _test_human_matches,
	]
	for check in checks:
		_expect(check.call() == true, "Matrix check aborted: %s." % check.get_method())
	if _failures.is_empty():
		print("Chicken Pit matrix tests passed: legal configurations and all three CPU birds.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_option_matrix() -> bool:
	var configurations := 0
	var earliest_pin := INF
	var latest_pin := 0.0
	var slowest := ""
	for power in POWERS:
		for decay in DECAYS:
			for length in range(6, 19):
				for speed in SPEEDS:
					var state := PitState.new(length, power, decay, speed)
					var label := "power %.1f / decay %.1f / L %d / speed %.1f" \
						% [power, decay, length, speed]
					var first_notch := INF
					for frame in 40 * 60:
						state.register_pull(0, _red[state.accepted_pulls[0] % 3], state.clock)
						var winner := state.step(FRAME)
						if first_notch == INF and state.captures[0] > 0:
							first_notch = state.clock
						if winner >= 0:
							break
					_expect(first_notch <= 15.0, label + ": perfect input captures before 15 seconds.")
					_expect(state.strength[0] > 0.0 and state.rope > 0.0 and state.scores[0] > 0.0,
						label + ": proportional decay never leaves an inert match.")
					_expect(state.pin_winner == 0 and state.clock >= 3.0 and state.clock <= 40.0,
						label + ": uncontested perfect play must pin in 3..40 seconds.")
					_expect(state.scores[0] > state.scores[1],
						label + ": the winning pin must also win on score.")
					earliest_pin = minf(earliest_pin, state.clock)
					if state.clock > latest_pin:
						latest_pin = state.clock
						slowest = label
					configurations += 1
	_expect(configurations == 351, "The matrix is the full 3 x 3 x 13 x 3 Cartesian product.")
	print("Option matrix: %d configurations; dominance pins %.3f..%.3f seconds (%s)."
		% [configurations, earliest_pin, latest_pin, slowest])
	return true


func _test_cpu_hysteresis() -> bool:
	_expect(CpuBird.bird_name(0) == "Chick" and CpuBird.bird_name(1) == "Hen"
		and CpuBird.bird_name(2) == "Rooster", "Difficulty names match the declared bird roster.")
	var state := PitState.new()
	var bird := CpuBird.new(0, 31)
	state.strength = [21.0, 21.0]
	_expect(bird.update(state) == 0.0 and bird.resting,
		"Strength above the upper hysteresis threshold enters rest.")
	state.step(FRAME)
	state.strength = [18.0, 18.0]
	_expect(bird.update(state) == 0.0 and bird.resting,
		"Inside the hysteresis band, a resting bird stays resting.")
	state.step(FRAME)
	state.strength = [15.0, 15.0]
	var before := state.strength[1]
	var gain := bird.update(state)
	_expect(gain > 0.0 and not bird.resting and gain == state.strength[1] - before,
		"Below the lower band, the return value is an ordinary pull's actual strength gain.")
	_expect(state.last_action[1] == _blue[0] and state.accepted_pulls[1] == 1,
		"The controller starts its rotation with a real blue-coop action.")
	state.step(FRAME)
	state.strength = [18.0, 18.0]
	_expect(bird.update(state) == 0.0 and not bird.resting,
		"An active bird holds cadence inside the band but still respects its rate cap.")
	state.step(FRAME)
	state.rope = 4.0
	state.strength = [80.0, 80.0]
	bird.update(state)
	_in_band(bird.target, 18.0, "Chick keeps its normal target at exactly 40% behind.")
	state.step(FRAME)
	state.rope = 4.01
	bird.update(state)
	_in_band(bird.target, 11.0, "Chick gives up some strength beyond 40% behind.")
	state.step(FRAME)
	state.rope = 0.0
	bird.update(state)
	_in_band(bird.target, 18.0, "Chick recovers its normal target when the lead shrinks.")
	return true


func _test_hen_breathers() -> bool:
	var state := PitState.new()
	var bird := CpuBird.new(1, 97)
	state.strength = [80.0, 80.0]
	bird.update(state)
	_in_band(bird.target, 26.0, "Hen starts at its primary target.")
	state.step(FRAME)
	state.rope = 0.1
	bird.update(state)
	_in_band(bird.target, 32.0, "Hen raises its target by six while behind.")
	state.step(FRAME)
	state.rope = -3.0
	bird.update(state)
	_in_band(bird.target, 20.0, "Hen lowers its target by six while comfortably ahead.")
	state.rope = 0.0
	var starts: Array[float] = []
	var durations: Array[float] = []
	var was_breathing := false
	for frame in 22 * 60:
		state.strength = [80.0, 80.0]
		state.step(FRAME)
		bird.update(state)
		var breathing := bird.target == 0.0
		if breathing and not was_breathing:
			starts.append(state.clock)
		elif not breathing and was_breathing:
			durations.append(state.clock - starts.back())
		if breathing:
			_expect(bird.resting, "A zero-target breather never attempts a pull.")
		was_breathing = breathing
	_expect(starts.size() >= 3 and durations.size() >= 2,
		"Hen takes repeated, finite breathers on the model clock.")
	if not starts.is_empty():
		_expect(starts[0] >= 4.0 and starts[0] <= 7.0 + FRAME,
			"The first breather starts after four to seven seconds.")
	for index in range(1, starts.size()):
		var interval := starts[index] - starts[index - 1]
		_expect(interval >= 4.0 - EPSILON and interval <= 7.0 + FRAME,
			"Hen breather starts remain four to seven seconds apart.")
	for duration in durations:
		_expect(duration >= 0.6 - EPSILON and duration <= 1.1 + FRAME,
			"Every observed breather lasts 0.6..1.1 seconds plus at most one frame.")
	return true


func _test_rooster_bursts() -> bool:
	var state := PitState.new()
	var bird := CpuBird.new(2, 53)
	state.strength = [60.0, 60.0]
	bird.update(state)
	_in_band(bird.target, 38.0, "Rooster rests below a strong player's normal ceiling.")
	state.step(FRAME)
	state.strength = [10.0, 60.0]
	bird.update(state)
	_in_band(bird.target, 46.0, "A newly weak player triggers a Rooster burst.")
	state.strength = [60.0, 60.0]
	state.step(1.49)
	bird.update(state)
	_in_band(bird.target, 46.0, "The burst persists for its full 1.5 seconds.")
	state.strength = [60.0, 60.0]
	state.step(0.02)
	bird.update(state)
	_in_band(bird.target, 38.0, "A completed burst returns to Rooster's primary target.")
	state.rope = 8.0
	state.strength = [60.0, 60.0]
	state.step(FRAME)
	bird.update(state)
	_in_band(bird.target, 46.0, "The last two notches activate Rooster's panic target.")
	state.rope = 0.0
	state.strength = [60.0, 60.0]
	state.step(2.0)
	state.strength = [60.0, 60.0]
	bird.update(state)
	_in_band(bird.target, 46.0, "Panic is latched for the exchange, not a short breather.")
	bird.reset(state.clock)
	bird.update(state)
	_in_band(bird.target, 38.0, "A new exchange resets panic at the existing match clock.")
	return true


func _test_cpu_determinism_and_gates() -> bool:
	for difficulty in 3:
		var first := PitState.new()
		var second := PitState.new()
		var a := CpuBird.new(difficulty, 1234)
		var b := CpuBird.new(difficulty, 1234)
		var previous_pull := -INF
		var previous_action := &""
		var pulls := 0
		for frame in 12 * 60:
			if frame % 6 == 0:
				first.register_pull(0, _red[first.accepted_pulls[0] % 3])
				second.register_pull(0, _red[second.accepted_pulls[0] % 3])
			var before := first.accepted_pulls[1]
			var gain := a.update(first)
			randf()
			var duplicate_gain := b.update(second)
			_expect(gain == duplicate_gain and a.target == b.target and a.resting == b.resting,
				"Seeded CPU decisions are independent of the engine's shared random stream.")
			_expect(first.accepted_pulls[1] - before <= 1,
				"A CPU update can accept at most one pull.")
			if first.accepted_pulls[1] > before:
				var interval := first.clock - previous_pull
				_expect(interval + EPSILON >= 1.0 / CpuBird.MAX_RATES[difficulty],
					"Every bird respects its own rate ceiling and the human ceiling.")
				_expect(first.last_action[1] == _blue[pulls % 3]
					and first.last_action[1] != previous_action
					and first.last_alternation[1] == 1.0,
					"Accepted CPU pulls rotate all three actions through normal alternation.")
				previous_action = first.last_action[1]
				previous_pull = first.clock
				pulls += 1
			_expect(a.update(first) == 0.0 and first.accepted_pulls[1] <= before + 1,
				"A repeated update without a new model frame cannot pull again.")
			first.step(FRAME)
			second.step(FRAME)
			_expect(first.rope == second.rope and first.scores == second.scores
				and first.strength == second.strength,
				"Equal seeds and frame input produce identical complete simulations.")
		_expect(pulls > 0, "Every bird must actually use the public pull path.")
	var state := PitState.new()
	var bird := CpuBird.new(2, 17)
	state.register_pull(1, _blue[0])
	_expect(bird.update(state) == 0.0 and state.accepted_pulls[1] == 1,
		"A CPU cannot bypass an already-used same-frame human gate.")
	state.strength = [40.0, 40.0]
	state.step(5.0)
	var before := state.accepted_pulls[1]
	bird.update(state)
	_expect(state.accepted_pulls[1] == before + 1,
		"A five-second hitch produces one new CPU pull, not a catch-up chord.")
	state.freeze()
	before = state.accepted_pulls[1]
	_expect(bird.update(state) == 0.0 and state.accepted_pulls[1] == before,
		"A finished match cannot be revived by the CPU controller.")
	var jittered := CpuBird.new(0, 100)
	var other := CpuBird.new(0, 101)
	var a_state := PitState.new()
	var b_state := PitState.new()
	jittered.update(a_state)
	other.update(b_state)
	_in_band(jittered.target, 18.0, "Per-pull target jitter stays within four percent.")
	_in_band(other.target, 18.0, "Every independent seed keeps the same legal target band.")
	_expect(jittered.target != other.target, "Different seeds vary targets rather than global force.")
	return true


func _test_human_matches() -> bool:
	for seed_value in [1, 7, 23]:
		for difficulty in 3:
			var state := _human_match(difficulty, 10.0, seed_value)
			var label := "Perfect human versus %s (seed %d)" \
				% [CpuBird.bird_name(difficulty), seed_value]
			_expect(state.pin_winner != 1 and state.scores[0] > state.scores[1],
				label + ": clean maximum-rate input must win the default match.")
			_expect(state.accepted_pulls[1] > 0, label + ": victory must include an active rival.")
		var mediocre := _human_match(0, 3.0, seed_value)
		_expect(mediocre.pin_winner != 1 and mediocre.scores[0] > mediocre.scores[1],
			"A comfortable clean 3-Hz player must beat Chick at defaults (seed %d)." % seed_value)
	return true


func _human_match(difficulty: int, human_frequency: float, seed_value: int) -> PitState:
	var state := PitState.new()
	var bird := CpuBird.new(difficulty, seed_value)
	var pull_index := 0
	for frame in 45 * 60:
		if state.clock + PitState.TIME_EPSILON >= float(pull_index) / human_frequency:
			state.register_pull(0, _red[pull_index % 3], state.clock)
			pull_index += 1
		bird.update(state)
		if state.step(FRAME) >= 0:
			break
	state.freeze()
	return state


func _in_band(actual: float, base: float, message: String) -> void:
	_expect(actual >= base * 0.96 - EPSILON and actual <= base * 1.04 + EPSILON,
		"%s Expected %.2f +/-4%%, got %.6f." % [message, base, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
