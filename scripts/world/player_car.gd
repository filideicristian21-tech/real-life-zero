class_name PlayerCar
extends CharacterBody3D
## L'auto del giocatore: guida arcade, massimo 50 km/h, frena da sola davanti ai pedoni (Guard:
## niente investimenti, niente danni, niente suoni d'urto). Consuma benzina e usura via Life.

var speed := 0.0
var yaw := 0.0
var driving := false
var it: Interactable
var vis: Node3D
var _acc_m := 0.0
var _save_t := 0.0
var braking_for_ped := false
var kind := "ginestra"

func setup(model_id: String, color: Color, pos: Vector3, p_yaw: float) -> void:
	kind = "ginestra" if model_id.begins_with("utilitaria") else "corallo"
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.7, 1.1, CarKit.LENGTH[kind] - 0.2)
	cs.shape = bs
	cs.position.y = 0.8      # base a 0,25 m: sale sui cordoli dei marciapiedi senza incastrarsi
	add_child(cs)
	vis = CarKit.model(self, kind, color, 90.0)
	position = Vector3(pos.x, 0.02, pos.z)
	yaw = p_yaw
	rotation.y = yaw
	it = Interactable.make(self, Vector3(-1.3, 1.0, 0.0), "my_car", _prompt, _use, 2.6)

func _prompt() -> String:
	if driving:
		return "Scendi dall'auto (%d km/h)" % int(absf(speed) * 3.6)
	var why := Life.can_drive()
	if why != "":
		return "La tua auto · " + why
	return "La tua auto · Sali e guida (benzina %d%%)" % Life.fuel_pct()

func _use() -> void:
	if driving:
		exit_car()
	else:
		enter_car()

func enter_car() -> void:
	var why := Life.can_drive()
	if why != "":
		Game.toast(why, "warn")
		return
	driving = true
	Game.player.start_driving(self)
	Game.toast("Al volante: avanti/indietro per accelerare e frenare, sinistra/destra per sterzare. Limite 50 km/h.", "info")

func in_blue_zone() -> bool:
	return position.x > 20.0 and position.x < 62.0 and position.z > 1.4 and position.z < 4.3

func exit_car() -> void:
	if absf(speed) > 1.0:
		Game.toast("Fermati prima di scendere.", "info")
		return
	if Life.parking_needed(in_blue_zone()):
		var c := int(Data.life["cars"]["parking"]["blue_lines_cents_per_hour"])
		Game.toast("Strisce blu: paga il parcheggio (€ %s l'ora) dall'app Auto, oppure spostati sulle strisce bianche." % Data.euro(c), "warn")
		return
	driving = false
	speed = 0.0
	Game.player.stop_driving(self)
	_store()
	SaveSystem.save_game()

func _store() -> void:
	if Life.has_car():
		Life.car["pos"] = [position.x, position.y, position.z]
		Life.car["yaw"] = yaw

func _pedestrian_ahead() -> bool:
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw)) * signf(speed if absf(speed) > 0.1 else 1.0)
	var look := 3.0 + absf(speed) * 0.9
	for n in get_tree().get_nodes_in_group("pedestrian"):
		var p := n as Node3D
		if p == null or p == Game.player or not p.is_visible_in_tree():
			continue
		var to := p.global_position - global_position
		to.y = 0
		var ahead := to.dot(fwd)
		if ahead > 0.5 and ahead < look and absf(to.dot(Vector3(fwd.z, 0, -fwd.x))) < 1.6:
			return true
	return false

func _physics_process(dt: float) -> void:
	if not driving:
		velocity = Vector3.ZERO
		return
	var inp: Vector2 = Game.player.drive_input()
	var dcfg: Dictionary = Data.life["cars"]["drive"]
	var vmax := float(dcfg["max_speed_kmh"]) / 3.6
	var vrev := float(dcfg["reverse_kmh"]) / 3.6
	var throttle := -inp.y
	if Life.can_drive() != "":
		throttle = 0.0
	if throttle > 0.05:
		speed = (speed + 9.0 * dt * throttle) if speed >= 0.0 else move_toward(speed, 0.0, 14.0 * dt)
	elif throttle < -0.05:
		speed = move_toward(speed, -vrev, (14.0 if speed > 0.0 else 4.0) * dt)
	else:
		speed = move_toward(speed, 0.0, 3.5 * dt)
	speed = clampf(speed, -vrev, vmax)
	braking_for_ped = _pedestrian_ahead()
	if braking_for_ped:
		speed = move_toward(speed, 0.0, 30.0 * dt)
	var steer := inp.x * clampf(absf(speed) / 3.0, 0.0, 1.0) * (1.5 - 0.6 * clampf(absf(speed) / vmax, 0.0, 1.0))
	yaw -= steer * dt * signf(speed)
	rotation.y = yaw
	velocity = Vector3(-sin(yaw), 0, -cos(yaw)) * speed
	var before := global_position
	move_and_slide()
	if get_slide_collision_count() > 0:
		speed *= 0.5      # urto morbido contro muri e auto: niente danni né suoni
	global_position.y = 0.02
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_acc_m += moved
	if _acc_m > 5.0:
		Life.drive_distance(_acc_m)
		_acc_m = 0.0
		if Life.can_drive() != "" and absf(speed) < 0.2:
			Game.toast(Life.can_drive(), "warn")
	_save_t += dt
	if _save_t > 3.0:
		_save_t = 0.0
		_store()
