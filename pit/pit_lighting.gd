extends Node

## A readable golden-hour cycle, using the existing key and fill rather than more lights.

const CYCLE_SECONDS := 96.0
const STILL_PHASE := 0.25
const EARLY_SKY := Color("667da6")
const LATE_SKY := Color("765b87")
const EARLY_HORIZON := Color("ffd29f")
const LATE_HORIZON := Color("ee9d83")
const EARLY_SUN := Color("ffdaa8")
const LATE_SUN := Color("ffbb91")
const EARLY_AMBIENT := Color("b9c9e4")
const LATE_AMBIENT := Color("b9acd5")

@onready var _sun: DirectionalLight3D = $"../Sun"
@onready var _fill: OmniLight3D = $"../Bounce"
@onready var _environment: Environment = ($"../WorldEnvironment" as WorldEnvironment).environment
@onready var _sky: ShaderMaterial = ($"../SkyDome" as MeshInstance3D).material_override as ShaderMaterial

var reduced_motion := false
var intense_effects := true
var inert := false
var _clock := 0.0
var _accent := 0.0
var _pressure := 0.0
var _cloud_material: StandardMaterial3D


func _ready() -> void:
	inert = DisplayServer.get_name() == "headless"
	_apply()


func reset_round() -> void:
	_clock = 0.0
	_accent = 0.0
	_pressure = 0.0
	_apply()


func set_cloud_material(material: StandardMaterial3D) -> void:
	_cloud_material = material
	_apply()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if value:
		_accent = 0.0
		_pressure = 0.0
	_apply()


func set_intense_effects(value: bool) -> void:
	intense_effects = value
	if not value:
		_accent = 0.0
		_pressure = 0.0
	_apply()


func update_lighting(delta: float, pressure: float, tension: float) -> void:
	if inert:
		return
	if not reduced_motion:
		var dt := maxf(delta, 0.0)
		_clock = fmod(_clock + dt, CYCLE_SECONDS)
		var amount := 1.0 - exp(-dt * 1.8)
		_accent = lerpf(_accent, clampf(tension, 0.0, 1.0) if intense_effects else 0.0, amount)
		_pressure = lerpf(_pressure, clampf(pressure, -1.0, 1.0) if intense_effects else 0.0, amount)
	_apply()


func _apply() -> void:
	if inert:
		return
	var phase := STILL_PHASE if reduced_motion else (1.0 - cos(_clock * TAU / CYCLE_SECONDS)) * 0.5
	var horizon := EARLY_HORIZON.lerp(LATE_HORIZON, phase)
	_sun.rotation_degrees = Vector3(lerpf(-34.0, -24.0, phase), lerpf(145.0, 158.0, phase), 0.0)
	_sun.light_color = EARLY_SUN.lerp(LATE_SUN, phase)
	_sun.light_energy = lerpf(0.50, 0.43, phase)
	_fill.light_color = Color("ffd1a1").lerp(Color("ffc19b"), phase)
	_fill.light_energy = lerpf(0.12, 0.17, phase) + _accent * 0.035
	_fill.position = Vector3(_pressure * 1.5, 4.5, 2.6)
	_environment.ambient_light_color = EARLY_AMBIENT.lerp(LATE_AMBIENT, phase)
	_environment.ambient_light_energy = lerpf(0.38, 0.42, phase)
	_environment.background_color = horizon
	_environment.fog_light_color = horizon.lerp(Color("eac5b3"), 0.4)
	_sky.set_shader_parameter("zenith_color", EARLY_SKY.lerp(LATE_SKY, phase))
	_sky.set_shader_parameter("horizon_color", horizon)
	var sun_direction := _sun.basis.z
	sun_direction.y = lerpf(-0.12, -0.23, phase)
	_sky.set_shader_parameter("sun_direction", sun_direction.normalized())
	if _cloud_material != null:
		_cloud_material.albedo_color = Color("ffe7cc").lerp(Color("ffd0b0"), phase)
