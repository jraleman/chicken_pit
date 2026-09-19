extends Control

## Native-resolution rope position, strength and rebound keys above the 3D farm.

const PitState = preload("res://games/chicken_pit/pit/pit_state.gd")
const CREAM := Color("fff8e7")
const GOLD := Color("ffd45c")
const INK := Color("25342f")

var lead_text := "DEAD EVEN"
var _state: PitState
var _colors: Array[Color] = [Color.WHITE, Color.WHITE]
var _names := PackedStringArray(["RED COOP", "BLUE COOP"])
var _keys: Array[PackedStringArray] = [PackedStringArray(), PackedStringArray()]
var _actions: Array[Array] = [[], []]
var _lit: Array[int] = [-1, -1]
var _pulse: Array[float] = [0.0, 0.0]
var _quality := PackedStringArray(["ROLL YOUR KEYS", "ROLL YOUR KEYS"])
var _cpu := ""
var _round_rule := "GROUND HELD WINS"
var _panel: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	accessibility_name = "Tug meter"
	_panel = StyleBoxFlat.new()
	_panel.bg_color = Color(INK, 0.94)
	_panel.border_color = Color(CREAM, 0.24)
	_panel.set_border_width_all(1)
	_panel.set_corner_radius_all(12)
	queue_redraw()


func configure(
	colors: Array[Color], names: PackedStringArray, cpu: String,
	round_rule := "GROUND HELD WINS"
) -> void:
	_colors = colors.duplicate()
	_names = names
	_cpu = cpu
	_round_rule = round_rule
	queue_redraw()


func set_keys(coop: int, labels: PackedStringArray, actions: Array[StringName]) -> void:
	_keys[coop] = labels
	_actions[coop] = actions
	queue_redraw()


func reset() -> void:
	_lit = [-1, -1]
	_pulse = [0.0, 0.0]
	_quality = PackedStringArray(["ROLL YOUR KEYS", "ROLL YOUR KEYS"])


func present(state: PitState) -> void:
	_state = state
	if state.pin_winner >= 0:
		lead_text = "RED PINS BLUE!" if state.pin_winner == 0 else "BLUE PINS RED!"
	elif absf(state.rope) < 0.05:
		lead_text = "DEAD EVEN"
	else:
		lead_text = "%s +%.1f" % ["RED" if state.rope > 0.0 else "BLUE", absf(state.rope)]
	accessibility_description = (
		"%s. Red strength %d out of 100. Blue strength %d out of 100."
		% [lead_text, roundi(state.strength[0]), roundi(state.strength[1])]
	)
	queue_redraw()


func accepted_pull(coop: int, action: StringName, alternating: bool) -> void:
	_lit[coop] = _actions[coop].find(action)
	_pulse[coop] = 0.24
	_quality[coop] = "GOOD RHYTHM" if alternating else "SWITCH KEYS!"
	queue_redraw()


func _process(delta: float) -> void:
	var changed := false
	for coop in 2:
		if _pulse[coop] > 0.0:
			_pulse[coop] = maxf(_pulse[coop] - delta, 0.0)
			changed = true
	if changed:
		queue_redraw()


func _draw() -> void:
	if _state == null or _panel == null:
		return
	var wide := size.x >= 860.0
	var middle_width := minf(560.0, size.x * 0.38) if wide else size.x
	var middle := Rect2(Vector2((size.x - middle_width) * 0.5, 0.0),
		Vector2(middle_width, 82.0))
	draw_style_box(_panel, middle)
	var font := get_theme_default_font()
	_text(font, _round_rule, middle.position + Vector2(0.0, 19.0),
		middle_width, 13, Color(CREAM, 0.62))
	var bar := Rect2(middle.position + Vector2(25.0, 34.0),
		Vector2(middle_width - 50.0, 10.0))
	draw_rect(bar, Color(CREAM, 0.15))
	var center := bar.get_center()
	var marker_x := center.x - _state.rope / _state.L * bar.size.x * 0.5
	var color := GOLD if absf(_state.rope) < 0.05 else _colors[0 if _state.rope > 0 else 1]
	draw_rect(Rect2(Vector2(minf(center.x, marker_x), bar.position.y),
		Vector2(absf(marker_x - center.x), bar.size.y)), color)
	for index in range(-_state.L, _state.L + 1):
		var x := center.x + float(index) / _state.L * bar.size.x * 0.5
		draw_line(Vector2(x, bar.position.y - 3.0), Vector2(x, bar.end.y + 3.0),
			Color(CREAM, 0.9 if index == 0 else 0.35), 2.0 if index == 0 else 1.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(marker_x, center.y - 10.0), Vector2(marker_x + 7.0, center.y),
		Vector2(marker_x, center.y + 10.0), Vector2(marker_x - 7.0, center.y),
	]), CREAM)
	_text(font, lead_text, middle.position + Vector2(0.0, 71.0),
		middle_width, 19, color.lightened(0.2))

	var team_width := minf(316.0, (size.x - middle_width - 48.0) * 0.5) if wide \
		else (size.x - 12.0) * 0.5
	for coop in 2:
		var at := Vector2(0.0 if coop == 0 else size.x - team_width,
			0.0 if wide else 92.0)
		_draw_coop(font, coop, Rect2(at, Vector2(team_width, 82.0)))


func _draw_coop(font: Font, coop: int, rect: Rect2) -> void:
	draw_style_box(_panel, rect)
	var color := _colors[coop]
	draw_string(font, rect.position + Vector2(13.0, 20.0), _names[coop],
		HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 53.0, 16, color.lightened(0.25))
	draw_string(font, rect.position + Vector2(rect.size.x - 43.0, 20.0),
		"%02d" % roundi(_state.strength[coop]), HORIZONTAL_ALIGNMENT_RIGHT, 30.0, 16, CREAM)
	var gauge := Rect2(rect.position + Vector2(13.0, 29.0),
		Vector2(rect.size.x - 26.0, 5.0))
	draw_rect(gauge, Color(CREAM, 0.12))
	draw_rect(Rect2(gauge.position, Vector2(gauge.size.x * _state.strength[coop] / 100.0,
		gauge.size.y)), color)
	if coop == 1 and not _cpu.is_empty():
		draw_string(font, rect.position + Vector2(13.0, 63.0), "CPU / %s" % _cpu.to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 26.0, 17, CREAM)
		return
	for index in _keys[coop].size():
		var key := Rect2(rect.position + Vector2(13.0 + index * 42.0, 43.0),
			Vector2(34.0, 27.0))
		var active := _lit[coop] == index and _pulse[coop] > 0.0
		draw_rect(key, color if active else Color(CREAM, 0.10))
		draw_rect(key, Color(CREAM, 0.26), false, 1.0)
		_text(font, _keys[coop][index], key.position + Vector2(0.0, 20.0),
			key.size.x, 16, INK if active else CREAM)
	if rect.size.x >= 280.0:
		var text := _quality[coop] if _pulse[coop] > 0.0 else "ROLL YOUR KEYS"
		draw_string(font, rect.position + Vector2(149.0, 61.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 158.0, 12, Color(CREAM, 0.70))


func _text(font: Font, text: String, at: Vector2, width: float, size_px: int, color: Color) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, size_px, color)
