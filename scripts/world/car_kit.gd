class_name CarKit
extends RefCounted
## v0.3: auto realistiche low-poly (Quaternius CC0 via Poly Pizza, RGS_Dev CC0), materiali PBR
## rifatti in Blender (vernice con clearcoat, vetri lucidi, gomme opache). Colore della vernice per istanza.

const MODELS := {
	"ginestra": "res://assets/cars_v03/ginestra.glb",   # utilitaria 3,6 m
	"corallo": "res://assets/cars_v03/corallo.glb",     # compatta 4,05 m
	"suv": "res://assets/cars_v03/suv.glb",
	"hatch": "res://assets/cars_v03/hatch.glb",
	"sedan": "res://assets/cars_v03/sedan.glb",
	"van": "res://assets/cars_v03/van.glb",
	"rotta": "res://assets/cars_v03/rotta.glb",
}
const PALETTE := [Color("#E9E7E2"), Color("#B9BCC0"), Color("#3A3D42"), Color("#1F2A44"), Color("#6B1E24"), Color("#9DB2C4"), Color("#C9C2B2"), Color("#2F4A3A"), Color("#B33A2E"), Color("#1A1A1C")]
const LENGTH := {"ginestra": 3.6, "corallo": 4.05, "suv": 4.4, "hatch": 4.0, "sedan": 4.5, "van": 4.9, "rotta": 4.2}

static var _paint_cache: Dictionary = {}
static var _trim: StandardMaterial3D = null

static func trim_mat() -> StandardMaterial3D:
	if _trim == null:
		_trim = StandardMaterial3D.new()
		_trim.vertex_color_use_as_albedo = true
		_trim.vertex_color_is_srgb = true
		_trim.roughness = 0.55
		_trim.metallic = 0.15
	return _trim

static func paint_mat(c: Color) -> StandardMaterial3D:
	var k := c.to_html()
	if _paint_cache.has(k):
		return _paint_cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.45
	m.roughness = 0.3
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.06
	_paint_cache[k] = m
	return m

## Modello visivo dell'auto (senza fisica). Il muso guarda verso -Z.
static func model(parent: Node, kind: String, color: Color, vis_end: float = 70.0) -> Node3D:
	var ps: PackedScene = load(MODELS.get(kind, MODELS["sedan"]))
	var n: Node3D = ps.instantiate()
	parent.add_child(n)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		if vis_end > 0.0:
			g.visibility_range_end = vis_end
			g.visibility_range_end_margin = 4.0
		for s in g.mesh.get_surface_count():
			var sm := g.mesh.surface_get_material(s)
			if sm and sm.resource_name == "Paint" and kind != "rotta":
				g.set_surface_override_material(s, paint_mat(color))
			elif sm and sm.resource_name == "Trim":
				g.set_surface_override_material(s, trim_mat())
	return n

## Auto parcheggiata (decorazione con collisione).
static func parked(parent: Node3D, kind: String, pos: Vector3, yaw: float, color: Color) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	model(root, kind, color)
	var len: float = LENGTH.get(kind, 4.2)
	var sz := Vector3(1.8, 1.5, len)
	Build.collider(parent, pos + Vector3(0, 0.75, 0), sz if absf(sin(yaw)) < 0.5 else Vector3(len, 1.5, 1.8))
	return root
