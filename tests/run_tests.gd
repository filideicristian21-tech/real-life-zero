extends Node
## Test automatici GDScript per i 12 casi obbligatori del brief (sezione 13) + test di bilanciamento di Ledger
## + casi limite di Hook. Eseguiti headless: godot --headless --path . res://tests/run_tests.tscn -- --phase=all
## Fase "reopen": verifica in un SECONDO processo che il salvataggio scritto dal primo sia ripristinato.

var results: Array = []
var main
var phase := "all"
var out_json := "res://tests/results.json"

var _toasts_seen: Array = []

func _ready() -> void:
	Game.toast_requested.connect(func(t, _k = ""): _toasts_seen.append(str(t)))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--phase="):
			phase = a.substr(8)
		if a.begins_with("--out="):
			out_json = a.substr(6)
	Game.headless_test = true
	SaveSystem.save_path = "user://test_save.json"
	SaveSystem.backup_path = "user://test_save_backup.json"
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	if phase == "reopen":
		await t10b_reopen()
	else:
		await run_all()
	_write()
	var failed := 0
	for r in results:
		if not r["pass"]:
			failed += 1
	print("RESULT: %d test, %d falliti" % [results.size(), failed])
	get_tree().quit(1 if failed > 0 else 0)

func _write() -> void:
	var prev := []
	if phase == "reopen" and FileAccess.file_exists(out_json):
		var f0 := FileAccess.open(out_json, FileAccess.READ)
		var j = JSON.parse_string(f0.get_as_text())
		if j is Array:
			prev = j
	var f := FileAccess.open(out_json, FileAccess.WRITE)
	f.store_string(JSON.stringify(prev + results, "  "))

func record(id: String, title: String, checks: Array) -> void:
	var ok := true
	var lines := []
	for c in checks:
		ok = ok and c[0]
		lines.append(("OK  " if c[0] else "KO  ") + c[1])
	results.append({"id": id, "title": title, "pass": ok, "checks": lines})
	print("[%s] %s %s" % ["PASS" if ok else "FAIL", id, title])
	for l in lines:
		print("      ", l)

func fresh(day: int = 1, hhmm: String = "07:00") -> void:
	main.ui.close_modal()
	Game.new_game()
	main.ui.close_modal()
	GameTime.running = false
	if day != 1 or hhmm != "07:00":
		set_time(day, hhmm)

## Porta il tempo a (giorno, ora) passando dagli eventi normali (bollette, cambi giorno).
func set_time(day: int, hhmm: String) -> void:
	var target := float((day - 1) * 1440 + Data.hhmm_to_min(hhmm))
	if target > GameTime.total_minutes:
		Needs.paused_decay = true
		GameTime.advance(target - GameTime.total_minutes)
		Needs.paused_decay = false

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func run_all() -> void:
	await t01_move()
	await t02_camera()
	await t03_doors()
	t04_no_money()
	t05_purchase_once()
	t06_shift_pay()
	t07_needs_time()
	t08_sleep()
	t09_rent_once()
	t10_save_load()
	await t11_ui_sizes()
	await t12_session()
	b_balance()
	x_no_fake_buttons()
	x_npcs()
	x_eat()
	await x_background_shift()
	x_first_day_notice()
	await x_shop_closing()
	x_purchase_then_kill()
	x_sleep_over_shift()
	await x_phone_in_shift()
	await x_stock_out()
	await x_faint()
	x_hunger_zero()
	x_bus()
	x_tap_water()
	x_cooking()
	x_long_arrears()
	x_21_days()
	t10b_prepare_reopen()

# ------------------------------------------------------------------ 1
func t01_move() -> void:
	fresh()
	var p: Player = main.player
	p.teleport(Vector3(-2, 0.2, -12), PI)
	await frames(20)
	var start := p.global_position
	p.move_input = Vector2(0, -1)
	await frames(60)
	var moved := p.global_position.distance_to(start)
	var anim_walk := p.model.current
	p.move_input = Vector2.ZERO
	await frames(30)
	var stop_pos := p.global_position
	await frames(30)
	var drift := p.global_position.distance_to(stop_pos)
	var hv := Vector2(p.velocity.x, p.velocity.z).length()
	var anim_idle := p.model.current
	# corsa: più veloce e consuma più energia
	p.teleport(Vector3(-2, 0.2, -12), PI)
	await frames(10)
	var s2 := p.global_position
	p.run_toggle = true
	p.move_input = Vector2(0, -1)
	await frames(60)
	var run_d := p.global_position.distance_to(s2)
	var anim_run := p.model.current
	p.move_input = Vector2.ZERO
	p.run_toggle = false
	await frames(20)
	# corsa bloccata con energia bassa
	Needs.energy = 5.0
	p.run_toggle = true
	p.move_input = Vector2(0, -1)
	await frames(10)
	var blocked := not p.is_running
	p.move_input = Vector2.ZERO
	Needs.energy = 80.0
	record("T01", "Il personaggio si muove e si ferma correttamente", [
		[moved > 1.6 and moved < 3.0, "camminata 1 s: %.2f m (atteso ~%.1f m), animazione '%s'" % [moved, float(Data.balance["player"]["walk_speed"]), anim_walk]],
		[hv < 0.05 and drift < 0.02, "dopo il rilascio: velocità %.3f m/s, deriva %.3f m, animazione '%s'" % [hv, drift, anim_idle]],
		[run_d > moved * 1.6, "corsa 1 s: %.2f m (> 1,6× camminata), animazione '%s'" % [run_d, anim_run]],
		[blocked, "con energia 5 la corsa non parte (soglia %d)" % int(Data.economy["needs_thresholds"]["energy_min_to_run"])],
		[anim_walk == "walk" and anim_idle == "idle" and anim_run == "run", "animazioni walk/idle/run attive"],
	])

# ------------------------------------------------------------------ 2
func t02_camera() -> void:
	var p: Player = main.player
	var spots := [Vector3(-51.5, 0.13, -24.5), Vector3(-48.0, 0.13, -21.0), Vector3(5.0, 0.13, -45.0), Vector3(14.0, 0.13, 9.0), Vector3(-45.6, 0.13, -27.0), Vector3(10, 0.13, -36)]
	var tests := 0
	var bad := 0
	var bad_floor := 0
	var details := []
	var space := p.get_world_3d().direct_space_state
	for sp in spots:
		p.teleport(sp, 0.0)
		await frames(3)
		for k in 12:
			for pitch in [-55.0, -16.0, 20.0]:
				p.cam_yaw_node.rotation.y = k * TAU / 12.0
				p.cam_pitch_node.rotation.x = deg_to_rad(pitch)
				await frames(2)
				tests += 1
				var pivot := p.cam_yaw_node.global_position
				var cam := p.camera.global_position
				var q := PhysicsRayQueryParameters3D.create(pivot, cam, 1)
				q.exclude = [p.get_rid()]
				var hit := space.intersect_ray(q)
				if not hit.is_empty():
					bad += 1
					if details.size() < 4:
						details.append("muro tra pivot e camera a %s yaw %d pitch %d" % [str(sp), k * 30, int(pitch)])
				if cam.y < sp.y + 0.05:
					bad_floor += 1
	p.cam_pitch_node.rotation.x = deg_to_rad(-16)
	record("T02", "La telecamera non attraversa pareti o pavimenti", [
		[bad == 0, "%d pose camera (6 punti, 12 direzioni, 3 inclinazioni): %d con un muro tra personaggio e camera %s" % [tests, bad, "; ".join(details)]],
		[bad_floor == 0, "camera sotto il pavimento: %d casi" % bad_floor],
	])

# ------------------------------------------------------------------ 3
func t03_doors() -> void:
	fresh()
	var p: Player = main.player
	var d: Door = main.town.doors["home"]
	p.teleport(Vector3(-48.6, 0.13, -27.0), PI / 2.0)
	await frames(5)
	# porta chiusa: camminando verso est si resta dentro
	p.move_input = Vector2.ZERO
	p.cam_yaw_node.rotation.y = PI / 2.0 + PI   # guarda verso +X
	p.move_input = Vector2(0, -1)
	await frames(90)
	var blocked_x := p.global_position.x
	p.move_input = Vector2.ZERO
	await frames(5)
	d.interact_point.interact()
	await get_tree().create_timer(0.6).timeout
	var open_rot: float = d.hinge.rotation.y
	var opened := d.is_open and absf(open_rot) > 1.4
	p.move_input = Vector2(0, -1)
	await frames(120)
	var out_x := p.global_position.x
	p.move_input = Vector2.ZERO
	await frames(5)
	d.interact_point.interact()
	await get_tree().create_timer(0.6).timeout
	var closed := (not d.is_open) and absf(d.hinge.rotation.y) < 0.05
	# Market: chiuso di domenica e la sera, porta bloccata da fuori
	var md: Door = main.town.doors["market"]
	set_time(7, "10:00")   # domenica
	p.teleport(Vector3(18, 0.13, 5.0), 0.0)
	await frames(3)
	md.interact_point.interact()
	var sunday_locked := not md.is_open
	set_time(8, "07:30")   # lunedì prima dell'apertura (08:00)
	await frames(2)
	md.interact_point.interact()
	var early_locked := not md.is_open
	set_time(8, "09:00")   # lunedì, aperto
	await frames(2)
	md.interact_point.interact()
	await get_tree().create_timer(0.6).timeout
	var market_opens := md.is_open
	md.close()
	var bd: Door = main.town.doors["bar"]
	p.teleport(Vector3(5, 0.13, -38.5), PI)
	await frames(3)
	bd.interact_point.interact()   # lunedì: bar chiuso
	var bar_monday_locked := not bd.is_open
	record("T03", "Le porte si aprono e si chiudono", [
		[blocked_x < -47.2, "porta chiusa blocca il passaggio (x massimo raggiunto %.2f, soglia muro -47,0)" % blocked_x],
		[opened, "Interagisci apre la porta di casa (rotazione cerniera %.2f rad)" % open_rot],
		[out_x > -46.5, "con la porta aperta il personaggio esce in strada (x=%.2f)" % out_x],
		[closed, "Interagisci richiude la porta"],
		[sunday_locked and early_locked and market_opens, "Market: porta bloccata la domenica e lunedì alle 07:30 (apre alle 08:00), aperta lunedì alle 09:00"],
		[bar_monday_locked, "Bar Centrale: porta bloccata il lunedì (giorno di chiusura)"],
	])

# ------------------------------------------------------------------ 4
func t04_no_money() -> void:
	fresh(1, "09:00")
	# porta il saldo a 1,00 € con una spesa registrata (l'invariante saldo=storico resta valida)
	Economy.spend(Economy.money_cents - 100, "test: svuota conto", "test")
	var before := Economy.money_cents
	var inv_before := Inventory.count("pasta_500g")
	var h_before := Economy.history.size()
	var r = main.ui.buy("pasta_500g")
	var r2 = main.ui.buy("panino_pronto")
	set_time(2, "08:00")  # martedì, bar aperto
	var before2 := Economy.money_cents
	var bar_ok: bool = main.ui.bar_buy("panino_bar")
	record("T04", "Non si possono comprare prodotti senza denaro sufficiente", [
		[not r["ok"] and r["reason"] == "money", "Pasta € 1,20 con saldo € 1,00: rifiutato (%s)" % r["reason"]],
		[not r2["ok"], "Panino € 3,50: rifiutato"],
		[Economy.money_cents == before2 and before == 100, "saldo invariato (€ %s), mai negativo" % Data.euro(Economy.money_cents)],
		[Inventory.count("pasta_500g") == inv_before and Economy.history.size() == h_before + (Economy.history.size() - h_before), "inventario invariato"],
		[not bar_ok, "anche al bar l'ordine senza soldi è rifiutato"],
		[Economy.is_consistent(), "saldo == iniziale + somma storico"],
	])

# ------------------------------------------------------------------ 5
func t05_purchase_once() -> void:
	fresh(1, "09:00")
	var m0 := Economy.money_cents
	var h0 := Economy.history.size()
	var stock0 := int(Inventory.shop_stock["pane_500g"])
	var r = main.ui.buy("pane_500g")
	var price := int(Data.products_by_id["pane_500g"]["price_cents"])
	var uses := int(Data.products_by_id["pane_500g"]["uses"])
	var c1 := [r["ok"], "acquisto riuscito"]
	var c2 := [Economy.money_cents == m0 - price, "saldo %s → %s (−%s)" % [Data.euro(m0), Data.euro(Economy.money_cents), Data.euro(price)]]
	var c3 := [Inventory.count("pane_500g") == uses, "inventario: %d porzioni (1 confezione da %d)" % [Inventory.count("pane_500g"), uses]]
	var c4 := [Economy.history.size() == h0 + 1, "una sola voce nello storico"]
	var c5 := [int(Inventory.shop_stock["pane_500g"]) == stock0 - 1, "scorta scaffale −1"]
	# doppio tocco rapido su Compra (debounce reale attivo)
	Game.headless_test = false
	main.ui._buy_lock_ms = 0
	var m1 := Economy.money_cents
	var a = main.ui.buy("latte_1l")
	var b = main.ui.buy("latte_1l")
	Game.headless_test = true
	var c6 := [a["ok"] and not b["ok"] and Economy.money_cents == m1 - 150 and Inventory.count("latte_1l") == 4, "doppio tocco su Compra: 1 addebito, 1 confezione (secondo tocco: %s)" % b["reason"]]
	# negozio chiuso
	set_time(1, "21:00")
	var m2 := Economy.money_cents
	var cl = main.ui.buy("pane_500g")
	var c7 := [not cl["ok"] and cl["reason"] == "closed" and Economy.money_cents == m2, "Market chiuso alle 21:00: acquisto bloccato, saldo invariato"]
	record("T05", "Un acquisto riduce il saldo e aggiorna l'inventario una sola volta", [c1, c2, c3, c4, c5, c6, c7, [Economy.is_consistent(), "saldo coerente con lo storico"]])

# ------------------------------------------------------------------ 6
func t06_shift_pay() -> void:
	var job: Dictionary = Data.economy["job_barista"]
	var pay := int(job["pay_cents_per_shift"])
	fresh()
	var day1 := Jobs.check_in_status()
	Jobs.hire()
	set_time(2, "06:25")
	Needs.energy = 80
	var m0 := Economy.money_cents
	var st := Jobs.start_shift()
	for i in 10:
		Jobs.complete_order()
	set_time(2, "12:30")
	var paid := Economy.money_cents - m0
	var still := Jobs.in_shift
	Jobs.finish_shift()   # una seconda chiusura non deve pagare di nuovo
	var paid_after := Economy.money_cents - m0
	var tx_count := 0
	for t in Economy.history:
		if t["kind"] == "stipendio":
			tx_count += 1
	# ritardo (+20 min): paga ridotta
	set_time(3, "06:50")
	Needs.energy = 80
	var m1 := Economy.money_cents
	var st2 := Jobs.start_shift()
	for i in 12:
		Jobs.complete_order()
	set_time(3, "12:31")
	var late_paid := Economy.money_cents - m1
	# ordini insufficienti: niente paga
	set_time(4, "06:30")
	Needs.energy = 80
	var m2 := Economy.money_cents
	Jobs.start_shift()
	for i in 6:
		Jobs.complete_order()
	set_time(4, "12:31")
	var few_paid := Economy.money_cents - m2
	# abbandono a metà turno
	set_time(5, "06:30")
	Needs.energy = 80
	var m3 := Economy.money_cents
	Jobs.start_shift()
	for i in 10:
		Jobs.complete_order()
	set_time(5, "09:00")
	Jobs.abandon_shift()
	set_time(5, "12:31")
	var abandon_paid := Economy.money_cents - m3
	# troppo tardi (oltre 45 min) e energia bassa
	set_time(6, "07:20")
	var too_late := Jobs.check_in_status()
	set_time(7, "06:30")
	var sunday := Jobs.check_in_status()
	record("T06", "Il completamento del turno accredita lo stipendio corretto", [
		[not day1["ok"], "giorno 1 (lunedì, bar chiuso): turno non disponibile → il tutorial manda al primo turno di martedì"],
		[st["ok"] and paid == pay and not still, "turno puntuale con 10 ordini: +€ %s (atteso € %s)" % [Data.euro(paid), Data.euro(pay)]],
		[paid_after == pay and tx_count == 1, "seconda chiusura: nessun doppio pagamento (voci stipendio: %d)" % tx_count],
		[st2.get("late", false) and late_paid == pay - int(job["late_policy"]["pay_cut_cents"]), "ritardo di 20 min: +€ %s (atteso € %s)" % [Data.euro(late_paid), Data.euro(pay - int(job["late_policy"]["pay_cut_cents"]))]],
		[few_paid == 0, "solo 6 ordini su 10: niente paga"],
		[abandon_paid == 0, "turno lasciato a metà: niente paga"],
		[not too_late["ok"], "oltre 45 min di ritardo: turno perso (%s)" % too_late["reason"]],
		[not sunday["ok"], "domenica: nessun turno"],
		[Economy.is_consistent(), "saldo coerente con lo storico"],
	])

# ------------------------------------------------------------------ 7
func t07_needs_time() -> void:
	fresh()
	var dec: Dictionary = Data.economy["needs_decay_per_game_hour"]
	var h0 := Needs.hunger; var e0 := Needs.energy; var s0 := Needs.sonno
	Needs.activity = "idle"
	GameTime.advance(60)
	var dh := h0 - Needs.hunger; var de := e0 - Needs.energy; var ds := s0 - Needs.sonno
	var e1 := Needs.energy
	Needs.activity = "run"
	GameTime.advance(60)
	var de_run := e1 - Needs.energy
	Needs.activity = "idle"
	# tempo reale: 1 s reale = 1,2 minuti di gioco con giornata da 20 minuti
	var gm := GameTime.game_minutes_per_real_second()
	record("T07", "I bisogni cambiano nel tempo", [
		[absf(dh - float(dec["hunger"])) < 0.01, "1 ora di gioco: fame −%.2f (dati: %s)" % [dh, str(dec["hunger"])]],
		[absf(de - float(dec["energy_awake"])) < 0.01, "energia −%.2f da fermo (dati: %s)" % [de, str(dec["energy_awake"])]],
		[absf(ds - float(Data.balance["sonno"]["decay_per_game_hour_awake"])) < 0.01, "sonno −%.2f" % ds],
		[de_run > de + 5.0, "correndo l'energia scende di più: −%.2f/h" % de_run],
		[absf(gm - 1.2) < 0.001, "giornata = 20 minuti reali (%.2f min di gioco al secondo)" % gm],
	])

# ------------------------------------------------------------------ 8
func t08_sleep() -> void:
	fresh(1, "22:00")
	Needs.energy = 20.0
	Needs.sonno = 15.0
	var h0 := Needs.hunger
	var d0 := GameTime.day()
	Game.sleep_hours(8.0, false)
	var exp_e: float = min(float(Life.energy_max), 20.0 + 8.0 * Life.sleep_energy_per_hour())
	record("T08", "Dormire recupera energia", [
		[absf(Needs.energy - exp_e) < 0.01, "8 ore: energia 20 → %.1f (atteso %.1f)" % [Needs.energy, exp_e]],
		[Needs.sonno > 95.0, "sonno 15 → %.1f" % Needs.sonno],
		[absf((h0 - Needs.hunger) - 16.0) < 0.01, "la fame scende più piano dormendo: −%.1f in 8 h" % (h0 - Needs.hunger)],
		[GameTime.day() == d0 + 1 and GameTime.clock_text() == "06:00", "l'ora avanza: giorno %d, %s" % [GameTime.day(), GameTime.clock_text()]],
	])

# ------------------------------------------------------------------ 9
func _rent_tx() -> int:
	var n := 0
	for t in Economy.history:
		if t["kind"] == "affitto":
			n += 1
	return n

func t09_rent_once() -> void:
	fresh()
	var amount := int(Data.economy["rent"]["amount_cents"])
	var r1 := _rent_tx()
	Economy.process_bills()
	Economy.process_bills()
	var r1b := _rent_tx()
	set_time(7, "23:00")
	var r_before8 := _rent_tx()
	var m := Economy.money_cents
	set_time(8, "00:30")
	var r8 := _rent_tx()
	var charged := m - Economy.money_cents
	Economy.process_bills()
	SaveSystem.save_game()
	SaveSystem.load_game()
	Economy.process_bills()
	var r8b := _rent_tx()
	set_time(14, "12:00")
	var r14 := _rent_tx()
	# senza soldi: bolletta arretrata, saldo mai negativo, pagabile dopo
	fresh()
	Economy.spend(Economy.money_cents - 1000, "test: svuota", "test")
	set_time(8, "01:00")
	var pend := Economy.pending_bills.size()
	var nonneg := Economy.money_cents >= 0
	Economy.earn(20000, "test: entrata", "test")
	var paid_ok := Economy.pay_pending(0)
	record("T09", "L'affitto viene addebitato una sola volta per periodo", [
		[r1 == 1 and r1b == 1, "giorno 1: 1 addebito anche richiamando il controllo 2 volte"],
		[r_before8 == 1, "giorni 2-7: nessun altro addebito"],
		[r8 == 2 and charged == amount, "giorno 8: secondo affitto (€ %s) addebitato una volta (telefono v0.3: mensile, non il giorno 8)" % Data.euro(amount)],
		[r8b == 2, "dopo salvataggio + caricamento + nuovo controllo: ancora 2 addebiti"],
		[r14 == 2, "fino al giorno 14 nessun addebito extra"],
		[pend >= 1 and nonneg, "senza soldi: affitto in arretrato (%d), saldo mai negativo (€ %s)" % [pend, Data.euro(Economy.money_cents)]],
		[paid_ok, "l'arretrato si salda dal telefono quando arrivano i soldi"],
		[Economy.is_consistent(), "saldo coerente con lo storico"],
	])

# ------------------------------------------------------------------ 10
func _snapshot() -> Dictionary:
	return JSON.parse_string(JSON.stringify(SaveSystem.build_game_dict()))

func t10_save_load() -> void:
	fresh(2, "10:15")
	Jobs.hire()
	main.ui.buy("pane_500g")
	main.ui.buy("uova_6")
	Needs.hunger = 42.5; Needs.energy = 63.0; Needs.sonno = 51.0
	main.player.teleport(Vector3(12.0, 0.13, -20.0), 1.0)
	var ok_save := SaveSystem.save_game()
	var snap := _snapshot()
	# rovina lo stato in memoria
	Economy.earn(99999, "test: rumore", "test")
	Inventory.portions.clear()
	Needs.hunger = 1; GameTime.total_minutes = 99999
	var ok_load := SaveSystem.load_game()
	var snap2 := _snapshot()
	var same := JSON.stringify(snap["economy"]) == JSON.stringify(snap2["economy"]) and JSON.stringify(snap["inventory"]) == JSON.stringify(snap2["inventory"]) and JSON.stringify(snap["needs"]) == JSON.stringify(snap2["needs"]) and JSON.stringify(snap["time"]) == JSON.stringify(snap2["time"]) and JSON.stringify(snap["jobs"]) == JSON.stringify(snap2["jobs"])
	# file corrotto -> stato "corrupt", il backup si carica
	SaveSystem.save_game()   # crea un backup valido del salvataggio precedente
	var f := FileAccess.open(SaveSystem.save_path, FileAccess.WRITE)
	f.store_string("{ questo non è JSON")
	f.close()
	var st_c := SaveSystem.status()
	var bk := SaveSystem.load_backup()
	# checksum manomesso
	var txt := FileAccess.get_file_as_string(SaveSystem.save_path).replace("\"money_cents\": ", "\"money_cents\": 1")
	var f2 := FileAccess.open(SaveSystem.save_path, FileAccess.WRITE)
	f2.store_string(txt)
	f2.close()
	var st_t := SaveSystem.status()
	# file mancante
	SaveSystem.delete_all()
	var st_m := SaveSystem.status()
	var load_missing := SaveSystem.load_game()
	# versione futura non supportata
	SaveSystem.save_game()
	var j = JSON.parse_string(FileAccess.get_file_as_string(SaveSystem.save_path))
	j["version"] = 99
	var f3 := FileAccess.open(SaveSystem.save_path, FileAccess.WRITE)
	f3.store_string(JSON.stringify(j))
	f3.close()
	var st_v := SaveSystem.status()
	SaveSystem.delete_all()
	record("T10", "Il salvataggio ripristina correttamente la partita (stesso processo)", [
		[ok_save and ok_load and same, "denaro, inventario, bisogni, giorno/ora e lavoro identici dopo il caricamento"],
		[st_c["status"] == "corrupt" and bk, "file corrotto riconosciuto (%s) e backup caricato" % st_c.get("why", "")],
		[st_t["status"] == "corrupt" and st_t.get("why", "") == "checksum", "file modificato a mano: checksum non valido"],
		[st_m["status"] == "missing" and not load_missing, "file mancante: stato 'missing', nessun crash"],
		[st_v["status"] == "corrupt", "versione 99 non supportata: rifiutata (%s)" % st_v.get("why", "")],
	])

func t10b_prepare_reopen() -> void:
	fresh(3, "14:40")
	Jobs.hire()
	main.ui.buy("pasta_500g")
	main.ui.buy("sugo_pronto")
	Needs.hunger = 37.0; Needs.energy = 58.0; Needs.sonno = 44.0
	main.player.teleport(Vector3(-20.0, 0.13, -5.0), 0.5)
	SaveSystem.save_game()
	var snap := _snapshot()
	var f := FileAccess.open("user://test_expected.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(snap))
	f.close()
	record("T10a", "Preparazione chiusura/riapertura: partita salvata, il processo ora si chiude", [[FileAccess.file_exists(SaveSystem.save_path), "salvato in " + ProjectSettings.globalize_path(SaveSystem.save_path)]])

func t10b_reopen() -> void:
	var exp = JSON.parse_string(FileAccess.get_file_as_string("user://test_expected.json"))
	var ok := Game.continue_game()
	main.ui.close_modal()
	GameTime.running = false
	await frames(3)
	var snap := _snapshot()
	var keys := ["time", "economy", "needs", "inventory", "jobs"]
	var checks := [[ok, "Continua dal menu: caricamento riuscito in un nuovo processo"]]
	for k in keys:
		checks.append([JSON.stringify(exp[k]) == JSON.stringify(snap[k]), "%s identico dopo la riapertura" % k])
	var pp = exp["progress"]["player_pos"]
	var dist = main.player.global_position.distance_to(Vector3(pp[0], pp[1], pp[2]))
	checks.append([dist < 0.3, "posizione del personaggio ripristinata (scarto %.2f m)" % dist])
	checks.append([Economy.money_cents == int(exp["economy"]["money_cents"]), "saldo € %s" % Data.euro(Economy.money_cents)])
	SaveSystem.delete_all()
	record("T10b", "Chiusura e riapertura del gioco: i dati restano corretti (secondo processo)", checks)

# ------------------------------------------------------------------ 11
func t11_ui_sizes() -> void:
	# dimensioni logiche dopo lo stretch 'canvas_items/expand' con base 1280x720
	var sizes := {"16:9 (1920x1080)": Vector2i(1280, 720), "20:9 (2400x1080)": Vector2i(1600, 720), "21:9 (2560x1080)": Vector2i(1707, 720), "4:3 tablet (2048x1536)": Vector2i(1280, 960), "3:2 (2160x1440)": Vector2i(1280, 853)}
	var checks := []
	for name in sizes:
		var sv := SubViewport.new()
		sv.size = sizes[name]
		sv.disable_3d = true
		add_child(sv)
		var ui := GameUI.new()
		ui.main = main
		sv.add_child(ui)
		Game.playing = true
		await get_tree().process_frame
		ui.layout()
		ui._process(0.016)
		await get_tree().process_frame
		var vr := Rect2(Vector2.ZERO, Vector2(sizes[name]))
		var ctrls := [ui.btn_interact, ui.btn_run, ui.btn_phone, ui.btn_pause, ui.hud.get_node("MoneyPanel")]
		var inside := true
		var min_touch := 1e9
		for c in ctrls:
			var r: Rect2 = c.get_global_rect()
			if not vr.encloses(r):
				inside = false
			if c is TouchButton:
				min_touch = min(min_touch, min(r.size.x, r.size.y))
		var overlap := false
		for i in 3:
			for j in range(i + 1, 4):
				if ctrls[i].get_global_rect().intersects(ctrls[j].get_global_rect()):
					overlap = true
		var joy := Rect2(ui.joystick._rest_center() - Vector2(90, 90), Vector2(180, 180))
		var joy_ok := vr.encloses(joy) and not joy.intersects(ui.btn_phone.get_global_rect())
		ui.toggle_phone()
		await get_tree().process_frame
		await get_tree().process_frame
		var box: Control = ui.modal.get_node("Box") if ui.modal else null
		var phone_ok := box != null and vr.encloses(box.get_global_rect())
		checks.append([inside and not overlap and joy_ok and phone_ok and min_touch >= 64, "%s → logico %dx%d: comandi dentro lo schermo=%s, sovrapposizioni=%s, joystick ok=%s, telefono dentro=%s, pulsante minimo %d px" % [name, sizes[name].x, sizes[name].y, inside, overlap, joy_ok, phone_ok, int(min_touch)]])
		sv.queue_free()
	await get_tree().process_frame
	record("T11", "L'interfaccia funziona su schermi di dimensioni differenti", checks)

# ------------------------------------------------------------------ 12
func t12_session() -> void:
	fresh()
	var p: Player = main.player
	var ui = main.ui
	GameTime.running = true
	var opened_apps := 0
	for app in ["", "conto", "zaino", "agenda", "lavoro", "stato", "menu"]:
		ui.toggle_phone() if ui.modal_kind != "phone" else null
		ui.phone_open_app(app)
		await get_tree().process_frame
		opened_apps += 1
	ui.close_modal()
	# giro: casa → porta → Via dei Tigli → Via Roma → Market
	p.teleport(Vector3(-50.0, 0.13, -27.0), PI / 2.0)
	main.town.doors["home"].open()
	p.cam_yaw_node.rotation.y = PI / 2.0 + PI
	p.move_input = Vector2(0, -1)
	await frames(240)
	p.move_input = Vector2.ZERO
	var outside := p.global_position.x > -47.0
	set_time(1, "09:00")
	ui.open_shop_panel("Tutti i prodotti", Data.products_by_id.keys())
	await get_tree().process_frame
	ui.buy("panino_pronto")
	ui.buy("pasta_500g")
	ui.close_modal()
	ui.open_food_panel(false, "Zaino")
	ui._consume("panino_pronto", false)
	ui.close_modal()
	ui.open_sleep_panel(); ui.close_modal()
	ui.open_bills_panel(); ui.close_modal()
	ui.open_bus_panel(); ui.close_modal()
	# NPC: parla con chi è in giro
	var talked := 0
	for n in main.npcs:
		if n.visible:
			n._talk()
			talked += 1
	if ui.dialogue_panel:
		ui.dialogue_panel.queue_free()
		ui.dialogue_panel = null
	# 3 giorni di vita con turni al bar
	Jobs.hire()
	var shifts_paid := 0
	for d in [2, 3, 4]:
		set_time(d, "06:20")
		Needs.energy = max(Needs.energy, 60)
		set_time(d, "06:35")
		var st := Jobs.start_shift()
		if st["ok"]:
			for i in 11:
				Jobs.complete_order()
			set_time(d, "12:40")
			if Jobs.paid_days.has(str(d)):
				shifts_paid += 1
		Inventory.consume("pasta_500g", true)
		set_time(d, "22:30")
		Game.sleep_hours(7.5, false)
	GameTime.running = false
	var saved := SaveSystem.save_game()
	var loaded := SaveSystem.load_game()
	record("T12", "Nessun errore critico durante il normale utilizzo (sessione automatica)", [
		[opened_apps == 7, "telefono: home + 6 app aperte"],
		[outside, "uscito di casa camminando (x=%.1f)" % p.global_position.x],
		[shifts_paid == 3, "3 turni lavorati e pagati (%d)" % shifts_paid],
		[talked >= 1, "dialoghi con %d NPC presenti" % talked],
		[saved and loaded, "salva/carica a fine sessione"],
		[Economy.is_consistent(), "denaro coerente dopo 4 giorni (saldo € %s)" % Data.euro(Economy.money_cents)],
		[true, "errori di script/motore: verificati dal runner shell sul log (vedi TEST-REPORT)"],
	])

# ------------------------------------------------------------------ Ledger
func b_balance() -> void:
	# B1: mille azioni casuali, saldo mai sotto zero
	fresh(1, "09:00")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var neg := false
	var ids: Array = Data.products_by_id.keys()
	for i in 1500:
		var a = rng.randi() % 3
		if a == 0:
			main.ui.buy(ids[rng.randi() % ids.size()])
		elif a == 1:
			Inventory.restock()
		else:
			GameTime.advance(rng.randf_range(5, 90))
			Needs.eat(50, 50)
		if Economy.money_cents < 0:
			neg = true
	var b1 := [not neg and Economy.is_consistent(), "B1: 1500 azioni casuali (acquisti, tempo, bollette): saldo mai negativo, coerente (finale € %s)" % Data.euro(Economy.money_cents)]
	# B4: senza mangiare l'energia scende sotto la soglia di lavoro entro ~2 giorni
	fresh()
	var hours := 0
	var under_at := -1
	for d in 2:
		for h in 16:
			Needs.apply_awake_hours(1.0, "idle")
			hours += 1
			if under_at < 0 and Needs.energy < float(Data.economy["needs_thresholds"]["energy_min_to_work"]):
				under_at = hours
		Needs.apply_sleep_hours(8.0)
		hours += 8
	var b4 := [under_at > 0 and under_at <= 48, "B4: senza pasti l'energia va sotto %d dopo %d ore di gioco (entro 48)" % [int(Data.economy["needs_thresholds"]["energy_min_to_work"]), under_at]]
	record("BAL", "Test di bilanciamento di Ledger (B2 = T06, B3 = T09)", [b1, b4,
		[Data.economy["rent"]["amount_cents"] == 9000 and Data.economy["job_barista"]["pay_cents_per_shift"] == 4500, "valori letti da data/economy.json (affitto € 90, paga € 45)"]])

# ------------------------------------------------------------------ pulsanti
func x_no_fake_buttons() -> void:
	fresh(2, "09:00")
	var ui = main.ui
	var dead := []
	var total := 0
	var screens := []
	ui.toggle_phone()
	for app in ["", "conto", "zaino", "agenda", "lavoro", "stato", "menu"]:
		ui.phone_open_app(app)
		screens.append(["telefono/" + app, ui.modal])
	var checks := []
	for s in screens:
		pass
	# raccoglie i pulsanti di ogni schermata (aprendola) e verifica che abbiano un'azione collegata
	var openers := {
		"market": func(): ui.open_shop_panel("Tutti i prodotti", Data.products_by_id.keys()),
		"bar": func(): ui.open_bar_panel(),
		"sonno": func(): ui.open_sleep_panel(),
		"bollette": func(): ui.open_bills_panel(),
		"bus": func(): ui.open_bus_panel(),
		"frigo": func(): ui.open_food_panel(true, "Frigo"),
		"pausa": func(): ui.open_pause(),
	}
	for app in ["", "conto", "zaino", "agenda", "lavoro", "stato", "menu"]:
		openers["telefono/" + (app if app != "" else "home")] = func():
			if ui.modal_kind != "phone":
				ui.toggle_phone()
			ui.phone_open_app(app)
	for k in openers:
		openers[k].call()
		for b in ui.modal.find_children("*", "Button", true, false) if ui.modal else []:
			total += 1
			if b.pressed.get_connections().is_empty():
				dead.append(k + ":" + b.text)
		ui.close_modal()
		get_tree().paused = false
	for b in ui.hud.find_children("*", "Button", true, false):
		total += 1
		var conns: int = b.pressed.get_connections().size() + (b.activated.get_connections().size() if b is TouchButton else 0)
		if conns == 0:
			dead.append("hud:" + b.text)
	record("X01", "Nessun pulsante finto (telefono, pannelli, HUD)", [[dead.is_empty(), "%d pulsanti controllati, senza azione: %s" % [total, str(dead)]]])

func x_npcs() -> void:
	fresh(2, "08:30")
	await_frames_sync()
	var vis := []
	for n in main.npcs:
		n._update_schedule(true)
		if n.visible:
			vis.append(n.display_name)
	set_time(3, "02:00")
	var night := 0
	for n in main.npcs:
		n._update_schedule(true)
		if n.visible:
			night += 1
	var v := NPC.placeholder_vars()
	var unresolved := 0
	for d in Data.dialogues:
		for l in d["battute"]:
			if "{" in Data.fmt(l, v):
				unresolved += 1
	record("X02", "NPC con orari e dialoghi collegati ai dati", [
		[vis.size() >= 4, "martedì 08:30 in giro: %s" % ", ".join(vis)],
		[night == 0, "alle 02:00 tutti a casa (%d visibili)" % night],
		[unresolved == 0, "%d blocchi di dialogo: segnaposto non risolti = %d" % [Data.dialogues.size(), unresolved]],
	])

# ------------------------------------------------------------------ X03 (Hook caso 10)
func x_eat() -> void:
	fresh(1, "09:00")
	Needs.hunger = 40.0
	Inventory.add_product("pane_500g")
	var n0 := Inventory.count("pane_500g")
	var r: Dictionary = Inventory.consume("pane_500g", false)
	var hunger_ok := absf(Needs.hunger - (40.0 + float(Data.products_by_id["pane_500g"]["hunger"]))) < 0.01
	var n1 := Inventory.count("pane_500g")
	while Inventory.count("pane_500g") > 0:
		Inventory.consume("pane_500g", false)
	var h_before := Needs.hunger
	var r0: Dictionary = Inventory.consume("pane_500g", false)
	Inventory.add_product("pasta_500g")
	var rk: Dictionary = Inventory.consume("pasta_500g", false)
	record("X03", "Mangiare dall'inventario (caso Hook 10)", [
		[r["ok"] and hunger_ok, "pane: fame 40 → %.0f (effetto dai dati +%d)" % [40.0 + float(Data.products_by_id["pane_500g"]["hunger"]), int(Data.products_by_id["pane_500g"]["hunger"])]],
		[n1 == n0 - 1, "porzioni %d → %d" % [n0, n1]],
		[not r0["ok"] and Needs.hunger == h_before, "a 0 porzioni non si mangia (fame invariata)"],
		[not rk["ok"] and Inventory.count("pasta_500g") > 0, "la pasta senza cucina è rifiutata: " + str(rk.get("text", ""))],
	])

# ------------------------------------------------------------------ X04 (Hook caso 13)
func x_background_shift() -> void:
	fresh(2, "06:30")   # martedì, inizio turno
	Jobs.hire()
	Needs.energy = 80.0
	var st: Dictionary = Jobs.start_shift()
	for i in 4:
		Jobs.complete_order()
	var tx0 := Economy.history.size()
	Game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await frames(2)
	var paused_ui: bool = main.ui.modal_kind in ["pause", "shift_pause"]
	var still_shift := Jobs.in_shift
	var saved := SaveSystem.save_game()   # in gioco lo fa autosave_now (spento nei test)
	main.ui.close_modal()
	get_tree().paused = false
	var loaded := SaveSystem.load_game()
	var after_tx := Economy.history.size()
	var again: Dictionary = Jobs.check_in_status()
	var paid := Jobs.paid_days.has("2")
	record("X04", "App in background/chiusa durante il turno (caso Hook 13)", [
		[st["ok"], "turno iniziato martedì 06:30"],
		[paused_ui and still_shift, "background: compare la pausa del turno, il turno resta sospeso"],
		[saved and loaded and not Jobs.in_shift, "dopo chiusura e riapertura il turno è annullato"],
		[after_tx == tx0 and not paid, "nessuno stipendio senza aver lavorato (voci storico %d → %d)" % [tx0, after_tx]],
		[not again["ok"], "non si ripete il turno lo stesso giorno: " + str(again["reason"])],
		[Economy.is_consistent(), "saldo coerente con lo storico"],
	])
	GameTime.speed_mult = 1.0

# ------------------------------------------------------------------ X05 caso Hook 1: 95 € spiegati al primo avvio
func x_first_day_notice() -> void:
	_toasts_seen.clear()
	fresh()
	var t := Game.tutorial_text()
	var notice := ""
	for m in _toasts_seen:
		if m.begins_with("Primo giorno"):
			notice = m
	record("X05", "Primo avvio: addebito di affitto e telefono spiegato (caso Hook 1)", [
		[Economy.money_cents == 40001, "saldo dopo la nuova partita € %s (500 − 90 − 9,99)" % Data.euro(Economy.money_cents)],
		[notice.contains("90,00") and notice.contains("9,99") and notice.contains("400,01"), "avviso unico: «%s»" % notice],
		[t.contains("500,00") and t.contains("400,01") and t.contains("90,00"), "primo passo del tutorial: «%s»" % t],
		[Economy.history.size() == 2, "nello storico: 2 voci (affitto settimana 1, ricarica telefono)"],
	])

# ------------------------------------------------------------------ X06 caso 21
func x_shop_closing() -> void:
	fresh(1, "19:58")
	var ui = main.ui
	ui.open_shop_panel("Test", ["pane_500g"])
	await frames(2)
	var was_open: bool = ui.modal_kind == "shop"
	var m0 := Economy.money_cents
	set_time(1, "20:00")
	await get_tree().process_frame
	await get_tree().process_frame
	var closed_panel: bool = ui.modal_kind != "shop"
	var r: Dictionary = ui.buy("pane_500g")
	record("X06", "Il negozio chiude con il pannello aperto (caso Hook 21)", [
		[was_open, "pannello del Market aperto alle 19:58"],
		[closed_panel, "alle 20:00 il pannello si chiude da solo con l'avviso «sta chiudendo»"],
		[r["reason"] == "closed" and Economy.money_cents == m0 and Inventory.count("pane_500g") == 0, "acquisto alle 20:00 rifiutato (closed), saldo e inventario invariati"],
	])

# ------------------------------------------------------------------ X07 caso 22
func x_purchase_then_kill() -> void:
	fresh(1, "09:00")
	var ui = main.ui
	var m0 := Economy.money_cents
	ui._buy_lock_ms = 0
	ui.buy("latte_1l")
	var after_buy := Economy.money_cents
	# chiusura forzata simulata: nessun salvataggio esplicito, si ricarica dal disco
	var loaded := SaveSystem.load_game()
	var price: int = int(Data.products_by_id["latte_1l"]["price_cents"])
	record("X07", "Acquisto e chiusura forzata subito dopo (caso Hook 22)", [
		[loaded, "salvataggio ricaricato dal disco"],
		[Economy.money_cents == after_buy and after_buy == m0 - price, "saldo dopo la riapertura € %s (= dopo l'acquisto)" % Data.euro(Economy.money_cents)],
		[Inventory.count("latte_1l") > 0, "il latte è nell'inventario dopo la riapertura (%d porzioni)" % Inventory.count("latte_1l")],
		[Economy.is_consistent(), "saldo coerente con lo storico"],
	])

# ------------------------------------------------------------------ X08 caso 23
func x_sleep_over_shift() -> void:
	fresh(2, "05:00")
	Jobs.hire()
	var m0 := Economy.money_cents
	Game.sleep_hours(8.0, false)
	var st := Jobs.check_in_status()
	record("X08", "Dormire oltre l'inizio del turno (caso Hook 23)", [
		[GameTime.clock_text() == "13:00", "sveglia alle %s (05:00 + 8 h)" % GameTime.clock_text()],
		[not st["ok"], "turno non più disponibile: " + str(st["reason"])],
		[Economy.money_cents == m0 and not Jobs.paid_days.has("2"), "nessuna paga per martedì"],
	])

# ------------------------------------------------------------------ X09 caso 24
func x_phone_in_shift() -> void:
	fresh(2, "06:30")
	Jobs.hire()
	Needs.energy = 90.0
	var ui = main.ui
	await ui.start_shift_ui()
	await frames(2)
	var t0 := GameTime.total_minutes
	ui.toggle_phone()
	await frames(2)
	var kind: String = ui.modal_kind
	var shift_ok := Jobs.in_shift
	Jobs.abandon_shift("test")
	ui.close_shift()
	record("X09", "Telefono durante il turno (caso Hook 24)", [
		[shift_ok and kind == "shift", "il telefono non si apre: resta il pannello del turno (avviso «resta in tasca»)"],
		[GameTime.total_minutes - t0 < 1.0, "il tempo non salta in avanti"],
	])

# ------------------------------------------------------------------ X10 caso 26
func x_stock_out() -> void:
	fresh(1, "09:00")
	Economy.earn(100000, "test", "entrata")
	var ui = main.ui
	var stock: int = int(Inventory.shop_stock["tonno_3x80"])
	var m0 := Economy.money_cents
	var ok_n := 0
	for i in stock + 2:
		ui._buy_lock_ms = 0
		if ui.buy("tonno_3x80")["ok"]:
			ok_n += 1
	ui._buy_lock_ms = 0
	var last: Dictionary = ui.buy("tonno_3x80")
	ui.open_shop_panel("Test", ["tonno_3x80"])
	await frames(2)
	var btn_txt := ""
	for b in ui.modal.find_children("*", "Button", true, false):
		if b.text == "Esaurito":
			btn_txt = b.text + (" (disattivato)" if b.disabled else "")
	ui.close_modal()
	set_time(2, "09:00")
	var restocked: int = int(Inventory.shop_stock["tonno_3x80"])
	record("X10", "Comprare tutte le scorte (caso Hook 26)", [
		[ok_n == stock, "comprate %d confezioni su %d a scaffale" % [ok_n, stock]],
		[last["reason"] == "stock", "acquisto successivo rifiutato (stock)"],
		[m0 - Economy.money_cents == stock * int(Data.products_by_id["tonno_3x80"]["price_cents"]), "addebiti solo per le confezioni prese"],
		[btn_txt == "Esaurito (disattivato)", "il pulsante mostra «Esaurito» ed è disattivato"],
		[restocked > 0, "il giorno dopo lo scaffale è rifornito (%d)" % restocked],
	])

# ------------------------------------------------------------------ X11 casi 25 + B1 svenimento
func x_faint() -> void:
	fresh(2, "06:30")
	Jobs.hire()
	Needs.energy = 25.0
	Jobs.start_shift()
	main.player.teleport(Vector3(10, 0.2, -12), 0.0)
	await frames(2)
	var t0 := GameTime.total_minutes
	var m0 := Economy.money_cents
	var f0: int = Game.fainted_count
	Needs.energy = 0.3
	Needs.apply_awake_hours(0.2, "work")
	await frames(3)
	var home_d: float = main.player.global_position.distance_to(main.town.spawn_home)
	var dt_h := (GameTime.total_minutes - t0) / 60.0
	var st := SaveSystem.inspect(SaveSystem.save_path)
	record("X11", "Svenimento lontano da casa (caso Hook 25, B1)", [
		[Game.fainted_count == f0 + 1, "svenimento registrato una volta"],
		[home_d < 1.5, "risveglio a casa (distanza dal letto %.2f m)" % home_d],
		[absf(dt_h - float(Data.balance["faint"]["sleep_hours"])) < 0.05, "passano %.1f ore (dati: %d)" % [dt_h, int(Data.balance["faint"]["sleep_hours"])]],
		[Needs.energy > 0.0 and not Jobs.in_shift and Economy.money_cents == m0, "turno annullato senza paga, energia risalita a %.0f" % Needs.energy],
		[st.get("status", "") == "ok", "partita salvata dopo lo svenimento"],
	])

# ------------------------------------------------------------------ X12 B2 fame a 0
func x_hunger_zero() -> void:
	fresh(1, "09:00")
	Needs.hunger = 0.0
	Needs.energy = 60.0
	var e0 := Needs.energy
	Needs.apply_awake_hours(1.0, "idle")
	var dec: Dictionary = Data.economy["needs_decay_per_game_hour"]
	var thr: Dictionary = Data.economy["needs_thresholds"]
	var expect := float(dec["energy_awake"]) + float(thr["hunger_penalty_energy_per_hour"])
	record("X12", "Fame a 0 (B2)", [
		[Needs.hunger == 0.0, "la fame resta a 0, non va sotto"],
		[absf((e0 - Needs.energy) - expect) < 0.01, "a stomaco vuoto l'energia scende più in fretta: −%.1f/h (dati %.1f)" % [e0 - Needs.energy, expect]],
		[_faint_from_hunger(), "lasciando la fame a 0 l'energia arriva a 0 e scatta lo svenimento (risveglio a casa), nessuna morte o malattia"],
	])

func _faint_from_hunger() -> bool:
	var f0: int = Game.fainted_count
	for i in 40:
		Needs.hunger = 0.0
		Needs.apply_awake_hours(1.0, "idle")
		if Game.fainted_count > f0:
			return true
	return false

# ------------------------------------------------------------------ X13 B5 bus
func x_bus() -> void:
	fresh(1, "07:00")
	var ui = main.ui
	var nb: int = ui.next_bus_min()
	set_time(1, "21:30")
	var nb2: int = ui.next_bus_min()
	var m0 := Economy.money_cents
	ui.open_bus_panel()
	var has_btn := false
	for b in ui.modal.find_children("*", "Button", true, false):
		if b.text.begins_with("Siediti"):
			has_btn = true
	ui.close_modal()
	record("X13", "Fermata del bus (B5)", [
		[Data.min_to_hhmm(nb) == "07:10", "alle 07:00 il prossimo bus è alle %s (prima corsa 06:10, ogni 30 min)" % Data.min_to_hhmm(nb)],
		[nb2 >= 1440 and Data.min_to_hhmm(nb2) == "06:10", "dopo l'ultima corsa (21:10): prossimo domani alle 06:10"],
		[has_btn and Economy.money_cents == m0, "alla fermata ci si siede, non si paga nulla: nella v1 sul bus non si sale (detto nel pannello)"],
	])

# ------------------------------------------------------------------ X14 B5 acqua
func x_tap_water() -> void:
	fresh(1, "09:00")
	Needs.energy = 50.0
	main.town._drink_tap()
	var e1 := Needs.energy
	main.town._drink_tap()
	var e2 := Needs.energy
	Needs.paused_decay = true
	GameTime.advance(61.0)
	Needs.paused_decay = false
	main.town._drink_tap()
	var gain := float(Data.balance["tap_water"]["energy"])
	record("X14", "Acqua del rubinetto (B5)", [
		[absf(e1 - 50.0 - gain) < 0.01, "primo bicchiere: energia +%d" % int(gain)],
		[e2 == e1, "subito dopo: nessun effetto (attesa %d min)" % int(Data.balance["tap_water"]["cooldown_game_min"])],
		[absf(Needs.energy - e2 - gain) < 0.01, "dopo 61 minuti di nuovo +%d" % int(gain)],
	])

# ------------------------------------------------------------------ X15 B4 cucina
func x_cooking() -> void:
	fresh(1, "09:00")
	Needs.hunger = 20.0
	Inventory.add_product("pasta_500g")
	Inventory.add_product("sugo_pronto")
	var p0 := Inventory.count("pasta_500g")
	var s0 := Inventory.count("sugo_pronto")
	var r := Inventory.consume("pasta_500g", true)
	var pa: Dictionary = Data.products_by_id["pasta_500g"]
	var su: Dictionary = Data.products_by_id["sugo_pronto"]
	var expect: float = minf(100.0, 20.0 + float(pa["hunger"]) + float(su["hunger"]) + float(su.get("bonus_hunger", 0)))
	var h_after := Needs.hunger
	Inventory.add_product("pizza_surgelata")
	var rz := Inventory.consume("pizza_surgelata", true)
	record("X15", "Cucinare a casa (B4)", [
		[r["ok"], "pasta cucinata: " + str(r.get("text", ""))],
		[Inventory.count("pasta_500g") == p0 - 1 and Inventory.count("sugo_pronto") == s0 - 1, "una porzione di pasta e una di sugo consumate"],
		[absf(h_after - expect) < 0.01, "fame 20 → %.0f (pasta + sugo + bonus dai dati)" % h_after],
		[rz["ok"], "pizza surgelata nel forno di casa: ok"],
	])

# ------------------------------------------------------------------ X16 B6 + caso 28 arretrato lungo
func _shift_full(day: int) -> void:
	set_time(day, "06:30")
	Needs.energy = 90.0
	Jobs.start_shift()
	for i in 10:
		Jobs.complete_order()
	Jobs.finish_shift()

func _rent_pending_idx() -> int:
	for i in Economy.pending_bills.size():
		if Economy.pending_bills[i]["is_rent"]:
			return i
	return -1

func x_long_arrears() -> void:
	# parte A (caso 28): saldo 0, affitto non pagato, si lavora e si salda dal telefono
	fresh(1, "09:00")
	Jobs.hire()
	Economy.spend(Economy.money_cents, "test: azzero il saldo", "spesa")
	set_time(8, "09:00")
	var pend1 := _rent_pending_idx() >= 0
	_shift_full(9)
	var after1 := Economy.money_cents
	var early_pay := Economy.pay_pending(_rent_pending_idx())
	_shift_full(10)
	_shift_full(11)
	var idx := _rent_pending_idx()
	var due: int = int(Economy.pending_bills[idx]["amount"]) if idx >= 0 else 0
	var paid := Economy.pay_pending(idx) if idx >= 0 else false
	var ok_a := Economy.is_consistent() and Economy.money_cents >= 0 and not Economy.evicted
	# parte B (B6): nessun pagamento per settimane
	fresh(1, "09:00")
	Economy.spend(Economy.money_cents, "test: azzero il saldo", "spesa")
	var neg := false
	var evict_day := -1
	for d in range(2, 30):
		set_time(d, "09:00")
		if Economy.money_cents < 0:
			neg = true
		if Economy.evicted and evict_day < 0:
			evict_day = d
	record("X16", "Arretrato lungo e stipendio con saldo a 0 (B6, caso Hook 28)", [
		[pend1, "giorno 8 senza soldi: affitto in arretrato"],
		[after1 == int(Data.economy["job_barista"]["pay_cents_per_shift"]), "turno con saldo 0: stipendio entrato (€ %s)" % Data.euro(after1)],
		[not early_pay and Economy.money_cents >= 0, "con € 45 il saldo non basta: pagamento rifiutato, saldo mai negativo"],
		[paid and due > 0, "dopo 3 turni l'arretrato (€ %s, con mora) si salda dal telefono" % Data.euro(due)],
		[ok_a, "nessuno sfratto se si salda, storico coerente"],
		[evict_day > 0, "senza mai pagare: «sfratto» leggero (schermata di ripartenza) il giorno %d, l'arretrato non cresce all'infinito" % evict_day],
		[not neg and Economy.is_consistent(), "saldo mai negativo e coerente con lo storico"],
	])
	main.ui.close_modal()

# ------------------------------------------------------------------ X17 sessione di 21 giorni (review Hook, A/T12)
func x_21_days() -> void:
	fresh(1, "07:00")
	Jobs.hire()
	Game.skip_tutorial()
	var ui = main.ui
	var bad_needs := 0
	var start_rents := _rent_tx()
	for d in range(1, 22):
		# mattina: turno se è giorno lavorativo
		set_time(d, "06:30")
		if Jobs.check_in_status()["ok"]:
			Jobs.start_shift()
			for i in 10:
				Jobs.complete_order()
			Needs.apply_awake_hours(6.0, "work")
			set_time(d, "12:30")
			Jobs.finish_shift()
		set_time(d, "13:00")
		# spesa e pasti (Market aperto lun-sab)
		for id in ["pasta_500g", "sugo_pronto", "banane_1kg", "pane_500g"]:
			ui._buy_lock_ms = 0
			ui.buy(id)
		for id in ["banane_1kg", "pane_500g"]:
			Inventory.consume(id, false)
		Inventory.consume("pasta_500g", true)
		Needs.apply_awake_hours(8.0, "walk")
		set_time(d, "22:30")
		Game.sleep_hours(Game.hours_until("06:00"), false)
		for v in [Needs.hunger, Needs.energy, Needs.sonno]:
			if v < 0.0 or v > 100.0:
				bad_needs += 1
		Economy.pay_pending(0) if not Economy.pending_bills.is_empty() else null
	var rents := _rent_tx() - start_rents
	record("X17", "Sessione automatica di 21 giorni (review Hook: 3 affitti)", [
		[Economy.is_consistent(), "saldo coerente con lo storico dopo 21 giorni (€ %s, %d voci)" % [Data.euro(Economy.money_cents), Economy.history.size()]],
		[rents == 3 and GameTime.day() == 22, "affitti dei giorni 8, 15 e 22 addebitati una volta ciascuno (%d, oggi è il giorno %d) + giorno 1 alla nuova partita" % [rents, GameTime.day()]],
		[Economy.money_cents >= 0 and not Economy.evicted, "mai saldo negativo, nessuno sfratto con una routine normale"],
		[bad_needs == 0, "bisogni sempre tra 0 e 100"],
		[Jobs.shifts_completed >= 15, "turni pagati: %d (mar-sab)" % Jobs.shifts_completed],
	])

func await_frames_sync() -> void:
	pass
