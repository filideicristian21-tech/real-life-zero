extends Node
## "Seconda vita" v0.3: banca (risparmi, canone, interessi), affidabilità, bollette di casa,
## casa (affitto/acquisto), mobili, vestiti, palestra, auto, bus, imprevisto del giovedì.
## Tutti i valori arrivano da data/life.json (Ledger v0.3). Denaro sempre in centesimi interi
## e sempre attraverso Economy.spend/earn (conto) o _sav() (risparmi): niente denaro creato o perso.

signal life_changed()
signal score_changed(score: int, delta: int, reason: String)
signal car_changed()

var savings_cents: int = 0
var savings_history: Array = []       # {day, time, desc, amount}
var savings_month_min: int = 0
var credit_score: int = 600
var score_gain_month: int = 0
var score_log: Array = []             # {day, delta, reason}
var processed: Dictionary = {}        # chiavi idempotenti: "month:3", "thu:2", "gymdecay:5"...
var home_id: String = "stanza_via_roma"
var rent_anchor_day: int = 1
var deposit_held_cents: int = 0
var owned_home: Dictionary = {}       # {id, principal_left, installments_paid, missed}
var furniture: Array = []
var clothes: Array = []
var wearing: Array = []
var equipment: Array = []             # bici_usata, zaino_termico
var skills: Dictionary = {"caffe": 5, "precisione": 5, "fisico": 5}
var energy_max: int = 90
var gym_pass_until: int = 0           # giorno (escluso) fino a cui vale l'abbonamento
var gym_sessions: int = 0
var gym_last_counted_day: int = -1
var gym_last_day: int = 0
var study_hours_today: Dictionary = {}
var coffee_skill_day: int = -1
var bus_pass_until: int = 0
var wh_month: int = 0                 # consumi elettrici extra del mese (Wh)
var power_suspended: bool = false
var income_log: Dictionary = {}       # "giorno" -> netto incassato quel giorno
var car: Dictionary = {}              # {model, fuel_l, km, wear_pct, ins_until, pos:[x,y,z], yaw, plan:{left,rata}, tax_until}
var parking_ticket_until: float = -1.0
var resident_pass_until: int = 0
var goal: Dictionary = {}             # {id, name, target_cents}
var last_event: Dictionary = {}
var capsules: int = 0

func cfg() -> Dictionary:
	return Data.life

func _ready() -> void:
	Economy.bill_event.connect(_on_bill_event)

func reset_new_game() -> void:
	var st: Dictionary = cfg()["start"]
	savings_cents = int(st["savings_cents"])
	savings_history.clear()
	savings_month_min = savings_cents
	credit_score = int(st["credit_score"])
	score_gain_month = 0
	score_log.clear()
	processed.clear()
	home_id = str(st["home_id"])
	rent_anchor_day = 1
	deposit_held_cents = int(home_cfg()["deposit_cents"])   # già versata prima dell'inizio (non è nello storico)
	owned_home = {}
	furniture = st["owned_furniture"].duplicate()
	clothes = st["owned_clothes"].duplicate()
	wearing = clothes.duplicate()
	equipment.clear()
	skills = st["skills"].duplicate()
	for k in skills:
		skills[k] = int(skills[k])
	energy_max = int(st["energy_max"])
	gym_pass_until = 0
	gym_sessions = 0
	gym_last_counted_day = -1
	gym_last_day = 0
	study_hours_today.clear()
	coffee_skill_day = -1
	bus_pass_until = 0
	wh_month = 0
	power_suspended = false
	income_log.clear()
	car = {}
	parking_ticket_until = -1.0
	resident_pass_until = 0
	goal = {}
	last_event = {}
	capsules = 0
	life_changed.emit()

# ======================================================================  CALENDARIO
func month_len() -> int:
	return int(cfg()["calendar"]["days_per_game_month"])

func month_of_day(d: int) -> int:
	return (d - 1) / month_len()

## Mese del calendario (1-12) per il giorno d (la partita inizia a ottobre).
func calendar_month(d: int) -> int:
	var m0: int = int(cfg()["calendar"]["start"]["month"]) - 1
	return (m0 + month_of_day(d)) % 12 + 1

func month_names() -> Array:
	return ["gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre"]

## Chiamata a ogni cambio giorno (e all'avvio). Idempotente per ogni giorno passato.
func process_day() -> void:
	var d := GameTime.day()
	# chiusure di fine mese per tutti i mesi conclusi
	for m in range(0, month_of_day(d)):
		if not processed.has("month:%d" % m):
			processed["month:%d" % m] = true
			_month_end(m)
	_utility_bills(d)
	_home_costs(d)
	_car_costs(d)
	_thursday_event(d)
	_gym_decay(d)
	_prune_income(d)
	power_suspended = _unpaid_utilities() >= int(cfg()["bills"]["suspension_after_unpaid"])
	life_changed.emit()

func _month_end(m: int) -> void:
	var b: Dictionary = cfg()["bank"]
	var md := (m + 1) * month_len()   # giorno 28, 56...
	# canone del conto
	Economy.charge_once("canone:%d" % m, "Canone %s (mese %d)" % [b["checking"]["name"], m + 1], int(b["checking"]["monthly_fee_cents"]), md, "canone", {"grace": int(cfg()["bills"]["grace_days"]), "late_fee": int(cfg()["bills"]["late_fee_cents"]), "late_event": "bill_late", "ok_event": ""})
	# interessi sul saldo minimo del mese (non sfruttabile)
	var s: Dictionary = b["savings"]
	var interest: int = int(floor(float(savings_month_min) * float(s["interest_bp_annual_gross"]) * float(10000 - int(s["withholding_tax_bp"])) / (10000.0 * 10000.0 * 12.0)))
	if interest > 0:
		_sav(interest, "Interessi netti mese %d (saldo minimo € %s)" % [m + 1, Data.euro(savings_month_min)])
	# affidabilità di fine mese
	if savings_cents >= 100000:
		score_event("month_end_savings_ge_100000")
	elif savings_cents >= 20000:
		score_event("month_end_savings_ge_20000")
	score_gain_month = 0
	savings_month_min = savings_cents
	wh_month = 0

# ======================================================================  RISPARMI
func _sav(amount: int, desc: String) -> void:
	savings_cents += amount
	savings_history.append({"day": GameTime.day(), "time": GameTime.clock_text(), "desc": desc, "amount": amount})
	if savings_history.size() > 300:
		savings_history = savings_history.slice(100)   # il saldo resta savings_cents; lo storico è solo vista
	savings_month_min = mini(savings_month_min, savings_cents)
	life_changed.emit()

func savings_consistent() -> bool:
	return savings_cents >= 0

## Ritorna "" se ok, altrimenti il messaggio d'errore (testi di Anchor).
func deposit(cents: int) -> String:
	if cents <= 0 or cents < int(cfg()["bank"]["savings"]["min_deposit_cents"]):
		return "Importo non valido."
	if not Economy.can_afford(cents):
		return "Nel conto hai solo %s €." % Data.euro(Economy.money_cents)
	if not Economy.spend(cents, "Versamento nel Salvadanaio", "risparmi"):
		return "Importo non valido."
	_sav(cents, "Versamento dal conto")
	return ""

func withdraw(cents: int) -> String:
	if cents <= 0:
		return "Importo non valido."
	if cents > savings_cents:
		return "Nei risparmi hai solo %s €." % Data.euro(savings_cents)
	_sav(-cents, "Prelievo verso il conto")
	Economy.earn(cents, "Prelievo dal Salvadanaio", "risparmi")
	return ""

# ======================================================================  AFFIDABILITÀ
func score_event(ev: String) -> void:
	var cs: Dictionary = cfg()["credit_score"]
	if ev == "" or not cs["events"].has(ev):
		return
	var delta: int = int(cs["events"][ev])
	if delta > 0:
		delta = mini(delta, int(cs["monthly_gain_cap"]) - score_gain_month)
		if delta <= 0:
			return
		score_gain_month += delta
	var old := credit_score
	credit_score = clampi(credit_score + delta, int(cs["min"]), int(cs["max"]))
	var real := credit_score - old
	score_log.append({"day": GameTime.day(), "delta": real, "reason": ev})
	if score_log.size() > 60:
		score_log = score_log.slice(20)
	score_changed.emit(credit_score, real, ev)

func score_band() -> String:
	var lbl := ""
	for b in cfg()["credit_score"]["ui_bands"]:
		if credit_score >= int(b["min"]):
			lbl = b["label"]
	return lbl

func _on_bill_event(kind: String, info: Dictionary) -> void:
	match kind:
		"paid":
			var ev: String = info.get("ok_event", "")
			if info.get("is_rent", false):
				ev = "rent_paid_on_time"
			if not info.get("late", false):
				score_event(ev)
		"late_fee":
			score_event("rent_late" if info.get("is_rent", false) else str(info.get("late_event", "bill_late")))
		"evicted":
			score_event("eviction")

# ======================================================================  REDDITO
func log_income(cents: int) -> void:
	var k := str(GameTime.day())
	income_log[k] = int(income_log.get(k, 0)) + cents

func net_income_28d() -> int:
	var d := GameTime.day()
	var s := 0
	for k in income_log:
		if int(k) > d - 28:
			s += int(income_log[k])
	return s

func _prune_income(d: int) -> void:
	for k in income_log.keys():
		if int(k) < d - 60:
			income_log.erase(k)

# ======================================================================  CASA
func all_homes() -> Array:
	return cfg()["homes_rent"] + cfg()["homes_sale"]

func home_by_id(id: String) -> Dictionary:
	for h in all_homes():
		if h["id"] == id:
			return h
	return {}

func home_cfg() -> Dictionary:
	return home_by_id(home_id)

func is_rental() -> bool:
	return owned_home.is_empty()

func furniture_slots() -> int:
	return int(home_cfg().get("furniture_slots", 3))

func furniture_used() -> int:
	var n := 0
	for f in furniture:
		if f != "letto_singolo_base":
			n += 1
	return n

## Configurazione affitto corrente nel formato usato da Economy.
func rent_cfg() -> Dictionary:
	var h := home_cfg()
	if not is_rental():
		return {}
	return {"amount_cents": int(h["rent_cents"]), "period_days": int(h["period_days"]), "first_due_day": rent_anchor_day,
		"late_fee_cents": int(h["late_fee_cents"]), "grace_days": int(h["grace_days"]),
		"eviction_after_missed_payments": int(h["eviction_after_missed_payments"]), "name": h["name"], "key": "rent" if home_id == "stanza_via_roma" else "rent_" + home_id}

func capability(c: String) -> bool:
	if c in home_cfg().get("provides", []):
		return true   # piano cottura della casa (a gas o incluso nel canone)
	for f in furniture:
		var fc := furniture_by_id(f)
		if c in fc.get("provides", []):
			return not power_suspended
	return false

func comfort() -> int:
	var bonus := 0
	for f in furniture:
		var e: Dictionary = furniture_by_id(f).get("effects", {})
		bonus += int(e.get("sleep_energy_per_hour_bonus", 0))
	return clampi(2 + furniture_used() + bonus * 2, 0, 10)

func sleep_energy_per_hour() -> float:
	var base := 12.0
	var bonus := 0.0
	for f in furniture:
		var e: Dictionary = furniture_by_id(f).get("effects", {})
		if e.has("sleep_energy_per_hour"):
			base = float(e["sleep_energy_per_hour"])
		bonus += float(e.get("sleep_energy_per_hour_bonus", 0))
	return base + bonus

func requirements_text(req) -> String:
	if req == null:
		return "nessuno"
	var p := []
	if req.has("credit_score_min"): p.append("affidabilità %d" % int(req["credit_score_min"]))
	if req.has("net_income_28d_min_cents"): p.append("entrate nette 28 gg € %s" % Data.euro(int(req["net_income_28d_min_cents"])))
	if req.has("cash_needed_cents"): p.append("liquidità € %s" % Data.euro(int(req["cash_needed_cents"])))
	return ", ".join(p)

## Requisito mancante per una casa (stringa vuota = ok).
func home_missing(h: Dictionary) -> String:
	var req = h.get("requirements", null)
	if req == null:
		return ""
	if credit_score < int(req.get("credit_score_min", 0)):
		return "affidabilità almeno %d (ora %d)" % [int(req["credit_score_min"]), credit_score]
	if net_income_28d() < int(req.get("net_income_28d_min_cents", 0)):
		return "entrate nette negli ultimi 28 giorni di almeno € %s (ora € %s)" % [Data.euro(int(req["net_income_28d_min_cents"])), Data.euro(net_income_28d())]
	if h.has("price_cents"):
		var m: Dictionary = cfg()["mortgage"]
		if Jobs.best_level() < int(m["min_job_level"]):
			return "un lavoro almeno di livello %d (promozione)" % int(m["min_job_level"])
		if not ("completo_colloquio" in wearing):
			return "indossare il Completo da colloquio per firmare in banca"
		if int(h["mortgage_installment_cents"]) * 100 > net_income_28d() * int(m["max_installment_pct_of_net_income"]):
			return "rata sotto il %d%% delle entrate" % int(m["max_installment_pct_of_net_income"])
	if furniture_used() > int(h["furniture_slots"]):
		return "spazio per i tuoi mobili (vendine qualcuno)"
	return ""

## Trasloco in affitto. Ritorna "" o il motivo.
func rent_home(id: String) -> String:
	var h := home_by_id(id)
	if h.is_empty() or not h.has("rent_cents"):
		return "Casa non trovata."
	if id == home_id and is_rental():
		return "Ci abiti già."
	var miss := home_missing(h)
	if miss != "":
		return "Non hai ancora i requisiti: %s." % miss
	if Economy.has_pending_rent():
		return "Prima salda l'affitto arretrato."
	var cost := int(h["deposit_cents"]) + int(h["rent_cents"])
	var refund := deposit_held_cents if is_rental() else 0
	if Economy.money_cents + refund < cost:
		return "Ti servono %s €, ne hai %s. Considera i risparmi." % [Data.euro(cost), Data.euro(Economy.money_cents + refund)]
	if refund > 0:
		Economy.earn(refund, "Cauzione restituita (%s)" % home_cfg()["name"], "cauzione")
	deposit_held_cents = 0
	Economy.spend(int(h["deposit_cents"]), "Cauzione %s" % h["name"], "cauzione")
	deposit_held_cents = int(h["deposit_cents"])
	home_id = id
	owned_home = {}
	rent_anchor_day = GameTime.day()
	var rc := rent_cfg()
	Economy.charge_once("%s:%d" % [rc["key"], 0], "Affitto %s (periodo 1)" % h["name"], int(h["rent_cents"]), GameTime.day(), "affitto", {"is_rent": true})
	life_changed.emit()
	return ""

## Acquisto con mutuo (anticipo + spese subito, rata mensile a fine mese).
func buy_home(id: String) -> String:
	var h := home_by_id(id)
	if h.is_empty() or not h.has("price_cents"):
		return "Casa non trovata."
	if not owned_home.is_empty():
		return "Hai già una casa di proprietà."
	var miss := home_missing(h)
	if miss != "":
		return "Non hai ancora i requisiti: %s." % miss
	var cash := int(h["down_payment_cents"]) + int(h["closing_costs_cents"])
	var refund := deposit_held_cents
	if Economy.money_cents + refund < cash:
		return "Ti servono %s €, ne hai %s. Considera i risparmi." % [Data.euro(cash), Data.euro(Economy.money_cents + refund)]
	if Economy.has_pending_rent():
		return "Prima salda l'affitto arretrato."
	if refund > 0:
		Economy.earn(refund, "Cauzione restituita (%s)" % home_cfg()["name"], "cauzione")
	deposit_held_cents = 0
	Economy.spend(int(h["down_payment_cents"]), "Anticipo %s" % h["name"], "casa_acquisto")
	Economy.spend(int(h["closing_costs_cents"]), "Notaio e spese %s" % h["name"], "casa_acquisto")
	home_id = id
	owned_home = {"id": id, "principal_left": int(h["mortgage_principal_cents"]), "installments_paid": 0, "missed": 0, "start_month": month_of_day(GameTime.day())}
	life_changed.emit()
	return ""

func _home_costs(d: int) -> void:
	if owned_home.is_empty():
		return
	var h := home_cfg()
	var mcfg: Dictionary = cfg()["mortgage"]
	for m in range(int(owned_home["start_month"]), month_of_day(d)):
		var key := "mutuo:%s:%d" % [owned_home["id"], m]
		if processed.has(key):
			continue
		processed[key] = true
		var due := (m + 1) * month_len()
		Economy.charge_once(key, "Rata mutuo %s (mese %d)" % [h["name"], m + 1], int(h["mortgage_installment_cents"]), due, "mutuo", {"grace": int(cfg()["bills"]["grace_days"]), "late_fee": int(mcfg["missed_installment"]["late_fee_cents"]), "late_event": "loan_installment_late", "ok_event": "loan_installment_on_time", "mortgage": true})
		Economy.charge_once("condo:%d" % m, "Spese condominiali (mese %d)" % (m + 1), int(h["condo_fees_monthly_cents"]), due, "condominio", {"grace": int(cfg()["bills"]["grace_days"]), "late_fee": int(cfg()["bills"]["late_fee_cents"]), "late_event": "bill_late", "ok_event": ""})
		owned_home["installments_paid"] = int(owned_home["installments_paid"]) + 1
		# quota capitale semplificata: rata - interessi del mese
		var i_cents := int(round(float(owned_home["principal_left"]) * float(mcfg["tan_bp"]) / 10000.0 / 12.0))
		owned_home["principal_left"] = maxi(0, int(owned_home["principal_left"]) - (int(h["mortgage_installment_cents"]) - i_cents))
	# rate non pagate: dopo 3 la banca propone la vendita assistita (conseguenza mite e spiegata)
	var missed := 0
	for b in Economy.pending_bills:
		if b.get("mortgage", false):
			missed += 1
	owned_home["missed"] = missed
	if missed >= int(mcfg["missed_installment"]["foreclosure_after_missed"]):
		_assisted_sale()

## Vendita assistita: la casa torna alla banca al prezzo di acquisto meno il debito; si torna nella stanza.
## Le rate arretrate vengono chiuse con il ricavato. Nessuna umiliazione, si riparte (Guard).
func _assisted_sale() -> void:
	var h := home_cfg()
	var arrears := 0
	var keep: Array = []
	for b in Economy.pending_bills:
		if b.get("mortgage", false):
			arrears += int(b["amount"])
		else:
			keep.append(b)
	Economy.pending_bills = keep
	var equity: int = maxi(0, int(h["price_cents"]) - int(owned_home["principal_left"]) - arrears - int(h["closing_costs_cents"]))
	score_event("foreclosure")
	owned_home = {}
	home_id = "stanza_via_roma"
	rent_anchor_day = GameTime.day()
	deposit_held_cents = 0
	if equity > 0:
		Economy.earn(equity, "Vendita assistita della casa: ti resta il capitale già pagato", "casa_acquisto")
	Game.toast("La banca ha concordato con te la vendita della casa. Torni nella stanza di Via dei Tigli e ti resta € %s." % Data.euro(equity), "warn")

# ======================================================================  BOLLETTE DI CASA
func _utility_bills(d: int) -> void:
	var h := home_cfg()
	var inc: Array = h.get("bills_included", [])
	var bills: Dictionary = cfg()["bills"]
	var opts := {"grace": int(bills["grace_days"]), "late_fee": int(bills["late_fee_cents"]), "late_event": "bill_late", "ok_event": "bill_paid_on_time", "utility": true}
	for m in range(0, month_of_day(d)):
		var due := (m + 1) * month_len()
		if not ("luce" in inc) and not processed.has("luce:%d" % m):
			processed["luce:%d" % m] = true
			var kwh := float(h.get("kwh_base_per_month", 0)) + float(wh_month) / 1000.0
			for f in furniture:
				kwh += float(furniture_by_id(f).get("kwh_per_month", 0))
			var amt := int(bills["electricity"]["fixed_cents"]) + int(round(kwh * float(bills["electricity"]["price_cents_per_kwh"])))
			Economy.charge_once("luce:%d" % m, "Bolletta luce mese %d (%.0f kWh)" % [m + 1, kwh], amt, due, "luce", opts)
		if not ("gas" in inc) and not processed.has("gas:%d" % m):
			processed["gas:%d" % m] = true
			var smc := float(h.get("smc_base_per_month", 0))
			if calendar_month(due) in bills["gas"]["heating_months"]:
				smc += float(h.get("smc_heating_per_month", 0))
			var g := int(bills["gas"]["fixed_cents"]) + int(round(smc * float(bills["gas"]["price_cents_per_smc"])))
			Economy.charge_once("gas:%d" % m, "Bolletta gas mese %d (%.0f Smc)" % [m + 1, smc], g, due, "gas", opts)
		var tari: Dictionary = cfg()["taxes"]["tari"]
		var annual: int = int(tari["annual_amount_cents_by_home"].get(home_id, 0))
		if annual > 0 and m % int(tari["installment_every_game_months"]) == 0 and not processed.has("tari:%d" % m):
			processed["tari:%d" % m] = true
			Economy.charge_once("tari:%d" % m, "%s rata %d" % [tari["name"], m / 3 + 1], annual / int(tari["installments_per_year"]), due, "tari", {"grace": int(bills["grace_days"]), "late_fee": int(tari["late_fee_cents"]), "late_event": "bill_late", "ok_event": "bill_paid_on_time"})

func _unpaid_utilities() -> int:
	var n := 0
	for b in Economy.pending_bills:
		if b.get("utility", false):
			n += 1
	return n

func use_appliance(wh: int) -> void:
	if not ("luce" in home_cfg().get("bills_included", [])):
		wh_month += wh

# ======================================================================  MOBILI E VESTITI
func furniture_by_id(id: String) -> Dictionary:
	for f in cfg()["furniture"]:
		if f["id"] == id:
			return f
	return {}

func clothes_by_id(id: String) -> Dictionary:
	for c in cfg()["clothes"]:
		if c["id"] == id:
			return c
	return {}

func resale_cents(price: int, pct: int) -> int:
	return price * pct / 100   # sempre sotto il prezzo: nessun ciclo compra/rivendi in guadagno

func buy_furniture(id: String) -> String:
	var f := furniture_by_id(id)
	if f.is_empty():
		return "Mobile non trovato."
	if id in furniture:
		return "Ce l'hai già."
	if furniture_used() >= furniture_slots():
		return "Non c'è più spazio. Vendi un mobile o cerca una casa più grande."
	if not Economy.spend(int(f["price_cents"]), "Mobili: %s" % f["name"], "mobili"):
		return "Ti servono %s €, ne hai %s." % [Data.euro(int(f["price_cents"])), Data.euro(Economy.money_cents)]
	furniture.append(id)
	life_changed.emit()
	return ""

func sell_furniture(id: String) -> String:
	if not (id in furniture) or id == "letto_singolo_base":
		return "Non puoi venderlo."
	var f := furniture_by_id(id)
	furniture.erase(id)
	var r := resale_cents(int(f["price_cents"]), int(cfg()["furniture_resale_pct"]))
	if r > 0:
		Economy.earn(r, "Vendita mobile usato: %s" % f["name"], "vendita")
	life_changed.emit()
	return ""

func buy_clothes(id: String) -> String:
	var c := clothes_by_id(id)
	if c.is_empty():
		return "Capo non trovato."
	if id in clothes:
		return "Ce l'hai già."
	if not GameTime.is_open(cfg()["clothes_shop"]["hours"]):
		return "Chiuso. Riapre %s." % GameTime.next_open_text(cfg()["clothes_shop"]["hours"])
	if not Economy.spend(int(c["price_cents"]), "Boutique Marisa: %s" % c["name"], "vestiti"):
		return "Ti servono %s €, ne hai %s." % [Data.euro(int(c["price_cents"])), Data.euro(Economy.money_cents)]
	clothes.append(id)
	if not (id in wearing):
		wearing.append(id)
	life_changed.emit()
	return ""

func sell_clothes(id: String) -> String:
	if not (id in clothes) or id == "maglietta_base":
		return "Non puoi venderlo."
	var c := clothes_by_id(id)
	clothes.erase(id)
	wearing.erase(id)
	var r := resale_cents(int(c["price_cents"]), int(cfg()["clothes_resale_pct"]))
	if r > 0:
		Economy.earn(r, "Vendita capo usato: %s" % c["name"], "vendita")
	life_changed.emit()
	return ""

func toggle_wear(id: String) -> void:
	if not (id in clothes):
		return
	if id in wearing:
		wearing.erase(id)
	else:
		wearing.append(id)
	life_changed.emit()

func worn_effect(key: String) -> int:
	var s := 0
	for w in wearing:
		s += int(clothes_by_id(w).get("effects", {}).get(key, 0))
	return s

func interview_score() -> int:
	var best := 0
	for k in skills:
		best = maxi(best, int(skills[k]))
	return 40 + best / 2 + worn_effect("interview_bonus")

func add_skill(k: String, n: int) -> void:
	skills[k] = mini(100, int(skills.get(k, 0)) + n)

# ======================================================================  PALESTRA
func gym() -> Dictionary:
	return cfg()["gym"]

func gym_has_pass() -> bool:
	return GameTime.day() < gym_pass_until

func buy_gym_pass() -> String:
	if gym_has_pass():
		return "Hai già l'abbonamento fino al giorno %d." % gym_pass_until
	if not Economy.spend(int(gym()["monthly_pass_cents"]), "%s: abbonamento 28 giorni" % gym()["name"], "palestra"):
		return "Ti servono %s €, ne hai %s." % [Data.euro(int(gym()["monthly_pass_cents"])), Data.euro(Economy.money_cents)]
	gym_pass_until = GameTime.day() + month_len()
	return ""

## Allenamento di 1 ora. Ritorna {ok, text}.
func gym_session(pay_single: bool) -> Dictionary:
	var g := gym()
	if not GameTime.is_open(g["hours"]):
		return {"ok": false, "text": "Chiuso. Riapre %s." % GameTime.next_open_text(g["hours"])}
	var cost_e: int = -int(g["session_effects"]["energy"]) - worn_effect("gym_energy_cost_reduction")
	if Needs.energy < cost_e + 5:
		return {"ok": false, "text": "Sei troppo stanco per allenarti: riposa prima."}
	if not gym_has_pass():
		if not pay_single:
			return {"ok": false, "text": "Serve l'abbonamento o un ingresso singolo."}
		if not Economy.spend(int(g["single_entry_cents"]), "%s: ingresso singolo" % g["name"], "palestra"):
			return {"ok": false, "text": "Ti servono %s €, ne hai %s." % [Data.euro(int(g["single_entry_cents"])), Data.euro(Economy.money_cents)]}
	GameTime.advance(60.0 * float(g["session_hours"]))
	Needs.energy -= cost_e
	Needs.hunger += float(g["session_effects"]["hunger"])
	Needs.eat(0, 0)
	add_skill("fisico", int(g["session_effects"]["fisico_skill"]))
	gym_last_day = GameTime.day()
	var msg := "Allenamento fatto: energia −%d, fame %d, fisico +%d." % [cost_e, int(g["session_effects"]["hunger"]), int(g["session_effects"]["fisico_skill"])]
	if gym_last_counted_day != GameTime.day():
		gym_last_counted_day = GameTime.day()
		gym_sessions += 1
		if gym_sessions % 3 == 0 and energy_max < 100:
			energy_max += 1
			msg += " Energia massima: %d." % energy_max
	life_changed.emit()
	return {"ok": true, "text": msg}

func _gym_decay(d: int) -> void:
	# -1 energia massima ogni 7 giorni senza palestra, mai sotto 90
	if energy_max <= 90:
		return
	var since := d - maxi(gym_last_day, 1)
	var k := "gymdecay:%d" % (since / 7)
	if since >= 7 and not processed.has(k + ":%d" % gym_last_day):
		processed[k + ":%d" % gym_last_day] = true
		energy_max = maxi(90, energy_max - 1)

# ======================================================================  STUDIO / CAFFÈ A CASA
func study(skill: String) -> String:
	if not ("scrivania_sedia" in furniture):
		return "Ti serve una scrivania."
	var e: Dictionary = furniture_by_id("scrivania_sedia")["effects"]
	var k := str(GameTime.day())
	if int(study_hours_today.get(k, 0)) >= int(e["study_max_hours_per_day"]):
		return "Per oggi hai studiato abbastanza."
	study_hours_today = {k: int(study_hours_today.get(k, 0)) + 1}
	GameTime.advance(60.0)
	Needs.energy += float(e["study_energy_per_hour"])
	Needs.eat(0, 0)
	add_skill(skill, int(e["study_skill_per_hour"]))
	return ""

func home_coffee() -> String:
	if not ("macchina_caffe" in furniture):
		return "Non hai la macchina del caffè."
	if not capability("cucina") and power_suspended:
		return "Luce sospesa: paga la bolletta."
	if capsules <= 0:
		var cons: Dictionary = furniture_by_id("macchina_caffe")["consumable"]
		if not Economy.spend(int(cons["price_cents"]), "Capsule caffè (10)", "spesa"):
			return "Servono le capsule (€ %s)." % Data.euro(int(cons["price_cents"]))
		capsules = 10
	capsules -= 1
	var e: Dictionary = furniture_by_id("macchina_caffe")["effects"]
	Needs.eat(0, float(e["energy_per_use"]))
	use_appliance(int(furniture_by_id("macchina_caffe")["wh_per_use"]))
	if coffee_skill_day != GameTime.day():
		coffee_skill_day = GameTime.day()
		add_skill("caffe", int(e["caffe_skill_per_day"]))
	return ""

# ======================================================================  BUS
func bus_has_pass() -> bool:
	return GameTime.day() < bus_pass_until

func buy_bus_pass() -> String:
	var b: Dictionary = cfg()["transport"]["bus"]
	if bus_has_pass():
		return "L'abbonamento vale fino al giorno %d." % bus_pass_until
	if not Economy.spend(int(b["monthly_pass_cents"]), "Abbonamento bus 28 giorni", "bus"):
		return "Ti servono %s €, ne hai %s." % [Data.euro(int(b["monthly_pass_cents"])), Data.euro(Economy.money_cents)]
	bus_pass_until = GameTime.day() + month_len()
	return ""

## Paga la corsa (o usa l'abbonamento). "" = ok.
func pay_bus_ride() -> String:
	if bus_has_pass():
		return ""
	var b: Dictionary = cfg()["transport"]["bus"]
	if not Economy.spend(int(b["ticket_cents"]), "Biglietto bus", "bus"):
		return "Il biglietto costa %s €: ne hai %s." % [Data.euro(int(b["ticket_cents"])), Data.euro(Economy.money_cents)]
	return ""

# ======================================================================  AUTO
func car_models() -> Array:
	return cfg()["cars"]["models"]

func car_model(id: String = "") -> Dictionary:
	if id == "":
		id = str(car.get("model", ""))
	for m in car_models():
		if m["id"] == id:
			return m
	return {}

func has_car() -> bool:
	return not car.is_empty()

func insured() -> bool:
	return has_car() and GameTime.day() < int(car.get("ins_until", 0))

func installment_cents(principal: int) -> int:
	var p: Dictionary = cfg()["cars"]["purchase"]["installment_plan"]
	var i: float = float(p["tan_bp"]) / 10000.0 / 12.0
	var n: int = int(p["term_months"])
	return int(round(principal * i / (1.0 - pow(1.0 + i, -n))))

## Acquisto auto. plan=false: tutto subito. Ritorna "" o il motivo.
func buy_car(id: String, plan: bool, spawn_pos: Vector3 = Vector3(-25, 0, -50), yaw: float = 0.0) -> String:
	var m := car_model(id)
	if m.is_empty():
		return "Modello non trovato."
	if has_car():
		return "Hai già un'auto."
	var pc: Dictionary = cfg()["cars"]["purchase"]
	var transfer := int(pc["ownership_transfer_cents"])
	var tax := int(m["road_tax_annual_cents"])
	if not plan:
		var total := int(m["price_cents"]) + transfer + tax
		if not Economy.can_afford(total):
			return "Ti servono %s €, ne hai %s." % [Data.euro(total), Data.euro(Economy.money_cents)]
		Economy.spend(int(m["price_cents"]), "Auto usata: %s" % m["name"], "auto")
		Economy.spend(transfer, "Passaggio di proprietà", "auto")
		Economy.spend(tax, "Bollo auto (1 anno)", "bollo")
		car = _new_car(m, spawn_pos, yaw, {})
	else:
		var ip: Dictionary = pc["installment_plan"]
		if credit_score < int(ip["min_credit_score"]):
			return "Per le rate serve affidabilità almeno %d (ora %d)." % [int(ip["min_credit_score"]), credit_score]
		if Jobs.total_shifts() < int(ip["min_shifts_completed"]):
			return "Per le rate servono almeno %d turni di lavoro completati." % int(ip["min_shifts_completed"])
		var down: int = int(m["price_cents"]) * int(ip["down_payment_pct"]) / 100
		var principal: int = int(m["price_cents"]) - down + transfer
		var rata := installment_cents(principal)
		if rata * 100 > net_income_28d() * int(ip["max_installment_pct_of_net_income"]):
			return "La rata (€ %s) supera il %d%% delle tue entrate degli ultimi 28 giorni." % [Data.euro(rata), int(ip["max_installment_pct_of_net_income"])]
		if not Economy.can_afford(down + tax):
			return "Ti servono %s € di anticipo e bollo, ne hai %s." % [Data.euro(down + tax), Data.euro(Economy.money_cents)]
		Economy.spend(down, "Anticipo auto: %s" % m["name"], "auto")
		Economy.spend(tax, "Bollo auto (1 anno)", "bollo")
		car = _new_car(m, spawn_pos, yaw, {"left": int(ip["term_months"]), "rata": rata, "start_month": month_of_day(GameTime.day()) + 1})
	car_changed.emit()
	life_changed.emit()
	return ""

func _new_car(m: Dictionary, pos: Vector3, yaw: float, plan: Dictionary) -> Dictionary:
	return {"model": m["id"], "fuel_l": 8.0, "km": float(m.get("km_start", 100000)), "km_bought": float(m.get("km_start", 100000)), "wear_pct": 0.0,
		"ins_until": 0, "pos": [pos.x, pos.y, pos.z], "yaw": yaw, "plan": plan, "tax_until": GameTime.day() + 336}

func buy_insurance() -> String:
	if not has_car():
		return "Non hai un'auto."
	var m := car_model()
	if not Economy.spend(int(m["insurance_monthly_cents"]), "Assicurazione RC (28 giorni)", "assicurazione"):
		return "Ti servono %s €, ne hai %s." % [Data.euro(int(m["insurance_monthly_cents"])), Data.euro(Economy.money_cents)]
	car["ins_until"] = maxi(int(car["ins_until"]), GameTime.day()) + month_len()
	car_changed.emit()
	return ""

func fuel_station_open() -> bool:
	return GameTime.is_open(cfg()["cars"]["fuel_station"]["hours"])

## Rifornimento: liters = 0 → pieno. Ritorna {ok, text}.
func refuel(liters: float) -> Dictionary:
	if not has_car():
		return {"ok": false, "text": "Non hai un'auto."}
	if not fuel_station_open():
		return {"ok": false, "text": "Chiuso. Riapre alle %s." % cfg()["cars"]["fuel_station"]["hours"]["open"]}
	var tank := float(car_model().get("tank_l", 35))
	var space := tank - float(car["fuel_l"])
	if space < 0.5:
		return {"ok": false, "text": "Il serbatoio è già pieno."}
	var l: float = space if liters <= 0.0 else minf(liters, space)
	var cost := int(round(l * float(cfg()["cars"]["fuel_price_cents_per_liter"])))
	if not Economy.spend(cost, "Benzina %.1f L" % l, "benzina"):
		return {"ok": false, "text": "Ti servono %s €, ne hai %s." % [Data.euro(cost), Data.euro(Economy.money_cents)]}
	car["fuel_l"] = float(car["fuel_l"]) + l
	car_changed.emit()
	return {"ok": true, "text": "Rifornimento fatto: −%s €. Serbatoio al %d%%." % [Data.euro(cost), fuel_pct()]}

func fuel_pct() -> int:
	if not has_car():
		return 0
	return int(round(100.0 * float(car["fuel_l"]) / float(car_model().get("tank_l", 35))))

## Ritorna "" se si può guidare, altrimenti il motivo.
func can_drive() -> String:
	if not has_car():
		return "Non hai un'auto."
	if not insured():
		return "Senza assicurazione non puoi guidare."
	if float(car["fuel_l"]) <= 0.01:
		return "Benzina finita. L'auto non parte."
	if float(car["wear_pct"]) >= 100.0:
		return "Auto ferma: serve la riparazione dal meccanico (€ %s)." % Data.euro(int(cfg()["cars"]["maintenance"]["repair_at_100_pct"]["cents"]))
	return ""

## Percorrenza di dist metri di gioco: consuma benzina e usura (km "reali" = dist * km_per_world_unit).
func drive_distance(world_m: float) -> void:
	if not has_car():
		return
	var km: float = world_m * float(cfg()["cars"]["drive"]["km_per_world_unit"])
	car["km"] = float(car["km"]) + km
	var lp100: float = float(car_model()["fuel_l_per_100km_x10"]) / 10.0
	car["fuel_l"] = maxf(0.0, float(car["fuel_l"]) - km * lp100 / 100.0)
	car["wear_pct"] = minf(100.0, float(car["wear_pct"]) + km / 100.0 * float(cfg()["cars"]["maintenance"]["wear_pct_per_100_km"]))

func service_car() -> String:
	if not has_car():
		return "Non hai un'auto."
	var mt: Dictionary = cfg()["cars"]["maintenance"]
	var cost: int = int(mt["repair_at_100_pct"]["cents"]) if float(car["wear_pct"]) >= 100.0 else int(mt["service_cents"])
	if not Economy.spend(cost, "Officina: tagliando/riparazione", "auto"):
		return "Ti servono %s €, ne hai %s." % [Data.euro(cost), Data.euro(Economy.money_cents)]
	car["wear_pct"] = 0.0
	car_changed.emit()
	return ""

func _car_costs(d: int) -> void:
	if not has_car():
		return
	var plan: Dictionary = car.get("plan", {})
	if not plan.is_empty():
		for m in range(int(plan["start_month"]), month_of_day(d)):
			var key := "rata_auto:%d" % m
			if processed.has(key) or int(plan["left"]) <= 0:
				continue
			processed[key] = true
			plan["left"] = int(plan["left"]) - 1
			Economy.charge_once(key, "Rata auto (mancano %d)" % int(plan["left"]), int(plan["rata"]), (m + 1) * month_len(), "rata_auto", {"grace": int(cfg()["bills"]["grace_days"]), "late_fee": int(cfg()["bills"]["late_fee_cents"]), "late_event": "loan_installment_late", "ok_event": "loan_installment_on_time"})
	if d >= int(car.get("tax_until", 0)):
		var m2 := car_model()
		var k2 := "bollo:%d" % int(car["tax_until"])
		if not processed.has(k2):
			processed[k2] = true
			car["tax_until"] = int(car["tax_until"]) + 336
			Economy.charge_once(k2, "Bollo auto (1 anno)", int(m2["road_tax_annual_cents"]), d, "bollo", {"grace": int(cfg()["bills"]["grace_days"]), "late_fee": int(cfg()["bills"]["late_fee_cents"]), "late_event": "bill_late", "ok_event": "bill_paid_on_time"})

## Sosta: sulle strisce blu (08-20) serve il ticket o il pass residenti. Ritorna "" se si può lasciare l'auto.
func parking_needed(in_blue: bool) -> bool:
	if not in_blue:
		return false
	if GameTime.day() < resident_pass_until:
		return false
	var p: Dictionary = cfg()["cars"]["parking"]
	var hrs: PackedStringArray = str(p["blue_lines_hours"]).split("-")
	var m := GameTime.minute_of_day()
	if m < Data.hhmm_to_min(hrs[0]) or m >= Data.hhmm_to_min(hrs[1]):
		return false
	return GameTime.total_minutes >= parking_ticket_until

func buy_parking_ticket(hours: int) -> String:
	var p: Dictionary = cfg()["cars"]["parking"]
	var cost := int(p["blue_lines_cents_per_hour"]) * hours
	if not Economy.spend(cost, "Parcheggio strisce blu %d h" % hours, "parcheggio"):
		return "Il ticket costa %s €: ne hai %s." % [Data.euro(cost), Data.euro(Economy.money_cents)]
	parking_ticket_until = maxf(parking_ticket_until, GameTime.total_minutes) + 60.0 * hours
	return ""

func buy_resident_pass() -> String:
	var p: Dictionary = cfg()["cars"]["parking"]
	if not Economy.spend(int(p["resident_pass_cents_per_month"]), "Pass residenti strisce blu (28 giorni)", "parcheggio"):
		return "Il pass costa %s €: ne hai %s." % [Data.euro(int(p["resident_pass_cents_per_month"])), Data.euro(Economy.money_cents)]
	resident_pass_until = maxi(resident_pass_until, GameTime.day()) + month_len()
	return ""

# ======================================================================  IMPREVISTO DEL GIOVEDÌ (deterministico)
func _thursday_event(d: int) -> void:
	if GameTime.weekday_code(d) != "gio" or d < 4:
		return
	var w := (d - 1) / 7
	var key := "thu:%d" % w
	if processed.has(key):
		return
	processed[key] = true
	var evs: Array = cfg()["thursday_events"]
	var pool: Array = []
	for e in evs:
		if not (e.get("requires_job", false) and not Jobs.any_employed()):
			pool.append(e)
	var ev: Dictionary = pool[w % pool.size()]
	var amt := int(ev["amount_cents"])
	last_event = {"day": d, "text": ev["text"], "amount": amt}
	if amt > 0:
		Economy.earn(amt, "Imprevisto: " + ev["text"], "imprevisto")
	elif amt < 0:
		Economy.charge_once("evt:%d" % w, "Imprevisto: " + ev["text"], -amt, d, "imprevisto", {"grace": 5, "late_fee": 0, "late_event": "", "ok_event": ""})
	if not Game.headless_test:
		Game.toast("Imprevisto del giovedì: %s %s%s €." % [ev["text"], "+" if amt > 0 else "−", Data.euro(absi(amt))], "warn" if amt < 0 else "ok")

# ======================================================================  RIEPILOGHI
## Spese per categoria negli ultimi n giorni (dallo storico del conto). Esclude i giroconti.
func spending_by_category(days: int) -> Dictionary:
	var out := {"Cibo": 0, "Affitto": 0, "Casa": 0, "Auto": 0, "Benzina": 0, "Assicurazione": 0, "Altro": 0}
	var income := 0
	var d0 := GameTime.day() - days
	for t in Economy.history:
		if int(t["day"]) <= d0:
			continue
		var a := int(t["amount"])
		var k := str(t.get("kind", ""))
		if k == "risparmi":
			continue
		if a > 0:
			income += a
			continue
		out[category_for(k)] += -a
	out["_entrate"] = income
	return out

static func category_for(kind: String) -> String:
	match kind:
		"spesa", "bar", "trattoria", "cibo":
			return "Cibo"
		"affitto":
			return "Affitto"
		"mobili", "bolletta", "luce", "gas", "tari", "canone", "mutuo", "condominio", "cauzione", "casa_acquisto", "telefono":
			return "Casa"
		"auto", "rata_auto", "bollo", "parcheggio":
			return "Auto"
		"benzina":
			return "Benzina"
		"assicurazione":
			return "Assicurazione"
	return "Altro"

# ======================================================================  SALVATAGGIO
func to_dict() -> Dictionary:
	return {"savings_cents": savings_cents, "savings_history": savings_history, "savings_month_min": savings_month_min,
		"credit_score": credit_score, "score_gain_month": score_gain_month, "score_log": score_log, "processed": processed.keys(),
		"home_id": home_id, "rent_anchor_day": rent_anchor_day, "deposit_held_cents": deposit_held_cents, "owned_home": owned_home,
		"furniture": furniture, "clothes": clothes, "wearing": wearing, "equipment": equipment, "skills": skills,
		"energy_max": energy_max, "gym_pass_until": gym_pass_until, "gym_sessions": gym_sessions, "gym_last_counted_day": gym_last_counted_day,
		"gym_last_day": gym_last_day, "study_hours_today": study_hours_today, "coffee_skill_day": coffee_skill_day,
		"bus_pass_until": bus_pass_until, "wh_month": wh_month, "power_suspended": power_suspended, "income_log": income_log,
		"car": car, "parking_ticket_until": parking_ticket_until, "resident_pass_until": resident_pass_until, "goal": goal, "last_event": last_event, "capsules": capsules}

func from_dict(d: Dictionary) -> void:
	reset_new_game()
	savings_cents = int(d.get("savings_cents", 0))
	savings_history = d.get("savings_history", [])
	savings_month_min = int(d.get("savings_month_min", savings_cents))
	credit_score = int(d.get("credit_score", 600))
	score_gain_month = int(d.get("score_gain_month", 0))
	score_log = d.get("score_log", [])
	processed.clear()
	for k in d.get("processed", []):
		processed[str(k)] = true
	home_id = str(d.get("home_id", "stanza_via_roma"))
	rent_anchor_day = int(d.get("rent_anchor_day", 1))
	deposit_held_cents = int(d.get("deposit_held_cents", deposit_held_cents))
	owned_home = d.get("owned_home", {})
	for k in ["principal_left", "installments_paid", "missed", "start_month"]:
		if owned_home.has(k):
			owned_home[k] = int(owned_home[k])
	furniture = d.get("furniture", furniture)
	clothes = d.get("clothes", clothes)
	wearing = d.get("wearing", wearing)
	equipment = d.get("equipment", [])
	var sk: Dictionary = d.get("skills", skills)
	for k in sk:
		skills[k] = int(sk[k])
	energy_max = int(d.get("energy_max", 90))
	gym_pass_until = int(d.get("gym_pass_until", 0))
	gym_sessions = int(d.get("gym_sessions", 0))
	gym_last_counted_day = int(d.get("gym_last_counted_day", -1))
	gym_last_day = int(d.get("gym_last_day", 0))
	study_hours_today = d.get("study_hours_today", {})
	coffee_skill_day = int(d.get("coffee_skill_day", -1))
	bus_pass_until = int(d.get("bus_pass_until", 0))
	wh_month = int(d.get("wh_month", 0))
	power_suspended = bool(d.get("power_suspended", false))
	income_log = {}
	var il: Dictionary = d.get("income_log", {})
	for k in il:
		income_log[str(k)] = int(il[k])
	car = d.get("car", {})
	if not car.is_empty():
		for k in ["fuel_l", "km", "km_bought", "wear_pct", "yaw"]:
			car[k] = float(car.get(k, 0))
		for k in ["ins_until", "tax_until"]:
			car[k] = int(car.get(k, 0))
		var pl: Dictionary = car.get("plan", {})
		for k in pl:
			pl[k] = int(pl[k])
	parking_ticket_until = float(d.get("parking_ticket_until", -1.0))
	resident_pass_until = int(d.get("resident_pass_until", 0))
	goal = d.get("goal", {})
	last_event = d.get("last_event", {})
	capsules = int(d.get("capsules", 0))
	life_changed.emit()
	car_changed.emit()
