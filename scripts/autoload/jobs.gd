extends Node
## Lavoro di barista al Bar Centrale da Mimmo (valori in data/economy.json -> job_barista).

signal shift_started(late: bool)
signal shift_ended(paid: bool, amount: int, reason: String)
signal order_count_changed(n: int)
signal hired()

var employed: bool = false
var in_shift: bool = false
var shift_day: int = -1
var shift_late: bool = false
var orders_done: int = 0
var paid_days: Dictionary = {}     # "giorno" -> centesimi pagati (mai due volte)
var worked_days: Dictionary = {}   # giorni in cui il turno è stato iniziato
var shifts_completed: int = 0

func cfg() -> Dictionary:
	return Data.economy["job_barista"]

func _ready() -> void:
	GameTime.minute_passed.connect(_on_minutes)

func reset_new_game() -> void:
	employed = false
	in_shift = false
	shift_day = -1
	shift_late = false
	orders_done = 0
	paid_days.clear()
	worked_days.clear()
	shifts_completed = 0

func hire() -> void:
	if not employed:
		employed = true
		hired.emit()

func shift_start_min() -> int:
	return Data.hhmm_to_min(cfg()["shift"]["start"])

func shift_end_min() -> int:
	return Data.hhmm_to_min(cfg()["shift"]["end"])

func is_workday(d: int = -1) -> bool:
	return GameTime.weekday_code(d) in cfg()["workdays"]

## Ritorna {ok, reason, late}.
func check_in_status() -> Dictionary:
	if not employed:
		return {"ok": false, "reason": "Non lavori ancora qui: parla con Mimmo."}
	var d := GameTime.day()
	if in_shift:
		return {"ok": false, "reason": "Sei già in turno."}
	if not is_workday(d):
		return {"ok": false, "reason": "Oggi (%s) non hai turno. Prossimo: %s." % [GameTime.weekday_name(), next_shift_text()]}
	if worked_days.has(str(d)):
		if paid_days.has(str(d)):
			return {"ok": false, "reason": "Il turno di oggi l'hai già fatto. Prossimo: %s." % next_shift_text()}
		return {"ok": false, "reason": "Il turno di oggi è stato interrotto e non si può ripetere. Prossimo: %s." % next_shift_text()}
	var m := GameTime.minute_of_day()
	var s := shift_start_min()
	var window: int = int(cfg()["shift"]["check_in_window_min"])
	var lp: Dictionary = cfg()["late_policy"]
	if m < s - window:
		return {"ok": false, "reason": "È presto: il turno inizia alle %s (puoi timbrare dalle %s)." % [Data.min_to_hhmm(s), Data.min_to_hhmm(s - window)]}
	if m >= s + int(lp["absent_after_min"]):
		return {"ok": false, "reason": "Troppo tardi: oltre %d minuti di ritardo il turno di oggi è perso." % int(lp["absent_after_min"])}
	if Needs.energy < float(cfg()["requirements"]["energy_min_at_start"]):
		return {"ok": false, "reason": "Sei troppo stanco per lavorare (energia sotto %d). Mangia o riposa." % int(cfg()["requirements"]["energy_min_at_start"])}
	return {"ok": true, "reason": "", "late": m > s + int(lp["late_after_min"])}

func start_shift() -> Dictionary:
	var st := check_in_status()
	if not st["ok"]:
		return st
	in_shift = true
	shift_day = GameTime.day()
	shift_late = st["late"]
	orders_done = 0
	worked_days[str(shift_day)] = true
	Needs.activity = "work"
	GameTime.speed_mult = float(Data.balance["time"]["shift_speed_mult"])
	shift_started.emit(shift_late)
	order_count_changed.emit(0)
	return st

func complete_order() -> void:
	if in_shift:
		orders_done += 1
		order_count_changed.emit(orders_done)

func _on_minutes(_dm: float) -> void:
	if in_shift and (GameTime.minute_of_day() >= shift_end_min() or GameTime.day() != shift_day):
		finish_shift()

## Fine turno: paga una sola volta per giorno, solo se i requisiti sono rispettati.
func finish_shift() -> void:
	if not in_shift:
		return
	in_shift = false
	GameTime.speed_mult = 1.0
	Needs.activity = "idle"
	var need: int = int(cfg()["requirements"]["orders_min_completed"])
	var key := str(shift_day)
	if orders_done < need:
		shift_ended.emit(false, 0, "Ordini serviti: %d su %d richiesti." % [orders_done, need])
		return
	if paid_days.has(key):
		shift_ended.emit(false, 0, "Turno già pagato.")
		return
	var pay: int = int(cfg()["pay_cents_per_shift"])
	if shift_late:
		pay -= int(cfg()["late_policy"]["pay_cut_cents"])
	paid_days[key] = pay
	shifts_completed += 1
	Economy.earn(pay, "Stipendio turno Bar Centrale (giorno %d)%s" % [shift_day, " – ritardo" if shift_late else ""], "stipendio")
	shift_ended.emit(true, pay, "")

func abandon_shift(reason: String = "Hai lasciato il turno prima della fine.") -> void:
	if not in_shift:
		return
	in_shift = false
	GameTime.speed_mult = 1.0
	Needs.activity = "idle"
	shift_ended.emit(false, 0, reason)

func next_shift_text() -> String:
	var d := GameTime.day()
	var s := shift_start_min()
	for i in range(0, 8):
		var dd := d + i
		if is_workday(dd) and not worked_days.has(str(dd)):
			if i == 0 and GameTime.minute_of_day() >= s + int(cfg()["late_policy"]["absent_after_min"]):
				continue
			var lbl := "oggi" if i == 0 else ("domani" if i == 1 else GameTime.weekday_name(dd).to_lower())
			return "%s %s–%s" % [lbl, cfg()["shift"]["start"], cfg()["shift"]["end"]]
	return "—"

func to_dict() -> Dictionary:
	return {"employed": employed, "in_shift": in_shift, "shift_day": shift_day, "orders_done": orders_done,
		"paid_days": paid_days, "worked_days": worked_days.keys(), "shifts_completed": shifts_completed}

## Un turno in corso al momento del salvataggio non si riprende: viene annullato senza paga.
func from_dict(d: Dictionary) -> void:
	employed = bool(d.get("employed", false))
	paid_days = {}
	for k in d.get("paid_days", {}):
		paid_days[str(k)] = int(d["paid_days"][k])
	worked_days.clear()
	for k in d.get("worked_days", []):
		worked_days[str(k)] = true
	shifts_completed = int(d.get("shifts_completed", 0))
	in_shift = false
	orders_done = 0
	shift_day = int(d.get("shift_day", -1))
	GameTime.speed_mult = 1.0
	if bool(d.get("in_shift", false)):
		Game.call_deferred("toast", "Il turno interrotto (app chiusa) è stato annullato: niente paga per oggi.")
