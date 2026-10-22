extends Node
## Conto corrente in centesimi interi. Ogni variazione passa da _apply() e finisce nello storico,
## quindi saldo == start_money_cents + somma(storico) sempre (i risparmi sono in Life, con il loro storico).
## Addebiti periodici idempotenti: ogni chiave ("rent:3", "tel28:1", "luce:0"...) si addebita una volta sola.

signal money_changed(cents: int)
signal transaction_added(tx: Dictionary)
signal bill_event(kind: String, info: Dictionary)

var money_cents: int = 0
var start_money_cents: int = 0
var history: Array = []          # {day, time, desc, amount, kind}
var charged_periods: Dictionary = {}
var pending_bills: Array = []     # {key, desc, amount, due_day, late_fee_applied, is_rent, kind, grace, late_fee, ...}
var missed_rent_count: int = 0
var evicted: bool = false
var eviction_count: int = 0

func reset_new_game() -> void:
	start_money_cents = int(Data.economy["start"]["money_cents"])
	money_cents = start_money_cents
	history.clear()
	charged_periods.clear()
	pending_bills.clear()
	missed_rent_count = 0
	evicted = false
	eviction_count = 0
	money_changed.emit(money_cents)

func can_afford(cents: int) -> bool:
	return cents >= 0 and money_cents >= cents

func _apply(amount: int, desc: String, kind: String) -> void:
	money_cents += amount
	var tx := {"day": GameTime.day(), "time": GameTime.clock_text(), "desc": desc, "amount": amount, "kind": kind}
	history.append(tx)
	if history.size() > 600:
		# Compatta lo storico molto vecchio in una riga di riporto, mantenendo l'invariante.
		var old: Array = history.slice(0, 150)
		var s := 0
		for t in old:
			s += int(t["amount"])
		history = history.slice(150)
		start_money_cents += s
	transaction_added.emit(tx)
	money_changed.emit(money_cents)

## Spesa con carta: ritorna false (e non tocca nulla) se il saldo non basta. Mai saldo negativo.
func spend(cents: int, desc: String, kind: String = "spesa") -> bool:
	if cents <= 0 or not can_afford(cents):
		return false
	_apply(-cents, desc, kind)
	return true

func earn(cents: int, desc: String, kind: String = "entrata") -> void:
	if cents <= 0:
		return
	_apply(cents, desc, kind)

func history_sum() -> int:
	var s := 0
	for t in history:
		s += int(t["amount"])
	return s

func is_consistent() -> bool:
	return money_cents == start_money_cents + history_sum() and money_cents >= 0

# ---------- Affitto e bollette ----------
## Affitto della casa attuale (vuoto se la casa è di proprietà).
func rent_cfg() -> Dictionary:
	var r: Dictionary = Life.rent_cfg() if Life.cfg().size() > 0 else {}
	if r.is_empty() and Life.is_rental():
		return Data.economy["rent"]
	return r

func rent_period_of_day(d: int) -> int:
	var c := rent_cfg()
	if c.is_empty():
		return -1
	return int(floor(float(d - int(c["first_due_day"])) / float(c["period_days"])))

func next_rent_due_day() -> int:
	var c := rent_cfg()
	if c.is_empty():
		return -1
	var p := rent_period_of_day(GameTime.day()) + 1
	return int(c["first_due_day"]) + p * int(c["period_days"])

func days_to_next_rent() -> int:
	var n := next_rent_due_day()
	return 999 if n < 0 else n - GameTime.day()

func phone_cfg() -> Dictionary:
	return Life.cfg()["bills"]["phone"]

## Da chiamare a inizio partita e a ogni cambio giorno. Idempotente: ogni periodo si addebita una volta sola.
func process_bills() -> void:
	var d := GameTime.day()
	var c := rent_cfg()
	if not c.is_empty():
		var p := rent_period_of_day(d)
		if p >= 0:
			var due_day: int = int(c["first_due_day"]) + p * int(c["period_days"])
			var key_prefix: String = str(c.get("key", "rent"))
			var per_lbl := "settimana" if int(c["period_days"]) == 7 else "mese"
			charge_once("%s:%d" % [key_prefix, p], "Affitto %s %d" % [per_lbl, p + 1], int(c["amount_cents"]), due_day, "affitto", {"is_rent": true})
	var ph := phone_cfg()
	var bp := int(floor(float(d - int(ph["first_due_day"])) / float(ph["period_days"])))
	if bp >= 0:
		charge_once("tel28:%d" % bp, "%s mese %d" % [ph["name"], bp + 1], int(ph["amount_cents"]), int(ph["first_due_day"]) + bp * int(ph["period_days"]), "telefono",
			{"grace": int(Life.cfg()["bills"]["grace_days"]), "late_fee": int(Life.cfg()["bills"]["late_fee_cents"]), "late_event": "bill_late", "ok_event": "bill_paid_on_time"})
	Life.process_day()
	_check_pending(d)

## Addebito una tantum per chiave. opts: is_rent, grace, late_fee, late_event, ok_event, utility, mortgage.
func charge_once(key: String, desc: String, amount: int, due_day: int, kind: String, opts: Dictionary = {}) -> void:
	if charged_periods.has(key) or amount <= 0:
		return
	charged_periods[key] = true
	var is_rent: bool = opts.get("is_rent", false)
	var info := {"key": key, "desc": desc, "amount": amount, "is_rent": is_rent, "kind": kind, "ok_event": opts.get("ok_event", "")}
	if spend(amount, desc, kind):
		bill_event.emit("paid", info)
	else:
		var b := {"key": key, "desc": desc, "amount": amount, "due_day": due_day, "late_fee_applied": false, "is_rent": is_rent, "kind": kind}
		for k in opts:
			b[k] = opts[k]
		pending_bills.append(b)
		info["missing"] = amount - money_cents
		bill_event.emit("unpaid", info)

func has_pending_rent() -> bool:
	for b in pending_bills:
		if b["is_rent"]:
			return true
	return false

func _check_pending(d: int) -> void:
	var rc := rent_cfg()
	missed_rent_count = 0
	for b in pending_bills:
		var grace: int = int(b.get("grace", rc.get("grace_days", 2) if b["is_rent"] else 5))
		if d > int(b["due_day"]) + grace:
			if not b["late_fee_applied"]:
				b["late_fee_applied"] = true
				var fee: int = int(b.get("late_fee", rc.get("late_fee_cents", 1000) if b["is_rent"] else 0))
				b["amount"] = int(b["amount"]) + fee
				b["fee_added"] = fee
				bill_event.emit("late_fee", b)
			if b["is_rent"]:
				missed_rent_count += 1
	var unpaid_rents := 0
	for b in pending_bills:
		if b["is_rent"]:
			unpaid_rents += 1
	if unpaid_rents == 0:
		evicted = false
	if not rc.is_empty() and unpaid_rents >= int(rc.get("eviction_after_missed_payments", 2)) and missed_rent_count >= 1 and not evicted:
		evicted = true
		eviction_count += 1
		bill_event.emit("evicted", {})

func pay_pending(index: int) -> bool:
	if index < 0 or index >= pending_bills.size():
		return false
	var b: Dictionary = pending_bills[index]
	if not spend(int(b["amount"]), b["desc"] + " (saldato)", str(b.get("kind", "affitto" if b["is_rent"] else "bolletta"))):
		return false
	pending_bills.remove_at(index)
	bill_event.emit("paid", {"key": b["key"], "desc": b["desc"], "amount": b["amount"], "is_rent": b["is_rent"], "late": b["late_fee_applied"], "ok_event": b.get("ok_event", "")})
	if not has_pending_rent():
		evicted = false
	return true

## Uscite note nei prossimi giorni (per l'app Banca): [{voce, importo, giorno}]
func upcoming(days: int = 7) -> Array:
	var out := []
	var nr := next_rent_due_day()
	var c := rent_cfg()
	if nr > 0 and nr - GameTime.day() <= days:
		out.append({"voce": "Affitto", "importo": int(c["amount_cents"]), "giorno": nr})
	var ph := phone_cfg()
	var d := GameTime.day()
	var bp := int(floor(float(d - int(ph["first_due_day"])) / float(ph["period_days"]))) + 1
	var pd := int(ph["first_due_day"]) + bp * int(ph["period_days"])
	if pd - d <= days:
		out.append({"voce": "Telefono", "importo": int(ph["amount_cents"]), "giorno": pd})
	var me := (Life.month_of_day(d) + 1) * Life.month_len() + 1
	if me - d <= days:
		out.append({"voce": "Canone conto e bollette di fine mese", "importo": int(Life.cfg()["bank"]["checking"]["monthly_fee_cents"]), "giorno": me})
	return out

func to_dict() -> Dictionary:
	return {"money_cents": money_cents, "start_money_cents": start_money_cents, "history": history,
		"charged_periods": charged_periods.keys(), "pending_bills": pending_bills,
		"missed_rent_count": missed_rent_count, "evicted": evicted, "eviction_count": eviction_count}

func from_dict(d: Dictionary) -> void:
	money_cents = int(d.get("money_cents", 0))
	start_money_cents = int(d.get("start_money_cents", money_cents))
	history = []
	for t in d.get("history", []):
		t["amount"] = int(t["amount"]); t["day"] = int(t["day"])
		history.append(t)
	charged_periods.clear()
	for k in d.get("charged_periods", []):
		charged_periods[str(k)] = true
	pending_bills = []
	for b in d.get("pending_bills", []):
		b["amount"] = int(b["amount"]); b["due_day"] = int(b["due_day"])
		for k in ["grace", "late_fee", "fee_added"]:
			if b.has(k):
				b[k] = int(b[k])
		pending_bills.append(b)
	missed_rent_count = int(d.get("missed_rent_count", 0))
	evicted = bool(d.get("evicted", false))
	eviction_count = int(d.get("eviction_count", 0))
	money_changed.emit(money_cents)
