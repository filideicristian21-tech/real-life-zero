extends Node
## Flusso di gioco: nuova partita/continua, tutorial, eventi, autosave, pausa/ripresa app.

signal toast_requested(text: String, kind: String)
signal tutorial_changed(step: int)
signal game_started()
signal day_summary(info: Dictionary)
signal evicted()
signal request_fade(on: bool)

const VERSION := "0.3.0"
var playing := false
var player: Node3D = null
var world: Node = null
var tutorial_step := 0
var tutorial_done := false
var met: Dictionary = {}
var flags: Dictionary = {}
var saved_player_pos = null
var saved_player_yaw := 0.0
var day_income := 0
var day_expense := 0
var _autosave_acc := 0.0
var sleeping := false
var headless_test := false

var _quiet_bills := false
var fainted_count := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	Economy.bill_event.connect(_on_bill)
	Economy.transaction_added.connect(_on_tx)
	GameTime.day_changed.connect(_on_day_changed)
	Needs.fainted.connect(_on_fainted)
	Needs.warning.connect(_on_need_warning)
	Jobs.shift_ended.connect(_on_shift_ended)
	Jobs.hired.connect(func(): tutorial_event("hired"))

func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"run": [KEY_SHIFT], "interact": [KEY_E, KEY_SPACE], "phone": [KEY_TAB, KEY_P], "pause": [KEY_ESCAPE],
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keys[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)

func toast(text: String, kind: String = "info") -> void:
	toast_requested.emit(text, kind)

func euro(c: int) -> String:
	return Data.euro(c)

# ---------------- Partita ----------------
func new_game() -> void:
	GameTime.reset_new_game()
	Economy.reset_new_game()
	Needs.reset_new_game()
	Inventory.reset_new_game()
	Jobs.reset_new_game()
	Life.reset_new_game()
	tutorial_step = 0
	tutorial_done = false
	met.clear()
	flags.clear()
	saved_player_pos = null
	saved_player_yaw = 0.0
	day_income = 0
	day_expense = 0
	_quiet_bills = true
	Economy.process_bills()   # giorno 1 è lunedì: affitto + telefono, spiegati con un solo avviso chiaro
	_quiet_bills = false
	_start()
	toast(Data.t("feedback.first_day_bills", first_day_vars()), "info")
	SaveSystem.save_game()

func continue_game(from_backup: bool = false) -> bool:
	var ok := SaveSystem.load_backup() if from_backup else SaveSystem.load_game()
	if not ok:
		return false
	Economy.process_bills()
	_start()
	var vars := {"giorno": GameTime.day(), "ora": GameTime.clock_text(), "saldo": euro(Economy.money_cents)}
	if from_backup:
		toast(Data.t("save.backup_loaded", vars), "ok")
	else:
		toast(Data.t("save.welcome_back", vars), "info")
	return true

func _start() -> void:
	playing = true
	GameTime.running = true
	get_tree().paused = false
	game_started.emit()
	tutorial_changed.emit(tutorial_step)

func stop() -> void:
	playing = false
	GameTime.running = false

func progress_to_dict() -> Dictionary:
	var pos = null
	var yaw := 0.0
	if player and is_instance_valid(player):
		pos = [player.global_position.x, player.global_position.y, player.global_position.z]
		yaw = player.get_yaw() if player.has_method("get_yaw") else 0.0
	elif saved_player_pos != null:
		pos = saved_player_pos
		yaw = saved_player_yaw
	return {"tutorial_step": tutorial_step, "tutorial_done": tutorial_done, "met": met.keys(), "flags": flags,
		"player_pos": pos, "player_yaw": yaw, "day_income": day_income, "day_expense": day_expense}

func progress_from_dict(d: Dictionary) -> void:
	tutorial_step = int(d.get("tutorial_step", 0))
	tutorial_done = bool(d.get("tutorial_done", false))
	met.clear()
	for k in d.get("met", []):
		met[str(k)] = true
	flags = d.get("flags", {})
	saved_player_pos = d.get("player_pos", null)
	saved_player_yaw = float(d.get("player_yaw", 0.0))
	day_income = int(d.get("day_income", 0))
	day_expense = int(d.get("day_expense", 0))

# ---------------- Tutorial ----------------
func tutorial_steps() -> Array:
	return Data.texts["tutorial"]

func tutorial_text() -> String:
	if tutorial_done or tutorial_step >= tutorial_steps().size():
		return ""
	var r: Dictionary = Data.economy["rent"]
	var vars := first_day_vars()
	vars["giorni_affitto"] = r["period_days"]
	vars["turno_inizio"] = Data.economy["job_barista"]["shift"]["start"]
	if tutorial_step == 0:
		var tel := int(Life.cfg()["bills"]["phone"]["amount_cents"])
		vars["saldo"] = euro(int(Data.economy["start"]["money_cents"]) - int(r["amount_cents"]) - tel) + " €"
	return Data.fmt(tutorial_steps()[tutorial_step]["text"], vars)

func tutorial_event(ev: String) -> void:
	if tutorial_done:
		return
	var steps := tutorial_steps()
	if tutorial_step < steps.size() and steps[tutorial_step]["done"] == ev:
		tutorial_step += 1
		if tutorial_step >= steps.size():
			tutorial_done = true
		tutorial_changed.emit(tutorial_step)

func skip_tutorial() -> void:
	tutorial_done = true
	tutorial_changed.emit(tutorial_step)

# ---------------- Eventi ----------------
func _on_tx(tx: Dictionary) -> void:
	if int(tx["amount"]) > 0:
		day_income += int(tx["amount"])
	else:
		day_expense += -int(tx["amount"])

func first_day_vars() -> Dictionary:
	var tel := int(Life.cfg()["bills"]["phone"]["amount_cents"])
	return {"iniziale": euro(int(Data.economy["start"]["money_cents"])) + " €", "affitto": euro(int(Data.economy["rent"]["amount_cents"])) + " €",
		"telefono": euro(tel) + " €", "saldo": euro(Economy.money_cents) + " €"}

func _on_bill(kind: String, info: Dictionary) -> void:
	if _quiet_bills and kind == "paid":
		return
	match kind:
		"paid":
			if info.get("is_rent", false):
				toast(Data.t("feedback.rent_paid", {"affitto": euro(int(info["amount"])), "giorno": Economy.next_rent_due_day()}), "info")
			else:
				toast("Addebitato: %s −%s €." % [info["desc"], euro(int(info["amount"]))], "info")
		"unpaid":
			toast(Data.t("feedback.rent_unpaid", {"affitto": euro(int(info["amount"])), "mancanti": euro(int(info["missing"]))}) + " Puoi saldarlo dal telefono (Conto).", "warn")
		"late_fee":
			if info.get("is_rent", false):
				toast("Affitto in ritardo: aggiunta una mora di %s €." % euro(int(info.get("fee_added", 0))), "warn")
			elif int(info.get("fee_added", 0)) > 0:
				toast("%s in ritardo: mora di %s €. L'affidabilità scende un po'." % [info["desc"], euro(int(info["fee_added"]))], "warn")
		"evicted":
			_mild_eviction()

## Sfratto "leggero" (Guard: conseguenze miti e sempre recuperabili).
## Nella stanza: il padrone propone un piano di rientro, la partita continua e l'arretrato resta da saldare.
## In un appartamento: si torna nella stanza; la cauzione copre l'arretrato e il resto viene restituito.
func _mild_eviction() -> void:
	if Life.home_id == "stanza_via_roma":
		toast("Due affitti non pagati. Il Sig. Bianchi ti propone un piano di rientro: salda l'arretrato dal telefono appena puoi. L'affidabilità è scesa.", "warn")
		evicted.emit()
		return
	var arrears := 0
	var keep: Array = []
	for b in Economy.pending_bills:
		if b["is_rent"]:
			arrears += int(b["amount"])
		else:
			keep.append(b)
	var dep := Life.deposit_held_cents
	var covered := mini(dep, arrears)
	Economy.pending_bills = keep
	if arrears > covered:
		Economy.pending_bills.append({"key": "arretrato:%d" % GameTime.day(), "desc": "Arretrato affitto non coperto dalla cauzione", "amount": arrears - covered, "due_day": GameTime.day(), "late_fee_applied": true, "is_rent": false, "kind": "affitto", "grace": 999, "late_fee": 0})
	var back := dep - covered
	Life.deposit_held_cents = 0
	Life.home_id = "stanza_via_roma"
	Life.rent_anchor_day = GameTime.day()
	Life.deposit_held_cents = 0
	Economy.evicted = false
	if back > 0:
		Economy.earn(back, "Cauzione restituita (meno l'arretrato)", "cauzione")
	toast("Affitti non pagati: torni nella stanza di Via dei Tigli. La cauzione ha coperto € %s di arretrato." % euro(covered), "warn")
	evicted.emit()

func _on_day_changed(_d: int) -> void:
	var info := {"day": GameTime.day() - 1, "income": day_income, "expense": day_expense, "balance": Economy.money_cents, "rent_in": Economy.days_to_next_rent()}
	day_income = 0
	day_expense = 0
	Economy.process_bills()
	day_summary.emit(info)

func _on_need_warning(k: String) -> void:
	match k:
		"fame": toast("Hai fame. Mangia qualcosa (Zaino o Market).", "warn")
		"energia": toast("Sei a corto di energia: sotto 20 non puoi iniziare il turno.", "warn")
		"sonno": toast("Hai sonno. Torna a casa a dormire.", "warn")

func _on_shift_ended(paid: bool, amount: int, reason: String) -> void:
	if paid:
		toast(Data.t("feedback.paid", {"paga": euro(amount), "saldo": euro(Economy.money_cents), "lavoro": Jobs.job(Jobs.cur_job).get("place", "lavoro")}), "ok")
	else:
		toast(Data.t("feedback.not_paid", {"motivo": reason}), "warn")

func _on_fainted() -> void:
	if sleeping or not playing:
		return
	Jobs.abandon_shift("Sei svenuto durante il turno.")
	toast(Data.balance["faint"]["message"], "warn")
	if world and world.has_method("send_player_home"):
		world.send_player_home()
	sleep_hours(float(Data.balance["faint"]["sleep_hours"]), false)
	fainted_count += 1
	SaveSystem.save_game()

## Sonno: fa passare il tempo un'ora alla volta (bollette e cambi giorno compresi), poi autosave.
func sleep_hours(h: float, autosave: bool = true) -> void:
	sleeping = true
	Needs.activity = "sleep"
	var whole := int(floor(h))
	for i in range(whole):
		GameTime.advance(60.0)
		Needs.apply_sleep_hours(1.0)
	var rest := h - whole
	if rest > 0.0:
		GameTime.advance(rest * 60.0)
		Needs.apply_sleep_hours(rest)
	Needs.activity = "idle"
	sleeping = false
	tutorial_event("slept")
	if autosave:
		if SaveSystem.save_game():
			toast(Data.t("save.slept"), "ok")
		else:
			toast(Data.t("save.error"), "warn")

## Ore da adesso fino all'ora hh:mm (domani se già passata).
func hours_until(hhmm: String) -> float:
	var target := Data.hhmm_to_min(hhmm)
	var now := GameTime.minute_of_day()
	var diff := target - now
	if diff <= 0:
		diff += 1440
	return diff / 60.0

# ---------------- Autosave e ciclo di vita app ----------------
func _process(delta: float) -> void:
	if not playing or get_tree().paused:
		return
	_autosave_acc += delta
	if _autosave_acc >= float(Data.balance.get("autosave_real_seconds", 90)):
		_autosave_acc = 0.0
		if not Jobs.in_shift:
			SaveSystem.save_game()

## Caso 22: dopo ogni acquisto si salva subito, così una chiusura forzata non separa soldi e inventario.
func save_after_purchase() -> void:
	if playing and not Jobs.in_shift:
		SaveSystem.save_game()

func autosave_now(reason: String) -> void:
	if playing and not headless_test:
		var ok := SaveSystem.save_game()
		print("[autosave] ", reason, " ok=", ok)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			autosave_now("app in background")
			if playing and world and world.has_method("open_pause"):
				world.open_pause()
		NOTIFICATION_WM_CLOSE_REQUEST:
			autosave_now("chiusura")
		NOTIFICATION_APPLICATION_RESUMED:
			pass

func money_context() -> String:
	var th: Dictionary = Data.economy["money_thresholds"]
	if Economy.money_cents < int(th["soldi_pochi_below_cents"]):
		return "soldi_pochi"
	if Economy.money_cents > int(th["soldi_tanti_above_cents"]):
		return "soldi_tanti"
	return ""
