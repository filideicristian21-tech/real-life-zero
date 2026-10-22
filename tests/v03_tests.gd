extends RefCounted
## Test automatici v0.3: casi di Hook v0.3 (B, L, J, H, A, X) automatizzabili + i 6 test di bilanciamento
## di Ledger portati da Python a GDScript. Chiamati da run_tests.gd (fase "all").

var T   # runner (run_tests.gd)

func _init(runner) -> void:
	T = runner

func run() -> void:
	b_bank()
	b_interest()
	l_bills()
	l_unpaid()
	j_three_jobs()
	j_late_overlap_quit()
	h_furniture()
	h_move_home()
	a_car()
	a_recurring()
	x_thursday()
	x_gym_comfort_bus()
	x_score()
	x_30_days()
	x_zero_recovery()
	x_migrate_v02()
	ledger_tests()
	x_texts_guard()
	x_new_apps()
	h_save_many()
	a_save_parked()

func hist_count(prefix: String) -> int:
	var n := 0
	for t in Economy.history:
		if str(t["desc"]).begins_with(prefix):
			n += 1
	return n

func give(c: int) -> void:
	Economy.earn(c, "Test: fondi di prova", "test")

func save_reload() -> bool:
	var ok := SaveSystem.save_game()
	Economy.money_cents += 777   # rovina lo stato in memoria
	Life.savings_cents += 555
	return ok and SaveSystem.load_game()

# ---------------------------------------------------------------- B banca
func b_bank() -> void:
	T.fresh(1, "09:00")
	var m0 := Economy.money_cents
	var s0 := Life.savings_cents
	var h0 := Economy.history.size()
	var e1 := Life.deposit(10000)
	var mid := [Economy.money_cents, Life.savings_cents]
	var e2 := Life.withdraw(4000)
	var moved := Economy.money_cents == m0 - 6000 and Life.savings_cents == s0 + 6000
	# B3: oltre il saldo
	var snap := [Economy.money_cents, Life.savings_cents, Economy.history.size()]
	var r1 := Life.withdraw(Life.savings_cents + 1)
	var r2 := Life.deposit(Economy.money_cents + 1)
	# B5: importi limite
	var r3 := Life.deposit(0)
	var r4 := Life.deposit(-500)
	var r5 := Life.withdraw(-1)
	var r6 := Life.deposit(9223372036854775)
	var unchanged := snap == [Economy.money_cents, Life.savings_cents, Economy.history.size()]
	T.record("V-B2/B3/B5", "Banca: versa/preleva, rifiuti oltre il saldo e importi non validi", [
		[e1 == "" and e2 == "" and mid[0] == m0 - 10000, "versati € 100 e prelevati € 40: conto e risparmi si spostano dello stesso importo"],
		[moved and Economy.money_cents + Life.savings_cents == m0 + s0, "nessuna moneta creata o persa (totale € %s)" % Data.euro(Economy.money_cents + Life.savings_cents)],
		[Economy.history.size() == h0 + 2 and Life.savings_history.size() >= 2, "2 voci nello storico del conto, 2 nei risparmi"],
		[r1 != "" and r2 != "", "prelievo e versamento oltre il disponibile rifiutati: «%s» / «%s»" % [r1, r2]],
		[r3 != "" and r4 != "" and r5 != "" and r6 != "", "0, negativi e importo enorme rifiutati"],
		[unchanged and Economy.is_consistent(), "dopo i rifiuti niente cambia; saldo = storico"],
	])

func b_interest() -> void:
	# €10.000 fermi un mese: 12,33 € netti (Ledger); versamento il giorno 28: 0 €; un solo accredito anche dopo save/load
	T.fresh(1, "09:00")
	give(1000000)
	Life.deposit(1000000)
	Life.savings_month_min = Life.savings_cents   # saldo minimo del mese = saldo dal giorno 1
	T.set_time(29, "09:00")
	var interest := 0
	for t in Life.savings_history:
		if str(t["desc"]).begins_with("Interessi"):
			interest += int(t["amount"])
	var fee := hist_count("Canone") + _pending_count("canone:0")
	var ok_sl := save_reload()
	Economy.process_bills()
	var interest2 := 0
	for t in Life.savings_history:
		if str(t["desc"]).begins_with("Interessi"):
			interest2 += int(t["amount"])
	var turno := Jobs.net_pay("barista")
	# deposito all'ultimo giorno
	T.fresh(1, "09:00")
	T.set_time(28, "10:00")
	give(1000000)
	Life.deposit(1000000)
	T.set_time(29, "09:00")
	var late_int := 0
	for t in Life.savings_history:
		if str(t["desc"]).begins_with("Interessi"):
			late_int += int(t["amount"])
	T.record("V-B7", "Interessi sul saldo minimo del mese (2% lordo, 26% ritenuta) e canone mensile", [
		[interest == 1233, "€ 10.000 fermi per 28 giorni: € %s netti (Ledger: 12,33)" % Data.euro(interest)],
		[interest < turno, "meno di un turno da barista (€ %s)" % Data.euro(turno)],
		[late_int == 0, "versamento il giorno 28: interessi € %s (non sfruttabile)" % Data.euro(late_int)],
		[fee == 1, "canone del conto (€ 2) addebitato una volta a fine mese"],
		[ok_sl and interest2 == interest and hist_count("Canone") + _pending_count("canone:0") == 1, "dopo salva/carica nessun accredito o canone ripetuto"],
		[Economy.is_consistent(), "saldo = storico"],
	])

# ---------------------------------------------------------------- L bollette
func _set_home(id: String) -> void:
	Life.home_id = id
	Life.rent_anchor_day = GameTime.day()
	Life.deposit_held_cents = int(Life.home_cfg().get("deposit_cents", 0))

func l_bills() -> void:
	T.fresh(1, "09:00")
	give(400000)
	_set_home("monolocale_corso")
	T.set_time(29, "09:00")
	var luce := hist_count("Bolletta luce") + _pending_count("luce:0")
	var gas := hist_count("Bolletta gas") + _pending_count("gas:0")
	# paga subito quelle in sospeso (L2) e verifica che alla scadenza non ripartano
	while not Economy.pending_bills.is_empty() and Economy.pay_pending(0):
		pass
	var before := Economy.history.size()
	var ok_sl := save_reload()
	Economy.process_bills()
	T.set_time(30, "09:00")
	var luce2 := hist_count("Bolletta luce")
	T.record("V-L1/L2/L6", "Bollette luce/gas del monolocale: una volta per mese, anche dopo salva/carica", [
		[luce == 1 and gas == 1, "mese 1: luce %d, gas %d (attese 1 e 1)" % [luce, gas]],
		[ok_sl and luce2 == 1, "dopo salva/carica e un giorno in più: ancora 1 bolletta luce"],
		[Economy.history.size() >= before, "storico intatto (%d voci)" % Economy.history.size()],
		[Economy.is_consistent() and Economy.money_cents >= 0, "saldo = storico, mai negativo"],
	])

func _pending_count(key: String) -> int:
	var n := 0
	for b in Economy.pending_bills:
		if str(b.get("key", "")) == key:
			n += 1
	return n

func l_unpaid() -> void:
	T.fresh(1, "09:00")
	_set_home("monolocale_corso")
	Economy.money_cents = 0
	Economy.start_money_cents = 0 - Economy.history_sum() + 0
	Economy.start_money_cents = -Economy.history_sum()   # saldo coerente a 0 €
	T.set_time(40, "09:00")
	var late := 0
	for t in Economy.history:
		if "mora" in str(t["desc"]).to_lower():
			late += 1
	var lf := 0
	for b in Economy.pending_bills:
		if b.get("late_fee_applied", false):
			lf += 1
	T.record("V-L3/L4", "Bollette non pagate: mora una volta, luce sospesa dopo 2 bollette, si riparte pagando", [
		[_pending_count("luce:0") == 1 and _pending_count("gas:0") == 1, "bollette del mese 1 in sospeso, una per tipo"],
		[lf >= 1, "mora applicata alle bollette scadute (%d)" % lf],
		[Life.power_suspended, "luce sospesa con 2+ bollette non pagate (piastra non utilizzabile)"],
		[Economy.money_cents >= 0 and Economy.is_consistent(), "saldo mai negativo e coerente"],
	])
	give(300000)
	while not Economy.pending_bills.is_empty() and Economy.pay_pending(0):
		pass
	Life.process_day()
	T.record("V-L4b", "Dopo il pagamento la luce torna", [[not Life.power_suspended and Economy.pending_bills.is_empty(), "nessuna bolletta in sospeso, luce attiva"]])

# ---------------------------------------------------------------- J lavori
func _do_shift(id: String, day: int, hhmm: String, n: int) -> Dictionary:
	T.set_time(day, hhmm)
	Needs.energy = 90.0
	var s: Dictionary = Jobs.start_shift(id)
	if not s["ok"]:
		return {"ok": false, "pay": 0, "why": s["reason"]}
	var m0 := Economy.money_cents
	if id == "rider":
		for i in n:
			Jobs.rider_pickup()
			Jobs.rider_drop()
	else:
		for i in n:
			Jobs.complete_order()
	Jobs.finish_shift()
	Jobs.finish_shift()   # doppio tocco: non deve pagare due volte
	return {"ok": true, "pay": Economy.money_cents - m0, "why": ""}

func j_three_jobs() -> void:
	T.fresh(1, "07:00")
	give(20000)
	Jobs.hire("barista")
	Jobs.hire("cassiere")
	var eq1 := Jobs.buy_equipment("bici_usata")
	var eq2 := Jobs.buy_equipment("zaino_termico")
	Jobs.hire("rider")
	var b := _do_shift("barista", 2, "06:30", 10)
	var c := _do_shift("cassiere", 3, "08:00", 12)
	var r := _do_shift("rider", 3, "18:30", 3)
	var tip := int(Jobs.job("rider")["tips_estimate"]["tip_cents"])
	T.record("V-J1", "Tre lavori: un turno puntuale ciascuno, paga dai dati e una sola volta", [
		[b["ok"] and b["pay"] == Jobs.net_pay("barista"), "barista: € %s (dati € %s) %s" % [Data.euro(b["pay"]), Data.euro(Jobs.net_pay("barista")), b["why"]]],
		[c["ok"] and c["pay"] == Jobs.net_pay("cassiere"), "cassiere: € %s (dati € %s) %s" % [Data.euro(c["pay"]), Data.euro(Jobs.net_pay("cassiere")), c["why"]]],
		[r["ok"] and r["pay"] == 3 * Jobs.net_pay("rider") + tip, "rider: 3 consegne = € %s (3 × € %s + mancia € %s) %s" % [Data.euro(r["pay"]), Data.euro(Jobs.net_pay("rider")), Data.euro(tip), r["why"]]],
		[eq1 == "" and eq2 == "", "bici (€ 140) e zaino termico (€ 35) comprati: requisiti del rider"],
		[Economy.is_consistent(), "saldo = storico"],
	])

func j_late_overlap_quit() -> void:
	T.fresh(1, "07:00")
	Jobs.hire("barista")
	Jobs.hire("cassiere")
	var late := _do_shift("barista", 2, "06:50", 10)
	var exp_late := Jobs.net_pay("barista") - Jobs.net_pay("barista") * 20 / 100
	# turni sovrapposti: cassiere 08:00 mentre si è in turno al bar
	T.set_time(3, "06:30")
	Needs.energy = 90.0
	Jobs.start_shift("barista")
	T.set_time(3, "08:00")
	var ov: Dictionary = Jobs.check_in_status("cassiere")
	for i in 10:
		Jobs.complete_order()
	Jobs.finish_shift()
	# mezzo turno: niente paga
	var half := _do_shift("cassiere", 4, "08:00", 5)
	# rider senza attrezzatura
	Jobs.hire("rider")
	var nr: Dictionary = Jobs.check_in_status("rider")
	# licenziamento
	Jobs.quit_job("cassiere")
	T.set_time(5, "08:00")
	var q: Dictionary = Jobs.check_in_status("cassiere")
	T.record("V-J2/J3/J4", "Ritardo −20%, turni sovrapposti impossibili, mezzo turno non pagato, dopo le dimissioni niente turni", [
		[late["ok"] and late["pay"] == exp_late, "barista in ritardo di 20 min: € %s (atteso € %s)" % [Data.euro(late["pay"]), Data.euro(exp_late)]],
		[not ov["ok"], "cassiere mentre sei al bar: «%s»" % ov["reason"]],
		[half["ok"] and half["pay"] == 0, "cassiere con 5 clienti su 12: paga € %s" % Data.euro(half["pay"])],
		[not nr["ok"], "rider senza bici/zaino: «%s»" % nr.get("reason", "")],
		[not q["ok"], "dopo le dimissioni: «%s»" % q["reason"]],
		[Economy.is_consistent(), "saldo = storico"],
	])

# ---------------------------------------------------------------- H casa e mobili
func h_furniture() -> void:
	T.fresh(1, "10:00")
	Economy.start_money_cents -= Economy.money_cents - 3000
	Economy.money_cents = 3000
	var poor := Life.buy_furniture("materasso_memory")
	var poor_ok := Economy.money_cents == 3000 and not ("materasso_memory" in Life.furniture)
	give(200000)
	var sleep0 := Life.sleep_energy_per_hour()
	var c0 := Life.comfort()
	var m0 := Economy.money_cents
	var e1 := Life.buy_furniture("materasso_memory")
	var paid := m0 - Economy.money_cents
	var sleep1 := Life.sleep_energy_per_hour()
	# ciclo compra/rivendi: si perde sempre
	var m1 := Economy.money_cents
	for i in 5:
		Life.sell_furniture("materasso_memory")
		Life.buy_furniture("materasso_memory")
	var loss := m1 - Economy.money_cents
	var resale_ok := true
	for f in Data.life["furniture"]:
		if int(f["price_cents"]) > 0 and Life.resale_cents(int(f["price_cents"]), int(Data.life["furniture_resale_pct"])) >= int(f["price_cents"]):
			resale_ok = false
	for c in Data.life["clothes"]:
		if Life.resale_cents(int(c["price_cents"]), int(Data.life["clothes_resale_pct"])) >= int(c["price_cents"]):
			resale_ok = false
	# spazio limitato nella stanza
	var full := ""
	for id in ["tende_oscuranti", "piastra_induzione", "forno_elettrico", "frigorifero_piccolo"]:
		var r := Life.buy_furniture(id)
		if r != "":
			full = r
	T.record("V-H1/H2/H4", "Mobili: acquisto, rifiuto senza soldi, comfort→sonno, niente trucco compra-rivendi", [
		[poor != "" and poor_ok, "senza soldi: «%s», niente cambia" % poor],
		[e1 == "" and paid == 19900, "materasso comprato a € %s" % Data.euro(paid)],
		[sleep1 > sleep0 and Life.comfort() > c0, "sonno %.1f→%.1f energia/ora, comfort %d→%d" % [sleep0, sleep1, c0, Life.comfort()]],
		[loss > 0, "5 cicli vendi+ricompra: perdita € %s" % Data.euro(loss)],
		[resale_ok, "ogni mobile e vestito si rivende sotto il prezzo (30%/20%)"],
		[full != "", "stanza piena: «%s»" % full],
		[Economy.is_consistent(), "saldo = storico"],
	])

func h_move_home() -> void:
	T.fresh(1, "10:00")
	var refused := Life.rent_home("monolocale_corso")
	give(300000)
	Life.credit_score = 650
	Life.log_income(100000)
	var dep_old := Life.deposit_held_cents
	T.set_time(3, "10:00")
	var m0 := Economy.money_cents
	var e := Life.rent_home("monolocale_corso")
	var h := Life.home_cfg()
	var spent := m0 - Economy.money_cents
	var expected := int(h["deposit_cents"]) + int(h["rent_cents"]) - dep_old
	var stanza_before := hist_count("Affitto Stanza") + hist_count("Affitto settimana")
	T.set_time(20, "10:00")
	var stanza_after := hist_count("Affitto Stanza") + hist_count("Affitto settimana")
	var mono := hist_count("Affitto %s" % h["name"])
	T.record("V-H6", "Trasloco: cauzione restituita, nuovo affitto una volta, il vecchio si ferma", [
		[refused != "", "senza requisiti: «%s»" % refused],
		[e == "" and spent == expected, "spesa netta € %s = cauzione + primo canone − cauzione della stanza (€ %s)" % [Data.euro(spent), Data.euro(expected)]],
		[stanza_after == stanza_before, "nessun affitto della stanza dopo il trasloco"],
		[mono == 1, "affitto del monolocale addebitato 1 volta in 17 giorni (periodo 28)"],
		[Economy.is_consistent(), "saldo = storico"],
	])

# ---------------------------------------------------------------- A auto
func a_car() -> void:
	T.fresh(1, "10:00")
	var no := Life.buy_car("utilitaria_ginestra", false)
	var no_ok := not Life.has_car()
	give(500000)
	var m0 := Economy.money_cents
	var ok := Life.buy_car("utilitaria_ginestra", false)
	var m := Life.car_model()
	var cost := m0 - Economy.money_cents
	var exp_cost := int(m["price_cents"]) + int(Data.life["cars"]["purchase"]["ownership_transfer_cents"]) + int(m["road_tax_annual_cents"])
	var no_ins := Life.can_drive()
	Life.buy_insurance()
	var can := Life.can_drive()
	Life.drive_distance(1.0e7)
	var empty := Life.can_drive()
	T.set_time(1, "12:00")
	var m1 := Economy.money_cents
	var rf: Dictionary = Life.refuel(10.0)
	var rf_cost := m1 - Economy.money_cents
	Economy.start_money_cents -= Economy.money_cents
	Economy.money_cents = 0
	var rf2: Dictionary = Life.refuel(5.0)
	var ok_sl := save_reload()
	T.record("V-A1/A4", "Auto: acquisto con e senza soldi, assicurazione obbligatoria, benzina e rifornimento", [
		[no != "" and no_ok, "senza soldi: «%s»" % no],
		[ok == "" and cost == exp_cost, "con i soldi: € %s (prezzo + passaggio + bollo = € %s)" % [Data.euro(cost), Data.euro(exp_cost)]],
		[no_ins != "" and can == "", "senza assicurazione non si guida («%s»), dopo l'RC sì" % no_ins],
		[empty != "", "serbatoio vuoto: «%s»" % empty],
		[rf["ok"] and rf_cost == 1850, "10 L a € 1,85 = € %s" % Data.euro(rf_cost)],
		[not rf2["ok"], "senza soldi il rifornimento è rifiutato"],
		[ok_sl and Life.has_car() and absf(float(Life.car["fuel_l"]) - 10.0) < 0.01, "dopo salva/carica l'auto e la benzina restano"],
		[Economy.is_consistent(), "saldo = storico"],
	])

func a_recurring() -> void:
	T.fresh(1, "10:00")
	give(900000)
	Life.buy_car("utilitaria_ginestra", false)
	Life.buy_insurance()
	Life.buy_resident_pass()
	var p_need := Life.parking_needed(true)
	Life.resident_pass_until = 0
	T.set_time(2, "10:00")
	var need2 := Life.parking_needed(true)
	Life.buy_parking_ticket(2)
	var need3 := Life.parking_needed(true)
	T.set_time(2, "21:00")
	var night := Life.parking_needed(true)
	var bollo := hist_count("Bollo auto")
	T.set_time(60, "10:00")
	var bollo2 := hist_count("Bollo auto")
	T.record("V-A5", "Costi ricorrenti: bollo una volta l'anno, assicurazione 28 giorni, strisce blu", [
		[bollo == 1 and bollo2 == 1, "bollo pagato all'acquisto e non ripetuto entro l'anno"],
		[not p_need, "pass residenti: niente ticket"],
		[need2 and not need3, "senza pass serve il ticket; dopo il ticket da 2 h si può lasciare l'auto"],
		[not night, "dopo le 20 le strisce blu sono gratis"],
		[not Life.insured(), "dopo 28 giorni l'assicurazione scade e va rinnovata"],
		[Economy.is_consistent(), "saldo = storico"],
	])

# ---------------------------------------------------------------- X integrazione
func x_thursday() -> void:
	var runs := []
	for k in 2:
		T.fresh(1, "07:00")
		give(100000)
		T.set_time(26, "09:00")
		var evs := []
		for t in Economy.history:
			if str(t["desc"]).begins_with("Imprevisto"):
				evs.append([t["day"], t["amount"]])
		for b in Economy.pending_bills:
			if str(b.get("key", "")).begins_with("evt:"):
				evs.append([b["due_day"], -int(b["amount"])])
		runs.append(evs)
	T.record("V-X5", "Imprevisto del giovedì deterministico (Nova)", [
		[runs[0].size() >= 3, "%d imprevisti nei giovedì 4, 11, 18, 25" % runs[0].size()],
		[runs[0] == runs[1], "due partite uguali danno gli stessi imprevisti"],
		[Economy.is_consistent(), "saldo = storico"],
	])

func x_gym_comfort_bus() -> void:
	T.fresh(1, "08:00")
	give(100000)
	var e0 := Life.energy_max
	Life.buy_gym_pass()
	var twice := Life.buy_gym_pass()
	for d in [1, 2, 3]:
		T.set_time(d, "18:00")
		Needs.energy = 90.0
		Life.gym_session(false)
	var e1 := Life.energy_max
	var m0 := Economy.money_cents
	var b1 := Life.pay_bus_ride()
	var paid := m0 - Economy.money_cents
	Life.buy_bus_pass()
	var m1 := Economy.money_cents
	Life.pay_bus_ride()
	T.record("V-X6", "Palestra (energia massima 90→100) e bus (biglietto o abbonamento)", [
		[twice != "", "abbonamento non comprabile due volte: «%s»" % twice],
		[e0 == 90 and e1 == 91, "3 sessioni in 3 giorni: energia massima %d→%d" % [e0, e1]],
		[b1 == "" and paid == 150, "corsa in bus € %s" % Data.euro(paid)],
		[Economy.money_cents == m1, "con l'abbonamento la corsa è gratis"],
		[Economy.is_consistent(), "saldo = storico"],
	])

func x_score() -> void:
	T.fresh(1, "08:00")
	give(300000)
	var s0 := Life.credit_score
	T.set_time(60, "09:00")
	var s1 := Life.credit_score
	var cap := int(Data.life["credit_score"]["monthly_gain_cap"])
	T.record("V-X7", "Affidabilità: sale pagando in tempo, con tetto mensile, tra 300 e 850", [
		[s1 > s0, "60 giorni di affitti puntuali: %d → %d" % [s0, s1]],
		[s1 - s0 <= cap * 3, "crescita entro il tetto (%d/mese)" % cap],
		[s1 >= 300 and s1 <= 850, "nei limiti"],
	])

## X1 (ridotto, Hook): 30 giorni con 2 lavori, auto, bollette e affitto; saldo = storico ogni giorno, nessun addebito doppio.
func x_30_days() -> void:
	T.fresh(1, "07:00")
	give(700000)
	Jobs.hire("barista")
	Jobs.hire("cassiere")
	Life.buy_car("utilitaria_ginestra", false)
	Life.buy_insurance()
	var bad := 0
	var neg := false
	for d in range(1, 31):
		if Jobs.is_workday(d, "barista"):
			_do_shift("barista", d, "06:30", 10)
		if Jobs.is_workday(d, "cassiere"):
			_do_shift("cassiere", d, "14:00", 12)
		T.set_time(d, "21:00")
		Life.drive_distance(2000.0)
		if Life.fuel_pct() < 30:
			T.set_time(d, "20:00") if GameTime.minute_of_day() < 1200 else null
			Life.refuel(0.0)
		Needs.hunger = 70.0; Needs.energy = 80.0; Needs.sonno = 80.0
		while not Economy.pending_bills.is_empty() and Economy.pay_pending(0):
			pass
		if not Economy.is_consistent():
			bad += 1
		if Economy.money_cents < 0:
			neg = true
	var keys := {}
	var dup := 0
	for t in Economy.history:
		var ds := str(t["desc"])
		if ds.begins_with("Affitto") or ds.begins_with("Stipendio") or ds.begins_with("Canone") or ds.begins_with("Ricarica"):
			var k := ds + "|" + str(t["day"]) + "|" + str(t["amount"])
			if keys.has(k):
				dup += 1
			keys[k] = true
	T.record("V-X1", "30 giorni con 2 lavori, auto, affitto e bollette (simulazione automatica)", [
		[bad == 0, "saldo = storico ogni sera per 30 giorni"],
		[not neg, "mai sotto zero"],
		[dup == 0, "nessun addebito o stipendio doppio"],
		[GameTime.day() == 30, "giorno finale 30, € %s, %d voci" % [Data.euro(Economy.money_cents), Economy.history.size()]],
	])

## X2: a 0 € con tutto in arretrato esiste sempre un modo per riprendersi (lavoro senza auto) e lo sfratto è leggero.
func x_zero_recovery() -> void:
	T.fresh(1, "07:00")
	Jobs.hire("barista")
	Economy.start_money_cents -= Economy.money_cents
	Economy.money_cents = 0
	T.set_time(9, "09:00")
	var arrears := Economy.pending_bills.size()
	var s := _do_shift("barista", 10, "06:30", 10)
	T.record("V-X2", "A zero euro: si lavora a piedi, si incassa, il debito resta lieve e recuperabile", [
		[arrears >= 1, "arretrati in sospeso: %d" % arrears],
		[s["ok"] and s["pay"] > 0, "turno al bar raggiungibile a piedi, pagato € %s" % Data.euro(s["pay"])],
		[Economy.money_cents >= 0 and Economy.is_consistent(), "saldo mai negativo, coerente"],
	])

## X3: un vero salvataggio v0.2 (generato con il codice v0.2.0) si carica nella v0.3 senza perdere soldi.
func x_migrate_v02() -> void:
	T.fresh(1, "07:00")
	var src := FileAccess.get_file_as_string("res://tests/fixtures/v02_save.json")
	var raw: Dictionary = JSON.parse_string(src)
	var f := FileAccess.open("user://test_v02_import.json", FileAccess.WRITE)
	f.store_string(src)
	f.close()
	var info := SaveSystem.inspect("user://test_v02_import.json")
	var ok := SaveSystem.load_from("user://test_v02_import.json")
	var money_ok: bool = Economy.money_cents == int(raw["game"]["economy"]["money_cents"])
	var hist_ok: bool = Economy.history.size() == raw["game"]["economy"]["history"].size()
	var h0 := Economy.history.size()
	Economy.process_bills()
	var no_retro: bool = Economy.history.size() == h0
	var saved := SaveSystem.save_game()
	var v := int(JSON.parse_string(FileAccess.get_file_as_string(SaveSystem.save_path))["version"])
	T.record("V-X3", "Salvataggio v0.2 reale → v0.3: migrato senza perdere soldi né storico", [
		[info["status"] == "ok" and info.get("migrated", false), "riconosciuto (versione %s) e migrato" % str(info.get("from_version", "?"))],
		[ok and money_ok, "saldo identico: € %s" % Data.euro(Economy.money_cents)],
		[hist_ok and Economy.is_consistent(), "storico identico (%d voci) e coerente" % Economy.history.size()],
		[no_retro, "nessun addebito retroattivo al caricamento"],
		[Life.credit_score == 600 and Life.home_id == "stanza_via_roma", "nuovi sistemi ai valori iniziali di Ledger"],
		[saved and v == SaveSystem.CURRENT_VERSION, "risalvato come versione %d" % v],
	])

# ---------------------------------------------------------------- Ledger: 6 test di bilanciamento (port da Python)
func _sim_days(days: int, job: bool, food_cents: int) -> Dictionary:
	T.fresh(1, "07:00")
	if job:
		Jobs.hire("barista")
	var mn := Economy.money_cents
	var zero_day := -1
	for d in range(1, days + 1):
		if job and Jobs.is_workday(d, "barista"):
			_do_shift("barista", d, "06:30", 10)
		T.set_time(d, "20:00")
		if not Economy.spend(food_cents, "Cibo (simulazione)", "cibo") and zero_day < 0:
			zero_day = d
		while not Economy.pending_bills.is_empty() and Economy.pay_pending(0):
			pass
		if not Economy.pending_bills.is_empty() and zero_day < 0:
			zero_day = d
		Needs.hunger = 70.0; Needs.energy = 80.0; Needs.sonno = 80.0
		mn = mini(mn, Economy.money_cents)
	return {"min": mn, "end": Economy.money_cents, "zero_day": zero_day, "ok": Economy.is_consistent()}

func ledger_tests() -> void:
	var a := _sim_days(30, true, 886)
	T.record("LEDGER-1", "Nessun bug di soldi: scenario barista + stanza, 30 giorni", [
		[a["min"] >= 0 and a["ok"], "minimo € %s, fine € %s (Ledger, modello Python: min 391,11 / fine 708,52)" % [Data.euro(a["min"]), Data.euro(a["end"])]],
		[a["end"] > 50000, "dopo 30 giorni si risparmia qualcosa"],
	])
	var resale_ok := true
	for f in Data.life["furniture"]:
		if int(f["price_cents"]) > 0 and Life.resale_cents(int(f["price_cents"]), int(Data.life["furniture_resale_pct"])) >= int(f["price_cents"]):
			resale_ok = false
	for c in Data.life["clothes"]:
		if Life.resale_cents(int(c["price_cents"]), int(Data.life["clothes_resale_pct"])) >= int(c["price_cents"]):
			resale_ok = false
	T.record("LEDGER-2", "Nessun ciclo compra/rivendi in guadagno", [[resale_ok, "ogni oggetto si rivende sotto il prezzo"]])
	var s: Dictionary = Data.life["bank"]["savings"]
	var i10k := int(floor(1000000.0 * float(s["interest_bp_annual_gross"]) * float(10000 - int(s["withholding_tax_bp"])) / (10000.0 * 10000.0 * 12.0)))
	T.record("LEDGER-3", "Interesse non sfruttabile", [[i10k == 1233 and i10k < Jobs.net_pay("barista"), "€ 10.000 per un mese = € %s < un turno" % Data.euro(i10k)]])
	var r: Dictionary = Jobs.job("rider")
	var need := 0
	for sh in r["shifts"]:
		need += int(sh["max_deliveries"]) * int(r["energy_extra_per_delivery"]) + int(sh["hours"]) * int(r["energy_per_hour"])
	T.record("LEDGER-4", "Rider: niente guadagno infinito (tetto consegne, energia insufficiente per due fasce piene)", [[need > 100, "due fasce piene richiedono %d di energia (massimo 100)" % need]])
	var mort_ok := true
	var txt := []
	var mc: Dictionary = Data.life["mortgage"]
	for h in Data.life["homes_sale"]:
		var P := float(h["mortgage_principal_cents"])
		var i := float(mc["tan_bp"]) / 10000.0 / 12.0
		var n := int(mc["term_months"])
		var rata := int(round(P * i / (1.0 - pow(1.0 + i, -n))))
		txt.append("%s € %s" % [h["id"], Data.euro(rata)])
		if rata != int(h["mortgage_installment_cents"]) or rata * n <= int(P):
			mort_ok = false
	T.record("LEDGER-5", "Mutuo coerente: rata dai dati, rata × n > capitale", [[mort_ok, ", ".join(txt) + " (Ledger: 217,92 / 388,30)"]])
	var z := _sim_days(30, false, 886)
	T.record("LEDGER-6", "Economia stretta: senza lavoro i soldi finiscono in circa 3 settimane", [[z["zero_day"] >= 15 and z["zero_day"] <= 28, "senza lavoro non si riesce più a pagare il giorno %d (Ledger: ~22)" % z["zero_day"]], [z["ok"] and z["min"] >= 0, "saldo mai negativo, coerente"]])

# ---------------------------------------------------------------- Guard: testi
func x_texts_guard() -> void:
	var all := FileAccess.get_file_as_string("res://data/texts.json") + FileAccess.get_file_as_string("res://data/dialogues.json") + FileAccess.get_file_as_string("res://data/life.json") + FileAccess.get_file_as_string("res://data/credits.txt")
	var low := all.to_lower()
	var bad := []
	for w in ["pegi", "scommess", "lotteria", "gratta e vinci", "crypto", "bitcoin", "trading", "slot machine", "fiat", "panda", "volkswagen", "polo ", "scooter"]:
		if w in low:
			bad.append(w)
	T.record("V-G1", "Regole di Guard nei testi del gioco", [
		[Data.t("build_label") == "Versione di prova (demo) — v0.3", "etichetta: «%s»" % Data.t("build_label")],
		[Data.t("privacy_web") .begins_with("Il gioco salva i dati solo nel tuo browser e non raccoglie dati personali."), "privacy web"],
		["non è consulenza finanziaria" in all, "avviso della banca inventata presente"],
		[bad.is_empty(), "nessuna parola vietata (PEGI, azzardo, trading, marchi reali): %s" % str(bad)],
	])

# ---------------------------------------------------------------- B1, J6, X4: app nuove del telefono
func _ui_text(node: Node) -> String:
	var out := []
	for l in node.find_children("*", "Label", true, false):
		out.append(l.text)
	for l in node.find_children("*", "RichTextLabel", true, false):
		out.append(l.text)
	return "\n".join(out)

func _open_app(app: String, tab: String) -> void:
	var ui = T.main.ui
	if ui.modal_kind != "phone":
		ui.toggle_phone()
	ui.life_ui.tabs[app] = tab
	ui.phone_open_app(app)

func x_new_apps() -> void:
	var ui = T.main.ui
	var dead := []
	var total := 0
	var shown := 0
	var apps := {"banca": ["conto", "risparmi", "spese", "aff"], "lavori": ["mio", "offerte", "cand", "promo"],
		"casa": ["mia", "cerca", "mobili", "armadio"], "auto": ["mia", "conc", "benzina", "ass"]}
	var places := {
		"banca_sportello": func(): ui.life_ui.open_bank(),
		"boutique": func(): ui.life_ui.open_boutique(),
		"palestra": func(): ui.life_ui.open_gym(),
		"trattoria": func(): ui.life_ui.open_trattoria(),
		"autosalone": func(): ui.life_ui.open_dealer(),
		"distributore": func(): ui.life_ui.open_fuel(),
	}
	var jobs_txt := []
	for state in 3:
		T.fresh(2, "12:00")
		if state >= 1:
			give(1000000)
			Jobs.hire("barista")
			Life.buy_car("utilitaria_ginestra", false)
			Life.buy_insurance()
			Life.buy_furniture("tende_oscuranti")
		if state >= 2:
			Jobs.hire("rider")
		_open_app("lavori", "mio")
		jobs_txt.append(_ui_text(ui.modal))
		for app in apps:
			for tab in apps[app]:
				_open_app(app, tab)
				shown += 1
				for b in ui.modal.find_children("*", "Button", true, false):
					total += 1
					if b.pressed.get_connections().is_empty():
						dead.append("%s/%s:%s" % [app, tab, b.text])
		ui.close_modal()
		for k in places:
			T.set_time(2, "12:00")
			places[k].call()
			if ui.modal:
				shown += 1
				for b in ui.modal.find_children("*", "Button", true, false):
					total += 1
					if b.pressed.get_connections().is_empty():
						dead.append("%s:%s" % [k, b.text])
			ui.close_modal()
			T.get_tree().paused = false
	# B1: il conto mostra lo stesso saldo del gioco
	T.fresh(2, "12:00")
	give(12345)
	_open_app("banca", "conto")
	var bank_txt := _ui_text(ui.modal)
	var shows_bal := ("Saldo disponibile: € " + Data.euro(Economy.money_cents)) in bank_txt
	ui.close_modal()
	var j0: String = jobs_txt[0]
	var j1: String = jobs_txt[1]
	var j2: String = jobs_txt[2]
	T.record("V-B1/J6/X4", "App nuove del telefono (Banca, Lavori, Casa, Auto) e sportelli dei luoghi: niente pulsanti finti", [
		[dead.is_empty() and total > 50, "%d schermate, %d pulsanti controllati, senza azione: %s" % [shown, total, str(dead)]],
		[shows_bal, "B1: l'app Banca mostra il saldo del gioco (€ %s)" % Data.euro(Economy.money_cents)],
		["Affitto · €" in bank_txt, "B1: «In arrivo (7 giorni)» elenca l'affitto con l'importo"],
		["Non hai ancora un lavoro" in j0, "J6: 0 lavori → «Non hai ancora un lavoro»"],
		[Jobs.title("barista") in j1 and not (Jobs.title("rider") in j1), "J6: 1 lavoro → solo %s" % Jobs.title("barista")],
		[Jobs.title("barista") in j2 and Jobs.title("rider") in j2, "J6: 2 lavori → %s e %s, con prossimo turno" % [Jobs.title("barista"), Jobs.title("rider")]],
	])

# ---------------------------------------------------------------- H7: salva con tutti i mobili
func h_save_many() -> void:
	T.fresh(2, "10:00")
	give(5000000)
	_set_home("bilocale_piazza")
	var bought := 0
	for f in Data.life["furniture"]:
		if Life.buy_furniture(str(f["id"])) == "":
			bought += 1
	var before := JSON.stringify(Life.furniture)
	var money := Economy.money_cents
	var ok := save_reload()
	var after := JSON.stringify(Life.furniture)
	T.record("V-H7", "Salva con tutti i mobili (bilocale, 12 posti) e ricarica: identici", [
		[bought >= 8, "%d mobili comprati (il catalogo ne ha %d; 10+ non è possibile: il caso Hook usa tutti quelli esistenti)" % [Life.furniture.size(), Data.life["furniture"].size()]],
		[ok and before == after, "dopo salva/carica l'elenco dei mobili è identico"],
		[Economy.money_cents == money and Economy.is_consistent(), "saldo invariato e = storico"],
	])

# ---------------------------------------------------------------- A7: salva con l'auto parcheggiata
func a_save_parked() -> void:
	T.fresh(2, "10:00")
	give(1000000)
	Life.buy_car("utilitaria_ginestra", false, Vector3(30.0, 0.02, 0.95), -PI / 2.0)
	Life.buy_insurance()
	var pc = T.main.player_car
	T.main.player.teleport(Vector3(30.0, 0.12, -1.5), 0.0)
	var entered := false
	if pc:
		pc.enter_car()
		entered = true
		pc.speed = 0.0
		pc.exit_car()
	var pos0: Array = Life.car["pos"].duplicate()
	var yaw0 := float(Life.car["yaw"])
	var ok := save_reload()
	var pos1: Array = Life.car["pos"]
	var d := Vector3(pos0[0], pos0[1], pos0[2]).distance_to(Vector3(pos1[0], pos1[1], pos1[2]))
	T.record("V-A7", "Salva con l'auto parcheggiata, ricarica: posizione e direzione uguali", [
		[entered, "salito e sceso dall'auto"],
		[ok and Life.has_car() and d < 0.05 and absf(float(Life.car["yaw"]) - yaw0) < 0.01, "scarto posizione %.3f m, direzione %.2f → %.2f rad" % [d, yaw0, float(Life.car["yaw"])]],
	])
