class_name TownV03
extends RefCounted
## v0.3: nuovi luoghi (nomi di Spark) e dettagli "Italia vera". Vetrine con interazione:
## gli interni di questi negozi non sono esplorabili (si entra con il pannello, come allo sportello).

static var t: Town
static var clock_hands: Array = []

static func m(k: String) -> StandardMaterial3D:
	return Build.mat(k)

static func build(town: Town) -> void:
	t = town
	_mats()
	_bank(31.0, 44.0)
	_boutique(45.0, 58.0)
	_gym(59.0, 72.0)
	_trattoria(29.0, 42.0)
	_fuel(43.0, 56.0)
	_dealer(57.0, 84.0)
	_blue_parking()
	_bus_stop_east()
	_bell_tower(Vector3(-9.5, 0, -50.0))
	_details()

static func _mats() -> void:
	Build.flat("shop_glow", Color(0.36, 0.31, 0.26), 0.8, 0.0, Color(1.0, 0.82, 0.58), 0.22)
	Build.flat("shop_shelf", Color(0.16, 0.14, 0.12), 0.7)
	Build.flat("sign_navy", Color("#1F3354"), 0.5)
	Build.flat("sign_cream", Color("#F1E8D4"), 0.6)
	Build.flat("sign_coral", Color("#D9583E"), 0.55)
	Build.flat("sign_bordeaux", Color("#6E2430"), 0.6)
	Build.flat("awning_a", Color("#B3423A"), 0.85)
	Build.flat("awning_b", Color("#EFE6D2"), 0.85)
	Build.flat("awning_g", Color("#2F5A44"), 0.85)
	Build.flat("awning_p", Color("#C98F95"), 0.85)
	Build.flat("plastic_white", Color("#F4F4F0"), 0.45)
	Build.flat("terracotta", Color("#A65A3A"), 0.9)
	Build.flat("geranium", Color("#D8243A"), 0.8)
	Build.flat("geranium_p", Color("#E46AA0"), 0.8)
	Build.flat("leaf", Color("#3F6B2E"), 0.9)
	Build.flat("blue_line", Color("#2D5FB3"), 0.7)
	Build.flat("cross_green", Color("#1FAF4A"), 0.4, 0.0, Color("#1FFF5A"), 1.4)
	Build.flat("atm_screen", Color("#1E4C7A"), 0.2, 0.0, Color("#5EA8FF"), 0.8)
	Build.flat("cast_iron", Color("#23342A"), 0.5, 0.5)
	Build.flat("clock_face", Color("#F2EEE2"), 0.6)
	Build.flat("ape_blue", Color("#8FA9B8"), 0.5)
	Build.flat("faded_sign", Color("#B9A890"), 0.95)
	Build.flat("cable", Color(0.08, 0.08, 0.08), 0.8)

static func _rot(nz: float) -> float:
	return 0.0 if nz > 0.0 else PI

## Edificio con vetrina illuminata, insegna e tenda da sole. fz = facciata, nz = verso la strada.
static func _shop(x0: float, x1: float, fz: float, nz: float, floors: int, plaster: String, sign_mat: String, sign_text: String, sign_col: Color, awn: Array, sub: String = "") -> Dictionary:
	var depth := 12.0
	var zb := fz - nz * depth
	var h := Town.GROUND_H + (floors - 1) * Town.FLOOR_H
	var cx := (x0 + x1) / 2.0
	var cz := (fz + zb) / 2.0
	Build.box(t, Vector3(cx, h / 2.0, cz), Vector3(x1 - x0, h, depth), m(plaster))
	Build.box(t, Vector3(cx, Town.GROUND_H, cz), Vector3(x1 - x0 + 0.14, 0.14, depth + 0.14), m("stone"), false)
	t.roof(x0, x1, minf(fz, zb), maxf(fz, zb), h, false)
	t.facade_windows("x", x0, x1, fz, nz, 2, floors + 1, true)
	t.facade_windows("x", x0, x1, zb, -nz, 2, floors + 1, false)
	# vetrina: fondo luminoso (finto interno), vetro, montanti e zoccolo
	var ww := x1 - x0 - 2.4
	var wz := fz + nz * 0.04
	Build.box(t, Vector3(cx, Town.CURB + 1.55, wz), Vector3(ww, 2.5, 0.04), m("shop_glow"), false, 0.0, false)
	Build.box(t, Vector3(cx, Town.CURB + 1.55, fz + nz * 0.5), Vector3(ww, 2.5, 0.04), m("glass_shop"), true, 0.0, false)
	# sagome dell'interno (scaffali/banco) davanti al fondo luminoso: dà profondità alla vetrina
	var unit := Build.box_mesh(Vector3(1, 1, 1))
	for hy in [0.95, 1.75]:
		Build.batch_add("shop_shelf", unit, m("shop_shelf"), Transform3D(Basis().scaled(Vector3(ww * 0.86, 0.05, 0.12)), Vector3(cx, Town.CURB + hy, fz + nz * 0.12)), false)
	for k in range(0, 5):
		Build.batch_add("shop_shelf", unit, m("shop_shelf"), Transform3D(Basis().scaled(Vector3(0.06, 1.6, 0.12)), Vector3(cx - ww * 0.43 + ww * 0.86 * k / 4.0, Town.CURB + 1.15, fz + nz * 0.12)), false)
	Build.batch_add("shop_shelf", unit, m("shop_shelf"), Transform3D(Basis().scaled(Vector3(ww * 0.4, 0.9, 0.2)), Vector3(cx + ww * 0.2, Town.CURB + 0.75, fz + nz * 0.16)), false)
	for s in [-1.0, 1.0]:
		Build.box(t, Vector3(cx + s * (ww / 2.0 + 0.05), Town.CURB + 1.55, fz + nz * 0.27), Vector3(0.1, 2.6, 0.55), m("frame"), false)
	Build.box(t, Vector3(cx, Town.CURB + 0.15, fz + nz * 0.27), Vector3(ww, 0.3, 0.55), m("stonebase"), false)
	Build.box(t, Vector3(cx, Town.CURB + 2.85, fz + nz * 0.27), Vector3(ww + 0.2, 0.12, 0.6), m("frame"), false)
	for k in range(1, 4):
		Build.box(t, Vector3(x0 + 1.2 + ww * k / 4.0, Town.CURB + 1.55, fz + nz * 0.52), Vector3(0.06, 2.5, 0.06), m("iron"), false)
	# insegna
	Build.box(t, Vector3(cx, Town.CURB + 3.25, fz + nz * 0.08), Vector3(ww * 0.8, 0.6, 0.1), m(sign_mat), false)
	Build.label3d(t, Vector3(cx, Town.CURB + 3.25, fz + nz * 0.14), sign_text, 64, sign_col, _rot(nz))
	if sub != "":
		Build.label3d(t, Vector3(cx + ww * 0.32, Town.CURB + 0.75, fz + nz * 0.53), sub, 22, Color(0.12, 0.12, 0.12), _rot(nz))
	# tenda da sole a strisce
	if not awn.is_empty():
		var n := Node3D.new()
		n.position = Vector3(cx, Town.CURB + 2.95, fz + nz * 0.1)
		n.rotation.y = _rot(nz)
		n.rotation.x = 0.0
		t.add_child(n)
		var strips := 10
		for i in strips:
			var b := Build.box(n, Vector3(-ww / 2.0 + ww * (i + 0.5) / strips, -0.35, 0.75), Vector3(ww / strips, 0.04, 1.6), m(awn[i % 2]), false)
			b.rotation.x = 0.42
	return {"cx": cx, "door": Vector3(cx, Town.CURB + 1.0, fz + nz * 1.2)}

static func _ui():
	return t.world_ui.life_ui if t.world_ui and "life_ui" in t.world_ui else null

static func _bank(x0: float, x1: float) -> void:
	var s := _shop(x0, x1, -7.0, 1.0, 3, "plaster_crema", "sign_navy", "Banca Popolare del Colle", Color("#F1E8D4"), [], "Sportello 08:30–13:30\nlun–ven")
	t.interactables["bank"] = Interactable.make(t, s["door"] + Vector3(-2.0, 0, 0), "bank", func(): return "Banca Popolare del Colle · Sportello", func(): _ui().open_bank(), 2.2)
	# bancomat incassato a lato
	var ax := x1 - 0.7
	Build.box(t, Vector3(ax, Town.CURB + 1.25, -6.95), Vector3(0.9, 1.6, 0.12), m("metal_grey"), false)
	Build.box(t, Vector3(ax, Town.CURB + 1.55, -6.88), Vector3(0.5, 0.35, 0.02), m("atm_screen"), false)
	Build.label3d(t, Vector3(ax, Town.CURB + 2.2, -6.87), "BANCOMAT", 26, Color.WHITE)
	t.interactables["atm"] = Interactable.make(t, Vector3(ax, Town.CURB + 1.0, -6.0), "atm", func(): return "Bancomat · Saldo e risparmi", func(): _ui().open_bank(), 1.4)

static func _boutique(x0: float, x1: float) -> void:
	var s := _shop(x0, x1, -7.0, 1.0, 2, "plaster_rosa", "awning_g", "Boutique Marisa", Color("#F1E8D4"), ["awning_p", "awning_b"], "Abbigliamento\n09:30–19:30")
	# due manichini in vetrina (silhouette semplici)
	for k in [-2.5, 2.5]:
		var p := Vector3(float(s["cx"]) + k, Town.CURB, -6.75)
		Build.cylinder(t, p + Vector3(0, 0.45, 0), 0.04, 0.9, m("iron"), false, 6)
		Build.box(t, p + Vector3(0, 1.25, 0), Vector3(0.42, 0.65, 0.22), m("awning_p" if k < 0 else "sign_navy"), false)
		Build.box(t, p + Vector3(0, 0.75, 0), Vector3(0.36, 0.45, 0.2), m("iron"), false)
	t.interactables["boutique"] = Interactable.make(t, s["door"], "boutique", func(): return "Boutique Marisa · Vestiti", func(): _ui().open_boutique(), 2.4)

static func _gym(x0: float, x1: float) -> void:
	var s := _shop(x0, x1, -7.0, 1.0, 2, "plaster_giallo", "sign_coral", "Palestra Fit Colle", Color.WHITE, [], "07:00–22:00\ndom. chiuso")
	for k in [-3.0, 0.0, 3.0]:   # tapis roulant in vetrina
		var p := Vector3(float(s["cx"]) + k, Town.CURB, -6.7)
		Build.box(t, p + Vector3(0, 0.15, 0), Vector3(0.7, 0.18, 0.3), m("iron"), false)
		Build.box(t, p + Vector3(0, 0.75, -0.1), Vector3(0.6, 0.06, 0.06), m("metal_grey"), false)
	t.interactables["gym"] = Interactable.make(t, s["door"], "gym", func(): return "Palestra Fit Colle · Allenati", func(): _ui().open_gym(), 2.4)

static func _trattoria(x0: float, x1: float) -> void:
	var s := _shop(x0, x1, 7.0, -1.0, 3, "plaster_ocra", "sign_bordeaux", "Trattoria Da Rosa", Color("#F1E8D4"), ["awning_a", "awning_b"], "Pranzo 12–14:30\nCena 19–22 · lun. chiuso")
	# dehors: tavolini e sedie di plastica bianca sul marciapiede
	for tx in [float(s["cx"]) - 3.5, float(s["cx"]) + 3.5]:
		var c := Vector3(tx, Town.CURB, 5.6)
		Build.cylinder(t, c + Vector3(0, 0.36, 0), 0.04, 0.72, m("plastic_white"), false, 6)
		Build.cylinder(t, c + Vector3(0, 0.73, 0), 0.42, 0.03, m("plastic_white"), false, 14)
		for a in [0.0, PI]:
			var q := c + Vector3(cos(a) * 0.75, 0, 0)
			Build.box(t, q + Vector3(0, 0.42, 0), Vector3(0.42, 0.05, 0.42), m("plastic_white"), false)
			Build.box(t, q + Vector3(cos(a) * 0.2, 0.68, 0), Vector3(0.04, 0.5, 0.42), m("plastic_white"), false)
			for lx in [-0.18, 0.18]:
				Build.box(t, q + Vector3(lx, 0.2, 0), Vector3(0.04, 0.4, 0.4), m("plastic_white"), false)
		Build.collider(t, c + Vector3(0, 0.45, 0), Vector3(2.0, 0.9, 0.9))
	# lavagnetta del menu
	var bp := Vector3(float(s["cx"]), Town.CURB, 5.0)
	Build.box(t, bp + Vector3(0, 0.55, 0), Vector3(0.6, 0.9, 0.05), m("iron"), false, 0.0, false)
	Build.label3d(t, bp + Vector3(0, 0.6, -0.04), "Menù pranzo\n€ 13\nprimo · secondo\nacqua", 20, Color("#F1E8D4"), PI)
	t.interactables["trattoria"] = Interactable.make(t, s["door"], "trattoria", func(): return "Trattoria Da Rosa · Mangia", func(): _ui().open_trattoria(), 2.4)

static func _fuel(x0: float, x1: float) -> void:
	var cx := (x0 + x1) / 2.0
	Build.box(t, Vector3(cx, 0.015, 13.0), Vector3(x1 - x0, 0.03, 12.0), m("asphalt"), false)
	# pensilina su 4 pilastri
	Build.box(t, Vector3(cx, 4.7, 11.5), Vector3(10.0, 0.5, 6.5), m("barrier_w"), false)
	Build.box(t, Vector3(cx, 4.75, 8.24), Vector3(10.0, 0.42, 0.04), m("sign_green"), false)
	Build.label3d(t, Vector3(cx, 4.75, 8.21), "DISTRIBUTORE DEL COLLE", 52, Color.WHITE, PI)
	for px in [-4.2, 4.2]:
		for pz in [9.2, 13.8]:
			Build.box(t, Vector3(cx + px, 2.35, pz), Vector3(0.3, 4.7, 0.3), m("barrier_w"))
	for px in [-2.0, 2.0]:
		var p := Vector3(cx + px, 0, 11.5)
		Build.box(t, p + Vector3(0, 0.12, 0), Vector3(1.2, 0.24, 2.6), m("stone"), false)
		Build.box(t, p + Vector3(0, 0.95, 0), Vector3(0.7, 1.5, 0.5), m("sign_green"))
		Build.box(t, p + Vector3(0, 1.35, -0.26), Vector3(0.45, 0.3, 0.02), m("atm_screen"), false)
		t.interactables["pump_%d" % int(px)] = Interactable.make(t, p + Vector3(0, 1.0, -1.6), "pump", func(): return "Pompa di benzina · Rifornimento", func(): _ui().open_fuel(), 3.6)
	# chiosco e totem prezzi
	Build.box(t, Vector3(cx, 1.4, 17.5), Vector3(5.0, 2.8, 3.0), m("plaster_crema"))
	Build.box(t, Vector3(cx, 1.3, 15.98), Vector3(2.4, 1.8, 0.04), m("shop_glow"), false)
	var tp := Vector3(x1 - 1.2, 0, 8.3)
	Build.box(t, tp + Vector3(0, 1.6, 0), Vector3(0.9, 3.2, 0.25), m("sign_green"))
	Build.label3d(t, tp + Vector3(0, 2.5, -0.14), "BENZINA\n%s" % Data.euro(int(Data.life["cars"]["fuel_price_cents_per_liter"])), 30, Color.WHITE, PI)
	Build.label3d(t, tp + Vector3(0, 1.3, -0.14), "07–21", 30, Color("#F2C230"), PI)

static func _dealer(x0: float, x1: float) -> void:
	var cx := (x0 + x1) / 2.0
	Build.box(t, Vector3(cx, 0.015, 13.0), Vector3(x1 - x0, 0.03, 12.0), m("asphalt"), false)
	var dash := Build.box_mesh(Vector3(1, 1, 1))
	for i in range(6):
		Build.batch_add("road_line", dash, m("line_white"), Transform3D(Basis().scaled(Vector3(0.12, 0.01, 5.0)), Vector3(x0 + 2.0 + i * 3.6, 0.035, 12.0)), false)
	# ufficio prefabbricato
	var op := Vector3(x1 - 4.0, 0, 16.0)
	Build.box(t, op + Vector3(0, 1.5, 0), Vector3(6.0, 3.0, 4.5), m("plaster_crema"))
	Build.box(t, op + Vector3(0, 1.3, -2.27), Vector3(3.2, 1.6, 0.04), m("shop_glow"), false)
	Build.box(t, op + Vector3(0, 3.1, 0), Vector3(6.3, 0.2, 4.8), m("metal_grey"), false)
	# insegna su due pali
	var sp := Vector3(x0 + 5.0, 0, 7.6)
	for k in [-2.4, 2.4]:
		Build.box(t, sp + Vector3(k, 2.0, 0), Vector3(0.12, 4.0, 0.12), m("metal_grey"))
	Build.box(t, sp + Vector3(0, 3.5, 0), Vector3(5.4, 1.0, 0.1), m("sign_navy"), false)
	Build.label3d(t, sp + Vector3(0, 3.62, -0.06), "Autosalone Bertoni", 56, Color.WHITE, PI)
	Build.label3d(t, sp + Vector3(0, 3.25, -0.06), "Usato Garantito · 09–19", 30, Color("#F2C230"), PI)
	# festoni con bandierine
	for i in range(18):
		var fx := x0 + 1.0 + i * 1.5
		Build.box(t, Vector3(fx, 3.4, 8.0), Vector3(0.4, 0.4, 0.02), m(["sign_coral", "sign_yellow", "bin_b", "barrier_w"][i % 4]), false, 0.0, false)
	Build.box(t, Vector3(cx, 3.6, 8.0), Vector3(x1 - x0 - 1.0, 0.02, 0.02), m("cable"), false, 0.0, false)
	# le due auto in vendita (dati di Ledger) + altre usate
	var mods: Array = Data.life["cars"]["models"]
	var spots := [Vector3(x0 + 3.8, 0.03, 12.0), Vector3(x0 + 7.4, 0.03, 12.0)]
	for i in mods.size():
		var md: Dictionary = mods[i]
		var kind := "ginestra" if str(md["id"]).begins_with("utilitaria") else "corallo"
		var node := CarKit.parked(t, kind, spots[i], 0.0, Color(md.get("color", "#C9C2B2")))
		node.set_meta("for_sale", md["id"])
		Build.box(t, spots[i] + Vector3(0, 0.6, -2.6), Vector3(0.05, 1.2, 0.05), m("metal_grey"), false)
		Build.box(t, spots[i] + Vector3(0, 1.25, -2.6), Vector3(1.4, 0.5, 0.04), m("barrier_w"), false)
		Build.label3d(t, spots[i] + Vector3(0, 1.25, -2.63), "%s\n€ %s" % [md["name"].split(" (")[0], Data.euro(int(md["price_cents"])).split(",")[0]], 22, Color(0.1, 0.1, 0.1), PI)
	CarKit.parked(t, "sedan", Vector3(x0 + 11.0, 0.03, 12.0), 0.0, CarKit.PALETTE[1])
	CarKit.parked(t, "suv", Vector3(x0 + 14.6, 0.03, 12.0), 0.0, CarKit.PALETTE[3])
	t.interactables["dealer"] = Interactable.make(t, op + Vector3(0, 1.0, -3.2), "dealer", func(): return "Autosalone Bertoni · Offerte", func(): _ui().open_dealer(), 2.6)
	t.interactables["dealer2"] = Interactable.make(t, Vector3(x0 + 5.6, 1.0, 9.0), "dealer_cars", func(): return "Auto in vendita · Guarda le offerte", func(): _ui().open_dealer(), 2.6)
	t.car_spawn = Vector3(x0 + 18.4, 0.02, 12.0)

static func _blue_parking() -> void:
	var dash := Build.box_mesh(Vector3(1, 1, 1))
	for i in range(0, 9):
		var x := 20.0 + i * 5.0
		Build.batch_add("blue_line", dash, m("blue_line"), Transform3D(Basis().scaled(Vector3(0.12, 0.01, 2.2)), Vector3(x, 0.026, 2.9)), false)
	Build.batch_add("blue_line", dash, m("blue_line"), Transform3D(Basis().scaled(Vector3(40.0, 0.01, 0.12)), Vector3(40.0, 0.026, 1.85)), false)
	# parchimetro
	var p := Vector3(40.5, Town.CURB, 4.5)
	Build.box(t, p + Vector3(0, 0.6, 0), Vector3(0.12, 1.2, 0.12), m("metal_grey"))
	Build.box(t, p + Vector3(0, 1.35, 0), Vector3(0.35, 0.5, 0.25), m("bin_b"), false)
	Build.label3d(t, p + Vector3(0, 1.45, -0.13), "P\n€ 1,20/h\n8–20", 18, Color.WHITE, PI)
	t.interactables["meter"] = Interactable.make(t, p + Vector3(0, 1.0, -0.4), "meter", func(): return "Parchimetro · Ticket 2 ore (€ 2,40)", func():
		var r := Life.buy_parking_ticket(2)
		Game.toast("Ticket pagato: 2 ore di sosta sulle strisce blu." if r == "" else r, "ok" if r == "" else "warn"), 1.4)
	_sign_disc(Vector3(19.0, Town.CURB, 4.4), "P", "bin_b", PI)

static func _bus_stop_east() -> void:
	var b := Vector3(64.0, Town.CURB, 6.2)
	for x in [-1.8, 1.8]:
		Build.box(t, b + Vector3(x, 1.2, 0.4), Vector3(0.1, 2.4, 0.1), m("shutter"))
	Build.box(t, b + Vector3(0, 2.45, 0), Vector3(4.0, 0.08, 1.6), m("shutter"), false)
	Build.box(t, b + Vector3(0, 1.3, 0.65), Vector3(3.8, 1.8, 0.04), m("glass_shop"), true)
	Build.box(t, b + Vector3(0, 0.45, 0.35), Vector3(2.6, 0.06, 0.4), m("metal_grey"), false)
	var pole := b + Vector3(-2.5, 0, -0.6)
	Build.box(t, pole + Vector3(0, 1.4, 0), Vector3(0.08, 2.8, 0.08), m("metal_grey"))
	Build.box(t, pole + Vector3(0, 2.6, 0), Vector3(0.6, 0.6, 0.04), m("sign_yellow"), false)
	Build.label3d(t, pole + Vector3(0, 2.6, -0.03), "BUS\n3", 40, Color(0.1, 0.1, 0.1), PI)
	Build.label3d(t, b + Vector3(0, 2.3, -0.82), "Linea 3 · Via Roma Est", 34, Color("#F3E9D2"), PI)
	t.interactables["bus_east"] = Interactable.make(t, b + Vector3(0, 1.0, -0.3), "bus_stop_east", func(): return "Fermata Linea 3 · Via Roma Est", func(): t.world_ui.open_bus_panel("roma_est"), 2.2)

static func _bell_tower(p: Vector3) -> void:
	var H := 24.0
	p.y = 0.0
	Build.box(t, p + Vector3(0, H / 2.0, 0), Vector3(4.6, H, 4.6), m("plaster_crema"))
	Build.box(t, p + Vector3(0, 0.5, 0), Vector3(4.8, 1.0, 4.8), m("stonebase"), false)
	Build.box(t, p + Vector3(0, H + 0.3, 0), Vector3(5.2, 0.6, 5.2), m("stone"), false)
	for k in [-1.0, 1.0]:      # cella campanaria (aperture scure)
		Build.box(t, p + Vector3(0, H - 2.0, k * 2.31), Vector3(2.4, 2.6, 0.04), m("glass_dark"), false)
		Build.box(t, p + Vector3(k * 2.31, H - 2.0, 0), Vector3(0.04, 2.6, 2.4), m("glass_dark"), false)
	var pm := MeshInstance3D.new()
	var pr := PrismMesh.new()
	pr.size = Vector3(5.0, 3.2, 5.0)
	pm.mesh = pr
	pm.material_override = m("roof")
	pm.position = p + Vector3(0, H + 2.2, 0)
	t.add_child(pm)
	# quadrante dell'orologio sul lato della piazza (sud), lancette aggiornate dall'ora di gioco
	var face := p + Vector3(0, H - 5.5, 2.32)
	var fm := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.1; cyl.bottom_radius = 1.1; cyl.height = 0.06; cyl.radial_segments = 24
	fm.mesh = cyl
	fm.material_override = m("clock_face")
	fm.position = face
	fm.rotation.x = PI / 2.0
	t.add_child(fm)
	clock_hands.clear()
	for spec in [[0.6, 0.09], [0.95, 0.06]]:
		var pivot := Node3D.new()
		pivot.position = face + Vector3(0, 0, 0.06)
		t.add_child(pivot)
		Build.box(pivot, Vector3(0, spec[0] / 2.0, 0), Vector3(spec[1], spec[0], 0.02), m("iron"), false, 0.0, false)
		clock_hands.append(pivot)
	GameTime.minute_passed.connect(func(_d): _update_clock())
	_update_clock()

static func _update_clock() -> void:
	if clock_hands.size() < 2 or not is_instance_valid(clock_hands[0]):
		return
	var mm := GameTime.minute_of_day()
	(clock_hands[0] as Node3D).rotation.z = -TAU * float(mm % 720) / 720.0
	(clock_hands[1] as Node3D).rotation.z = -TAU * float(mm % 60) / 60.0

static func _sign_disc(p: Vector3, text: String, mk: String, rot: float) -> void:
	Build.box(t, p + Vector3(0, 1.1, 0), Vector3(0.06, 2.2, 0.06), m("metal_grey"))
	var n := Node3D.new()
	n.position = p + Vector3(0, 2.25, 0)
	n.rotation.y = rot
	t.add_child(n)
	Build.box(n, Vector3.ZERO, Vector3(0.55, 0.55, 0.03), m(mk), false)
	Build.label3d(n, Vector3(0, 0, 0.02), text, 48, Color.WHITE)

static func _limit_sign(p: Vector3, rot: float) -> void:
	Build.box(t, p + Vector3(0, 1.1, 0), Vector3(0.06, 2.2, 0.06), m("metal_grey"))
	var n := Node3D.new()
	n.position = p + Vector3(0, 2.3, 0)
	n.rotation.y = rot
	t.add_child(n)
	var c := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.32; cm.bottom_radius = 0.32; cm.height = 0.03; cm.radial_segments = 20
	c.mesh = cm
	c.material_override = m("barrier_r")
	c.rotation.x = PI / 2.0
	n.add_child(c)
	var c2 := MeshInstance3D.new()
	var cm2 := CylinderMesh.new()
	cm2.top_radius = 0.25; cm2.bottom_radius = 0.25; cm2.height = 0.035; cm2.radial_segments = 20
	c2.mesh = cm2
	c2.material_override = m("barrier_w")
	c2.rotation.x = PI / 2.0
	n.add_child(c2)
	Build.label3d(n, Vector3(0, 0, 0.03), "50", 56, Color(0.1, 0.1, 0.1))

static func _scooter(p: Vector3, yaw: float, col: String) -> void:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = yaw
	t.add_child(n)
	Build.box(n, Vector3(0, 0.45, 0), Vector3(0.36, 0.28, 0.9), m(col), false)
	Build.box(n, Vector3(0, 0.66, 0.15), Vector3(0.3, 0.1, 0.5), m("iron"), false)
	Build.box(n, Vector3(0, 0.75, -0.5), Vector3(0.12, 0.7, 0.12), m(col), false)
	Build.box(n, Vector3(0, 1.08, -0.5), Vector3(0.6, 0.04, 0.04), m("iron"), false)
	for z in [-0.48, 0.42]:
		var w := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.2; cm.bottom_radius = 0.2; cm.height = 0.1; cm.radial_segments = 12
		w.mesh = cm
		w.material_override = m("iron")
		w.position = Vector3(0, 0.2, z)
		w.rotation.z = PI / 2.0
		n.add_child(w)

static func _ape(p: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = yaw
	t.add_child(n)
	Build.box(n, Vector3(0, 0.95, -0.9), Vector3(1.25, 1.3, 1.0), m("ape_blue"), false)
	Build.box(n, Vector3(0, 1.25, -1.41), Vector3(1.0, 0.55, 0.03), m("glass_dark"), false)
	Build.box(n, Vector3(0, 0.6, 0.6), Vector3(1.35, 0.08, 2.0), m("metal_grey"), false)
	for s in [-1.0, 1.0]:
		Build.box(n, Vector3(s * 0.66, 0.8, 0.6), Vector3(0.04, 0.4, 2.0), m("ape_blue"), false)
	Build.box(n, Vector3(0, 0.8, 1.6), Vector3(1.35, 0.4, 0.04), m("ape_blue"), false)
	Build.box(n, Vector3(0.2, 0.85, 0.5), Vector3(0.5, 0.4, 0.5), m("bench_wood"), false)   # cassette
	for w in [Vector3(0, 0.25, -1.2), Vector3(-0.6, 0.25, 0.9), Vector3(0.6, 0.25, 0.9)]:
		var wm := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.25; cm.bottom_radius = 0.25; cm.height = 0.14; cm.radial_segments = 12
		wm.mesh = cm
		wm.material_override = m("iron")
		wm.position = w
		wm.rotation.z = PI / 2.0
		n.add_child(wm)
	Build.collider(t, p + Vector3(0, 0.7, 0), Vector3(1.4, 1.4, 3.2), yaw)

static func _geraniums(p: Vector3) -> void:
	Build.cylinder(t, p + Vector3(0, 0.2, 0), 0.22, 0.4, m("terracotta"), false, 10)
	var unit := SphereMesh.new()
	unit.radius = 0.5; unit.height = 1.0; unit.radial_segments = 8; unit.rings = 4
	Build.batch_add("ger_leaf", unit, m("leaf"), Transform3D(Basis().scaled(Vector3(0.5, 0.32, 0.5)), p + Vector3(0, 0.52, 0)), false)
	for k in 5:
		var a := k * TAU / 5.0
		Build.batch_add("ger_flower", unit, m("geranium" if k % 2 == 0 else "geranium_p"), Transform3D(Basis().scaled(Vector3(0.12, 0.12, 0.12)), p + Vector3(cos(a) * 0.15, 0.68, sin(a) * 0.15)), false)

static func _details() -> void:
	# scooter parcheggiati sul marciapiede
	_scooter(Vector3(7.5, Town.CURB, 4.7), PI / 2.0, "barrier_w")
	_scooter(Vector3(8.6, Town.CURB, 4.7), PI / 2.0, "sign_coral")
	_scooter(Vector3(-25.5, Town.CURB, -4.7), -PI / 2.0, "sign_navy")
	# Ape a tre ruote su Via dei Tigli
	_ape(Vector3(-37.2, 0.02, -46.0), PI)
	# vasi di gerani accanto alle porte
	for p in [Vector3(-46.2, Town.CURB, -21.5), Vector3(-46.2, Town.CURB, -27.0), Vector3(1.8, Town.CURB, -38.6), Vector3(8.2, Town.CURB, -38.6), Vector3(33.0, Town.CURB, 6.4), Vector3(38.0, Town.CURB, 6.4), Vector3(46.5, Town.CURB, -6.4), Vector3(56.5, Town.CURB, -6.4)]:
		_geraniums(p)
	# tavolini e sedie di plastica bianca fuori dal Bar Centrale
	for tx in [1.0, 9.6]:
		var c := Vector3(tx, Town.CURB, -37.4)
		Build.cylinder(t, c + Vector3(0, 0.36, 0), 0.04, 0.72, m("plastic_white"), false, 6)
		Build.cylinder(t, c + Vector3(0, 0.73, 0), 0.4, 0.03, m("plastic_white"), false, 14)
		for a in [PI / 2.0, -PI / 2.0]:
			var q := c + Vector3(0, 0, sin(a) * 0.72)
			Build.box(t, q + Vector3(0, 0.42, 0), Vector3(0.42, 0.05, 0.42), m("plastic_white"), false)
			Build.box(t, q + Vector3(0, 0.68, sin(a) * 0.2), Vector3(0.42, 0.5, 0.04), m("plastic_white"), false)
		Build.collider(t, c + Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 2.0))
	# farmacia con croce verde (sull'edificio di fronte alla piazza)
	var fp := Vector3(-16.0, Town.CURB, -6.95)
	Build.box(t, fp + Vector3(0, 3.9, 0.35), Vector3(0.06, 0.06, 0.7), m("iron"), false)
	var cr := Node3D.new()
	cr.position = fp + Vector3(0, 3.9, 0.75)
	cr.rotation.y = PI / 2.0
	t.add_child(cr)
	Build.box(cr, Vector3.ZERO, Vector3(0.7, 0.22, 0.08), m("cross_green"), false, 0.0, false)
	Build.box(cr, Vector3.ZERO, Vector3(0.22, 0.7, 0.08), m("cross_green"), false, 0.0, false)
	Build.label3d(t, fp + Vector3(2.4, 3.25, 0.05), "FARMACIA", 44, Color("#1F7A3A"))
	# fontanella in ghisa
	var nz := Vector3(-34.0, Town.CURB, -22.0)
	Build.cylinder(t, nz + Vector3(0, 0.55, 0), 0.16, 1.1, m("cast_iron"), true, 10)
	Build.box(t, nz + Vector3(0.2, 0.85, 0), Vector3(0.3, 0.05, 0.05), m("cast_iron"), false)
	Build.box(t, nz + Vector3(0.25, 0.03, 0), Vector3(0.5, 0.06, 0.35), m("iron"), false)
	t.interactables["nasone"] = Interactable.make(t, nz + Vector3(0.6, 0.9, 0), "nasone", func(): return "Fontanella · Bevi (gratis)", t._drink_fountain, 1.3)
	# bacheca comunale in piazza (annunci collegati al gioco)
	var bp := Vector3(-7.5, Town.CURB, -27.0)
	for k in [-0.9, 0.9]:
		Build.box(t, bp + Vector3(0, 0.9, k), Vector3(0.08, 1.8, 0.08), m("iron"))
	Build.box(t, bp + Vector3(0, 1.45, 0), Vector3(0.06, 1.0, 1.8), m("cork"), false)
	Build.label3d(t, bp + Vector3(0.05, 1.7, -0.45), "CERCASI\ncassiere/a\nMarket Il Girasole", 16, Color(0.1, 0.1, 0.1), PI / 2.0)
	Build.label3d(t, bp + Vector3(0.05, 1.25, -0.45), "Rider in bici\nConsegnaGiù", 16, Color(0.1, 0.1, 0.1), PI / 2.0)
	Build.label3d(t, bp + Vector3(0.05, 1.6, 0.45), "AFFITTASI\nmonolocale\nCorso Italia", 16, Color(0.1, 0.1, 0.1), PI / 2.0)
	Build.label3d(t, bp + Vector3(0.05, 1.15, 0.45), "Sagra del paese\nsabato in piazza", 16, Color(0.6, 0.1, 0.1), PI / 2.0)
	Build.label3d(t, bp + Vector3(0.09, 2.05, 0), "Bacheca comunale", 22, Color(0.95, 0.92, 0.85), PI / 2.0)
	# tombini sull'asfalto
	for p in [Vector3(-60, 0.03, -1.0), Vector3(-12, 0.03, 1.3), Vector3(25, 0.03, -1.2), Vector3(70, 0.03, 0.8), Vector3(-40.5, 0.03, -30), Vector3(-39.0, 0.03, -70)]:
		var tm := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.38; cm.bottom_radius = 0.38; cm.height = 0.02; cm.radial_segments = 14
		tm.mesh = cm
		tm.material_override = m("iron")
		tm.position = p
		tm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.add_child(tm)
	# insegne sbiadite anni '80 sulle serrande chiuse
	for s in [[Vector3(-79.0, Town.CURB + 3.1, -6.94), "OTTICA · FOTO", 0.0], [Vector3(-54.0, Town.CURB + 3.1, -6.94), "MERCERIA Lina", 0.0], [Vector3(-79.0, Town.CURB + 3.1, 6.94), "ALIMENTARI", PI], [Vector3(-10.5, Town.CURB + 3.1, 6.94), "CALZATURE", PI]]:
		Build.label3d(t, s[0], s[1], 46, Color("#A89A86"), s[2])
	# scritta innocua sul muro del parcheggio
	Build.label3d(t, Vector3(-22.0, 0.75, -58.85), "CIAO SAN VITO!", 60, Color("#3D7FC4"), 0.0)
	# panni stesi tra le finestre e cavi sopra la strada
	for lp in [[Vector3(-66.0, 5.6, -6.6), 0.0], [Vector3(-27.0, 5.6, -6.6), 0.0], [Vector3(-90.0, 5.6, 6.6), PI]]:
		var n := Node3D.new()
		n.position = lp[0]
		n.rotation.y = lp[1]
		t.add_child(n)
		Build.box(n, Vector3.ZERO, Vector3(3.2, 0.015, 0.015), m("cable"), false, 0.0, false)
		var cols := ["barrier_w", "bin_b", "sign_coral", "barrier_w", "awning_g"]
		for k in cols.size():
			Build.box(n, Vector3(-1.3 + k * 0.62, -0.32, 0), Vector3(0.45, 0.6, 0.015), m(cols[k]), false, 0.0, false)
	for cx in [-62.0, -14.0, 44.0, 80.0]:
		Build.box(t, Vector3(cx, 6.6, 0), Vector3(0.025, 0.025, 14.0), m("cable"), false, 0.0, false)
	Build.box(t, Vector3(10.0, 6.8, -6.92), Vector3(60.0, 0.025, 0.025), m("cable"), false, 0.0, false)
	# limiti di velocità all'ingresso del paese e cartello attraversamento pedonale
	_limit_sign(Vector3(-92.0, Town.CURB, 4.4), -PI / 2.0)
	_limit_sign(Vector3(92.0, Town.CURB, -4.4), PI / 2.0)
	_sign_disc(Vector3(15.6, Town.CURB, -4.4), "ATTRAV.\nPEDONALE", "bin_b", 0.0)
	# altra isola ecologica in Via dei Tigli
	var bins := ["bin_y", "bin_b", "bin_g", "bin_m"]
	for i in bins.size():
		Build.box(t, Vector3(-34.5, Town.CURB + 0.6, -40.0 - i * 1.0), Vector3(0.9, 1.2, 0.9), m(bins[i]))
