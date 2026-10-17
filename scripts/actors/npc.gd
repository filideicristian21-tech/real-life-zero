class_name NPC
extends CharacterBody3D
## NPC con orari: fuori dagli orari è "a casa" (nascosto, senza collisione).
## Nei suoi orari segue un percorso a waypoint (o resta fermo) con animazioni e collisioni,
## si ferma se il giocatore gli è davanti e parla con Interagisci (dialoghi di Lumen).

var npc_id := ""
var display_name := ""
var model: CharacterModel
var schedule: Array = []     # [{from:"08:00", to:"12:00", path:[Vector3...], loop:true, speed:1.2, stand_yaw:0}]
var active_block: Dictionary = {}
var wp_index := 0
var speed := 1.2
var anim_move := "walk"
var talk_point: Interactable
var _talk_timer := 0.0
var _cs: CollisionShape3D
var _gravity := 9.8
var home_pos := Vector3.ZERO
var face_player_t := 0.0

func setup(p_id: String, model_path: String, p_schedule: Array, recolor: Dictionary = {}, target_height: float = 1.75) -> void:
	npc_id = p_id
	display_name = Data.places["npcs"].get(p_id, p_id)
	name = "NPC_" + p_id
	schedule = p_schedule
	collision_layer = 4
	collision_mask = 1 | 2
	_cs = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	_cs.shape = cap
	_cs.position.y = 0.85
	add_child(_cs)
	model = CharacterModel.new()
	add_child(model)
	model.load_model(model_path, recolor, target_height)
	talk_point = Interactable.make(self, Vector3(0, 1.2, 0), "npc_" + p_id, func(): return "Parla con " + display_name, _talk, 1.8)
	_update_schedule(true)

func _block_active(b: Dictionary) -> bool:
	var m := GameTime.minute_of_day()
	if b.has("days") and not (GameTime.weekday_code() in b["days"]):
		return false
	if b.has("open_hours"):
		return GameTime.is_open(b["open_hours"])
	return m >= Data.hhmm_to_min(b["from"]) and m < Data.hhmm_to_min(b["to"])

func _update_schedule(force: bool = false) -> void:
	var found: Dictionary = {}
	for b in schedule:
		if _block_active(b):
			found = b
			break
	if found == active_block and not force:
		return
	active_block = found
	if found.is_empty():
		visible = false
		_cs.disabled = true
		return
	visible = true
	_cs.disabled = false
	wp_index = 0
	speed = float(found.get("speed", 1.2))
	anim_move = "run" if speed > 2.5 else "walk"
	var path: Array = found["path"]
	global_position = path[0]
	velocity = Vector3.ZERO
	if path.size() == 1:
		model.rotation.y = float(found.get("stand_yaw", 0.0))

func _physics_process(delta: float) -> void:
	_talk_timer -= delta
	if Engine.get_physics_frames() % 30 == 0:
		_update_schedule()
	if not visible:
		return
	var path: Array = active_block.get("path", [])
	if path.is_empty():
		return
	var stop := false
	if Game.player:
		var to_p: Vector3 = Game.player.global_position - global_position
		to_p.y = 0
		var fwd := Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))
		if to_p.length() < 1.6 and (fwd.dot(to_p.normalized()) > 0.3 or _talk_timer > 0.0):
			stop = true
		if _talk_timer > 0.0 and to_p.length() > 0.1:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(to_p.x, to_p.z), clampf(6.0 * delta, 0, 1))
	if path.size() == 1 or stop:
		velocity.x = 0
		velocity.z = 0
		if path.size() == 1 and _talk_timer <= 0.0:
			model.rotation.y = lerp_angle(model.rotation.y, float(active_block.get("stand_yaw", 0.0)), clampf(3.0 * delta, 0, 1))
		model.play("idle")
	else:
		var target: Vector3 = path[wp_index]
		var to := target - global_position
		to.y = 0
		if to.length() < 0.4:
			wp_index = (wp_index + 1) % path.size()
		else:
			var dir := to.normalized()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), clampf(8.0 * delta, 0, 1))
			model.play(anim_move, clampf(speed / (4.5 if anim_move == "run" else 1.3), 0.6, 1.4))
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.3
	move_and_slide()

func _context() -> String:
	if not Game.met.has(npc_id):
		return "primo_incontro"
	if npc_id == "padrone_di_casa" and Economy.pending_bills.size() > 0:
		return "affitto_scaduto"
	if npc_id == "barista_titolare" and flags_failed_shift():
		return "turno_non_valido"
	var mc := Game.money_context()
	if mc != "" and randf() < 0.5:
		return mc
	return "mattina" if GameTime.hour() < 14 else "sera"

func flags_failed_shift() -> bool:
	return Game.flags.get("last_shift_failed_day", -1) == GameTime.day()

func lines_for(ctx: String) -> Array:
	for d in Data.dialogues:
		if d["npc"] == npc_id and d["contesto"] == ctx:
			return d["battute"]
	return ["Ciao!"]

static func placeholder_vars() -> Dictionary:
	var e: Dictionary = Data.economy
	var job: Dictionary = e["job_barista"]
	var bus: Dictionary = Data.balance["bus"]
	return {
		"turno_inizio": job["shift"]["start"], "turno_fine": job["shift"]["end"],
		"paga_turno": Data.euro(int(job["pay_cents_per_shift"])),
		"apertura": e["minimarket"]["hours"]["open"], "chiusura": e["minimarket"]["hours"]["close"],
		"affitto": Data.euro(int(e["rent"]["amount_cents"])), "giorni_affitto": e["rent"]["period_days"],
		"scadenza": Economy.next_rent_due_day(), "giorni_mancanti": Economy.days_to_next_rent(),
		"giorni_tolleranza": e["rent"]["grace_days"], "frequenza_bus": bus["every_min"], "ultimo_bus": bus["last"],
		"prezzo_biglietto": Data.euro(int(bus["ticket_cents"])),
	}

func _talk() -> void:
	_talk_timer = 6.0
	var ctx := _context()
	var lines := lines_for(ctx)
	var vars := placeholder_vars()
	var out: Array = []
	if ctx == "primo_incontro":
		for l in lines:
			out.append(Data.fmt(l, vars))
		Game.met[npc_id] = true
	else:
		out.append(Data.fmt(lines[randi() % lines.size()], vars))
	model.play_once("interact")
	Game.world.show_dialogue(display_name, out, self)
