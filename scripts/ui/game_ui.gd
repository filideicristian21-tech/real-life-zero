class_name GameUI
extends CanvasLayer
## HUD, comandi touch, telefono «Zero Phone», pannelli (negozio, bar, turno, sonno, bollette, bus),
## menu principale, pausa, crediti. Ogni pulsante visibile ha una funzione reale.

var main: Node
var root: Control
var hud: Control
var clock_lbl: Label
var day_lbl: Label
var money_lbl: Label
var bars := {}
var prompt_lbl: Label
var prompt_panel: PanelContainer
var toast_box: VBoxContainer
var tut_panel: PanelContainer
var tut_lbl: Label
var tut_ok: Button
var joystick: TouchJoystick
var btn_interact: TouchButton
var btn_run: TouchButton
var btn_phone: TouchButton
var btn_pause: TouchButton
var modal_layer: Control
var modal: Control = null
var modal_kind := ""
var fade_rect: ColorRect
var dialogue_panel: PanelContainer = null
var phone_app := ""
var shift_ui: Dictionary = {}
var _pending_summary = null
var _buy_lock_ms := 0
var _toasts: Array = []
var _toast_queue: Array = []
const HUD_BTN := Color(0.102, 0.102, 0.102, 0.6)
var build_lbl: Label
var life_ui: LifeUI
var rider_lbl: Label

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.make_theme()
	add_child(root)
	life_ui = LifeUI.new(self)
	_build_hud()
	var rp := PanelContainer.new()
	rp.name = "RiderPanel"
	rp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rp.set_anchors_preset(Control.PRESET_CENTER_TOP)
	rp.position = Vector2(-300, 70)
	rp.custom_minimum_size = Vector2(600, 0)
	rp.visible = false
	rider_lbl = UIKit.label("", 20, Color.WHITE, true)
	rider_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rp.add_child(rider_lbl)
	hud.add_child(rp)
	Life.score_changed.connect(func(_s, d, _r):
		if d != 0 and not Game.headless_test:
			show_toast("Affidabilità %+d (ora %d)." % [d, Life.credit_score], "ok" if d > 0 else "warn"))
	modal_layer = Control.new()
	modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(modal_layer)
	toast_box = VBoxContainer.new()
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_box.position = Vector2(-330, 118)
	toast_box.custom_minimum_size = Vector2(660, 0)
	root.add_child(toast_box)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)
	Game.toast_requested.connect(show_toast)
	Game.tutorial_changed.connect(func(_s): _refresh_tutorial())
	Economy.money_changed.connect(func(_c): _refresh_hud())
	Needs.needs_changed.connect(_refresh_hud)
	Jobs.order_count_changed.connect(func(_n): _refresh_shift())
	layout()

# =====================================================================  HUD
func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	# in alto a sinistra: orologio, giorno, bisogni
	var tl := PanelContainer.new()
	tl.position = Vector2(16, 14)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(tl)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	tl.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	tl.add_theme_stylebox_override("panel", UIKit.sb(Color(0.08, 0.08, 0.08, 0.55), 12, 10))
	clock_lbl = UIKit.label("Lun 07:00", 24)
	h.add_child(clock_lbl)
	day_lbl = UIKit.label("Giorno 1", 15, UIKit.MUTED)
	day_lbl.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(day_lbl)
	for k in [["fame", "Fame", Color("#F2A65A")], ["energia", "Energia", Color("#5BC17A")], ["sonno", "Sonno", Color("#7BA7E0")]]:
		var row := HBoxContainer.new()
		var l := UIKit.label(k[1], 13, UIKit.MUTED)
		l.custom_minimum_size = Vector2(58, 0)
		row.add_child(l)
		var b := UIKit.bar(50, k[2])
		b.add_theme_stylebox_override("fill", UIKit.sb(k[2], 2, 0))
		b.add_theme_stylebox_override("background", UIKit.sb(Color(1, 1, 1, 0.14), 2, 0))
		b.custom_minimum_size = Vector2(118, 4)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		v.add_child(row)
		bars[k[0]] = b
	# in alto a destra: saldo + pausa
	var tr := PanelContainer.new()
	tr.name = "MoneyPanel"
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(tr)
	tr.add_theme_stylebox_override("panel", UIKit.sb(Color(0.08, 0.08, 0.08, 0.55), 12, 10))
	money_lbl = UIKit.label("€ 500,00", 24)
	tr.add_child(money_lbl)
	btn_pause = _touch_btn("II", 64, HUD_BTN)
	btn_pause.activated.connect(open_pause)
	hud.add_child(btn_pause)
	# prompt di interazione
	prompt_panel = PanelContainer.new()
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_lbl = UIKit.label("", 22)
	prompt_panel.add_child(prompt_lbl)
	hud.add_child(prompt_panel)
	# tutorial
	tut_panel = PanelContainer.new()
	var tv := HBoxContainer.new()
	tut_panel.add_child(tv)
	tut_lbl = UIKit.label("", 20, Color.WHITE, true)
	tut_lbl.custom_minimum_size = Vector2(430, 0)
	tut_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(tut_lbl)
	tut_ok = UIKit.button("OK", func(): Game.tutorial_event("tap"), true, 44)
	tv.add_child(tut_ok)
	tv.add_child(UIKit.button("Salta tutorial", func(): Game.skip_tutorial(), false, 44))
	hud.add_child(tut_panel)
	# comandi touch
	joystick = TouchJoystick.new()
	joystick.changed.connect(func(val): if main and main.player: main.player.move_input = val)
	hud.add_child(joystick)
	btn_interact = _touch_btn("", 136, HUD_BTN)
	btn_interact.tooltip_text = "Interagisci"
	btn_interact.icon = load("res://assets/ui/icon_interact.png")
	btn_interact.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_interact.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn_interact.expand_icon = false
	btn_interact.activated.connect(func(): if main and main.player and not is_modal_open(): main.player.try_interact())
	hud.add_child(btn_interact)
	btn_run = _touch_btn("", 92, HUD_BTN)
	btn_run.icon = load("res://assets/ui/icon_run.png")
	btn_run.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_run.tooltip_text = "Corri"
	btn_run.activated.connect(_toggle_run)
	hud.add_child(btn_run)
	btn_phone = _touch_btn("", 92, HUD_BTN)
	btn_phone.icon = load("res://assets/ui/icon_phone.png")
	btn_phone.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_phone.tooltip_text = "Telefono"
	btn_phone.activated.connect(toggle_phone)
	hud.add_child(btn_phone)
	build_lbl = UIKit.label(Data.t("build_label"), 13, Color(1, 1, 1, 0.5))
	hud.add_child(build_lbl)

func _touch_btn(text: String, size: int, col: Color) -> TouchButton:
	var b := TouchButton.new()
	b.text = text
	b.custom_minimum_size = Vector2(size, size)
	b.size = Vector2(size, size)
	b.add_theme_stylebox_override("normal", UIKit.sb(col, size / 2, 4))
	b.add_theme_stylebox_override("hover", UIKit.sb(col.lightened(0.1), size / 2, 4))
	b.add_theme_stylebox_override("pressed", UIKit.sb(col.darkened(0.25), size / 2, 4))
	b.add_theme_stylebox_override("disabled", UIKit.sb(Color(0.1, 0.1, 0.1, 0.4), size / 2, 4))
	b.add_theme_font_size_override("font_size", 16 if size < 130 else 17)
	return b

## Interagisci diventa corallo solo quando c'è qualcosa vicino; Corri si accende quando è attiva.
func _set_btn_color(b: TouchButton, col: Color) -> void:
	if b.has_meta("col") and b.get_meta("col") == col:
		return
	b.set_meta("col", col)
	var r := int(b.custom_minimum_size.x / 2)
	b.add_theme_stylebox_override("normal", UIKit.sb(col, r, 4))
	b.add_theme_stylebox_override("hover", UIKit.sb(col.lightened(0.1), r, 4))

## Posiziona gli elementi in base alla dimensione reale del viewport (UI adattiva).
func layout() -> void:
	if root == null:
		return
	var s := root.get_viewport_rect().size
	var m := 22.0
	btn_interact.position = Vector2(s.x - 136 - m - 10, s.y - 136 - m - 10)
	btn_run.position = Vector2(s.x - 92 - m - 6, btn_interact.position.y - 92 - 18)
	btn_phone.position = Vector2(btn_interact.position.x - 92 - 22, s.y - 92 - m)
	btn_pause.position = Vector2(s.x - 64 - 16, 14)
	var mp: Control = hud.get_node("MoneyPanel")
	mp.position = Vector2(s.x - 64 - 16 - 12 - max(mp.size.x, 160), 14)
	build_lbl.position = Vector2(16, s.y - 24)
	tut_panel.size = Vector2(0, 0)
	tut_panel.position = Vector2(s.x / 2.0 - 340, s.y * 0.0 + 14)
	tut_panel.custom_minimum_size = Vector2(min(680.0, s.x - 520.0), 0)
	tut_panel.position.x = (s.x - tut_panel.custom_minimum_size.x) / 2.0
	toast_box.position = Vector2(s.x / 2.0 - 330, 150)
	if modal:
		_center_modal()

func _process(_dt: float) -> void:
	if not Game.playing:
		hud.visible = false
		return
	hud.visible = true
	clock_lbl.text = GameTime.short_label()
	day_lbl.text = "  Giorno %d%s" % [GameTime.day(), "  ×%d" % int(GameTime.speed_mult) if GameTime.speed_mult > 1.0 else ""]
	var p: Player = main.player if main else null
	var txt := ""
	if p and p.current_target and not is_modal_open():
		txt = p.current_target.get_prompt()
	prompt_panel.visible = txt != ""
	prompt_lbl.text = txt
	var s := root.get_viewport_rect().size
	prompt_panel.position = Vector2((s.x - prompt_panel.size.x) / 2.0, s.y - 170)
	btn_interact.disabled = txt == ""
	var can_run := Needs.can_run()
	btn_run.disabled = not can_run
	var controls_on := not is_modal_open()
	for b in [btn_interact, btn_run, btn_phone, joystick]:
		b.visible = controls_on
	joystick.enabled = controls_on
	if p:
		p.input_enabled = controls_on and not (Jobs.in_shift and Jobs.cur_job != "rider")
	if rider_lbl:
		var rt := life_ui.rider_text()
		rider_lbl.text = rt
		rider_lbl.get_parent().visible = rt != "" and controls_on
	var mp: Control = hud.get_node("MoneyPanel")
	mp.position.x = s.x - 64 - 16 - 12 - mp.size.x
	tut_panel.visible = Game.playing and not is_modal_open() and tut_lbl.text != ""
	_set_btn_color(btn_interact, UIKit.CORAL if (p and p.current_target) else HUD_BTN)
	_set_btn_color(btn_run, UIKit.CORAL.darkened(0.15) if (p and p.run_toggle) else HUD_BTN)
	_update_toasts(_dt)
	_check_shop_closing()

## Caso 21: se il negozio chiude mentre il pannello è aperto, il pannello si chiude con un avviso chiaro.
func _check_shop_closing() -> void:
	if modal == null:
		return
	var hours: Dictionary = {}
	var name := ""
	if modal_kind == "shop":
		hours = Data.economy["minimarket"]["hours"]
		name = "Il Market"
	elif modal_kind == "bar" and not Jobs.in_shift:
		hours = Data.economy["bar"]["hours"]
		name = "Il Bar Centrale"
	if hours.is_empty() or GameTime.is_open(hours):
		return
	close_modal()
	show_toast("%s sta chiudendo: per oggi niente acquisti. %s" % [name, Data.t("feedback.closed", {"apertura": GameTime.next_open_text(hours)})], "warn")

func _refresh_hud() -> void:
	money_lbl.text = "€ " + Data.euro(Economy.money_cents)
	bars["fame"].value = Needs.hunger
	bars["energia"].value = Needs.energy
	bars["sonno"].value = Needs.sonno
	if modal and modal_kind == "phone":
		_render_phone()

func _toggle_run() -> void:
	if not main or not main.player:
		return
	if not Needs.can_run():
		show_toast(Data.t("feedback.too_tired_run"), "warn")
		return
	main.player.run_toggle = not main.player.run_toggle

func _refresh_tutorial() -> void:
	var t := Game.tutorial_text()
	tut_panel.visible = t != "" and Game.playing
	tut_lbl.text = t
	if t != "":
		var steps: Array = Game.tutorial_steps()
		tut_ok.visible = steps[Game.tutorial_step]["done"] == "tap"
	layout()

# =====================================================================  TOAST
func show_toast(text: String, kind: String = "info") -> void:
	if kind == "warn":
		Sfx.play("error", Vector3.INF, -6)
	elif kind == "ok":
		Sfx.play("confirm", Vector3.INF, -6)
	print("[toast] ", text)
	# un messaggio alla volta: gli altri aspettano in coda (max 4, si scartano i più vecchi)
	_toast_queue.append({"text": text, "kind": kind})
	while _toast_queue.size() > 4:
		_toast_queue.pop_front()
	if _toasts.is_empty():
		_next_toast()

func _next_toast() -> void:
	if _toast_queue.is_empty():
		return
	var q: Dictionary = _toast_queue.pop_front()
	var p := PanelContainer.new()
	var col := Color(0.08, 0.08, 0.08, 0.72)
	if q["kind"] == "warn":
		col = Color(0.42, 0.13, 0.09, 0.82)
	elif q["kind"] == "ok":
		col = Color(0.1, 0.3, 0.17, 0.8)
	p.add_theme_stylebox_override("panel", UIKit.sb(col, 10, 10))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIKit.label(q["text"], 18, Color.WHITE, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(560, 0)
	p.add_child(l)
	p.modulate.a = 0.0
	toast_box.add_child(p)
	var dur: float = clampf(3.0 + q["text"].length() * 0.015, 3.0, 5.0)
	_toasts.append({"node": p, "t": dur, "dur": dur})

func _update_toasts(dt: float) -> void:
	var vs := root.get_viewport_rect().size
	if modal != null and is_instance_valid(modal):
		# con un pannello aperto il messaggio va in basso per non coprirne il testo
		if toast_box.get_index() < modal.get_index():
			toast_box.move_to_front()
		toast_box.position = Vector2(vs.x / 2.0 - 290, vs.y - 16 - toast_box.size.y)
	else:
		var y := 14.0
		if tut_panel.visible:
			y = tut_panel.position.y + tut_panel.size.y + 10.0
		toast_box.position = Vector2(vs.x / 2.0 - 290, y)
	for t in _toasts.duplicate():
		t["t"] -= dt
		var node: Control = t["node"]
		var age: float = t["dur"] - t["t"]
		node.modulate.a = clampf(minf(age / 0.25, t["t"] / 0.6), 0.0, 1.0)
		if t["t"] <= 0.0:
			node.queue_free()
			_toasts.erase(t)
			_next_toast()

# =====================================================================  MODALI
func is_modal_open() -> bool:
	return modal != null or dialogue_panel != null

func close_modal() -> void:
	if modal:
		modal.queue_free()
	modal = null
	if modal_kind == "phone":
		Sfx.play("phone_close")
	modal_kind = ""
	if get_tree().paused and Game.playing:
		get_tree().paused = false

func _center_modal() -> void:
	var s := root.get_viewport_rect().size
	var box: Control = modal.get_node_or_null("Box")
	if box:
		var w: float = min(box.custom_minimum_size.x, s.x - 40)
		box.size = Vector2(w, min(s.y - 40, box.get_combined_minimum_size().y))
		box.position = (s - box.size) / 2.0

## Apre un pannello modale: content_fn(vbox) riempie il contenuto. Ritorna il VBox.
func open_modal(kind: String, title: String, content_fn: Callable, width: float = 640, closable: bool = true) -> VBoxContainer:
	if modal:
		modal.queue_free()
	modal_kind = kind
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(dim)
	modal = dim
	var box := PanelContainer.new()
	box.name = "Box"
	box.custom_minimum_size = Vector2(width, 0)
	dim.add_child(box)
	var outer := VBoxContainer.new()
	box.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var tl := UIKit.label(title, 28)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	if closable:
		head.add_child(UIKit.button("Chiudi ", close_modal, false, 48))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var s := root.get_viewport_rect().size
	scroll.custom_minimum_size = Vector2(0, min(520.0, s.y - 170.0))
	outer.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	content_fn.call(v)
	dim.set_meta("scroll", scroll)
	dim.set_meta("content", v)
	await get_tree().process_frame
	refit_modal()
	return v

func refit_modal() -> void:
	if modal == null or not modal.has_meta("scroll"):
		return
	var s := root.get_viewport_rect().size
	var scroll: ScrollContainer = modal.get_meta("scroll")
	var v: VBoxContainer = modal.get_meta("content")
	var need: float = v.get_combined_minimum_size().y + 8
	scroll.custom_minimum_size.y = min(need, s.y - 170.0)
	_center_modal()

func _row(v: VBoxContainer, left: String, right: Control = null, sub: String = "") -> HBoxContainer:
	var h := HBoxContainer.new()
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 0)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_child(UIKit.label(left, 22, Color.WHITE, true))
	if sub != "":
		lv.add_child(UIKit.label(sub, 16, UIKit.MUTED, true))
	h.add_child(lv)
	if right:
		right.custom_minimum_size.x = max(right.custom_minimum_size.x, 150)
		h.add_child(right)
	v.add_child(h)
	v.add_child(HSeparator.new())
	return h

func fade(mid: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.35)
	tw.tween_callback(mid)
	tw.tween_interval(0.25)
	tw.tween_property(fade_rect, "color:a", 0.0, 0.45)

func rest_minutes(mins: float, energy_gain: float, msg: String) -> void:
	main.rest_minutes(mins, energy_gain, msg)

# =====================================================================  MARKET
func open_shop_panel(title: String, ids: Array) -> void:
	var mm: Dictionary = Data.economy["minimarket"]
	if not GameTime.is_open(mm["hours"]):
		show_toast(Data.t("feedback.closed", {"apertura": GameTime.next_open_text(mm["hours"])}), "warn")
		return
	open_modal("shop", "Market Il Girasole · " + title, func(v): _fill_shop(v, ids), 720)

func _fill_shop(v: VBoxContainer, ids: Array) -> void:
	v.add_child(UIKit.label("Saldo: € %s · Prezzi IVA inclusa (stime)" % Data.euro(Economy.money_cents), 18, UIKit.MUTED))
	for id in ids:
		var p: Dictionary = Data.products_by_id[id]
		var b := UIKit.button("Compra € " + Data.euro(int(p["price_cents"])), func(): buy(id, ids), true, 52)
		var stock := int(Inventory.shop_stock.get(id, 0))
		if stock <= 0:
			b.disabled = true
			b.text = "Esaurito"
		var eff := "Fame +%d · Energia +%d per porzione · %d porzioni" % [int(p["hunger"]), int(p["energy"]), int(p.get("uses", 1))]
		if p.has("requires"):
			eff += " · da cucinare (%s)" % p["requires"]
		if p.has("side_effect"):
			eff += " · peggiora il sonno"
		_row(v, p["name"], b, "%s\nNe hai: %d porzioni · Scaffale: %d" % [eff, Inventory.count(id), stock])

## Acquisto con protezione dal doppio tocco: un solo addebito per tocco, inventario aggiornato una volta.
func buy(id: String, ids: Array = []) -> Dictionary:
	var now := Time.get_ticks_msec()
	if now - _buy_lock_ms < 300 and not Game.headless_test:
		return {"ok": false, "reason": "debounce"}
	_buy_lock_ms = now
	var p: Dictionary = Data.products_by_id[id]
	var r := Inventory.buy_product(id)
	match r["reason"]:
		"":
			Sfx.play("coins")
			Game.save_after_purchase()
			show_toast(Data.t("feedback.bought", {"prodotto": p["name"], "prezzo": Data.euro(int(p["price_cents"])), "saldo": Data.euro(Economy.money_cents)}), "ok")
			Game.tutorial_event("bought")
		"money":
			show_toast(Data.t("feedback.no_money", {"prezzo": Data.euro(int(p["price_cents"])), "saldo": Data.euro(Economy.money_cents)}), "warn")
		"closed":
			show_toast(Data.t("feedback.closed", {"apertura": GameTime.next_open_text(Data.economy["minimarket"]["hours"])}), "warn")
		"stock":
			show_toast("Prodotto esaurito per oggi. Torna domani.", "warn")
	if modal and modal_kind == "shop" and not ids.is_empty():
		var t: String = (modal.get_node("Box").get_child(0).get_child(0).get_child(0) as Label).text.replace("Market Il Girasole · ", "")
		open_shop_panel(t, ids)
	return r

# =====================================================================  CIBO (frigo / cucina / zaino)
func open_food_panel(has_kitchen: bool, title: String) -> void:
	open_modal("food", title, func(v): _fill_food(v, has_kitchen), 680)

func _fill_food(v: VBoxContainer, has_kitchen: bool) -> void:
	if Inventory.total_items() == 0:
		var mm: Dictionary = Data.economy["minimarket"]["hours"]
		v.add_child(UIKit.label(Data.t("phone.inv_empty", {"apertura": mm["open"], "chiusura": mm["close"]}), 20, UIKit.MUTED, true))
		return
	for id in Inventory.portions.keys():
		var p: Dictionary = Data.products_by_id[id]
		var req := str(p.get("requires", ""))
		var b := UIKit.button("Cucina e mangia" if req != "" else "Mangia/Bevi", func(): _consume(id, has_kitchen), true, 50)
		if req != "" and not has_kitchen:
			b.disabled = true
			b.text = "Serve la cucina"
		_row(v, "%s × %d porz." % [p["name"], Inventory.count(id)], b, "Fame +%d · Energia +%d" % [int(p["hunger"]), int(p["energy"])])

func _consume(id: String, has_kitchen: bool) -> void:
	var r := Inventory.consume(id, has_kitchen)
	if r["ok"]:
		Sfx.play("cup")
		show_toast(r["text"], "ok")
	else:
		show_toast(r.get("text", "Non puoi."), "warn")
	if modal and (modal_kind == "food"):
		var t: String = (modal.get_node("Box").get_child(0).get_child(0).get_child(0) as Label).text
		open_food_panel(has_kitchen, t)
	elif modal and modal_kind == "phone":
		_render_phone()

# =====================================================================  BAR
func open_bar_panel() -> void:
	open_modal("bar", "Bar Centrale da Mimmo", _fill_bar, 720)

func _fill_bar(v: VBoxContainer) -> void:
	var bar: Dictionary = Data.economy["bar"]
	var open := GameTime.is_open(bar["hours"])
	var disc := Jobs.employed
	v.add_child(UIKit.label("LAVORO", 18, UIKit.CORAL))
	var job: Dictionary = Data.economy["job_barista"]
	if not Jobs.employed:
		var b := UIKit.button("Chiedi lavoro a Mimmo", func():
			close_modal()
			_mimmo_talk(), true, 50)
		if not open:
			b.disabled = true
		_row(v, "Barista part-time", b, "Turni %s–%s (%s) · € %s a turno" % [job["shift"]["start"], job["shift"]["end"], ", ".join(job["workdays"]), Data.euro(int(job["pay_cents_per_shift"]))])
	else:
		var st := Jobs.check_in_status()
		var b2 := UIKit.button("Inizia turno", func(): start_shift_ui(), true, 50)
		b2.disabled = not st["ok"]
		_row(v, "Turno di oggi", b2, (("In ritardo: paga −€ %s. " % Data.euro(int(job["late_policy"]["pay_cut_cents"]))) if st.get("late", false) else "") + (st["reason"] if not st["ok"] else "Puoi timbrare adesso. Servi almeno %d ordini." % int(job["requirements"]["orders_min_completed"])))
	v.add_child(UIKit.label("ORDINA AL BANCO" + ("  · sconto dipendenti 50%" if disc else ""), 18, UIKit.CORAL))
	if not open:
		v.add_child(UIKit.label(Data.t("feedback.closed", {"apertura": GameTime.next_open_text(bar["hours"])}), 20, UIKit.MUTED))
		return
	for it in bar["menu"]:
		var price := _bar_price(it)
		var b3 := UIKit.button("€ " + Data.euro(price), func(): bar_buy(it["id"]), true, 50)
		_row(v, it["name"], b3, "Fame +%d · Energia +%d · si consuma subito" % [int(it["hunger"]), int(it["energy"])])

func _bar_price(it: Dictionary) -> int:
	var p := int(it["price_cents"])
	if Jobs.employed:
		p = int(round(p * (1.0 - float(Data.economy["bar"]["employee_discount"]))))
	return p

func bar_buy(id: String) -> bool:
	var now := Time.get_ticks_msec()
	if now - _buy_lock_ms < 300 and not Game.headless_test:
		return false
	_buy_lock_ms = now
	var it: Dictionary = Data.bar_menu_by_id[id]
	if not GameTime.is_open(Data.economy["bar"]["hours"]):
		show_toast(Data.t("feedback.closed", {"apertura": GameTime.next_open_text(Data.economy["bar"]["hours"])}), "warn")
		return false
	var price := _bar_price(it)
	if not Economy.spend(price, "Bar Centrale: " + it["name"], "bar"):
		show_toast(Data.t("feedback.no_money", {"prezzo": Data.euro(price), "saldo": Data.euro(Economy.money_cents)}), "warn")
		return false
	Needs.eat(float(it["hunger"]), float(it["energy"]))
	Game.save_after_purchase()
	Sfx.play("cup")
	show_toast("%s servito. −€ %s · Saldo: € %s" % [it["name"], Data.euro(price), Data.euro(Economy.money_cents)], "ok")
	if modal and modal_kind == "bar":
		open_bar_panel()
	return true

func _mimmo_talk() -> void:
	for n in main.npcs:
		if n.npc_id == "barista_titolare" and n.visible:
			n._talk()
			return
	show_toast("Mimmo non c'è adesso.", "info")

# =====================================================================  TURNO (minigioco)
func start_shift_ui() -> void:
	var st := Jobs.start_shift()
	if not st["ok"]:
		show_toast(st["reason"], "warn")
		return
	close_modal()
	main.player.teleport(Vector3(5.0, Town.CURB, -51.3), 0.0)
	if st.get("late", false):
		show_toast("Sei in ritardo: la paga di oggi sarà ridotta di € %s." % Data.euro(int(Data.economy["job_barista"]["late_policy"]["pay_cut_cents"])), "warn")
	shift_ui = {"order": "", "t": 0.0, "next": 0.5, "served": 0, "missed": 0, "wrong": 0}
	var v := await open_modal("shift", "Turno al Bar Centrale", func(_v): pass, 760, false)
	if v == null:
		return
	shift_ui["vbox"] = v
	shift_ui["info"] = UIKit.label("", 20, UIKit.MUTED, true)
	v.add_child(shift_ui["info"])
	shift_ui["order_lbl"] = UIKit.label("In attesa del prossimo cliente…", 30, Color.WHITE, true)
	v.add_child(shift_ui["order_lbl"])
	shift_ui["bar"] = UIKit.bar(100, UIKit.CORAL)
	v.add_child(shift_ui["bar"])
	var grid := GridContainer.new()
	grid.columns = 3
	v.add_child(grid)
	for id in Data.balance["shift_minigame"]["items"]:
		var it: Dictionary = Data.bar_menu_by_id[id]
		var b := UIKit.button(it["name"], func(): serve(id), true, 64)
		b.custom_minimum_size.x = 220
		grid.add_child(b)
	v.add_child(UIKit.button("Lascia il turno (niente paga)", _ask_leave_shift, false, 48))
	_refresh_shift()
	await get_tree().process_frame
	refit_modal()

func _ask_leave_shift() -> void:
	_confirm("Lasciare il turno adesso? Non verrai pagato per oggi.", Jobs.abandon_shift.bind("Hai lasciato il turno prima della fine."), "Lascia")

func _process_shift(dt: float) -> void:
	if not Jobs.in_shift or Jobs.cur_job != "barista" or shift_ui.is_empty() or get_tree().paused:
		return
	var cfg: Dictionary = Data.balance["shift_minigame"]
	if shift_ui["order"] == "":
		shift_ui["next"] -= dt
		if shift_ui["next"] <= 0.0:
			var items: Array = cfg["items"]
			shift_ui["order"] = items[randi() % items.size()]
			shift_ui["t"] = float(cfg["order_timeout_real_s"])
			_refresh_shift()
	else:
		shift_ui["t"] -= dt
		if shift_ui.has("bar"):
			shift_ui["bar"].value = 100.0 * shift_ui["t"] / float(cfg["order_timeout_real_s"])
		if shift_ui["t"] <= 0.0:
			shift_ui["missed"] += 1
			shift_ui["order"] = ""
			shift_ui["next"] = float(cfg["order_interval_real_s"])
			show_toast("Il cliente se n'è andato senza essere servito.", "warn")
			_refresh_shift()

func _physics_process(dt: float) -> void:
	_process_shift(dt)

func serve(id: String) -> void:
	if not Jobs.in_shift or shift_ui.get("order", "") == "":
		return
	if id == shift_ui["order"]:
		Jobs.complete_order()
		Sfx.play("cup")
		shift_ui["order"] = ""
		shift_ui["next"] = float(Data.balance["shift_minigame"]["order_interval_real_s"])
	else:
		shift_ui["wrong"] += 1
		Sfx.play("error")
		show_toast("Ordine sbagliato! Il cliente voleva: " + Data.bar_menu_by_id[shift_ui["order"]]["name"], "warn")
	_refresh_shift()

func _refresh_shift() -> void:
	if shift_ui.is_empty() or not shift_ui.has("info") or not is_instance_valid(shift_ui["info"]):
		return
	var job: Dictionary = Data.economy["job_barista"]
	shift_ui["info"].text = "Ore %s · fine turno %s · Ordini serviti: %d / %d richiesti · persi: %d · sbagliati: %d" % [GameTime.clock_text(), job["shift"]["end"], Jobs.orders_done, int(job["requirements"]["orders_min_completed"]), shift_ui["missed"], shift_ui["wrong"]]
	if shift_ui["order"] != "":
		var nm: String = Data.bar_menu_by_id[shift_ui["order"]]["name"]
		var item: String = nm.left(1).to_lower() + nm.substr(1)
		var art := "un "
		if item.begins_with("spremuta") or item.begins_with("brioche") or item.begins_with("pizzetta"):
			art = "una "
		elif item.begins_with("acqua") or item.begins_with("aranciata"):
			art = "un'"
		var phrases := ["«%s%s, per favore!»", "«Mi fa %s%s?»", "«Per me %s%s, grazie.»"]
		var idx: int = (Jobs.orders_done + shift_ui["missed"] + shift_ui["wrong"]) % 3
		var line: String = phrases[idx] % [art, item]
		shift_ui["order_lbl"].text = "Cliente: " + line.replace("«un", "«Un").replace("«una", "«Una")
	else:
		shift_ui["order_lbl"].text = "In attesa del prossimo cliente…"

func close_shift() -> void:
	if modal_kind == "shift":
		close_modal()
	shift_ui = {}
	life_ui.cashier = {}
	if main and main.player:
		if Jobs.cur_job == "barista":
			main.player.teleport(Vector3(5.0, Town.CURB, -47.5), PI)
		elif Jobs.cur_job == "cassiere":
			main.player.teleport(Vector3(16.5, Town.CURB, 5.4), PI)

# =====================================================================  SONNO
func open_sleep_panel() -> void:
	open_modal("sleep", "Letto", _fill_sleep, 620)

func _fill_sleep(v: VBoxContainer) -> void:
	var maxh := float(Data.economy["sleep"]["max_hours"])
	v.add_child(UIKit.label("Ore %s · Sonno %d%% · Energia %d%%" % [GameTime.clock_text(), int(Needs.sonno), int(Needs.energy)], 20, UIKit.MUTED))
	var shift_start: String = Data.economy["job_barista"]["shift"]["start"]
	var wake := Data.min_to_hhmm(Data.hhmm_to_min(shift_start) - 30)
	var opts := [["Dormi fino alle %s (sveglia per il turno)" % wake, Game.hours_until(wake)], ["Dormi fino alle 07:00", Game.hours_until("07:00")], ["Dormi 8 ore", 8.0], ["Riposa 1 ora", 1.0]]
	for o in opts:
		var h: float = o[1]
		var b := UIKit.button("Dormi", func(): do_sleep(h), true, 50)
		var sub := "%.1f ore" % h
		if h > maxh:
			b.disabled = true
			sub += " · troppe (max %d): è ancora presto" % int(maxh)
		_row(v, o[0], b, sub)

func do_sleep(h: float) -> void:
	close_modal()
	if Jobs.in_shift:
		return
	fade(func(): Game.sleep_hours(h, true))

# =====================================================================  BOLLETTE / BUS
func open_bills_panel() -> void:
	open_modal("bills", "Bacheca · Prossime spese", _fill_bills, 660)

func _fill_bills(v: VBoxContainer) -> void:
	var r: Dictionary = Data.economy["rent"]
	_row(v, "Affitto: € %s" % Data.euro(int(r["amount_cents"])), null, "%s · prossima scadenza: giorno %d (%s), tra %d giorni" % [r["room_name"], Economy.next_rent_due_day(), GameTime.weekday_name(Economy.next_rent_due_day()), Economy.days_to_next_rent()])
	for b in Data.economy["recurring_bills"]:
		_row(v, "%s: € %s" % [b["name"], Data.euro(int(b["amount_cents"]))], null, "ogni %d giorni, il %s" % [int(b["period_days"]), b["due_weekday"]])
	if Economy.pending_bills.is_empty():
		v.add_child(UIKit.label("Nessuna bolletta arretrata.", 20, UIKit.GREEN))
	for i in Economy.pending_bills.size():
		var pb: Dictionary = Economy.pending_bills[i]
		var btn := UIKit.button("Paga € " + Data.euro(int(pb["amount"])), func(): _pay_pending(i), true, 50)
		btn.disabled = not Economy.can_afford(int(pb["amount"]))
		_row(v, "Da pagare: " + pb["desc"], btn, "scaduta il giorno %d" % int(pb["due_day"]))

func _pay_pending(i: int) -> void:
	if not Economy.pay_pending(i):
		show_toast("Non hai abbastanza soldi.", "warn")
	if modal_kind == "bills":
		open_bills_panel()
	elif modal_kind == "phone":
		_render_phone()

func next_bus_min() -> int:
	var bus: Dictionary = Data.balance["bus"]
	var first := Data.hhmm_to_min(bus["first"])
	var last := Data.hhmm_to_min(bus["last"])
	var every := int(bus["every_min"])
	var m := GameTime.minute_of_day()
	var t := first
	while t <= last:
		if t >= m:
			return t
		t += every
	return first + 1440

var bus_stop_id := "fontana"
func open_bus_panel(stop: String = "fontana") -> void:
	bus_stop_id = stop
	var nm := "Piazza della Fontana" if stop == "fontana" else "Via Roma Est"
	open_modal("bus", "Fermata · Linea 3, " + nm, _fill_bus, 640)

func _bus_other() -> Dictionary:
	for s in Data.life["bus_v03"]["stops"]:
		if s["id"] != bus_stop_id:
			return s
	return {}

func _fill_bus(v: VBoxContainer) -> void:
	var bus: Dictionary = Data.balance["bus"]
	var tb: Dictionary = Data.life["transport"]["bus"]
	var nb := next_bus_min()
	var other := _bus_other()
	var ride := int(Data.life["bus_v03"]["ride_minutes"])
	v.add_child(UIKit.label("Corse ogni %d minuti dalle %s alle %s. Biglietto € %s, abbonamento € %s per 28 giorni." % [int(bus["every_min"]), bus["first"], bus["last"], Data.euro(int(tb["ticket_cents"])), Data.euro(int(tb["monthly_pass_cents"]))], 20, Color.WHITE, true))
	v.add_child(UIKit.label("Prossimo passaggio: %s%s" % [Data.min_to_hhmm(nb), " (domani)" if nb >= 1440 else ""], 22, UIKit.CORAL))
	if Life.bus_has_pass():
		v.add_child(UIKit.label("Abbonamento attivo fino al giorno %d." % Life.bus_pass_until, 17, UIKit.GREEN))
	var wait_bus: int = nb - GameTime.minute_of_day()
	var rb := UIKit.button("Prendi il bus delle %s per %s (%d min di viaggio)" % [Data.min_to_hhmm(nb), other.get("name", ""), ride], func(): take_bus(), true, 56)
	rb.disabled = nb >= 1440 or (not Life.bus_has_pass() and not Economy.can_afford(int(tb["ticket_cents"])))
	v.add_child(rb)
	if nb >= 1440:
		v.add_child(UIKit.label("Per oggi le corse sono finite.", 17, UIKit.MUTED))
	var wait: int = mini(wait_bus, int(bus["wait_rest_minutes"])) if nb < 1440 else int(bus["wait_rest_minutes"])
	var b := UIKit.button("Siediti sotto la pensilina (%d min)" % max(wait, 5), func():
		close_modal()
		rest_minutes(max(wait, 5), float(bus["wait_energy"]), "Ti sei seduto alla fermata e hai visto passare il bus."), false, 52)
	v.add_child(b)

## Corsa in bus tra le due fermate: aspetta il bus, paga (o abbonamento), viaggia 6 minuti.
func take_bus() -> bool:
	var nb := next_bus_min()
	if nb >= 1440:
		show_toast("Per oggi le corse sono finite.", "warn")
		return false
	var err := Life.pay_bus_ride()
	if err != "":
		show_toast(err, "warn")
		return false
	var other := _bus_other()
	var wait := nb - GameTime.minute_of_day()
	var ride := int(Data.life["bus_v03"]["ride_minutes"])
	close_modal()
	var go := func():
		GameTime.advance(float(wait + ride))
		var p: Array = other["pos"]
		if main and main.player:
			main.player.teleport(Vector3(float(p[0]), Town.CURB + 0.05, float(p[1]) + (0.8 if float(p[1]) > 0 else -0.8)), 0.0 if float(p[1]) < 0 else PI)
		Game.toast("Sei sceso a %s (%s%d min)." % [other["name"], "abbonamento, " if Life.bus_has_pass() else "biglietto € 1,50, ", wait + ride], "ok")
		Game.save_after_purchase()
	if Game.headless_test:
		go.call()
	else:
		fade(go)
	return true

# =====================================================================  DIALOGHI
func show_dialogue(who: String, lines: Array, npc: NPC) -> void:
	if dialogue_panel:
		dialogue_panel.queue_free()
	var p := PanelContainer.new()
	dialogue_panel = p
	var s := root.get_viewport_rect().size
	p.custom_minimum_size = Vector2(min(820.0, s.x - 60), 0)
	root.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(UIKit.label(who, 22, UIKit.CORAL))
	var line_lbl := UIKit.label(lines[0], 24, Color.WHITE, true)
	v.add_child(line_lbl)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(h)
	var idx := [0]
	var next_btn := UIKit.button("Avanti ▸", func(): pass, true, 48)
	var close_fn := func():
		if is_instance_valid(p):
			p.queue_free()
		dialogue_panel = null
	var hire_btn := UIKit.button("Accetto il lavoro", func():
		Jobs.hire()
		show_toast("Assunto al Bar Centrale da Mimmo! Primo turno: %s." % Jobs.next_shift_text(), "ok")
		close_fn.call(), true, 48)
	hire_btn.visible = false
	var update := func():
		line_lbl.text = lines[idx[0]]
		var last: bool = idx[0] >= lines.size() - 1
		next_btn.visible = not last
		hire_btn.visible = last and npc != null and npc.npc_id == "barista_titolare" and not Jobs.employed
	next_btn.pressed.connect(func():
		idx[0] = mini(idx[0] + 1, lines.size() - 1)
		update.call())
	h.add_child(hire_btn)
	h.add_child(next_btn)
	h.add_child(UIKit.button("Chiudi", close_fn, false, 48))
	update.call()
	await get_tree().process_frame
	if is_instance_valid(p):
		p.position = Vector2((s.x - p.size.x) / 2.0, s.y - p.size.y - 30)

# =====================================================================  TELEFONO
func toggle_phone() -> void:
	if modal_kind == "phone":
		close_modal()
		return
	if Jobs.in_shift and Jobs.cur_job != "rider":
		show_toast("Durante il turno il telefono resta in tasca. Usa la pausa (II) se ti serve fermarti.", "info")
		return
	if is_modal_open():
		return
	Sfx.play("phone_open")
	phone_app = ""
	Game.tutorial_event("phone_opened")
	open_modal("phone", "Zero Phone", func(v): _phone_content(v), 600)

func _render_phone() -> void:
	if modal_kind != "phone":
		return
	var title := "Zero Phone" if phone_app == "" else "Zero Phone · " + Data.t("phone." + phone_app)
	open_modal("phone", title, func(v): _phone_content(v), 600)

func phone_open_app(app: String) -> void:
	phone_app = app
	_render_phone()

func _phone_content(v: VBoxContainer) -> void:
	if phone_app == "":
		v.add_child(UIKit.label("%s · %s · € %s" % [GameTime.weekday_name(), GameTime.clock_text(), Data.euro(Economy.money_cents)], 20, UIKit.MUTED))
		if Economy.days_to_next_rent() <= 2:
			v.add_child(UIKit.label("Affitto in scadenza tra %d giorni: € %s" % [Economy.days_to_next_rent(), Data.euro(int(Data.economy["rent"]["amount_cents"]))], 18, Color("#F2A65A")))
		for jid in ["barista", "cassiere", "rider"]:
			if Jobs.st(jid)["employed"]:
				v.add_child(UIKit.label("Prossimo turno (%s): %s" % [Jobs.title(jid), Jobs.next_shift_text(jid)], 18, Color("#F2A65A")))
		if not Life.goal.is_empty():
			v.add_child(UIKit.label("Obiettivo %s: € %s su € %s" % [Life.goal["name"], Data.euro(mini(Life.savings_cents, int(Life.goal["target_cents"]))), Data.euro(int(Life.goal["target_cents"]))], 17, UIKit.MUTED))
		var g := GridContainer.new()
		g.columns = 3
		v.add_child(g)
		for a in ["banca", "lavori", "casa", "auto", "zaino", "agenda", "stato", "menu"]:
			var b := UIKit.button(Data.t("phone." + a), func(): phone_open_app(a), true, 96)
			b.custom_minimum_size.x = 170
			g.add_child(b)
		return
	v.add_child(UIKit.button("◂ Home", func(): phone_open_app(""), false, 46))
	match phone_app:
		"conto": _app_conto(v)
		"banca": life_ui.app_banca(v)
		"lavori": life_ui.app_lavori(v)
		"casa": life_ui.app_casa(v)
		"auto": life_ui.app_auto(v)
		"zaino": _app_zaino(v)
		"agenda": _app_agenda(v)
		"lavoro": _app_lavoro(v)
		"stato": _app_stato(v)
		"menu": _app_menu(v)

func _app_conto(v: VBoxContainer) -> void:
	v.add_child(UIKit.label("Saldo: € " + Data.euro(Economy.money_cents), 30))
	v.add_child(UIKit.label("Prossima spesa: Affitto € %s il giorno %d" % [Data.euro(int(Data.economy["rent"]["amount_cents"])), Economy.next_rent_due_day()], 18, UIKit.MUTED))
	for i in Economy.pending_bills.size():
		var pb: Dictionary = Economy.pending_bills[i]
		var btn := UIKit.button("Paga € " + Data.euro(int(pb["amount"])), func(): _pay_pending(i), true, 46)
		btn.disabled = not Economy.can_afford(int(pb["amount"]))
		_row(v, "Arretrato: " + pb["desc"], btn)
	v.add_child(UIKit.label("Storico movimenti", 20, UIKit.CORAL))
	if Economy.history.is_empty():
		v.add_child(UIKit.label(Data.t("phone.hist_empty"), 18, UIKit.MUTED))
	var hist := Economy.history.duplicate()
	hist.reverse()
	for t in hist.slice(0, 40):
		var amt := int(t["amount"])
		var l := UIKit.label(("+" if amt > 0 else "−") + "€ " + Data.euro(absi(amt)), 20, UIKit.GREEN if amt > 0 else UIKit.RED)
		l.custom_minimum_size.x = 130
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var h := HBoxContainer.new()
		var d := UIKit.label("G%d %s · %s" % [int(t["day"]), t["time"], t["desc"]], 17, Color.WHITE, true)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(d)
		h.add_child(l)
		v.add_child(h)

func _app_zaino(v: VBoxContainer) -> void:
	v.add_child(UIKit.label("%d porzioni · Tocca per usare (i cibi da cucinare si usano a casa)" % Inventory.total_items(), 18, UIKit.MUTED, true))
	var at_home := false
	if main and main.player:
		var p: Vector3 = main.player.global_position
		at_home = p.x > -55.0 and p.x < -47.0 and p.z > -29.0 and p.z < -20.0
	_fill_food(v, at_home)

func _app_agenda(v: VBoxContainer) -> void:
	v.add_child(UIKit.label("Giorno %d · %s · %s" % [GameTime.day(), GameTime.weekday_name(), GameTime.clock_text()], 26))
	var e: Dictionary = Data.economy
	for i in range(0, 7):
		var d := GameTime.day() + i
		var items := []
		if Jobs.employed and Jobs.is_workday(d):
			items.append("turno %s–%s" % [e["job_barista"]["shift"]["start"], e["job_barista"]["shift"]["end"]])
		if d == Economy.next_rent_due_day() or (i == 0 and Economy.rent_period_of_day(d) >= 0 and (d - int(e["rent"]["first_due_day"])) % int(e["rent"]["period_days"]) == 0):
			items.append("affitto € %s" % Data.euro(int(e["rent"]["amount_cents"])))
		if GameTime.weekday_code(d) in e["minimarket"]["hours"]["closed_days"]:
			items.append("Market chiuso")
		if GameTime.weekday_code(d) in e["bar"]["hours"]["closed_days"]:
			items.append("Bar chiuso")
		_row(v, "%s %d" % [GameTime.weekday_name(d), d], null, ", ".join(items) if not items.is_empty() else "—")
	v.add_child(UIKit.label("Orari: Market %s–%s (dom. chiuso) · Bar %s–%s (lun. chiuso)" % [e["minimarket"]["hours"]["open"], e["minimarket"]["hours"]["close"], e["bar"]["hours"]["open"], e["bar"]["hours"]["close"]], 17, UIKit.MUTED, true))

func _app_lavoro(v: VBoxContainer) -> void:
	var j: Dictionary = Data.economy["job_barista"]
	if not Jobs.employed:
		v.add_child(UIKit.label(Data.t("phone.no_job"), 20, UIKit.MUTED, true))
		v.add_child(UIKit.label("Offerta: barista part-time, turni %s–%s (%s), € %s netti a turno." % [j["shift"]["start"], j["shift"]["end"], ", ".join(j["workdays"]), Data.euro(int(j["pay_cents_per_shift"]))], 18, Color.WHITE, true))
		return
	v.add_child(UIKit.label("Barista · Bar Centrale da Mimmo", 24))
	v.add_child(UIKit.label("Prossimo turno: " + Jobs.next_shift_text(), 20, UIKit.CORAL))
	v.add_child(UIKit.label("Paga: € %s a turno (pagata a fine turno). Requisiti: energia ≥ %d all'inizio, almeno %d ordini serviti. Ritardo oltre %d min: −€ %s; oltre %d min il turno è perso." % [Data.euro(int(j["pay_cents_per_shift"])), int(j["requirements"]["energy_min_at_start"]), int(j["requirements"]["orders_min_completed"]), int(j["late_policy"]["late_after_min"]), Data.euro(int(j["late_policy"]["pay_cut_cents"])), int(j["late_policy"]["absent_after_min"])], 18, Color.WHITE, true))
	v.add_child(UIKit.label("Turni pagati: %d" % Jobs.shifts_completed, 18, UIKit.MUTED))

func _app_stato(v: VBoxContainer) -> void:
	v.add_child(UIKit.label("%s, %d anni · %s" % [Data.places["protagonist"], int(Data.places["age"]), Data.economy["rent"]["room_name"]], 20, UIKit.MUTED, true))
	for k in [["Fame (sazietà)", Needs.hunger, Color("#F2A65A")], ["Energia", Needs.energy, Color("#5BC17A")], ["Sonno (riposo)", Needs.sonno, Color("#7BA7E0")]]:
		v.add_child(UIKit.label("%s: %d%%" % [k[0], int(k[1])], 20))
		v.add_child(UIKit.bar(k[1], k[2]))
	var tips := []
	if Needs.hunger < 25: tips.append("Hai fame: mangia qualcosa.")
	if Needs.energy < 20: tips.append("Energia bassa: niente turno sotto 20.")
	if Needs.sonno < 20: tips.append("Hai sonno: dormi a casa.")
	if Needs.energy < float(Data.economy["needs_thresholds"]["energy_min_to_run"]): tips.append("Troppo stanco per correre.")
	v.add_child(UIKit.label("\n".join(tips) if not tips.is_empty() else "Stai bene.", 18, UIKit.MUTED, true))

func _app_menu(v: VBoxContainer) -> void:
	v.add_child(UIKit.button("Salva partita", func():
		show_toast(Data.t("save.saving"), "info")
		if SaveSystem.save_game(): show_toast(Data.t("save.saved"), "ok")
		else: show_toast(Data.t("save.error"), "warn"), true))
	v.add_child(UIKit.button("Pausa", func():
		close_modal()
		open_pause()))
	v.add_child(UIKit.button("Suoni: " + ("disattivati" if Sfx.muted else "attivi"), func():
		Sfx.muted = not Sfx.muted
		_render_phone()))
	v.add_child(UIKit.button("Riprendi tutorial" if Game.tutorial_done else "Salta tutorial", func():
		if Game.tutorial_done:
			Game.tutorial_done = false
			Game.tutorial_step = 0
			Game.tutorial_changed.emit(0)
		else:
			Game.skip_tutorial()
		_render_phone()))
	v.add_child(UIKit.button("Crediti e licenze", func(): show_credits()))
	v.add_child(UIKit.label(Game.privacy_text(), 16, UIKit.MUTED, true))

# =====================================================================  PAUSA / MENU / CREDITI
func open_pause() -> void:
	if not Game.playing or modal_kind == "pause" or modal_kind == "shift_pause":
		return
	if modal_kind == "shift":
		# durante il turno la pausa ferma il tempo senza chiudere il minigioco
		get_tree().paused = true
		modal_kind = "shift_pause"
		_pause_overlay()
		return
	get_tree().paused = true
	open_modal("pause", Data.t("pause.title"), func(v):
		v.add_child(UIKit.button("Riprendi", func(): close_modal(), true))
		v.add_child(UIKit.button("Salva", func():
			if SaveSystem.save_game(): show_toast(Data.t("save.saved"), "ok")
			else: show_toast(Data.t("save.error"), "warn")))
		v.add_child(UIKit.button("Menu principale", func(): _confirm(Data.t("pause.quit_confirm"), _quit_to_menu, "Esci"))), 480, false)

func _quit_to_menu() -> void:
	Game.stop()
	get_tree().paused = false
	show_main_menu()

func _pause_overlay() -> void:
	var ov := PanelContainer.new()
	ov.name = "PauseOverlay"
	var v := VBoxContainer.new()
	ov.add_child(v)
	v.add_child(UIKit.label("Pausa (turno in corso)", 26))
	v.add_child(UIKit.button("Riprendi", func():
		get_tree().paused = false
		modal_kind = "shift"
		ov.queue_free(), true))
	root.add_child(ov)
	var s := root.get_viewport_rect().size
	ov.position = s / 2.0 - Vector2(160, 60)

func _confirm(text: String, yes: Callable, yes_label: String = "Sì") -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.sb(Color(0.08, 0.08, 0.08, 0.97), 16, 18))
	root.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var l := UIKit.label(text, 22, Color.WHITE, true)
	l.custom_minimum_size = Vector2(440, 0)
	v.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(h)
	h.add_child(UIKit.button("Annulla", func(): p.queue_free()))
	h.add_child(UIKit.button(yes_label, func():
		p.queue_free()
		yes.call(), true))
	await get_tree().process_frame
	if is_instance_valid(p):
		p.position = (root.get_viewport_rect().size - p.size) / 2.0

func show_main_menu() -> void:
	Game.stop()
	if dialogue_panel:
		dialogue_panel.queue_free()
		dialogue_panel = null
	var st := SaveSystem.status()
	open_modal("menu", "REAL LIFE: ZERO", func(v): _fill_menu(v, st), 560, false)

func _fill_menu(v: VBoxContainer, st: Dictionary) -> void:
	v.add_child(UIKit.label("Una nuova vita a San Vito al Colle", 20, UIKit.MUTED))
	if st["status"] == "ok":
		v.add_child(UIKit.button("Continua", func():
			close_modal()
			if not Game.continue_game():
				show_main_menu(), true, 64))
		v.add_child(UIKit.label(Data.t("save.continue_sub", {"giorno": st["day"], "ora": st["clock"], "saldo": Data.euro(int(st["money"]))}), 18, UIKit.MUTED))
		v.add_child(UIKit.button("Nuova partita", func(): _confirm(Data.t("save.confirm_new"), _start_new, "Sì, ricomincia")))
	elif st["status"] == "corrupt":
		v.add_child(UIKit.label(Data.t("save.corrupt"), 20, Color("#F2A65A"), true))
		var bs := SaveSystem.backup_status()
		var bb := UIKit.button("Prova il backup", func():
			close_modal()
			if not Game.continue_game(true):
				show_toast(Data.t("save.backup_bad"), "warn")
				show_main_menu(), true, 60)
		bb.disabled = bs["status"] != "ok"
		v.add_child(bb)
		v.add_child(UIKit.button("Nuova partita", func():
			close_modal()
			Game.new_game(), false, 56))
	else:
		v.add_child(UIKit.label(Data.t("save.missing"), 18, UIKit.MUTED, true))
		v.add_child(UIKit.button("Nuova partita", func():
			close_modal()
			Game.new_game(), true, 64))
	v.add_child(UIKit.button("Crediti e licenze", func(): show_credits()))
	v.add_child(UIKit.label("%s (%s) · Godot %s · %s" % [Data.t("build_label"), Game.VERSION, Engine.get_version_info()["string"], Data.t("rating")], 15, UIKit.MUTED))
	v.add_child(UIKit.label(Game.privacy_text(), 15, UIKit.MUTED, true))

func _start_new() -> void:
	close_modal()
	Game.new_game()

func show_credits() -> void:
	var back := modal_kind
	var was_playing := Game.playing
	open_modal("credits", "Crediti e licenze", func(v):
		var f := FileAccess.open("res://data/credits.txt", FileAccess.READ)
		var txt := f.get_as_text() if f else "Vedi docs/LICENSES.md"
		var l := UIKit.label(txt, 15, Color.WHITE, true)
		v.add_child(l)
		v.add_child(UIKit.label("— Godot Engine —\n" + Engine.get_license_text(), 13, UIKit.MUTED, true))
		var info := Engine.get_copyright_info()
		var parts := ""
		for c in info:
			parts += c["name"] + "; "
		v.add_child(UIKit.label("Componenti terzi del motore: " + parts, 12, UIKit.MUTED, true))
		v.add_child(UIKit.button("Indietro", func():
			if was_playing and back == "phone":
				close_modal()
				toggle_phone()
				phone_open_app("menu")
			elif not was_playing:
				show_main_menu()
			else:
				close_modal())), 760, false)

func show_evicted() -> void:
	# v0.3: niente game over (Guard): avviso chiaro e si continua a giocare.
	if Game.headless_test:
		return
	open_modal("evicted", "Affitto: piano di rientro", func(v):
		v.add_child(UIKit.label("Due affitti non pagati. Non perdi la partita: l'arretrato resta da saldare (app Banca o bacheca di casa) e la tua affidabilità è scesa. Lavorando qualche turno torni in pari.", 22, Color.WHITE, true))
		v.add_child(UIKit.label("Consiglio: tieni da parte i soldi dell'affitto nel Salvadanaio.", 18, UIKit.MUTED, true))
		v.add_child(UIKit.button("Ho capito", func(): close_modal(), true, 56)), 620, true)

func queue_day_summary(info: Dictionary) -> void:
	if Game.headless_test:
		return
	show_toast("Riepilogo giorno %d: entrate € %s · uscite € %s · saldo € %s · affitto tra %d giorni." % [int(info["day"]), Data.euro(int(info["income"])), Data.euro(int(info["expense"])), Data.euro(int(info["balance"])), int(info["rent_in"])], "info")
