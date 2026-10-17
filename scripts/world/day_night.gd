class_name DayNight
extends Node
## Ciclo giorno/notte legato a GameTime: sole dinamico, cielo, ambiente, lampioni e finestre.

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var town: Town
var _acc := 0.0
var night_factor := 0.0

func setup(p_town: Town, parent: Node) -> void:
	town = p_town
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_bias = 0.05
	parent.add_child(sun)
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.004
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
	var elev := sin(clampf(day_frac, 0.0, 1.0) * PI) * 62.0
	var is_day := day_frac > 0.0 and day_frac < 1.0
	var az := lerpf(-100.0, 100.0, clampf(day_frac, 0.0, 1.0))
	if is_day:
		sun.rotation_degrees = Vector3(-max(elev, 4.0), az, 0)
	else:
		sun.rotation_degrees = Vector3(-35, 160, 0)   # luna
	var low := clampf(elev / 25.0, 0.0, 1.0)
	var sun_col := Color(1.0, 0.72, 0.5).lerp(Color(1.0, 0.97, 0.9), low)
	var n := 0.0
	if not is_day:
		n = 1.0
	elif elev < 8.0:
		n = 1.0 - elev / 8.0
	night_factor = n
	sun.light_color = sun_col if is_day else Color(0.55, 0.62, 0.85)
	sun.light_energy = lerpf(0.0, 1.25, low) if is_day else 0.12
	sun.shadow_enabled = is_day and elev > 3.0
	var day_sky := Color("#9EC3DB")
	var night_sky := Color(0.05, 0.07, 0.14)
	var dusk := Color(0.95, 0.6, 0.45)
	var top := day_sky.darkened(0.25).lerp(night_sky, n)
	var hor := day_sky.lightened(0.25).lerp(dusk, (1.0 - low) * (1.0 - n)).lerp(Color(0.12, 0.12, 0.2), n)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	sky_mat.ground_bottom_color = Color(0.2, 0.2, 0.2).lerp(Color(0.02, 0.02, 0.04), n)
	env.ambient_light_energy = lerpf(0.9, 0.35, n)
	env.fog_light_color = hor
	if town:
		town.set_night(n)
