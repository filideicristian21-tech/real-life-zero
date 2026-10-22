extends Node3D
## Scena principale: costruisce San Vito al Colle, il giocatore, gli NPC, la UI e gestisce il flusso.

var town: Town
var player: Player
var ui: GameUI
var day_night: DayNight
var npcs: Array[NPC] = []
var _cam_touch := -1
var _cam_last := Vector2.ZERO
var test_mode := false
var player_car: PlayerCar = null

func _ready() -> void:
	test_mode = OS.get_cmdline_user_args().has("--test") or Game.headless_test
	Game.world = self
	town = Town.new()
	town.name = "Town"
	add_child(town)
	ui = GameUI.new()
	ui.main = self
	town.build(ui)
	day_night = DayNight.new()
	add_child(day_night)
	day_night.setup(town, self)
	player = Player.new()
	player.name = "Player"
	add_child(player)
	Game.player = player
	player.teleport(town.spawn_home, 0.0)
	_spawn_npcs()
	add_child(ui)
	Game.game_started.connect(_on_game_started)
	Game.evicted.connect(func(): ui.show_evicted())
	Life.car_changed.connect(_sync_car)
	Game.day_summary.connect(func(info): ui.queue_day_summary(info))
	Jobs.shift_ended.connect(func(paid, _a, _r):
		if not paid:
			Game.flags["last_shift_failed_day"] = GameTime.day()
		ui.close_shift())
	get_tree().root.size_changed.connect(func(): ui.layout())
	if not test_mode:
		ui.show_main_menu()

func _on_game_started() -> void:
	var p = Game.saved_player_pos
	if p is Array and p.size() == 3 and float(p[1]) > -5.0:
		player.teleport(Vector3(float(p[0]), float(p[1]) + 0.05, float(p[2])), Game.saved_player_yaw)
	else:
		player.teleport(town.spawn_home, 0.0)
	_sync_car(true)
	day_night.update(true)

## Crea/rimuove l'auto del giocatore in base a Life.car (acquisto, caricamento, nuova partita).
func _sync_car(force: bool = false) -> void:
	if player_car and (force or not Life.has_car()):
		if player.car == player_car:
			player.stop_driving(player_car)
		player_car.queue_free()
		player_car = null
	if Life.has_car() and player_car == null:
		var c: Dictionary = Life.car
		var md := Life.car_model()
		var p: Array = c.get("pos", [town.car_spawn.x, 0.02, town.car_spawn.z])
		player_car = PlayerCar.new()
		player_car.name = "PlayerCar"
		add_child(player_car)
		player_car.setup(str(c["model"]), Color(md.get("color", "#C9C2B2")), Vector3(float(p[0]), 0.02, float(p[2])), float(c.get("yaw", 0.0)))

func send_player_home() -> void:
	player.teleport(town.spawn_home, 0.0)

func open_pause() -> void:
	if Game.playing and not get_tree().paused:
		ui.open_pause()

func show_dialogue(who: String, lines: Array, npc: NPC) -> void:
	ui.show_dialogue(who, lines, npc)

func _spawn_npcs() -> void:
	var y := Town.CURB
	var bar_h: Dictionary = Data.economy["bar"]["hours"]
	var mm_h: Dictionary = Data.economy["minimarket"]["hours"]
	var defs := [
		["barista_titolare", "res://assets/characters/casual.glb", [
			{"open_hours": bar_h, "path": [Vector3(1.5, y, -51.6), Vector3(8.5, y, -51.6)], "speed": 0.9}], {"LightBrown": Color("#F1EEE6"), "LightBlue": Color("#1E1E22"), "Red_Dark": Color("#4A3426"), "Hair": Color("#3A3A3A")}, 1.74],
		["cassiera_minimarket", "res://assets/characters/cassiera.glb", [
			{"open_hours": mm_h, "path": [Vector3(10.0, y, 11.5)], "stand_yaw": PI / 2.0}], {"Orange": Color("#2F4F6A")}, 1.66],
		["padrone_di_casa", "res://assets/characters/padrone.glb", [
			{"from": "08:00", "to": "10:00", "path": [Vector3(-45.6, y, -24.0)], "stand_yaw": -PI / 2.0},
			{"from": "18:00", "to": "19:30", "path": [Vector3(-45.6, y, -24.0)], "stand_yaw": -PI / 2.0}], {}, 1.75],
		["passante_anziana", "res://assets/characters/anziana.glb", [
			{"from": "08:00", "to": "12:00", "path": [Vector3(-30, y, -5.6), Vector3(-9, y, -8.5), Vector3(4, y, -18), Vector3(16, y, -18), Vector3(26, y, -8.5), Vector3(18, y, -5.4), Vector3(14, y, -0.5), Vector3(18, y, 5.6), Vector3(26, y, 5.6), Vector3(18, y, 5.6), Vector3(14, y, 0.5), Vector3(10, y, -5.6)], "speed": 0.9},
			{"from": "15:00", "to": "18:30", "path": [Vector3(-9, y, -8.5), Vector3(3, y, -30), Vector3(17, y, -30), Vector3(26, y, -10), Vector3(-9, y, -8.5)], "speed": 0.9}], {"Hair": Color("#C9C6C0"), "HairBase": Color("#B9B6B0"), "Shirt": Color("#8A6F8E"), "Pants": Color("#4A4440")}, 1.6],
		["passante_runner", "res://assets/characters/hoodie.glb", [
			{"from": "06:00", "to": "09:00", "path": [Vector3(-90, y, -5.5), Vector3(90, y, -5.5), Vector3(92, 0.05, 0), Vector3(90, y, 5.5), Vector3(-90, y, 5.5), Vector3(-92, 0.05, 0)], "speed": 3.4},
			{"from": "18:00", "to": "20:30", "path": [Vector3(-90, y, -5.5), Vector3(90, y, -5.5), Vector3(92, 0.05, 0), Vector3(90, y, 5.5), Vector3(-90, y, 5.5), Vector3(-92, 0.05, 0)], "speed": 3.4}], {"Purple": Color("#B23A3A"), "LightBlue": Color("#222428"), "Hair": Color("#1C1712")}, 1.78],
		["persona_fermata_bus", "res://assets/characters/pendolare.glb", [
			{"from": "06:40", "to": "09:10", "path": [Vector3(-20.0, y, -5.2)], "stand_yaw": 0.0},
			{"from": "17:00", "to": "19:30", "path": [Vector3(-20.0, y, -5.2)], "stand_yaw": 0.0}], {}, 1.72],
		# v0.3 (Lumen/Spark): personale dei nuovi luoghi, davanti alle vetrine; outfit senza loghi
		["impiegato_banca", "res://assets/characters/casual.glb", [
			{"open_hours": Data.life["bank"]["hours"], "path": [Vector3(35.0, y, -6.1)], "stand_yaw": 0.0}], {"LightBrown": Color("#A9C8E8"), "LightBlue": Color("#1C2740"), "Red_Dark": Color("#141414"), "Hair": Color("#55504A")}, 1.77],
		["commessa_vestiti", "res://assets/characters/cassiera.glb", [
			{"open_hours": Data.life["clothes_shop"]["hours"], "path": [Vector3(53.4, y, -6.1)], "stand_yaw": 0.0}], {"Orange": Color("#7A2E3A")}, 1.65],
		["istruttore_palestra", "res://assets/characters/hoodie.glb", [
			{"open_hours": Data.life["gym"]["hours"], "path": [Vector3(67.4, y, -6.1), Vector3(62.0, y, -6.1)], "speed": 0.8}], {"Purple": Color("#18181A"), "LightBlue": Color("#18181A"), "Hair": Color("#2A2018")}, 1.82],
		["cameriere_ristorante", "res://assets/characters/casual.glb", [
			{"open_hours": Data.life["restaurant"]["hours_lunch"].merged({"closed_days": Data.life["restaurant"]["closed_days"]}), "path": [Vector3(32.0, y, 6.1), Vector3(38.5, y, 6.1)], "speed": 0.8},
			{"open_hours": Data.life["restaurant"]["hours_dinner"].merged({"closed_days": Data.life["restaurant"]["closed_days"]}), "path": [Vector3(32.0, y, 6.1), Vector3(38.5, y, 6.1)], "speed": 0.8}], {"LightBrown": Color("#F4F2EC"), "LightBlue": Color("#141414"), "Red_Dark": Color("#141414"), "Hair": Color("#2B2420")}, 1.74],
		["venditore_auto_usate", "res://assets/characters/padrone.glb", [
			{"open_hours": Data.life["cars"]["dealer"]["hours"], "path": [Vector3(78.0, 0.05, 12.4), Vector3(66.0, 0.05, 12.4)], "speed": 0.7}], {}, 1.72],
		["capo_rider", "res://assets/characters/hoodie.glb", [
			{"from": "11:00", "to": "14:30", "path": [Vector3(-6.4, y, -25.6)], "stand_yaw": -PI / 2.0},
			{"from": "18:00", "to": "22:30", "path": [Vector3(-6.4, y, -25.6)], "stand_yaw": -PI / 2.0}], {"Purple": Color("#D9662B"), "LightBlue": Color("#2A3340"), "Hair": Color("#5A3A22")}, 1.68],
	]
	for d in defs:
		var n := NPC.new()
		add_child(n)
		n.setup(d[0], d[1], d[2], d[3], d[4])
		npcs.append(n)

func _unhandled_input(event: InputEvent) -> void:
	if not Game.playing or ui.is_modal_open():
		_cam_touch = -1
		return
	var s := get_viewport().get_visible_rect().size
	var sens: float = float(Data.balance["camera"]["sensitivity_touch"])
	if event is InputEventScreenTouch:
		if event.pressed and _cam_touch == -1 and event.position.x > s.x * 0.42:
			_cam_touch = event.index
			_cam_last = event.position
		elif not event.pressed and event.index == _cam_touch:
			_cam_touch = -1
	elif event is InputEventScreenDrag and event.index == _cam_touch:
		var d: Vector2 = event.position - _cam_last
		_cam_last = event.position
		player.rotate_camera(d * sens)
	elif event.is_action_pressed("interact"):
		player.try_interact()
	elif event.is_action_pressed("phone"):
		ui.toggle_phone()
	elif event.is_action_pressed("pause"):
		ui.open_pause()

## Riposo generico (panchina, fermata): fa passare il tempo e recupera un po' di energia.
func rest_minutes(mins: float, energy_gain: float, msg: String) -> void:
	ui.fade(func():
		GameTime.advance(mins)
		Needs.eat(0, energy_gain)
		Game.toast(msg + " (+%d min)" % int(mins), "info"))
