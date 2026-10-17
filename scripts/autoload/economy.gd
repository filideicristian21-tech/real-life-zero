extends Node
## Denaro in centesimi interi. Ogni variazione passa da _apply() e finisce nello storico,
## quindi saldo == start_money_cents + somma(storico) sempre.

signal money_changed(cents: int)
signal transaction_added(tx: Dictionary)
signal bill_event(kind: String, info: Dictionary)

var money_cents: int = 0
var start_money_cents: int = 0
var history: Array = []          # {day, time, desc, amount, kind}
var charged_periods: Dictionary = {}  # "rent:0" -> true ecc. (una sola volta per periodo)
var pending_bills: Array = []     # bollette non pagate {key, desc, amount, due_day, late_fee_applied}
var missed_rent_count: int = 0
var evicted: bool = false

func reset_new_game() -> void:
	start_money_cents = int(Data.economy["start"]["money_cents"])
	money_cents = start_money_cents
	history.clear()
	charged_periods.clear()
	pending_bills.clear()
	missed_rent_count = 0
	evicted = false
	money_changed.emit(money_cents)

func can_afford(cents: int) -> bool:
	return cents >= 0 and money_cents >= cents

func _apply(amount: int, desc: String, kind: String) -> void:
	money_cents += amount
	var tx := {"day": GameTime.day(), "time": GameTime.clock_text(), "desc": desc, "amount": amount, "kind": kind}
	history.append(tx)
	if history.size() > 400:
		# Compatta lo storico molto vecchio in una riga di riporto, mantenendo l'invariante.
		var old: Array = history.slice(0, 100)
		var s := 0
		for t in old:
			s += int(t["amount"])
		history = history.slice(100)
		start_money_cents += s
	transaction_added.emit(tx)
	money_changed.emit(money_cents)

## Spesa: ritorna false (e non tocca nulla) se il saldo non basta. Mai saldo negativo.
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
func rent_cfg() -> Dictionary:
	return Data.economy["rent"]

func rent_period_of_day(d: int) -> int:
	var first: int = int(rent_cfg()["first_due_day"])
	return int(floor(float(d - first) / float(rent_cfg()["period_days"])))

func next_rent_due_day() -> int:
	var c := rent_cfg()
	var p := rent_period_of_day(GameTime.day()) + 1
	return int(c["first_due_day"]) + p * int(c["period_days"])

func days_to_next_rent() -> int:
	return next_rent_due_day() - GameTime.day()

## Da chiamare a inizio partita e a ogni cambio giorno. Idempotente: ogni periodo si addebita una volta sola.
func process_bills() -> void:
	var d := GameTime.day()
	var c := rent_cfg()
	var p := rent_period_of_day(d)
	if p >= 0:
		var due_day: int = int(c["first_due_day"]) + p * int(c["period_days"])
		_charge_once("rent:%d" % p, "Affitto settimana %d" % (p + 1), int(c["amount_cents"]), due_day, true)
	for b in Data.economy.get("recurring_bills", []):
		var bp := int(floor(float(d - 1) / float(b["period_days"])))
		_charge_once("%s:%d" % [b["id"], bp], "%s settimana %d" % [b["name"], bp + 1], int(b["amount_cents"]), 1 + bp * int(b["period_days"]), false)
	_check_pending(d)

func _charge_once(key: String, desc: String, amount: int, due_day: int, is_rent: bool) -> void:
	if charged_periods.has(key):
		return
	charged_periods[key] = true
	if spend(amount, desc, "affitto" if is_rent else "bolletta"):
		bill_event.emit("paid", {"key": key, "desc": desc, "amount": amount, "is_rent": is_rent})
	else:
		pending_bills.append({"key": key, "desc": desc, "amount": amount, "due_day": due_day, "late_fee_applied": false, "is_rent": is_rent})
		bill_event.emit("unpaid", {"key": key, "desc": desc, "amount": amount, "missing": amount - money_cents, "is_rent": is_rent})

func _check_pending(d: int) -> void:
	var grace: int = int(rent_cfg()["grace_days"])
	missed_rent_count = 0
	for b in pending_bills:
		if b["is_rent"] and d > int(b["due_day"]) + grace:
			if not b["late_fee_applied"]:
				b["late_fee_applied"] = true
				b["amount"] = int(b["amount"]) + int(rent_cfg()["late_fee_cents"])
				bill_event.emit("late_fee", b)
			missed_rent_count += 1
	var unpaid_rents := 0
	for b in pending_bills:
		if b["is_rent"]:
			unpaid_rents += 1
	if unpaid_rents >= int(rent_cfg()["eviction_after_missed_payments"]) and missed_rent_count >= 1 and not evicted:
		evicted = true
		bill_event.emit("evicted", {})

func pay_pending(index: int) -> bool:
	if index < 0 or index >= pending_bills.size():
		return false
	var b: Dictionary = pending_bills[index]
	if not spend(int(b["amount"]), b["desc"] + " (saldato)", "affitto" if b["is_rent"] else "bolletta"):
		return false
	pending_bills.remove_at(index)
	bill_event.emit("paid", {"key": b["key"], "desc": b["desc"], "amount": b["amount"], "is_rent": b["is_rent"]})
	return true

func to_dict() -> Dictionary:
	return {"money_cents": money_cents, "start_money_cents": start_money_cents, "history": history,
		"charged_periods": charged_periods.keys(), "pending_bills": pending_bills,
		"missed_rent_count": missed_rent_count, "evicted": evicted}

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
		pending_bills.append(b)
	missed_rent_count = int(d.get("missed_rent_count", 0))
	evicted = bool(d.get("evicted", false))
	money_changed.emit(money_cents)
