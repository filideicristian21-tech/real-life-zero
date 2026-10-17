class_name Town
extends Node3D
## San Vito al Colle: quartiere di 200x200 m costruito da codice con materiali PBR (Poly Haven / ambientCG)
## e prop GLB. Tre interni esplorabili: casa (Via dei Tigli 12), Bar Centrale da Mimmo, Market Il Girasole.

const CURB := 0.12
const GROUND_H := 3.6   # altezza piano terra (soffitto interni)
const FLOOR_H := 3.1

# Palette di Spark
const C_OCRA := Color("#D9B98C")
const C_ROSA := Color("#C99A8B")
const C_VERDE := Color("#3E5B4A")
const C_TRAV := Color("#CFC6B4")
const C_COPPO := Color("#A65A3A")
const C_SODIO := Color("#F2A65A")
const C_CREMA := Color("#F3E9D2")

var doors: Dictionary = {}
var interactables: Dictionary = {}
var lamp_lights: Array[OmniLight3D] = []
var lamp_bulbs: Array = []
var interior_lights: Dictionary = {}
var spawn_home := Vector3(-50.5, CURB, -24.5)
var spawn_home_yaw := 0.0
var rng := RandomNumberGenerator.new()
var world_ui: Node = null   # main, per aprire i pannelli
var places: Dictionary

func build(p_world_ui: Node) -> void:
	world_ui = p_world_ui
	places = Data.places
	rng.seed = 12345
	_materials()
	_ground_and_streets()
	_piazza()
	_bus_stop()
	_parking()
	_home()
	_bar()
	_market()
	_decor_buildings()
	_street_furniture()
	_boundaries()
	var n := Build.flush_batches(self)
	var sb := Build.static_batch(self)
	print("[town] LOD automatico su ", Build.auto_lod(self), " oggetti")
	print("[town] elementi in MultiMesh: ", n, " · box/cilindri statici uniti: ", sb)

# ------------------------------------------------------------------ materiali
func _materials() -> void:
	Build.pbr("asphalt", "asphalt", Color(0.62, 0.62, 0.6), 0.25, 0.95)
	Build.pbr("sidewalk", "paving", Color(0.95, 0.92, 0.86), 0.45, 0.9)
	Build.pbr("cobble", "cobble", Color(0.95, 0.9, 0.82), 0.35, 0.9)
	Build.pbr("grass", "grass", Color(0.8, 0.85, 0.7), 0.2, 1.0)
	# facciate: intonaco PBR (Poly Haven painted_plaster_wall, CC0) tinto con la palette di Spark
	Build.pbr("plaster_ocra", "facade", Color("#D9B98C") * 1.25, 0.28, 0.95, 0.9)
	Build.pbr("plaster_rosa", "facade", Color("#C99A8B") * 1.25, 0.28, 0.95, 0.9)
	Build.pbr("plaster_crema", "facade", Color("#E6D7BC") * 1.18, 0.28, 0.95, 0.9)
	Build.pbr("plaster_giallo", "facade", Color("#E3C27A") * 1.2, 0.28, 0.95, 0.9)
	Build.pbr("stonebase", "stonebase", Color(0.92, 0.88, 0.8), 0.55, 0.95, 0.9)
	# pavimenti opachi: piastrelle da ~33 cm al Market, graniglia al Bar
	Build.pbr("floor_market", "floor_market", Color(1.0, 0.97, 0.9), 1.0, 0.62, 0.5)
	Build.pbr("floor_bar", "floor_bar", Color(0.8, 0.74, 0.66), 2.2, 0.6, 0.4)
	Build.pbr("walltiles", "walltiles", Color(0.95, 0.93, 0.88), 1.0, 0.45, 0.5)
	Build.pbr("plaster_int", "plaster", Color("#EDE6DA"), 0.4, 0.95, 0.3)
	Build.pbr("plaster_bar", "plaster", Color("#E9E0C9"), 0.4, 0.95, 0.3)
	Build.pbr("roof", "roof", Color(1, 1, 1), 0.5, 0.85)
	Build.pbr("wood_floor", "wood", Color(0.95, 0.9, 0.85), 0.6, 0.7)
	Build.pbr("tiles", "tiles", Color(1, 1, 1), 0.6, 0.5)
	Build.pbr("marble", "marble", Color(1, 1, 1), 0.5, 0.35, 0.3)
	Build.pbr("travertino", "paving", C_TRAV, 1.2, 0.85, 0.3)
	Build.flat("stone", C_TRAV, 0.85)
	Build.flat("shutter", C_VERDE, 0.7)
	Build.flat("frame", Color("#EFEAE0"), 0.6)
	Build.flat("glass_dark", Color(0.16, 0.2, 0.24), 0.08, 0.3)
	Build.flat("glass_lit", Color(0.3, 0.26, 0.18), 0.2, 0.0, C_SODIO, 0.0)
	Build.flat("glass_shop", Color(0.55, 0.65, 0.7, 0.28), 0.05, 0.2)
	Build.flat("iron", Color(0.12, 0.13, 0.13), 0.5, 0.6)
	Build.flat("metal_grey", Color(0.55, 0.56, 0.56), 0.5, 0.7)
	Build.flat("serranda", Color(0.62, 0.63, 0.62), 0.45, 0.6)
	Build.flat("door_wood", Color("#6B4A33"), 0.6)
	Build.flat("door_green", C_VERDE, 0.5)
	Build.flat("line_white", Color(0.92, 0.92, 0.9), 0.7)
	Build.flat("sign_green", Color("#24402F"), 0.6)
	Build.flat("sign_yellow", Color("#F2C230"), 0.6)
	Build.flat("water", Color(0.35, 0.55, 0.62, 0.75), 0.05, 0.1)
	Build.flat("lamp_bulb", Color(1, 0.95, 0.8), 0.3, 0.0, C_SODIO, 0.0)
	Build.flat("shelf", Color(0.92, 0.92, 0.9), 0.5, 0.3)
	Build.flat("bin_y", Color("#E8C23A"), 0.6)
	Build.flat("bin_b", Color("#2F5DA8"), 0.6)
	Build.flat("bin_g", Color("#3C8A46"), 0.6)
	Build.flat("bin_m", Color("#7A5233"), 0.6)
	Build.flat("bench_wood", Color("#8A6440"), 0.7)
	Build.flat("cork", Color("#B98C5A"), 0.9)
	Build.flat("paper", Color("#F7F4EA"), 0.9)
	Build.flat("barrier_r", Color("#C8352B"), 0.6)
	Build.flat("barrier_w", Color("#F1F1EE"), 0.6)
	Build.flat("hedge", Color("#4F6B3A"), 0.95)
	Build.flat("bed_cover", Color("#7C8FA6"), 0.9)

# ------------------------------------------------------------------ terreno e strade
func _ground_and_streets() -> void:
	Build.box(self, Vector3(0, -0.1, 0), Vector3(200, 0.2, 200), Build.mat("grass"))
	# Via Roma Vecchia (est-ovest)
	Build.box(self, Vector3(0, 0.01, 0), Vector3(200, 0.02, 8), Build.mat("asphalt"), false)
	_sidewalk(Vector3(0, 0, -5.5), Vector3(200, 0, 3))
	_sidewalk(Vector3(0, 0, 5.5), Vector3(200, 0, 3))
	# Via dei Tigli (nord-sud)
	Build.box(self, Vector3(-40, 0.01, -52), Vector3(8, 0.02, 96), Build.mat("asphalt"), false)
	_sidewalk(Vector3(-45.5, 0, -53.5), Vector3(3, 0, 93))
	_sidewalk(Vector3(-34.5, 0, -53.5), Vector3(3, 0, 93))
	# segnaletica: mezzeria tratteggiata e strisce pedonali
	var dash := Build.box_mesh(Vector3(1, 1, 1))
	for i in range(-48, 49):
		if absf(i * 2.0 + 40.0) < 6.0:
			continue
		Build.batch_add("road_line", dash, Build.mat("line_white"), Transform3D(Basis().scaled(Vector3(1.4, 0.01, 0.14)), Vector3(i * 2.0 + 0.5, 0.025, 0)), false)
	for i in range(0, 24):
		Build.batch_add("road_line", dash, Build.mat("line_white"), Transform3D(Basis().scaled(Vector3(0.14, 0.01, 1.4)), Vector3(-40, 0.025, -8.0 - i * 3.6)), false)
	for zc in [[10.0, 0.0], [-40.0, 0.0]]:
		pass
	# strisce pedonali davanti alla piazza (x=10) e all'incrocio con Via dei Tigli (x=-30)
	for xc in [12.0, -30.0]:
		for k in range(7):
			Build.batch_add("road_line", dash, Build.mat("line_white"), Transform3D(Basis().scaled(Vector3(0.5, 0.01, 7.2)), Vector3(xc - 3.0 + k * 1.0, 0.026, 0)), false)
	for k in range(7):
		Build.batch_add("road_line", dash, Build.mat("line_white"), Transform3D(Basis().scaled(Vector3(7.2, 0.01, 0.5)), Vector3(-40, 0.026, -9.0 - k * 1.0)), false)
	# righe dei parcheggi lungo il lato sud della strada
	for i in range(-18, 19):
		var x := i * 5.0
		if x > -46.0 and x < -34.0:
			continue
		Build.batch_add("road_line", dash, Build.mat("line_white"), Transform3D(Basis().scaled(Vector3(0.12, 0.01, 2.2)), Vector3(x, 0.025, 2.9)), false)

func _sidewalk(center: Vector3, size: Vector3) -> void:
	Build.box(self, Vector3(center.x, CURB / 2.0, center.z), Vector3(size.x, CURB, size.z), Build.mat("sidewalk"))
	# cordolo in travertino
	var kerb := Build.box_mesh(Vector3(1, 1, 1))
	if size.x > size.z:
		for s in [-1.0, 1.0]:
			Build.batch_add("kerb", kerb, Build.mat("stone"), Transform3D(Basis().scaled(Vector3(size.x, CURB + 0.01, 0.18)), Vector3(center.x, CURB / 2.0 + 0.003, center.z + s * (size.z / 2.0 - 0.09))))
	else:
		for s in [-1.0, 1.0]:
			Build.batch_add("kerb", kerb, Build.mat("stone"), Transform3D(Basis().scaled(Vector3(0.18, CURB + 0.01, size.z)), Vector3(center.x + s * (size.x / 2.0 - 0.09), CURB / 2.0 + 0.003, center.z)))

# ------------------------------------------------------------------ piazza
func _piazza() -> void:
	Build.box(self, Vector3(10, CURB / 2.0, -23.5), Vector3(40, CURB, 33), Build.mat("cobble"))
	var c := Vector3(10, CURB, -24)
	Build.cylinder(self, c + Vector3(0, 0.3, 0), 3.0, 0.6, Build.mat("travertino"), true, 24)
	Build.cylinder(self, c + Vector3(0, 0.58, 0), 2.75, 0.06, Build.mat("water"), false, 24)
	Build.cylinder(self, c + Vector3(0, 1.1, 0), 0.35, 1.6, Build.mat("travertino"), false, 12)
	Build.cylinder(self, c + Vector3(0, 1.85, 0), 0.95, 0.22, Build.mat("travertino"), false, 16)
	Build.cylinder(self, c + Vector3(0, 1.95, 0), 0.85, 0.04, Build.mat("water"), false, 16)
	Build.label3d(self, c + Vector3(0, 0.45, 3.02), "Piazza della Fontana", 48, Color("#5a5245"))
	interactables["fountain"] = Interactable.make(self, c + Vector3(0, 1.0, 3.2), "fountain", func(): return "Fontana · Bevi (gratis)", _drink_fountain, 1.9)
	# tre panchine
	for p in [Vector3(3, 0, -24), Vector3(17, 0, -24), Vector3(10, 0, -31.5)]:
		var rot := 0.0
		if p.x < 10.0: rot = PI / 2.0
		elif p.x > 10.0: rot = -PI / 2.0
		_bench(c + p - Vector3(10, 0, -24), rot)
	# edicola chiusa (serranda abbassata, nessuna porta)
	var k := Vector3(24, CURB, -13)
	Build.box(self, k + Vector3(0, 1.3, 0), Vector3(3.0, 2.6, 2.2), Build.mat("shutter"))
	Build.box(self, k + Vector3(0, 2.7, 0), Vector3(3.4, 0.15, 2.6), Build.mat("iron"), false)
	Build.box(self, k + Vector3(0, 1.2, 1.12), Vector3(2.6, 1.9, 0.05), Build.mat("serranda"), false)
	Build.label3d(self, k + Vector3(0, 2.35, 1.16), "EDICOLA", 64, C_CREMA)
	Build.label3d(self, k + Vector3(0, 1.4, 1.16), "Chiusa per ferie", 32, Color(0.15, 0.15, 0.15))
	# alberi in vaso
	for p in [Vector3(-7, CURB, -10), Vector3(27, CURB, -37), Vector3(-7, CURB, -37), Vector3(27, CURB, -22)]:
		Build.box(self, p + Vector3(0, 0.35, 0), Vector3(1.2, 0.7, 1.2), Build.mat("travertino"))
		Build.prop(self, "res://assets/props/shrub_02.glb", p + Vector3(0, 0.55, 0), rng.randf() * TAU, 0.35)

func _bench(pos: Vector3, rot: float) -> void:
	var n := Node3D.new()
	n.position = pos + Vector3(0, CURB, 0)
	n.rotation.y = rot
	add_child(n)
	Build.box(n, Vector3(0, 0.45, 0), Vector3(1.8, 0.07, 0.45), Build.mat("bench_wood"), false)
	Build.box(n, Vector3(0, 0.75, -0.2), Vector3(1.8, 0.35, 0.05), Build.mat("bench_wood"), false)
	for x in [-0.75, 0.75]:
		Build.box(n, Vector3(x, 0.22, 0), Vector3(0.08, 0.45, 0.45), Build.mat("iron"), false)
	Build.collider(self, pos + Vector3(0, CURB + 0.4, 0), Vector3(1.8 if absf(rot) < 0.1 else 0.5, 0.8, 0.5 if absf(rot) < 0.1 else 1.8))
	var it := Interactable.make(n, Vector3(0, 0.6, 0.5), "bench", func(): return "Siediti sulla panchina · riposa 30 min", func(): world_ui.rest_minutes(30, 3.0, "Ti sei riposato sulla panchina."), 1.4)

func _drink_fountain() -> void:
	var cd: float = float(Data.balance["tap_water"]["cooldown_game_min"])
	if GameTime.total_minutes - Inventory.last_tap_water_min < cd:
		Game.toast("Hai appena bevuto.", "info")
		return
	Inventory.last_tap_water_min = GameTime.total_minutes
	Needs.eat(0, float(Data.balance["tap_water"]["energy"]))
	Game.toast("Acqua fresca della fontana. Energia +%d." % int(Data.balance["tap_water"]["energy"]), "ok")

# ------------------------------------------------------------------ fermata bus
func _bus_stop() -> void:
	var b := Vector3(-21, CURB, -6.2)
	for x in [-1.8, 1.8]:
		Build.box(self, b + Vector3(x, 1.2, -0.4), Vector3(0.1, 2.4, 0.1), Build.mat("shutter"))
	Build.box(self, b + Vector3(0, 2.45, 0), Vector3(4.0, 0.08, 1.6), Build.mat("shutter"), false)
	Build.box(self, b + Vector3(0, 1.3, -0.65), Vector3(3.8, 1.8, 0.04), Build.mat("glass_shop"), true)
	Build.box(self, b + Vector3(0, 0.45, -0.35), Vector3(2.6, 0.06, 0.4), Build.mat("metal_grey"), false)
	var pole := b + Vector3(2.5, 0, 0.6)
	Build.box(self, pole + Vector3(0, 1.4, 0), Vector3(0.08, 2.8, 0.08), Build.mat("metal_grey"))
	Build.box(self, pole + Vector3(0, 2.6, 0), Vector3(0.6, 0.6, 0.04), Build.mat("sign_yellow"), false)
	Build.label3d(self, pole + Vector3(0, 2.6, 0.03), "BUS\n3", 40, Color(0.1, 0.1, 0.1))
	Build.box(self, pole + Vector3(0, 1.5, 0.05), Vector3(0.5, 0.7, 0.03), Build.mat("paper"), false)
	Build.label3d(self, pole + Vector3(0, 1.5, 0.075), "Linea 3\nPiazza della\nFontana\nogni 30'", 18, Color(0.1, 0.1, 0.1))
	Build.label3d(self, b + Vector3(0, 2.3, 0.82), "Linea 3 · Piazza della Fontana", 34, C_CREMA)
	interactables["bus"] = Interactable.make(self, b + Vector3(0, 1.0, 0.3), "bus_stop", func(): return "Fermata Linea 3 · Orari", func(): world_ui.open_bus_panel(), 2.2)

# ------------------------------------------------------------------ parcheggio
func _parking() -> void:
	var c := Vector3(-22, 0, -50)
	Build.box(self, c + Vector3(0, 0.01, 0), Vector3(20, 0.02, 18), Build.mat("asphalt"), false)
	var dash := Build.box_mesh(Vector3(1, 1, 1))
	for i in range(6):
		for s in [-1.0, 1.0]:
			Build.batch_add("road_line", dash, Build.mat("line_white"), Transform3D(Basis().scaled(Vector3(0.12, 0.01, 4.8)), c + Vector3(-7.5 + i * 3.0, 0.025, s * 5.5)), false)
	Build.label3d(self, c + Vector3(-9.9, 2.2, 0), "P  Parcheggio", 48, Color.WHITE, PI / 2.0)
	Build.box(self, c + Vector3(-9.95, 1.2, 0), Vector3(0.06, 2.4, 0.06), Build.mat("metal_grey"))
	Build.box(self, c + Vector3(-9.9, 2.2, 0), Vector3(0.04, 0.5, 1.6), Build.mat("bin_b"), false)
	var cars := ["sedan", "hatchback-sports", "van", "suv", "sedan"]
	var slots := [Vector3(-6, 0, -5.5), Vector3(0, 0, -5.5), Vector3(3, 0, 5.5), Vector3(-3, 0, 5.5), Vector3(6, 0, 5.5)]
	for i in slots.size():
		_car(c + slots[i], 0.0 if slots[i].z < 0 else PI, cars[i])
	# due auto coperte dal telo (Poly Haven, CC0): più credibili delle auto giocattolo
	for cp in [c + Vector3(-6, 0, 5.5), c + Vector3(3, 0, -5.5)]:
		Build.prop(self, COVERED_CAR, cp + Vector3(0, 0.3, 0), 0.0, 1.0, 80.0)
		Build.collider(self, cp + Vector3(0, 0.75, 0), Vector3(2.0, 1.5, 4.4))
	# siepe di confine
	Build.box(self, c + Vector3(0, 0.6, -9.3), Vector3(20, 1.2, 0.8), Build.mat("hedge"))

func _car(pos: Vector3, rot: float, kind: String) -> void:
	Build.prop(self, "res://assets/props/cars/%s.glb" % kind, pos, rot, 1.7, 80.0, true)
	var sz := Vector3(2.4, 1.6, 4.4)
	if absf(sin(rot)) > 0.5:
		sz = Vector3(4.4, 1.6, 2.4)
	Build.collider(self, pos + Vector3(0, 0.8, 0), sz)

# ------------------------------------------------------------------ muri con aperture
## Muro lungo l'asse "x" o "z" da a0 ad a1, a coordinata fissa "fixed", con aperture
## [{c, w, b, t, kind}] (kind: "door" vuoto | "glass" vetro con collisione | "window" vetro piccolo).
func wall(axis: String, a0: float, a1: float, fixed: float, h: float, th: float, m: Material, openings: Array, y0: float = 0.0, inner_m: Material = null) -> void:
	openings.sort_custom(func(a, b): return a["c"] < b["c"])
	var cur := a0
	for o in openings:
		var o0: float = o["c"] - o["w"] / 2.0
		var o1: float = o["c"] + o["w"] / 2.0
		if o0 > cur:
			_wall_seg(axis, cur, o0, fixed, y0, y0 + h, th, m)
		if o["b"] > 0.0:
			_wall_seg(axis, o0, o1, fixed, y0, y0 + o["b"], th, m)
		if o["t"] < h:
			_wall_seg(axis, o0, o1, fixed, y0 + o["t"], y0 + h, th, m)
		if o["kind"] == "glass" or o["kind"] == "window":
			var mid: float = (o0 + o1) / 2.0
			var gh: float = o["t"] - o["b"]
			var gpos := Vector3(mid, y0 + o["b"] + gh / 2.0, fixed) if axis == "x" else Vector3(fixed, y0 + o["b"] + gh / 2.0, mid)
			var gsize := Vector3(o1 - o0, gh, 0.04) if axis == "x" else Vector3(0.04, gh, o1 - o0)
			Build.box(self, gpos, gsize, Build.mat("glass_shop"), true, 0.0, false)
			var fsize := Vector3(o1 - o0 + 0.1, 0.08, th + 0.06) if axis == "x" else Vector3(th + 0.06, 0.08, o1 - o0 + 0.1)
			Build.box(self, gpos + Vector3(0, -gh / 2.0, 0), fsize, Build.mat("frame"), false)
			Build.box(self, gpos + Vector3(0, gh / 2.0, 0), fsize, Build.mat("frame"), false)
		cur = o1
	if cur < a1:
		_wall_seg(axis, cur, a1, fixed, y0, y0 + h, th, m)

func _wall_seg(axis: String, s0: float, s1: float, fixed: float, ya: float, yb: float, th: float, m: Material) -> void:
	if s1 - s0 < 0.01 or yb - ya < 0.01:
		return
	if axis == "x":
		Build.box(self, Vector3((s0 + s1) / 2.0, (ya + yb) / 2.0, fixed), Vector3(s1 - s0, yb - ya, th), m)
	else:
		Build.box(self, Vector3(fixed, (ya + yb) / 2.0, (s0 + s1) / 2.0), Vector3(th, yb - ya, s1 - s0), m)

## Finestre decorative con persiane su una facciata (MultiMesh). normal = direzione verso l'esterno.
func facade_windows(axis: String, a0: float, a1: float, fixed: float, normal: float, floors_from: int, floors_to: int, balconies: bool) -> void:
	var length := a1 - a0
	var bays := maxi(1, int(length / 3.2))
	var step := length / bays
	var unit := Build.box_mesh(Vector3(1, 1, 1))
	for f in range(floors_from, floors_to):
		var ybase := GROUND_H + (f - 1) * FLOOR_H
		var balcony_floor := balconies and f == floors_from and rng.randf() < 0.7
		for b in bays:
			var a := a0 + step * (b + 0.5)
			var ww := 1.05
			var wh := 1.55 if not balcony_floor else 2.25
			var wy := ybase + (0.9 if not balcony_floor else 0.15) + wh / 2.0
			var out := normal * 0.16
			var lit := rng.randf() < 0.38
			var closed := rng.randf() < 0.3
			var pos := _fpos(axis, a, wy, fixed + out)
			var sc := Vector3(ww, wh, 0.04) if axis == "x" else Vector3(0.04, wh, ww)
			Build.batch_add("glass_lit" if lit else "glass_dark", unit, Build.mat("glass_lit" if lit else "glass_dark"), Transform3D(Basis().scaled(sc), pos), false)
			# davanzale / cornice
			var sill := Vector3(ww + 0.3, 0.07, 0.22) if axis == "x" else Vector3(0.22, 0.07, ww + 0.3)
			Build.batch_add("sill", unit, Build.mat("frame"), Transform3D(Basis().scaled(sill), _fpos(axis, a, wy - wh / 2.0 - 0.03, fixed + normal * 0.2)), false)
			Build.batch_add("sill", unit, Build.mat("frame"), Transform3D(Basis().scaled(sill), _fpos(axis, a, wy + wh / 2.0 + 0.04, fixed + normal * 0.2)), false)
			# persiane: aperte ai lati o chiuse davanti
			if closed:
				var shs := Vector3(ww, wh, 0.05) if axis == "x" else Vector3(0.05, wh, ww)
				Build.batch_add("shutter", unit, Build.mat("shutter"), Transform3D(Basis().scaled(shs), _fpos(axis, a, wy, fixed + normal * 0.2)), false)
			else:
				for s in [-1.0, 1.0]:
					var shs2 := Vector3(ww / 2.0, wh, 0.05) if axis == "x" else Vector3(0.05, wh, ww / 2.0)
					Build.batch_add("shutter", unit, Build.mat("shutter"), Transform3D(Basis().scaled(shs2), _fpos(axis, a + s * (ww * 0.78), wy, fixed + normal * 0.2)), false)
			if balcony_floor:
				var slab := Vector3(ww + 1.0, 0.14, 1.0) if axis == "x" else Vector3(1.0, 0.14, ww + 1.0)
				Build.batch_add("balcony", unit, Build.mat("stone"), Transform3D(Basis().scaled(slab), _fpos(axis, a, ybase + 0.07, fixed + normal * 0.5)))
				var rail := Vector3(ww + 1.0, 0.05, 0.05) if axis == "x" else Vector3(0.05, 0.05, ww + 1.0)
				for ry in [0.55, 1.05]:
					Build.batch_add("iron", unit, Build.mat("iron"), Transform3D(Basis().scaled(rail), _fpos(axis, a, ybase + ry, fixed + normal * 0.97)))
				for k in range(7):
					var pa := a - (ww + 1.0) / 2.0 + k * (ww + 1.0) / 6.0
					Build.batch_add("iron", unit, Build.mat("iron"), Transform3D(Basis().scaled(Vector3(0.035, 1.0, 0.035)), _fpos(axis, pa, ybase + 0.55, fixed + normal * 0.97)))
				for pk in range(rng.randi_range(0, 3)):
					var pa2 := a - 0.6 + pk * 0.55
					Build.batch_add("pot", unit, Build.flat("terracotta", Color("#A85A3A"), 0.9), Transform3D(Basis().scaled(Vector3(0.3, 0.26, 0.3)), _fpos(axis, pa2, ybase + 0.27, fixed + normal * 0.75)), false)
					Build.batch_add("foliage", _sphere(), Build.flat("foliage", Color("#4E7A3A"), 0.9), Transform3D(Basis().scaled(Vector3(0.42, 0.36, 0.42) * rng.randf_range(0.8, 1.2)), _fpos(axis, pa2, ybase + 0.55, fixed + normal * 0.75)), false)

static var _sph: SphereMesh
static func _sphere() -> SphereMesh:
	if _sph == null:
		_sph = SphereMesh.new()
		_sph.radius = 0.5; _sph.height = 1.0; _sph.radial_segments = 8; _sph.rings = 4
	return _sph

## Aiuola rialzata con cordolo in pietra e cespugli (al posto delle strisce d'erba tra marciapiede e case).
func _planter(x0: float, x1: float, z0: float, z1: float) -> void:
	var c := Vector3((x0 + x1) / 2.0, 0, (z0 + z1) / 2.0)
	Build.box(self, c + Vector3(0, 0.15, 0), Vector3(x1 - x0, 0.3, z1 - z0), Build.mat("stone"))
	Build.box(self, c + Vector3(0, 0.305, 0), Vector3(x1 - x0 - 0.2, 0.02, z1 - z0 - 0.2), Build.flat("soil", Color("#3B2E24"), 1.0), false)
	var long := maxf(x1 - x0, z1 - z0)
	var n := int(long / 1.3)
	for i in n:
		var t := (i + 0.5) / float(n)
		var pos := Vector3(lerpf(x0, x1, t), 0.55, c.z) if x1 - x0 > z1 - z0 else Vector3(c.x, 0.55, lerpf(z0, z1, t))
		var k := rng.randf_range(0.7, 1.1)
		Build.batch_add("foliage", _sphere(), Build.flat("foliage", Color("#4E7A3A"), 0.9), Transform3D(Basis().scaled(Vector3(0.8, 0.6, 0.8) * k), pos), true)

## Cartello stradale italiano generico (divieto di sosta / senso unico), senza testi di marchi.
func _road_sign(p: Vector3, kind: String, rot: float) -> void:
	Build.box(self, p + Vector3(0, 1.2, 0), Vector3(0.06, 2.4, 0.06), Build.mat("metal_grey"))
	var n := Node3D.new()
	n.position = p + Vector3(0, 2.25, 0)
	n.rotation.y = rot
	add_child(n)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.3; disc.bottom_radius = 0.3; disc.height = 0.02; disc.radial_segments = 20; disc.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.rotation.x = PI / 2.0
	mi.material_override = Build.flat("sign_red", Color("#C8352B"), 0.5)
	n.add_child(mi)
	var inner := MeshInstance3D.new()
	var d2 := CylinderMesh.new()
	d2.top_radius = 0.24; d2.bottom_radius = 0.24; d2.height = 0.025; d2.radial_segments = 20; d2.rings = 1
	inner.mesh = d2
	inner.rotation.x = PI / 2.0
	inner.material_override = Build.flat("sign_blue", Color("#1F4E9C"), 0.5)
	n.add_child(inner)
	if kind == "sosta":
		var bar := Build.box(n, Vector3(0, 0, 0.016), Vector3(0.46, 0.06, 0.01), Build.mat("sign_red"), false)
		bar.rotation.z = PI / 4.0
	else:
		Build.box(n, Vector3(0, 0, 0.016), Vector3(0.36, 0.1, 0.01), Build.mat("barrier_w"), false)

func _fpos(axis: String, a: float, y: float, f: float) -> Vector3:
	return Vector3(a, y, f) if axis == "x" else Vector3(f, y, a)

## Tetto a due falde in coppi + cornicione.
func roof(x0: float, x1: float, z0: float, z1: float, top: float, flat_roof: bool) -> void:
	var w := x1 - x0
	var d := z1 - z0
	var c := Vector3((x0 + x1) / 2.0, top, (z0 + z1) / 2.0)
	Build.box(self, c + Vector3(0, 0.12, 0), Vector3(w + 0.5, 0.24, d + 0.5), Build.mat("stone"), false)
	if flat_roof:
		for s in [-1.0, 1.0]:
			Build.box(self, c + Vector3(0, 0.6, s * (d / 2.0 + 0.1)), Vector3(w + 0.4, 0.8, 0.2), Build.mat("stone"), false)
			Build.box(self, c + Vector3(s * (w / 2.0 + 0.1), 0.6, 0), Vector3(0.2, 0.8, d + 0.4), Build.mat("stone"), false)
		return
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	var rh: float = min(w, d) * 0.22
	if w >= d:
		pm.size = Vector3(d + 0.7, rh, w + 0.7)
		mi.rotation.y = PI / 2.0
	else:
		pm.size = Vector3(w + 0.7, rh, d + 0.7)
	mi.mesh = pm
	mi.material_override = Build.mat("roof")
	mi.position = c + Vector3(0, 0.24 + rh / 2.0, 0)
	add_child(mi)

# ------------------------------------------------------------------ edificio decorativo pieno
func decor_building(x0: float, x1: float, z0: float, z1: float, floors: int, mkey: String, front: String, shop_ground: bool) -> void:
	var h := GROUND_H + (floors - 1) * FLOOR_H
	var m := Build.mat(mkey)
	Build.box(self, Vector3((x0 + x1) / 2.0, h / 2.0, (z0 + z1) / 2.0), Vector3(x1 - x0, h, z1 - z0), m)
	# zoccolo in pietra
	Build.box(self, Vector3((x0 + x1) / 2.0, 0.4, (z0 + z1) / 2.0), Vector3(x1 - x0 + 0.08, 0.8, z1 - z0 + 0.08), Build.mat("stonebase"), false)
	# marcapiano
	Build.box(self, Vector3((x0 + x1) / 2.0, GROUND_H, (z0 + z1) / 2.0), Vector3(x1 - x0 + 0.14, 0.14, z1 - z0 + 0.14), Build.mat("stone"), false)
	roof(x0, x1, z0, z1, h, rng.randf() < 0.25)
	for side in ["front", "back"]:
		var fz := z0 if (front == "n") == (side == "front") else z1
		var nz := -1.0 if fz == z0 else 1.0
		if front == "n" or front == "s":
			facade_windows("x", x0, x1, fz, nz, 2, floors + 1, side == "front")
			if side == "front":
				_ground_floor_front("x", x0, x1, fz, nz, shop_ground)
		else:
			var fx := x0 if (front == "w") == (side == "front") else x1
			var nx := -1.0 if fx == x0 else 1.0
			facade_windows("z", z0, z1, fx, nx, 2, floors + 1, side == "front")
			if side == "front":
				_ground_floor_front("z", z0, z1, fx, nx, shop_ground)

## Piano terra senza porte: serrande abbassate (negozi chiusi) o finestre con inferriata.
func _ground_floor_front(axis: String, a0: float, a1: float, fixed: float, normal: float, shop: bool) -> void:
	var unit := Build.box_mesh(Vector3(1, 1, 1))
	var length := a1 - a0
	var bays := maxi(1, int(length / 3.6))
	var step := length / bays
	for b in bays:
		var a := a0 + step * (b + 0.5)
		if shop and b % 2 == 0:
			var sz := Vector3(2.6, 2.5, 0.06) if axis == "x" else Vector3(0.06, 2.5, 2.6)
			Build.batch_add("serranda", unit, Build.mat("serranda"), Transform3D(Basis().scaled(sz), _fpos(axis, a, CURB + 1.3, fixed + normal * 0.04)), false)
			var bx := Vector3(2.8, 0.35, 0.3) if axis == "x" else Vector3(0.3, 0.35, 2.8)
			Build.batch_add("serranda_box", unit, Build.mat("metal_grey"), Transform3D(Basis().scaled(bx), _fpos(axis, a, CURB + 2.72, fixed + normal * 0.15)), false)
			if rng.randf() < 0.35:
				var lbl := Build.label3d(self, _fpos(axis, a, CURB + 1.5, fixed + normal * 0.09), ["AFFITTASI\ntel. 0000 000000", "CEDESI ATTIVITÀ", "CHIUSO"][rng.randi() % 3], 30, Color(0.75, 0.1, 0.1))
				lbl.rotation.y = _rot_for(axis, normal)
		else:
			var ws := Vector3(1.1, 1.4, 0.04) if axis == "x" else Vector3(0.04, 1.4, 1.1)
			var wp := _fpos(axis, a, 1.9, fixed + normal * 0.03)
			Build.batch_add("glass_dark", unit, Build.mat("glass_dark"), Transform3D(Basis().scaled(ws), wp), false)
			for k in range(5):
				var ga := a - 0.45 + k * 0.225
				Build.batch_add("iron", unit, Build.mat("iron"), Transform3D(Basis().scaled(Vector3(0.03, 1.4, 0.03)), _fpos(axis, ga, 1.9, fixed + normal * 0.1)), false)

func _rot_for(axis: String, normal: float) -> float:
	if axis == "x":
		return 0.0 if normal > 0 else PI
	return PI / 2.0 if normal > 0 else -PI / 2.0

func _decor_buildings() -> void:
	var cols := ["plaster_ocra", "plaster_rosa", "plaster_crema", "plaster_giallo"]
	var north := [[-100, -86], [-85, -73], [-72, -61], [-60, -48], [-32, -22.5], [-21.5, -11], [31, 44], [45, 58], [59, 72], [73, 86], [87, 100]]
	for i in north.size():
		var s = north[i]
		decor_building(s[0], s[1], -19.0, -7.0, 2 + (i * 7) % 3, cols[i % 4], "s", i % 2 == 0)
	var south := [[-100, -86], [-85, -73], [-72, -59], [-58, -48], [-32, -18], [-17, -4], [-3, 7], [29, 42], [43, 56], [57, 70], [71, 84], [85, 100]]
	for i in south.size():
		var s = south[i]
		decor_building(s[0], s[1], 7.0, 19.0, 2 + (i * 5) % 3, cols[(i + 2) % 4], "n", i % 3 != 1)
	# lato ovest della piazza e lato est
	decor_building(-22, -11, -40, -20, 3, "plaster_crema", "e", false)
	decor_building(31, 44, -40, -20, 3, "plaster_rosa", "w", true)
	# Via dei Tigli
	decor_building(-60, -48, -50, -36, 3, "plaster_rosa", "e", false)
	decor_building(-60, -48, -66, -52, 2, "plaster_ocra", "e", false)
	decor_building(-32, -22.5, -34, -21, 2, "plaster_giallo", "w", false)
	decor_building(-60, -48, -82, -68, 3, "plaster_crema", "e", false)
	decor_building(-32, -20, -82, -64, 3, "plaster_ocra", "w", true)
	# dietro al bar
	decor_building(17, 30, -56, -42, 3, "plaster_giallo", "s", true)

# ------------------------------------------------------------------ CASA (Via dei Tigli 12)
func _home() -> void:
	var x0 := -60.0; var x1 := -47.0; var z0 := -34.0; var z1 := -20.0
	var floors := 3
	var top := GROUND_H + (floors - 1) * FLOOR_H
	var m := Build.mat("plaster_ocra")
	var th := 0.3
	var y0 := CURB
	# pavimento interno
	Build.box(self, Vector3((x0 + x1) / 2.0, CURB / 2.0, (z0 + z1) / 2.0), Vector3(x1 - x0, CURB, z1 - z0), Build.mat("wood_floor"))
	# muri piano terra: porta sul lato est (verso Via dei Tigli) a z=-27
	wall("z", z0, z1, x1 - th / 2.0, GROUND_H - CURB, th, m, [{"c": -27.0, "w": 1.25, "b": 0.0, "t": 2.3, "kind": "door"}, {"c": -23.0, "w": 1.2, "b": 0.9, "t": 2.4, "kind": "window"}], y0)
	wall("x", x0, x1, z1 - th / 2.0, GROUND_H - CURB, th, m, [{"c": -51.0, "w": 1.2, "b": 0.9, "t": 2.4, "kind": "window"}], y0)
	wall("x", x0, x1, z0 + th / 2.0, GROUND_H - CURB, th, m, [], y0)
	wall("z", z0, z1, x0 + th / 2.0, GROUND_H - CURB, th, m, [], y0)
	# tramezzi interni: la stanza è x[-55,-47], z[-29,-20] (appartamento condiviso, il resto è dei coinquilini)
	var mi := Build.mat("plaster_int")
	wall("z", -29.0, z1, -55.0, GROUND_H - CURB, 0.15, mi, [], y0)
	wall("x", -55.0, x1, -29.0, GROUND_H - CURB, 0.15, mi, [], y0)
	# piani superiori pieni (soffitto della stanza)
	Build.box(self, Vector3((x0 + x1) / 2.0, GROUND_H + (top - GROUND_H) / 2.0, (z0 + z1) / 2.0), Vector3(x1 - x0, top - GROUND_H, z1 - z0), m)
	Build.box(self, Vector3((x0 + x1) / 2.0, GROUND_H, (z0 + z1) / 2.0), Vector3(x1 - x0 + 0.14, 0.14, z1 - z0 + 0.14), Build.mat("stone"), false)
	Build.box(self, Vector3((x0 + x1) / 2.0, GROUND_H - 0.03, (z0 + z1) / 2.0), Vector3(x1 - x0 - 0.2, 0.06, z1 - z0 - 0.2), Build.mat("plaster_int"), false)
	facade_windows("z", z0, z1, x1, 1.0, 2, floors + 1, true)
	facade_windows("x", x0, x1, z1, 1.0, 2, floors + 1, false)
	roof(x0, x1, z0, z1, top, false)
	# porta d'ingresso vera (sempre apribile per il protagonista)
	var d := Door.new()
	add_child(d)
	d.setup("home", "Casa · Via dei Tigli 12", 1.2, 2.25, Build.mat("door_wood"), Build.mat("frame"))
	d.position = Vector3(x1 - th / 2.0, y0, -27.0)
	d.rotation.y = PI / 2.0   # +Z locale -> +X mondo (esterno)
	doors["home"] = d
	d.opened.connect(func(_d): Game.tutorial_event("left_home") if Game.player and Game.player.global_position.x < x1 else null)
	Build.label3d(self, Vector3(x1 + 0.02, 2.65, -27.0), "Via dei Tigli 12", 36, Color(0.2, 0.2, 0.2), PI / 2.0)
	Build.box(self, Vector3(x1 + 0.01, 2.65, -27.0), Vector3(0.02, 0.22, 1.1), Build.mat("paper"), false)
	# ---- arredo (Kenney Furniture Kit, scala 2)
	var F := "res://assets/props/%s.glb"
	Build.prop(self, F % "bedSingle", Vector3(-54.85, y0, -20.5), PI / 2.0, 2.0)
	Build.collider(self, Vector3(-53.7, y0 + 0.4, -21.3), Vector3(2.3, 0.8, 1.15))
	Build.box(self, Vector3(-53.7, y0 + 0.75, -21.3), Vector3(1.9, 0.05, 1.0), Build.mat("bed_cover"), false)
	interactables["bed"] = Interactable.make(self, Vector3(-53.5, y0 + 0.8, -22.2), "bed", func(): return "Letto · Dormi", func(): world_ui.open_sleep_panel(), 1.6)
	# angolo cucina lungo il tramezzo z=-29
	var kz := -28.9
	Build.prop(self, F % "kitchenFridge", Vector3(-54.9, y0, kz), 0.0, 2.0)
	Build.prop(self, F % "kitchenStove", Vector3(-53.9, y0, kz), 0.0, 2.0)
	Build.prop(self, F % "kitchenSink", Vector3(-53.0, y0, kz), 0.0, 2.0)
	Build.prop(self, F % "kitchenCabinet", Vector3(-52.1, y0, kz), 0.0, 2.0)
	Build.collider(self, Vector3(-53.5, y0 + 0.9, -28.45), Vector3(3.4, 1.8, 0.9))
	interactables["fridge"] = Interactable.make(self, Vector3(-54.5, y0 + 1.0, -27.7), "fridge", func(): return "Frigo · Mangia", func(): world_ui.open_food_panel(true, "Frigo"), 1.3)
	interactables["stove"] = Interactable.make(self, Vector3(-53.5, y0 + 1.0, -27.7), "stove", func(): return "Fornelli e forno · Cucina", func(): world_ui.open_food_panel(true, "Cucina"), 1.2)
	interactables["sink"] = Interactable.make(self, Vector3(-52.6, y0 + 1.0, -27.7), "sink", func(): return "Lavello · Bevi acqua del rubinetto", _drink_tap, 1.2)
	# tavolo e sedia
	Build.prop(self, F % "table", Vector3(-51.2, y0, -24.0), 0.0, 1.6)
	Build.collider(self, Vector3(-50.5, y0 + 0.35, -24.4), Vector3(1.4, 0.7, 0.8))
	Build.prop(self, F % "chair", Vector3(-50.7, y0, -25.1), PI, 2.0)
	# armadio/libreria, lampada, tappeto, pianta
	Build.prop(self, F % "bookcaseOpen", Vector3(-48.3, y0, -20.6), PI, 2.0)
	Build.collider(self, Vector3(-48.7, y0 + 0.9, -20.8), Vector3(0.9, 1.8, 0.5))
	Build.prop(self, F % "rugRectangle", Vector3(-52.0, y0 + 0.005, -23.5), 0.0, 2.0)
	Build.prop(self, PLANT, Vector3(-47.9, y0, -28.3), 0.0, 2.6, 40.0)
	Build.prop(self, F % "radio", Vector3(-50.9, y0 + 0.66, -24.2), 0.0, 1.5)
	# bacheca con le scadenze
	Build.box(self, Vector3(-47.55, y0 + 1.6, -24.6), Vector3(0.04, 0.8, 1.1), Build.mat("cork"), false)
	Build.box(self, Vector3(-47.57, y0 + 1.6, -24.4), Vector3(0.04, 0.3, 0.25), Build.mat("paper"), false)
	interactables["board"] = Interactable.make(self, Vector3(-48.0, y0 + 1.3, -24.6), "board", func(): return "Bacheca · Prossime spese", func(): world_ui.open_bills_panel(), 1.4)
	# luce della stanza con interruttore
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(-51.0, GROUND_H - 0.5, -24.5)
	lamp.omni_range = 9.0
	lamp.light_energy = 1.8
	lamp.light_color = Color(1.0, 0.9, 0.75)
	add_child(lamp)
	interior_lights["home"] = lamp
	Build.box(self, Vector3(-51.0, GROUND_H - 0.12, -24.5), Vector3(0.5, 0.1, 0.5), Build.mat("lamp_bulb"), false)
	Build.box(self, Vector3(-47.33, y0 + 1.2, -26.0), Vector3(0.03, 0.12, 0.08), Build.mat("frame"), false)
	interactables["switch"] = Interactable.make(self, Vector3(-47.6, y0 + 1.2, -26.0), "switch", func(): return "Interruttore · " + ("Spegni" if lamp.visible else "Accendi") + " la luce", _toggle_home_light, 1.2)
	spawn_home = Vector3(-52.5, y0, -23.0)

func _toggle_home_light() -> void:
	var lamp: OmniLight3D = interior_lights["home"]
	lamp.visible = not lamp.visible
	Build.mat("lamp_bulb")
	Sfx.play("click")

func _drink_tap() -> void:
	var cd: float = float(Data.balance["tap_water"]["cooldown_game_min"])
	if GameTime.total_minutes - Inventory.last_tap_water_min < cd:
		Game.toast("Hai già bevuto da poco.", "info")
		return
	Inventory.last_tap_water_min = GameTime.total_minutes
	Needs.eat(0, float(Data.balance["tap_water"]["energy"]))
	Game.toast("Un bicchiere d'acqua del rubinetto. Energia +%d." % int(Data.balance["tap_water"]["energy"]), "ok")

# ------------------------------------------------------------------ BAR CENTRALE DA MIMMO
func _bar() -> void:
	var x0 := -6.0; var x1 := 16.0; var z0 := -56.0; var z1 := -40.0
	var floors := 3
	var top := GROUND_H + (floors - 1) * FLOOR_H
	var m := Build.mat("plaster_crema")
	var th := 0.3
	var y0 := CURB
	Build.box(self, Vector3((x0 + x1) / 2.0, CURB / 2.0, (z0 + z1) / 2.0), Vector3(x1 - x0, CURB, z1 - z0), Build.mat("floor_bar"))
	wall("x", x0, x1, z1 - th / 2.0, GROUND_H - CURB, th, m, [
		{"c": -2.0, "w": 4.5, "b": 0.6, "t": 2.8, "kind": "glass"},
		{"c": 5.0, "w": 1.6, "b": 0.0, "t": 2.4, "kind": "door"},
		{"c": 11.5, "w": 6.0, "b": 0.6, "t": 2.8, "kind": "glass"}], y0)
	wall("x", x0, x1, z0 + th / 2.0, GROUND_H - CURB, th, m, [], y0)
	wall("z", z0, z1, x0 + th / 2.0, GROUND_H - CURB, th, m, [], y0)
	wall("z", z0, z1, x1 - th / 2.0, GROUND_H - CURB, th, m, [], y0)
	Build.box(self, Vector3((x0 + x1) / 2.0, GROUND_H + (top - GROUND_H) / 2.0, (z0 + z1) / 2.0), Vector3(x1 - x0, top - GROUND_H, z1 - z0), m)
	Build.box(self, Vector3((x0 + x1) / 2.0, GROUND_H - 0.03, (z0 + z1) / 2.0), Vector3(x1 - x0 - 0.2, 0.06, z1 - z0 - 0.2), Build.mat("plaster_bar"), false)
	facade_windows("x", x0, x1, z1, 1.0, 2, floors + 1, true)
	roof(x0, x1, z0, z1, top, false)
	# insegna verde con scritte crema
	Build.box(self, Vector3(5.0, 3.05, z1 + 0.1), Vector3(9.0, 0.8, 0.12), Build.mat("sign_green"), false)
	Build.label3d(self, Vector3(5.0, 3.1, z1 + 0.17), "BAR CENTRALE  ·  da Mimmo", 80, C_CREMA)
	var hrs: Dictionary = Data.economy["bar"]["hours"]
	Build.label3d(self, Vector3(6.6, 1.55, z1 + 0.17), "Bar Centrale da Mimmo\n%s – %s\nChiuso il lunedì" % [hrs["open"], hrs["close"]], 22, Color(0.15, 0.15, 0.15))
	Build.box(self, Vector3(6.6, 1.55, z1 + 0.16), Vector3(0.9, 0.42, 0.02), Build.mat("paper"), false)
	# tenda/dehors
	Build.box(self, Vector3(5.0, 2.55, z1 + 0.9), Vector3(16, 0.06, 1.8), Build.mat("sign_green"), false)
	var d := Door.new()
	add_child(d)
	d.setup("bar", "Bar Centrale da Mimmo", 1.5, 2.3, Build.mat("door_green"), Build.mat("frame"), Build.mat("glass_shop"))
	d.position = Vector3(5.0, y0, z1 - th / 2.0)
	doors["bar"] = d
	d.lock_fn = func(outside: bool) -> String:
		if outside and not GameTime.is_open(Data.economy["bar"]["hours"]) and not Jobs.in_shift:
			return Data.t("feedback.closed", {"apertura": GameTime.next_open_text(Data.economy["bar"]["hours"])})
		return ""
	# bancone in marmo
	var cz := -50.0
	Build.box(self, Vector3(4.5, y0 + 0.55, cz), Vector3(10.0, 1.1, 0.75), Build.mat("marble"))
	Build.box(self, Vector3(4.5, y0 + 1.13, cz), Vector3(10.2, 0.06, 0.9), Build.mat("marble"), false)
	Build.box(self, Vector3(-0.45, y0 + 0.55, -52.6), Vector3(0.75, 1.1, 4.4), Build.mat("marble"))
	var F := "res://assets/props/%s.glb"
	Build.flat("gondola_dark", Color(0.32, 0.33, 0.35), 0.5, 0.5)
	# retro-banco: mobile in legno, mensole con bottiglie senza marca, macchina dell'espresso
	Build.box(self, Vector3(4.5, y0 + 0.5, -55.4), Vector3(10.0, 1.0, 0.7), Build.mat("door_wood"))
	Build.box(self, Vector3(4.5, y0 + 1.02, -55.4), Vector3(10.1, 0.04, 0.75), Build.mat("marble"), false)
	Build.box(self, Vector3(4.5, y0 + 2.0, -55.82), Vector3(10.0, 1.6, 0.04), Build.flat("mirror", Color(0.55, 0.58, 0.6), 0.05, 0.9), false)
	var unit := Build.box_mesh(Vector3.ONE)
	var bottle := CylinderMesh.new()
	bottle.top_radius = 0.35; bottle.bottom_radius = 1.0; bottle.height = 1.0; bottle.radial_segments = 8; bottle.rings = 1
	var bcols := [Color(0.25, 0.45, 0.25, 0.85), Color(0.55, 0.3, 0.12, 0.85), Color(0.8, 0.8, 0.75, 0.6), Color(0.7, 0.2, 0.15, 0.85), Color(0.9, 0.75, 0.3, 0.8)]
	for sy in [1.55, 1.95, 2.35]:
		Build.box(self, Vector3(4.5, y0 + sy, -55.62), Vector3(10.0, 0.04, 0.36), Build.mat("door_wood"), false)
		var x := 0.0
		while x < 9.4:
			var ci := rng.randi() % bcols.size()
			var h := rng.randf_range(0.22, 0.32)
			var xf := Transform3D(Basis().scaled(Vector3(0.04, h, 0.04)), Vector3(-0.2 + x, y0 + sy + 0.02 + h / 2.0, -55.62 + rng.randf_range(-0.06, 0.06)))
			Build.batch_add("bottle_%d" % ci, bottle, Build.flat("bottle_%d" % ci, bcols[ci], 0.1, 0.0), xf, false)
			x += rng.randf_range(0.11, 0.2)
	# macchina dell'espresso in acciaio con 3 gruppi e tazzine sopra
	var chrome := Build.flat("chrome", Color(0.78, 0.79, 0.8), 0.18, 0.95)
	var mx := 4.5
	Build.box(self, Vector3(mx, y0 + 1.3, -55.35), Vector3(1.3, 0.52, 0.55), chrome, false)
	Build.box(self, Vector3(mx, y0 + 1.06, -55.15), Vector3(1.32, 0.04, 0.3), Build.mat("gondola_dark"), false)
	for g in range(3):
		Build.cylinder(self, Vector3(mx - 0.4 + g * 0.4, y0 + 1.18, -55.05), 0.05, 0.08, Build.mat("gondola_dark"), false, 8)
	for i in range(8):
		Build.cylinder(self, Vector3(mx - 0.5 + i * 0.14, y0 + 1.6, -55.35), 0.035, 0.06, Build.mat("paper"), false, 8)
	Build.cylinder(self, Vector3(mx + 0.85, y0 + 1.2, -55.35), 0.12, 0.32, Build.mat("gondola_dark"), false, 10)   # macinino
	# vetrina dei cornetti sul bancone
	Build.box(self, Vector3(1.4, y0 + 1.3, cz), Vector3(1.6, 0.36, 0.6), Build.mat("glass_shop"), false)
	Build.box(self, Vector3(1.4, y0 + 1.48, cz), Vector3(1.62, 0.03, 0.62), chrome, false)
	for i in range(6):
		Build.prop(self, "res://assets/props/food/croissant.glb", Vector3(0.85 + i * 0.22, y0 + 1.17, cz + rng.randf_range(-0.1, 0.1)), rng.randf() * TAU, 0.3)
	# piattini e tazzine sul bancone
	for i in range(4):
		Build.cylinder(self, Vector3(4.0 + i * 1.3, y0 + 1.17, cz + 0.1), 0.07, 0.01, Build.mat("paper"), false, 10)
		Build.cylinder(self, Vector3(4.0 + i * 1.3, y0 + 1.2, cz + 0.1), 0.035, 0.05, Build.mat("paper"), false, 8)
	# zoccolo in piastrelle fino a 1,2 m sulle pareti interne (fondo e lati)
	Build.box(self, Vector3((x0 + x1) / 2.0, y0 + 0.6, z0 + th + 0.011), Vector3(x1 - x0 - 2 * th, 1.2, 0.02), Build.mat("walltiles"), false)
	for wx in [x0 + th + 0.011, x1 - th - 0.011]:
		Build.box(self, Vector3(wx, y0 + 0.6, (z0 + z1) / 2.0), Vector3(0.02, 1.2, z1 - z0 - 2 * th), Build.mat("walltiles"), false)
	# listino prezzi dai dati
	var lines := "LISTINO\n"
	for it in Data.economy["bar"]["menu"]:
		lines += "%s  € %s\n" % [it["name"], Data.euro(int(it["price_cents"]))]
	Build.box(self, Vector3(12.5, y0 + 2.1, z0 + 0.32), Vector3(2.0, 1.6, 0.04), Build.mat("sign_green"), false)
	Build.label3d(self, Vector3(12.5, y0 + 2.1, z0 + 0.35), lines, 26, C_CREMA)
	# sgabelli alti al bancone (acciaio e seduta in legno)
	for i in range(5):
		var sp := Vector3(0.8 + i * 1.8, y0, -48.95)
		Build.cylinder(self, sp + Vector3(0, 0.38, 0), 0.025, 0.76, chrome, false, 6)
		Build.cylinder(self, sp + Vector3(0, 0.02, 0), 0.2, 0.03, chrome, false, 10)
		Build.cylinder(self, sp + Vector3(0, 0.78, 0), 0.19, 0.05, Build.mat("door_wood"), false, 12)
		Build.collider(self, sp + Vector3(0, 0.4, 0), Vector3(0.38, 0.8, 0.38))
	# tavolini da bistrot in marmo con sedie
	for tp in [Vector3(-3.5, 0, -43.0), Vector3(10.5, 0, -43.0), Vector3(13.5, 0, -46.5), Vector3(-3.5, 0, -46.5)]:
		var c3: Vector3 = tp + Vector3(0, y0, 0)
		Build.cylinder(self, c3 + Vector3(0, 0.74, 0), 0.36, 0.03, Build.mat("marble"), false, 16)
		Build.cylinder(self, c3 + Vector3(0, 0.37, 0), 0.03, 0.72, Build.mat("iron"), false, 6)
		Build.cylinder(self, c3 + Vector3(0, 0.015, 0), 0.22, 0.03, Build.mat("iron"), false, 10)
		Build.collider(self, c3 + Vector3(0, 0.4, 0), Vector3(0.8, 0.8, 0.8))
		for ang in [0.0, PI]:
			var cp: Vector3 = c3 + Vector3(cos(ang) * 0.65, 0, sin(ang) * 0.65)
			var ch := Node3D.new()
			ch.position = cp
			ch.rotation.y = -ang + PI / 2.0
			add_child(ch)
			Build.box(ch, Vector3(0, 0.46, 0), Vector3(0.42, 0.04, 0.42), Build.mat("door_wood"), false)
			Build.box(ch, Vector3(0, 0.72, 0.2), Vector3(0.42, 0.42, 0.03), Build.mat("door_wood"), false)
			for lx in [-0.18, 0.18]:
				for lz in [-0.18, 0.18]:
					Build.box(ch, Vector3(lx, 0.23, lz), Vector3(0.025, 0.46, 0.025), Build.mat("iron"), false)
	for pp in [Vector3(-5.2, y0, -41.0), Vector3(15.2, y0, -41.0), Vector3(2.6, y0, -39.0), Vector3(7.4, y0, -39.0)]:
		Build.prop(self, PLANT, pp, rng.randf() * TAU, 3.2, 40.0)
	# lampade a sospensione (emissive, una sola luce vera per il budget mobile)
	Build.flat("pendant", Color(0.95, 0.85, 0.65), 0.5, 0.0, Color(1.0, 0.82, 0.55), 1.6)
	for lx in [1.0, 4.5, 8.0, -3.5, 11.5]:
		var lz := -50.0 if lx >= 1.0 and lx <= 8.0 else -44.5
		Build.cylinder(self, Vector3(lx, GROUND_H - 0.45, lz), 0.006, 0.8, Build.mat("iron"), false, 4)
		var shade := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.06; cone.bottom_radius = 0.22; cone.height = 0.2; cone.radial_segments = 12; cone.rings = 1
		shade.mesh = cone
		shade.material_override = Build.mat("pendant")
		shade.position = Vector3(lx, GROUND_H - 0.95, lz)
		shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shade)
	var light := OmniLight3D.new()
	light.position = Vector3(5, GROUND_H - 0.6, -48)
	light.omni_range = 16.0
	light.light_energy = 2.2
	light.light_color = Color(1.0, 0.92, 0.8)
	add_child(light)
	interior_lights["bar"] = light
	interactables["bar_counter"] = Interactable.make(self, Vector3(6.5, y0 + 1.1, -49.2), "bar_counter", func(): return "Bancone · Ordina / Lavoro", func(): world_ui.open_bar_panel(), 1.7)

# ------------------------------------------------------------------ MARKET IL GIRASOLE
func _market() -> void:
	var x0 := 8.0; var x1 := 28.0; var z0 := 7.0; var z1 := 23.0
	var floors := 2
	var top := GROUND_H + (floors - 1) * FLOOR_H
	var m := Build.mat("plaster_giallo")
	var th := 0.3
	var y0 := CURB
	Build.box(self, Vector3((x0 + x1) / 2.0, CURB / 2.0, (z0 + z1) / 2.0), Vector3(x1 - x0, CURB, z1 - z0), Build.mat("floor_market"))
	wall("x", x0, x1, z0 + th / 2.0, GROUND_H - CURB, th, m, [
		{"c": 12.0, "w": 5.0, "b": 0.5, "t": 2.8, "kind": "glass"},
		{"c": 18.0, "w": 1.8, "b": 0.0, "t": 2.4, "kind": "door"},
		{"c": 24.0, "w": 5.0, "b": 0.5, "t": 2.8, "kind": "glass"}], y0)
	wall("x", x0, x1, z1 - th / 2.0, GROUND_H - CURB, th, m, [], y0)
	wall("z", z0, z1, x0 + th / 2.0, GROUND_H - CURB, th, m, [], y0)
	wall("z", z0, z1, x1 - th / 2.0, GROUND_H - CURB, th, m, [], y0)
	Build.box(self, Vector3((x0 + x1) / 2.0, GROUND_H + (top - GROUND_H) / 2.0, (z0 + z1) / 2.0), Vector3(x1 - x0, top - GROUND_H, z1 - z0), m)
	Build.box(self, Vector3((x0 + x1) / 2.0, GROUND_H - 0.03, (z0 + z1) / 2.0), Vector3(x1 - x0 - 0.2, 0.06, z1 - z0 - 0.2), Build.mat("plaster_int"), false)
	facade_windows("x", x0, x1, z0, -1.0, 2, floors + 1, false)
	roof(x0, x1, z0, z1, top, true)
	Build.box(self, Vector3(18.0, 3.05, z0 - 0.1), Vector3(10.0, 0.8, 0.12), Build.mat("sign_yellow"), false)
	Build.label3d(self, Vector3(18.0, 3.1, z0 - 0.17), "MARKET  Il Girasole", 84, Color("#3A2A10"), PI)
	var hrs: Dictionary = Data.economy["minimarket"]["hours"]
	Build.box(self, Vector3(16.3, 1.55, z0 - 0.16), Vector3(0.9, 0.42, 0.02), Build.mat("paper"), false)
	Build.label3d(self, Vector3(16.3, 1.55, z0 - 0.18), "Market Il Girasole\n%s – %s\nDomenica chiuso" % [hrs["open"], hrs["close"]], 22, Color(0.15, 0.15, 0.15), PI)
	# volantini in vetrina
	for i in range(3):
		Build.box(self, Vector3(10.5 + i * 1.4, 1.6, z0 + 0.02), Vector3(0.7, 0.9, 0.02), Build.mat("paper"), false)
		Build.label3d(self, Vector3(10.5 + i * 1.4, 1.6, z0 - 0.0), ["OFFERTA\nPasta\n€ 1,20", "Pane\nfresco\nogni\nmattina", "Frutta\nbanane\n€ 2,00/kg"][i], 18, Color(0.75, 0.12, 0.1), PI)
	var d := Door.new()
	add_child(d)
	d.setup("market", "Market Il Girasole", 1.6, 2.3, Build.mat("metal_grey"), Build.mat("frame"), Build.mat("glass_shop"))
	d.position = Vector3(18.0, y0, z0 + th / 2.0)
	d.rotation.y = PI   # esterno verso -Z (strada)
	doors["market"] = d
	d.lock_fn = func(outside: bool) -> String:
		if outside and not GameTime.is_open(Data.economy["minimarket"]["hours"]):
			return Data.t("feedback.closed", {"apertura": GameTime.next_open_text(Data.economy["minimarket"]["hours"])})
		return ""
	# 4 corsie corte con scaffali e prodotti
	var groups := [
		{"title": "Pane e colazione", "ids": ["pane_500g", "latte_1l", "biscotti", "banane_1kg"], "props": ["loaf", "carton", "cookie", "banana"]},
		{"title": "Pasta e dispensa", "ids": ["pasta_500g", "sugo_pronto", "tonno_3x80", "uova_6"], "props": ["bag", "can", "can", "egg"]},
		{"title": "Pronti e surgelati", "ids": ["panino_pronto", "pizza_surgelata"], "props": ["sandwich", "pizza-box"]},
		{"title": "Bevande", "ids": ["acqua_15l", "energy_drink"], "props": ["soda-bottle", "can"]},
	]
	for gi in groups.size():
		var g: Dictionary = groups[gi]
		var sx := 14.0 + gi * 3.6
		_gondola(Vector3(sx, y0, 16.5), g["ids"])
		Build.label3d(self, Vector3(sx, y0 + 2.45, 13.4), g["title"], 30, Color("#3A2A10"), PI)
		Build.box(self, Vector3(sx, y0 + 2.45, 13.42), Vector3(1.9, 0.32, 0.02), Build.mat("sign_yellow"), false)
		for side in [-1.0, 1.0]:
			var gid := "shelf_%d" % gi
			Interactable.make(self, Vector3(sx + side * 0.9, y0 + 1.0, 16.5), gid, func(): return "Scaffale %s · Prezzi e acquisti" % g["title"], func(): world_ui.open_shop_panel(g["title"], g["ids"]), 2.9)
	_market_fridge(y0)
	for pp in [Vector3(15.6, y0, 6.3), Vector3(20.4, y0, 6.3)]:
		Build.prop(self, PLANT, pp, rng.randf() * TAU, 3.0, 40.0)
	# cassa
	Build.box(self, Vector3(11.0, y0 + 0.5, 11.5), Vector3(1.0, 1.0, 2.6), Build.mat("door_wood"))
	Build.box(self, Vector3(11.0, y0 + 1.02, 11.5), Vector3(1.1, 0.05, 2.7), Build.mat("marble"), false)
	interactables["cassa"] = Interactable.make(self, Vector3(12.0, y0 + 1.0, 11.0), "cassa", func(): return "Cassa · Tutti i prodotti", func(): world_ui.open_shop_panel("Tutti i prodotti", Data.products_by_id.keys()), 1.6)
	var light := OmniLight3D.new()
	light.position = Vector3(18, GROUND_H - 0.6, 15)
	light.omni_range = 16.0
	light.light_energy = 2.0
	light.light_color = Color(0.95, 0.97, 1.0)
	add_child(light)
	interior_lights["market"] = light
	Build.box(self, Vector3(18, GROUND_H - 0.1, 15), Vector3(8, 0.06, 0.3), Build.mat("lamp_bulb"), false)

## Forma e colore delle confezioni (mesh semplici ripetute con MultiMesh, nessun marchio)
const PACKS := {
	"pane_500g": ["box", Vector3(0.24, 0.11, 0.12), Color("#B8834A")],
	"latte_1l": ["box", Vector3(0.07, 0.2, 0.07), Color("#F2F2EE")],
	"biscotti": ["box", Vector3(0.19, 0.06, 0.12), Color("#D9822B")],
	"banane_1kg": ["box", Vector3(0.22, 0.08, 0.13), Color("#E8C93A")],
	"pasta_500g": ["box", Vector3(0.09, 0.2, 0.05), Color("#2C4E9A")],
	"sugo_pronto": ["cyl", Vector3(0.04, 0.11, 0.04), Color("#B3261E")],
	"tonno_3x80": ["cyl", Vector3(0.045, 0.045, 0.045), Color("#C9CCCF")],
	"uova_6": ["box", Vector3(0.2, 0.07, 0.1), Color("#D8C7A6")],
	"panino_pronto": ["box", Vector3(0.16, 0.06, 0.08), Color("#EFE3C6")],
	"pizza_surgelata": ["box", Vector3(0.28, 0.04, 0.28), Color("#C8402E")],
	"acqua_15l": ["cyl", Vector3(0.045, 0.31, 0.045), Color(0.62, 0.8, 0.92)],
	"energy_drink": ["cyl", Vector3(0.033, 0.13, 0.033), Color("#2E8B57")],
}
static var _pack_mesh := {}

func _pack(id: String, xf: Transform3D) -> void:
	var spec: Array = PACKS.get(id, ["box", Vector3(0.1, 0.1, 0.1), Color.GRAY])
	if not _pack_mesh.has(spec[0]):
		if spec[0] == "box":
			_pack_mesh["box"] = Build.box_mesh(Vector3.ONE)
		else:
			var cm := CylinderMesh.new()
			cm.top_radius = 1.0; cm.bottom_radius = 1.0; cm.height = 1.0; cm.radial_segments = 8; cm.rings = 1
			_pack_mesh["cyl"] = cm
	var sz: Vector3 = spec[1]
	var scale := sz if spec[0] == "box" else Vector3(sz.x, sz.y, sz.x)
	var m := Build.flat("pack_" + id, spec[2], 0.55)
	Build.batch_add("pack_" + id, _pack_mesh[spec[0]], m, Transform3D(xf.basis.scaled(scale), xf.origin + Vector3(0, sz.y / 2.0, 0)), false)

## Scaffale metallico a gondola: schienale forato, 4 ripiani per lato, file di prodotti piccoli e cartellini prezzo.
func _gondola(c: Vector3, ids: Array) -> void:
	var L := 6.0
	Build.flat("gondola", Color(0.78, 0.79, 0.8), 0.45, 0.55)
	Build.flat("gondola_dark", Color(0.32, 0.33, 0.35), 0.5, 0.5)
	Build.box(self, c + Vector3(0, 0.07, 0), Vector3(1.0, 0.14, L), Build.mat("gondola_dark"))
	Build.box(self, c + Vector3(0, 1.0, 0), Vector3(0.06, 1.85, L), Build.mat("gondola"))
	Build.collider(self, c + Vector3(0, 1.0, 0), Vector3(1.0, 2.0, L))
	for e in [-1.0, 1.0]:
		Build.box(self, c + Vector3(0, 1.0, e * L / 2.0), Vector3(1.0, 1.95, 0.05), Build.mat("gondola"), false)
	var levels := [0.16, 0.56, 0.96, 1.36]
	var unit := Build.box_mesh(Vector3.ONE)
	var seg := L / float(ids.size())
	for side in [-1.0, 1.0]:
		for ly in levels:
			Build.batch_add("gondola_shelf", unit, Build.mat("gondola"), Transform3D(Basis().scaled(Vector3(0.45, 0.025, L - 0.1)), c + Vector3(side * 0.25, ly, 0)), false)
			Build.batch_add("price_rail", unit, Build.mat("paper"), Transform3D(Basis().scaled(Vector3(0.012, 0.04, L - 0.1)), c + Vector3(side * 0.48, ly - 0.01, 0)), false)
		for k in ids.size():
			var id: String = ids[k]
			var spec: Array = PACKS.get(id, ["box", Vector3(0.1, 0.1, 0.1), Color.GRAY])
			var w: float = (spec[1].z if spec[0] == "box" else spec[1].x * 2.0) + 0.025
			var dpt: float = (spec[1].x if spec[0] == "box" else spec[1].x * 2.0) + 0.02
			var z0: float = c.z - L / 2.0 + seg * k + 0.08
			var n := int((seg - 0.16) / w)
			var stock_ratio := 0.75 + rng.randf() * 0.25
			for ly in levels:
				for i in n:
					if rng.randf() > stock_ratio:
						continue
					for dd in range(2):
						var x: float = c.x + side * (0.43 - dpt / 2.0 - dd * dpt)
						var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.06, 0.06)), Vector3(x, ly + 0.013, z0 + w * (i + 0.5)))
						_pack(id, xf)
			var p: Dictionary = Data.products_by_id[id]
			var tag := Build.label3d(self, Vector3(c.x + side * 0.495, levels[1] - 0.012, z0 + seg / 2.0 - 0.08), "%s  € %s" % [p["name"], Data.euro(int(p["price_cents"]))], 11, Color(0.1, 0.1, 0.1), side * PI / 2.0)
			tag.width = 220

## Frigo a vetri lungo la parete di fondo, con luce fredda.
func _market_fridge(y0: float) -> void:
	var z := 22.35
	Build.flat("fridge_body", Color(0.9, 0.91, 0.92), 0.4, 0.3)
	Build.flat("fridge_inner", Color(0.85, 0.9, 1.0), 0.6, 0.0, Color(0.8, 0.9, 1.0), 0.6)
	Build.box(self, Vector3(18.0, y0 + 1.05, z), Vector3(9.0, 2.1, 0.7), Build.mat("fridge_body"))
	Build.box(self, Vector3(18.0, y0 + 1.1, z - 0.3), Vector3(8.6, 1.7, 0.04), Build.mat("fridge_inner"), false)
	Build.box(self, Vector3(18.0, y0 + 1.1, z - 0.37), Vector3(8.6, 1.7, 0.02), Build.mat("glass_shop"), false)
	var unit := Build.box_mesh(Vector3.ONE)
	for k in range(6):
		Build.batch_add("fridge_mullion", unit, Build.mat("fridge_body"), Transform3D(Basis().scaled(Vector3(0.05, 1.75, 0.05)), Vector3(13.7 + k * 1.72, y0 + 1.1, z - 0.4)), false)
	for ly in [0.45, 0.85, 1.25, 1.62]:
		for i in range(52):
			var id: String = ["latte_1l", "energy_drink", "acqua_15l", "latte_1l"][int(ly * 10) % 4] if i % 3 != 0 else "energy_drink"
			_pack(id, Transform3D(Basis(), Vector3(13.85 + i * 0.165, y0 + ly, z - 0.22)))
	Build.label3d(self, Vector3(18.0, y0 + 2.3, z - 0.37), "FRESCHI E BEVANDE", 30, Color("#3A2A10"), PI)

const PLANT := "res://assets/props/ph_potted_plant_04/potted_plant_04.gltf"
const COVERED_CAR := "res://assets/props/ph_covered_car/covered_car.gltf"

# ------------------------------------------------------------------ arredo urbano
func _street_furniture() -> void:
	var lamp_pos := []
	for i in range(-9, 10):
		lamp_pos.append([Vector3(i * 10.0 + 3.0, CURB, -4.6), 0.0])
		if i % 2 == 0:
			lamp_pos.append([Vector3(i * 10.0 - 2.0, CURB, 4.6), PI])
	for j in range(1, 9):
		lamp_pos.append([Vector3(-44.6, CURB, -8.0 - j * 10.0), PI / 2.0])
	lamp_pos.append([Vector3(-8.5, CURB, -38.5), 0.0])
	lamp_pos.append([Vector3(28.5, CURB, -38.5), 0.0])
	var lit_near := [Vector3(10, 0, -24), Vector3(5, 0, -5), Vector3(18, 0, 5), Vector3(-40, 0, -27), Vector3(-25, 0, -5), Vector3(-44, 0, -18), Vector3(28, 0, -38), Vector3(-8, 0, -38)]
	for lp in lamp_pos:
		var p: Vector3 = lp[0]
		var n := Build.prop(self, "res://assets/props/street_lamp_01.glb", p, lp[1], 1.15, 55.0, false)
		Build.cylinder(self, p + Vector3(0, 2.0, 0), 0.09, 4.0, Build.mat("iron"), true, 6).visible = false
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.16; sm.height = 0.32
		bulb.mesh = sm
		bulb.material_override = Build.mat("lamp_bulb")
		bulb.position = p + Vector3(0, 4.15, 0)
		add_child(bulb)
	# luci vere solo sui lampioni principali (budget mobile)
	for q in lit_near:
		var l := OmniLight3D.new()
		l.position = Vector3(q.x, 4.0, q.z)
		l.omni_range = 13.0
		l.light_energy = 0.0
		l.light_color = C_SODIO
		add_child(l)
		lamp_lights.append(l)
	# cassonetti della differenziata
	var bins := [["bin_y", "plastica"], ["bin_b", "carta"], ["bin_g", "vetro"], ["bin_m", "organico"]]
	for i in bins.size():
		var p := Vector3(-8.0 + i * 1.0, CURB, 6.3)
		Build.box(self, p + Vector3(0, 0.6, 0), Vector3(0.9, 1.2, 0.9), Build.mat(bins[i][0]))
	# aiuole al posto dell'erba lungo Via dei Tigli (fuori dalla casa)
	_planter(-48.0, -47.05, -100.0 + 2.0, -36.0)
	_planter(-48.0, -47.05, -19.0, -7.2)
	_planter(-32.95, -32.0, -98.0, -84.0)
	_planter(-32.95, -32.0, -62.0, -36.0)
	# segnali stradali generici
	for sx in [-70.0, -15.0, 40.0, 75.0]:
		_road_sign(Vector3(sx, CURB, 4.3), "sosta", PI)
	_road_sign(Vector3(-44.4, CURB, -60.0), "senso", PI / 2.0)
	# auto parcheggiate anche su Via dei Tigli
	_car(Vector3(-37.2, 0.02, -62.0), 0.0, "hatchback-sports")
	_car(Vector3(-37.2, 0.02, -76.0), PI, "sedan")
	# cartelli stradali
	_street_sign(Vector3(-46.8, CURB, -6.8), "Via Roma Vecchia", 0.0)
	_street_sign(Vector3(-47.0, CURB, -9.0), "Via dei Tigli", PI / 2.0)
	_street_sign(Vector3(-9.0, CURB, -6.8), "Piazza della Fontana", 0.0)
	# auto parcheggiate lungo Via Roma Vecchia
	var kinds := ["sedan", "hatchback-sports", "van", "sedan", "suv", "hatchback-sports", "sedan", "delivery"]
	var xs := [-82.5, -67.5, -57.5, -22.5, -2.5, 32.5, 52.5, 77.5]
	for i in xs.size():
		_car(Vector3(xs[i], 0.02, 2.6), PI / 2.0 if i % 2 == 0 else -PI / 2.0, kinds[i])
	# alberi nei giardini dietro le case (sud) e al parco nord
	for i in range(14):
		var p := Vector3(-90 + i * 13.0 + rng.randf_range(-3, 3), 0, rng.randf_range(28, 90))
		_tree(p)
	for i in range(10):
		var p := Vector3(rng.randf_range(-10, 90), 0, rng.randf_range(-92, -62))
		_tree(p)
	for i in range(6):
		var p := Vector3(rng.randf_range(-95, -65), 0, rng.randf_range(-92, -25))
		_tree(p)

func _tree(p: Vector3) -> void:
	Build.prop(self, "res://assets/props/shrub_02.glb", p + Vector3(0, 0.6, 0), rng.randf() * TAU, rng.randf_range(0.7, 1.1), 50.0, false)
	Build.collider(self, p + Vector3(0, 1.0, 0), Vector3(1.5, 2.0, 1.5))

func _street_sign(p: Vector3, text: String, rot: float) -> void:
	Build.box(self, p + Vector3(0, 1.3, 0), Vector3(0.07, 2.6, 0.07), Build.mat("metal_grey"))
	var n := Node3D.new()
	n.position = p + Vector3(0, 2.5, 0)
	n.rotation.y = rot
	add_child(n)
	Build.box(n, Vector3(0, 0, 0), Vector3(1.8, 0.35, 0.03), Build.mat("barrier_w"), false)
	Build.label3d(n, Vector3(0, 0, 0.02), text, 32, Color(0.1, 0.1, 0.1))
	Build.label3d(n, Vector3(0, 0, -0.02), text, 32, Color(0.1, 0.1, 0.1), PI)

func _boundaries() -> void:
	# muretto e siepe al confine + barriere "Strada chiusa" dove finiscono le strade
	for s in [-1.0, 1.0]:
		Build.box(self, Vector3(0, 0.6, s * 99.5), Vector3(200, 1.2, 1.0), Build.mat("hedge"))
		Build.box(self, Vector3(s * 99.5, 0.6, 0), Vector3(1.0, 1.2, 200), Build.mat("hedge"))
		Build.collider(self, Vector3(0, 5, s * 100.5), Vector3(202, 10, 1))
		Build.collider(self, Vector3(s * 100.5, 5, 0), Vector3(1, 10, 202))
	for p in [[Vector3(-97.5, 0, 0), PI / 2.0], [Vector3(97.5, 0, 0), PI / 2.0], [Vector3(-40, 0, -97.5), 0.0]]:
		var n := Node3D.new()
		n.position = p[0]
		n.rotation.y = p[1]
		add_child(n)
		for k in range(8):
			Build.box(n, Vector3(-3.5 + k, 0.5, 0), Vector3(0.95, 1.0, 0.4), Build.mat("barrier_r" if k % 2 == 0 else "barrier_w"), false)
		Build.label3d(n, Vector3(0, 1.35, 0.25), "STRADA CHIUSA · Lavori in corso", 40, Color(0.1, 0.1, 0.1))
		Build.label3d(n, Vector3(0, 1.35, -0.25), "STRADA CHIUSA · Lavori in corso", 40, Color(0.1, 0.1, 0.1), PI)
		Build.collider(self, p[0] + Vector3(0, 1, 0), Vector3(8, 2, 0.6) if p[1] == 0.0 else Vector3(0.6, 2, 8))

## Chiamato da DayNight: accende lampioni e finestre di sera.
func set_night(f: float) -> void:
	for l in lamp_lights:
		l.light_energy = 1.6 * f
		l.visible = f > 0.05   # di giorno spente davvero: niente passate di luce extra
	Build.mat("lamp_bulb").emission_energy_multiplier = 3.0 * f
	Build.mat("glass_lit").emission_energy_multiplier = 2.6 * f
	for k in interior_lights:
		var il: OmniLight3D = interior_lights[k]
		il.distance_fade_enabled = true
		il.distance_fade_begin = 22.0
		il.distance_fade_length = 6.0
	for l in lamp_lights:
		l.distance_fade_enabled = true
		l.distance_fade_begin = 35.0
		l.distance_fade_length = 8.0
	for k in ["bar", "market"]:
		var hrs: Dictionary = Data.economy["bar" if k == "bar" else "minimarket"]["hours"]
		interior_lights[k].visible = GameTime.is_open(hrs) or (k == "bar" and Jobs.in_shift)
