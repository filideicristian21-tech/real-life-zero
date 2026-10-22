extends Node
## Lavori v0.3 (data/life.json -> jobs): barista, cassiere, rider. Livelli, promozioni, puntualità,
## trattenute forfettarie, candidature. Ogni turno si paga una sola volta (chiave lavoro:giorno:fascia).
## L'API "senza job_id" (hire, start_shift, complete_order, ...) resta quella del barista per compatibilità.

signal shift_started(late: bool)
signal shift_ended(paid: bool, amount: int, reason: String)
signal order_count_changed(n: int)
signal hired()
signal promoted(job_id: String, title: String, pay: int)
signal delivery_changed()

var state: Dictionary = {}          # job_id -> {employed, level, completed, on_time, late, missed, deliveries, del_on_time}
var applications: Dictionary = {}   # job_id -> {status, day, answer_day}
var paid_keys: Dictionary = {}      # "barista:12:0" -> cents
var worked_keys: Dictionary = {}    # turni iniziati
var in_shift: bool = false
var cur_job: String = ""
var cur_slot: int = 0
var shift_day: int = -1
var shift_late: bool = false
var orders_done: int = 0            # barista: ordini; cassiere: clienti serviti; rider: consegne
var change_errors: int = 0
var del_on_time_streak: int = 0
var del_on_time_count: int = 0
var delivery: Dictionary = {}       # {stage: pickup|drop, pickup:[x,z], drop:[x,z], deadline}
var _missed_checked: Dictionary = {}

func _ready() -> void:
	GameTime.minute_passed.connect(_on_minutes)
	GameTime.day_changed.connect(_on_day)

func jobs_cfg() -> Array:
	return Data.life["jobs"]

func job(id: String) -> Dictionary:
	for j in jobs_cfg():
		if j["id"] == id:
			return j
	return {}

## Compatibilità v0.2: configurazione barista "piatta".
func cfg() -> Dictionary:
	return Data.economy["job_barista"]

func reset_new_game() -> void:
	state.clear()
	for j in jobs_cfg():
		state[j["id"]] = _blank()
	applications.clear()
	paid_keys.clear()
	worked_keys.clear()
	in_shift = false
	cur_job = ""
	shift_day = -1
	orders_done = 0
	change_errors = 0
	delivery = {}
	_missed_checked.clear()

func _blank() -> Dictionary:
	return {"employed": false, "level": 1, "completed": 0, "on_time": 0, "late": 0, "missed": 0, "deliveries": 0, "del_on_time": 0, "since_service": 0}

func st(id: String) -> Dictionary:
	if not state.has(id):
		state[id] = _blank()
	return state[id]

# ---------------- proprietà compatibili (barista) ----------------
var employed: bool:
	get: return bool(st("barista")["employed"])
var shifts_completed: int:
	get: return int(st("barista")["completed"])
var paid_days: Dictionary:
	get:
		var out := {}
		for k in paid_keys:
			var p: PackedStringArray = str(k).split(":")
			if p[0] == "barista":
				out[p[1]] = paid_keys[k]
		return out
var worked_days: Dictionary:
	get:
		var out := {}
		for k in worked_keys:
			var p: PackedStringArray = str(k).split(":")
			if p[0] == "barista":
				out[p[1]] = true
		return out

func any_employed() -> bool:
	for k in state:
		if state[k]["employed"]:
			return true
	return false

func total_shifts() -> int:
	var n := 0
	for k in state:
		n += int(state[k]["completed"])
	return n

func best_level() -> int:
	var b := 0
	for k in state:
		if state[k]["employed"]:
			b = maxi(b, int(state[k]["level"]))
	return b

func level_cfg(id: String) -> Dictionary:
	var lv := int(st(id)["level"])
	for l in job(id)["levels"]:
		if int(l["level"]) == lv:
			return l
	return job(id)["levels"][0]

func title(id: String) -> String:
	return str(level_cfg(id)["title"])

func net_pay(id: String) -> int:
	var l := level_cfg(id)
	return int(l.get("net_cents_per_shift", l.get("net_cents_per_delivery", 0)))

func gross_pay(id: String) -> int:
	var l := level_cfg(id)
	return int(l.get("gross_cents_per_shift", l.get("gross_cents_per_delivery", 0)))

func hire(id: String = "barista") -> void:
	if not st(id)["employed"]:
		st(id)["employed"] = true
		applications.erase(id)
		hired.emit()

func quit_job(id: String) -> void:
	if in_shift and cur_job == id:
		abandon_shift("Ti sei licenziato.")
	var s := st(id)
	s["employed"] = false
	s["level"] = 1
	s["completed"] = 0
	s["on_time"] = 0
	s["late"] = 0
	s["missed"] = 0

## Candidatura: risposta il giorno dopo, con regola deterministica (punteggio colloquio).
func apply(id: String) -> String:
	var j := job(id)
	if j.is_empty():
		return "Offerta non trovata."
	if st(id)["employed"]:
		return "Lavori già qui."
	var a: Dictionary = applications.get(id, {})
	if a.get("status", "") == "pending":
		return "Candidatura già inviata: risposta il giorno %d." % int(a["answer_day"])
	if a.get("status", "") == "rejected" and GameTime.day() < int(a["retry_day"]):
		return "%s ha scelto qualcun altro. Puoi riprovare il giorno %d." % [j.get("place", ""), int(a["retry_day"])]
	var miss := missing_requirement(id)
	if miss != "":
		return "Non hai ancora i requisiti: %s." % miss
	applications[id] = {"status": "pending", "day": GameTime.day(), "answer_day": GameTime.day() + 1, "score": Life.interview_score()}
	return ""

func missing_requirement(id: String) -> String:
	var j := job(id)
	var req: Dictionary = j.get("requirements", {})
	for item in req.get("owns_item", []):
		if not (item in Life.equipment):
			for e in j.get("equipment", []):
				if e["id"] == item:
					return "%s (€ %s)" % [e["name"], Data.euro(int(e["price_cents"]))]
	return ""

func _answer_applications() -> void:
	for id in applications.keys():
		var a: Dictionary = applications[id]
		if a["status"] != "pending" or GameTime.day() < int(a["answer_day"]):
			continue
		var need := int(job(id).get("hiring", {}).get("interview_score_min", 0))
		var score := maxi(int(a["score"]), Life.interview_score())
		if score >= need:
			hire(id)
			Game.toast("Ti hanno preso! Inizi come %s: prossimo turno %s." % [title(id), next_shift_text(id)], "ok")
		else:
			a["status"] = "rejected"
			a["retry_day"] = GameTime.day() + int(Data.life["interview"]["retry_after_days"])
			Game.toast("%s ha scelto qualcun altro (colloquio %d/%d). Puoi riprovare tra %d giorni: vestiti curati e più esperienza aiutano." % [job(id).get("place", ""), score, need, int(Data.life["interview"]["retry_after_days"])], "warn")

func buy_equipment(eid: String) -> String:
	for e in job("rider")["equipment"]:
		if e["id"] == eid:
			if eid in Life.equipment:
				return "Ce l'hai già."
			if not Economy.spend(int(e["price_cents"]), "ConsegnaGiù: %s" % e["name"], "lavoro"):
				return "Ti servono %s €, ne hai %s." % [Data.euro(int(e["price_cents"])), Data.euro(Economy.money_cents)]
			Life.equipment.append(eid)
			return ""
	return "Articolo non trovato."

# ---------------- orari ----------------
func shift_start_min(id: String = "barista", slot: int = 0) -> int:
	return Data.hhmm_to_min(job(id)["shifts"][slot]["start"])

func shift_end_min(id: String = "barista", slot: int = 0) -> int:
	return Data.hhmm_to_min(job(id)["shifts"][slot]["end"])

func is_workday(d: int = -1, id: String = "barista") -> bool:
	return GameTime.weekday_code(d) in job(id)["workdays"]

func _worked_today(id: String, d: int) -> int:
	var n := 0
	for k in worked_keys:
		var p: PackedStringArray = str(k).split(":")
		if p[0] == id and int(p[1]) == d:
			n += 1
	return n

## Fascia valida adesso per il lavoro (o -1).
func current_slot(id: String) -> int:
	var j := job(id)
	var m := GameTime.minute_of_day()
	var window: int = int(j.get("check_in_window_min", 15))
	for i in j["shifts"].size():
		var s := shift_start_min(id, i)
		var lp: Dictionary = j.get("late_policy", {"absent_after_min": 9999})
		var limit := s + int(lp.get("absent_after_min", 9999)) if id != "rider" else shift_end_min(id, i) - 30
		if m >= s - window and m < limit:
			return i
	return -1

## Ritorna {ok, reason, late, slot}.
func check_in_status(id: String = "barista") -> Dictionary:
	var j := job(id)
	if not st(id)["employed"]:
		if id == "barista":
			return {"ok": false, "reason": "Non lavori ancora qui: parla con Mimmo."}
		return {"ok": false, "reason": "Non lavori ancora per %s: candidati dal telefono (Lavori)." % j.get("place", "")}
	var d := GameTime.day()
	if in_shift:
		return {"ok": false, "reason": "Sei già in turno."}
	if not is_workday(d, id):
		return {"ok": false, "reason": "Oggi (%s) non hai turno. Prossimo: %s." % [GameTime.weekday_name(), next_shift_text(id)]}
	var slot := current_slot(id)
	var m := GameTime.minute_of_day()
	if slot < 0:
		var s0 := shift_start_min(id, 0)
		var window: int = int(j.get("check_in_window_min", 15))
		if id == "barista" and worked_keys.has("barista:%d:0" % d):
			if paid_keys.has("barista:%d:0" % d):
				return {"ok": false, "reason": "Il turno di oggi l'hai già fatto. Prossimo: %s." % next_shift_text(id)}
			return {"ok": false, "reason": "Il turno di oggi è stato interrotto e non si può ripetere. Prossimo: %s." % next_shift_text(id)}
		if m < s0 - window:
			return {"ok": false, "reason": "È presto: il turno inizia alle %s (puoi timbrare dalle %s)." % [Data.min_to_hhmm(s0), Data.min_to_hhmm(s0 - window)]}
		if id == "barista":
			return {"ok": false, "reason": "Troppo tardi: oltre %d minuti di ritardo il turno di oggi è perso." % int(j["late_policy"]["absent_after_min"])}
		return {"ok": false, "reason": "Adesso non c'è un turno. Prossimo: %s." % next_shift_text(id)}
	if worked_keys.has("%s:%d:%d" % [id, d, slot]):
		if paid_keys.has("%s:%d:%d" % [id, d, slot]):
			return {"ok": false, "reason": "Il turno di oggi l'hai già fatto. Prossimo: %s." % next_shift_text(id)}
		return {"ok": false, "reason": "Il turno di oggi è stato interrotto e non si può ripetere. Prossimo: %s." % next_shift_text(id)}
	if _worked_today(id, d) >= int(j.get("max_shifts_per_day", 9)):
		return {"ok": false, "reason": "Oggi hai già fatto il tuo turno. Prossimo: %s." % next_shift_text(id)}
	var emin := float(j["requirements"]["energy_min_at_start"])
	if Needs.energy < emin:
		return {"ok": false, "reason": "Sei troppo stanco per lavorare (energia sotto %d). Mangia o riposa." % int(emin)}
	var miss := missing_requirement(id)
	if miss != "":
		return {"ok": false, "reason": "Ti manca: %s." % miss}
	var late := false
	if j.has("late_policy"):
		late = m > shift_start_min(id, slot) + int(j["late_policy"]["late_after_min"])
	return {"ok": true, "reason": "", "late": late, "slot": slot}

func start_shift(id: String = "barista") -> Dictionary:
	var s := check_in_status(id)
	if not s["ok"]:
		return s
	in_shift = true
	cur_job = id
	cur_slot = int(s["slot"])
	shift_day = GameTime.day()
	shift_late = s["late"]
	orders_done = 0
	change_errors = 0
	del_on_time_count = 0
	del_on_time_streak = 0
	delivery = {}
	worked_keys["%s:%d:%d" % [id, shift_day, cur_slot]] = true
	Needs.activity = "work"
	GameTime.speed_mult = float(Data.balance["time"]["shift_speed_mult"]) if id != "rider" else float(Data.balance["time"].get("rider_speed_mult", 0.5))
	if id == "rider":
		_next_delivery()
	shift_started.emit(shift_late)
	order_count_changed.emit(0)
	return s

func complete_order() -> void:
	if in_shift and cur_job != "rider":
		orders_done += 1
		order_count_changed.emit(orders_done)

func change_error() -> void:
	if in_shift and cur_job == "cassiere":
		change_errors += 1

func _on_minutes(_dm: float) -> void:
	if not in_shift:
		return
	if GameTime.day() != shift_day or GameTime.minute_of_day() >= shift_end_min(cur_job, cur_slot):
		finish_shift()

# ---------------- rider ----------------
func delivery_points() -> Array:
	return Data.balance.get("rider_points", [])

func _next_delivery() -> void:
	var j := job("rider")
	var maxd: int = int(j["shifts"][cur_slot].get("max_deliveries", 7)) + int(level_cfg("rider").get("bonus_max_deliveries_per_shift", 0))
	if orders_done >= maxd:
		delivery = {}
		delivery_changed.emit()
		return
	var pts := delivery_points()
	var pickups: Array = Data.balance.get("rider_pickups", [])
	if pts.is_empty() or pickups.is_empty():
		delivery = {}
		return
	var n := orders_done + shift_day * 3 + cur_slot
	var slow := 1.2 if int(st("rider")["since_service"]) >= int(j["equipment"][0]["maintenance_every_deliveries"]) else 1.0
	var limit: float = (float(j["on_time_threshold_min"]) + float(Life.worn_effect("rider_on_time_bonus_min"))) / slow
	delivery = {"stage": "pickup", "pickup": pickups[n % pickups.size()], "drop": pts[(n * 7 + 3) % pts.size()], "deadline": GameTime.total_minutes + limit * 2.0, "limit": limit}
	delivery_changed.emit()

func rider_pickup() -> void:
	if delivery.get("stage", "") == "pickup":
		delivery["stage"] = "drop"
		delivery["deadline"] = GameTime.total_minutes + float(delivery["limit"])
		delivery_changed.emit()

## Consegna fatta: conta la puntualità e prepara la successiva.
func rider_drop() -> bool:
	if not in_shift or cur_job != "rider" or delivery.get("stage", "") != "drop":
		return false
	var on_time: bool = GameTime.total_minutes <= float(delivery["deadline"])
	orders_done += 1
	var s := st("rider")
	s["deliveries"] = int(s["deliveries"]) + 1
	s["since_service"] = int(s["since_service"]) + 1
	if on_time:
		s["del_on_time"] = int(s["del_on_time"]) + 1
		del_on_time_count += 1
		del_on_time_streak += 1
	else:
		del_on_time_streak = 0
	var extra: float = float(job("rider")["energy_extra_per_delivery"]) - float(Life.worn_effect("rider_energy_per_delivery_reduction"))
	Needs.energy -= extra
	Needs.eat(0, 0)
	if int(s["deliveries"]) % 10 == 0:
		Life.add_skill("fisico", int(job("rider")["skill_gain_per_10_deliveries"]))
	order_count_changed.emit(orders_done)
	_next_delivery()
	return on_time

func rider_tips() -> int:
	var t: Dictionary = job("rider")["tips_estimate"]
	return (del_on_time_count / int(t["every_on_time_deliveries"])) * int(t["tip_cents"])

## Fine turno: paga una sola volta per turno, solo se i requisiti sono rispettati.
func finish_shift() -> void:
	if not in_shift:
		return
	in_shift = false
	GameTime.speed_mult = 1.0
	Needs.activity = "idle"
	var id := cur_job
	var j := job(id)
	var key := "%s:%d:%d" % [id, shift_day, cur_slot]
	var s := st(id)
	if paid_keys.has(key):
		shift_ended.emit(false, 0, "Turno già pagato.")
		return
	if id == "rider":
		_pay_rider(key)
		return
	var req: Dictionary = j["requirements"]
	var need := int(req.get("orders_min_completed", req.get("customers_min_served", 0)))
	if orders_done < need:
		shift_ended.emit(false, 0, "%s: %d su %d richiesti." % ["Ordini serviti" if id == "barista" else "Clienti serviti", orders_done, need])
		return
	if id == "cassiere" and change_errors > int(req["max_change_errors"]):
		shift_ended.emit(false, 0, "Troppi errori nel resto: %d (massimo %d)." % [change_errors, int(req["max_change_errors"])])
		return
	var gross := gross_pay(id)
	var net := net_pay(id)
	var cut := 0
	if shift_late:
		cut = net * int(j["late_policy"]["pay_cut_pct"]) / 100
	var pay := net - cut
	paid_keys[key] = pay
	s["completed"] = int(s["completed"]) + 1
	if shift_late:
		s["late"] = int(s["late"]) + 1
	else:
		s["on_time"] = int(s["on_time"]) + 1
	Life.add_skill(str(j["skill"]), int(j["skill_gain_per_shift"]))
	var tax := gross - net
	Economy.earn(pay, "Stipendio %s (giorno %d): lordo € %s − trattenute € %s%s" % [j.get("place", id), shift_day, Data.euro(gross), Data.euro(tax), " − ritardo 20%" if shift_late else ""], "stipendio")
	Life.log_income(pay)
	shift_ended.emit(true, pay, "")
	_check_promotion(id)

func _pay_rider(key: String) -> void:
	var n := orders_done
	if n <= 0:
		shift_ended.emit(false, 0, "Nessuna consegna completata.")
		return
	var pay := n * net_pay("rider")
	var tips := rider_tips()
	paid_keys[key] = pay + tips
	var s := st("rider")
	s["completed"] = int(s["completed"]) + 1
	s["on_time"] = int(s["on_time"]) + 1
	Economy.earn(pay, "ConsegnaGiù: %d consegne × € %s netti (lordo € %s, trattenute 20%%)" % [n, Data.euro(net_pay("rider")), Data.euro(n * gross_pay("rider"))], "stipendio")
	if tips > 0:
		Economy.earn(tips, "Mance consegne puntuali (%d)" % del_on_time_count, "mancia")
	Life.log_income(pay + tips)
	delivery = {}
	shift_ended.emit(true, pay + tips, "")
	_check_promotion("rider")

func abandon_shift(reason: String = "Hai lasciato il turno prima della fine.") -> void:
	if not in_shift:
		return
	if cur_job == "rider" and orders_done > 0:
		# le consegne già fatte si pagano comunque (lavoro a consegna)
		finish_shift()
		return
	in_shift = false
	GameTime.speed_mult = 1.0
	Needs.activity = "idle"
	delivery = {}
	shift_ended.emit(false, 0, reason)

func punctuality_pct(id: String) -> int:
	var s := st(id)
	if id == "rider":
		return 100 if int(s["deliveries"]) == 0 else int(100.0 * float(s["del_on_time"]) / float(s["deliveries"]))
	var tot := int(s["completed"]) + int(s["missed"])
	return 100 if tot == 0 else int(100.0 * float(s["on_time"]) / float(tot))

func next_level(id: String) -> Dictionary:
	var lv := int(st(id)["level"])
	for l in job(id)["levels"]:
		if int(l["level"]) == lv + 1:
			return l
	return {}

func promotion_progress(id: String) -> String:
	var nl := next_level(id)
	if nl.is_empty():
		return "Sei al livello più alto."
	var c: Dictionary = nl["conditions"]
	var s := st(id)
	var done := int(s["deliveries"]) if id == "rider" else int(s["completed"])
	var need := int(c.get("deliveries_completed", c.get("shifts_completed", 0)))
	var pk := "on_time_pct_min" if id == "rider" else "punctuality_pct_min"
	return "Verso %s: %d/%d %s · puntualità %d%% (min %d%%) · abilità %s %d/%d" % [nl["title"], done, need, "consegne" if id == "rider" else "turni completi", punctuality_pct(id), int(c[pk]), job(id)["skill"], int(Life.skills.get(job(id)["skill"], 0)), int(c["skill_min"])]

func _check_promotion(id: String) -> void:
	var nl := next_level(id)
	if nl.is_empty():
		return
	var c: Dictionary = nl["conditions"]
	var s := st(id)
	var done := int(s["deliveries"]) if id == "rider" else int(s["completed"])
	var need := int(c.get("deliveries_completed", c.get("shifts_completed", 0)))
	var pk := "on_time_pct_min" if id == "rider" else "punctuality_pct_min"
	if done >= need and punctuality_pct(id) >= int(c[pk]) and int(Life.skills.get(job(id)["skill"], 0)) >= int(c["skill_min"]):
		s["level"] = int(nl["level"])
		var pay := int(nl.get("net_cents_per_shift", nl.get("net_cents_per_delivery", 0)))
		promoted.emit(id, str(nl["title"]), pay)
		Game.toast("Promozione! Ora sei %s. Nuova paga: %s € %s." % [nl["title"], Data.euro(pay), "a consegna" if id == "rider" else "a turno"], "ok")

## Turni saltati (barista, cassiere): abbassano la puntualità, quindi rallentano la promozione.
func _on_day(d: int) -> void:
	_answer_applications()
	var prev := d - 1
	if prev < 1 or _missed_checked.has(prev):
		return
	_missed_checked[prev] = true
	for id in ["barista", "cassiere"]:
		if st(id)["employed"] and is_workday(prev, id) and _worked_today(id, prev) == 0:
			st(id)["missed"] = int(st(id)["missed"]) + 1

func next_shift_text(id: String = "barista") -> String:
	var j := job(id)
	var d := GameTime.day()
	for i in range(0, 8):
		var dd := d + i
		if not is_workday(dd, id):
			continue
		for slot in j["shifts"].size():
			if worked_keys.has("%s:%d:%d" % [id, dd, slot]):
				continue
			if id != "rider" and _worked_today(id, dd) >= int(j.get("max_shifts_per_day", 9)):
				continue
			if i == 0:
				var lim := shift_start_min(id, slot) + int(j.get("late_policy", {}).get("absent_after_min", 0)) if id != "rider" else shift_end_min(id, slot) - 30
				if GameTime.minute_of_day() >= lim:
					continue
			var lbl := "oggi" if i == 0 else ("domani" if i == 1 else GameTime.weekday_name(dd).to_lower())
			return "%s %s–%s" % [lbl, j["shifts"][slot]["start"], j["shifts"][slot]["end"]]
	return "—"

func to_dict() -> Dictionary:
	# chiavi v0.2 mantenute per compatibilità (employed, paid_days, worked_days, shifts_completed)
	return {"v": 3, "state": state, "applications": applications, "paid_keys": paid_keys, "worked_keys": worked_keys.keys(),
		"in_shift": in_shift, "shift_day": shift_day, "orders_done": orders_done, "missed_checked": _missed_checked.keys(),
		"employed": employed, "shifts_completed": shifts_completed}

## Un turno in corso al momento del salvataggio non si riprende: viene annullato senza paga.
func from_dict(d: Dictionary) -> void:
	reset_new_game()
	if int(d.get("v", 2)) < 3:
		# migrazione dal salvataggio v0.2: solo barista
		var b := st("barista")
		b["employed"] = bool(d.get("employed", false))
		b["completed"] = int(d.get("shifts_completed", 0))
		b["on_time"] = b["completed"]
		for k in d.get("paid_days", {}):
			paid_keys["barista:%s:0" % str(k)] = int(d["paid_days"][k])
		for k in d.get("worked_days", []):
			worked_keys["barista:%s:0" % str(k)] = true
	else:
		var sd: Dictionary = d.get("state", {})
		for k in sd:
			var s: Dictionary = _blank()
			for f in sd[k]:
				s[f] = sd[k][f] if f == "employed" else int(sd[k][f])
			s["employed"] = bool(s["employed"])
			state[k] = s
		applications = d.get("applications", {})
		for k in d.get("paid_keys", {}):
			paid_keys[str(k)] = int(d["paid_keys"][k])
		for k in d.get("worked_keys", []):
			worked_keys[str(k)] = true
		for k in d.get("missed_checked", []):
			_missed_checked[int(k)] = true
	in_shift = false
	orders_done = 0
	shift_day = int(d.get("shift_day", -1))
	GameTime.speed_mult = 1.0
	if bool(d.get("in_shift", false)):
		Game.call_deferred("toast", "Il turno interrotto (app chiusa) è stato annullato: niente paga per oggi.")
