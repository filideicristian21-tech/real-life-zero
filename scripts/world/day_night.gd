class_name DayNight
extends Node
## Ciclo giorno/notte legato a GameTime: sole dinamico, cielo, ambiente, lampioni e finestre.

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var town: Town
var _acc := 0.0
var night_factor := 0.0

func setup(p_town: Town, parent: Node) -> void:
	town = p_town
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 32.0
	sun.shadow_bias = 0.05
	parent.add_child(sun)
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://assets/shaders/sky.gdshader")
	sky_mat.set_shader_parameter("panorama", load("res://assets/textures/sky_kloofendal_1k.hdr"))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# luce ambiente a colore (calcolata qui): niente ricalcolo della radiance del cielo a ogni cambio d'ora
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.08
	# SSAO non esiste nel renderer Compatibility (web/mobile): l'occlusione è finta (zoccoli scuri, ombre a terra)
	env.fog_enabled = true
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.15
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	update(true)

func _process(delta: float) -> void:
	_acc += delta
	if _acc > 0.25:
		_acc = 0.0
		update()

func update(_force: bool = false) -> void:
	var t := GameTime.minute_of_day() / 60.0 + fmod(GameTime.total_minutes, 1.0) / 60.0
	var rise := 6.5
	var set_h := 19.75
	var day_frac := (t - rise) / (set_h - rise)
	var elev := sin(clampf(day_frac, 0.0, 1.0) * PI) * 44.0   # sole basso e caldo (max 44°)
	var is_day := day_frac > 0.0 and day_frac < 1.0
	var az := lerpf(-100.0, 100.0, clampf(day_frac, 0.0, 1.0))
	if is_day:
		sun.rotation_degrees = Vector3(-max(elev, 4.0), az, 0)
	else:
		sun.rotation_degrees = Vector3(-35, 160, 0)   # luna
	var low := clampf(elev / 25.0, 0.0, 1.0)
	var sun_col := Color(1.0, 0.66, 0.42).lerp(Color("#FFE8C8"), low)
	var n := 0.0
	if not is_day:
		n = 1.0
	elif elev < 8.0:
		n = 1.0 - elev / 8.0
	night_factor = n
	sun.light_color = sun_col if is_day else Color(0.55, 0.62, 0.85)
	sun.light_energy = lerpf(0.55, 1.4, low) if is_day else 0.1
	sun.shadow_enabled = is_day and elev > 3.0
	var dusk_f := (1.0 - low) * (1.0 - n)
	sky_mat.set_shader_parameter("day_energy", lerpf(0.55, 1.0, low))
	sky_mat.set_shader_parameter("night", n)
	sky_mat.set_shader_parameter("dusk", dusk_f)
	sky_mat.set_shader_parameter("yaw", -az / 360.0)
	var day_amb := Color(0.74, 0.8, 0.88)
	var dusk_amb := Color(0.85, 0.66, 0.55)
	var night_amb := Color(0.2, 0.24, 0.38)
	env.ambient_light_color = day_amb.lerp(dusk_amb, dusk_f).lerp(night_amb, n)
	env.ambient_light_energy = lerpf(0.75, 0.5, n) + 0.2 * dusk_f
	env.fog_light_color = Color(0.72, 0.8, 0.88).lerp(Color(0.85, 0.62, 0.5), dusk_f).lerp(Color("#1B2235"), n)
	if town:
		town.set_night(n)
