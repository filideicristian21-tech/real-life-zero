class_name Build
extends RefCounted
## Utility di costruzione: materiali PBR condivisi, box con collisione, MultiMesh per elementi ripetuti.

static var _mats: Dictionary = {}
static var _tex: Dictionary = {}

static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load("res://assets/textures/%s.jpg" % name)
	return _tex[name]

## Materiale PBR con texture triplanare in coordinate mondo (scala coerente su ogni muro).
static func pbr(key: String, tex_name: String, tint: Color, uv: float = 0.5, rough: float = 0.9, normal_scale: float = 0.6) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(tex_name + "_albedo")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = tex(tex_name + "_normal")
	m.normal_scale = normal_scale
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(uv, uv, uv)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m

static func flat(key: String, c: Color, rough: float = 0.8, metal: float = 0.0, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m

static func mat(key: String) -> StandardMaterial3D:
	return _mats.get(key)

## Box visivo (+ collisione opzionale). pos = centro, size = dimensioni.
static func box(parent: Node, pos: Vector3, size: Vector3, m: Material, collide: bool = true, rot_y: float = 0.0, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot_y
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	if collide:
		collider(parent, pos, size, rot_y)
	return mi

static func collider(parent: Node, pos: Vector3, size: Vector3, rot_y: float = 0.0) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	sb.position = pos
	sb.rotation.y = rot_y
	sb.collision_layer = 1
	sb.collision_mask = 0
	parent.add_child(sb)
	return sb

static func cylinder(parent: Node, pos: Vector3, r: float, h: float, m: Material, collide: bool = true, segs: int = 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = r
		sh.height = h
		cs.shape = sh
		sb.add_child(cs)
		sb.position = pos
		sb.collision_mask = 0
		parent.add_child(sb)
	return mi

static func label3d(parent: Node, pos: Vector3, text: String, size: int, col: Color, rot_y: float = 0.0, outline: int = 0, width: float = 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/Inter.ttf")
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = col
	l.outline_size = outline
	l.position = pos
	l.rotation.y = rot_y
	l.double_sided = false
	if size <= 30:
		l.visibility_range_end = 32.0   # cartellini e avvisi piccoli: non si leggono da lontano
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.width = width
	parent.add_child(l)
	return l

## Istanzia un modello GLB (prop). Ritorna il Node3D.
## vis_end > 0: oltre questa distanza il modello non viene disegnato (budget mobile).
static func prop(parent: Node, path: String, pos: Vector3, rot_y: float = 0.0, scale: float = 1.0, vis_end: float = 0.0, shadows: bool = true) -> Node3D:
	var ps: PackedScene = load(path)
	var n: Node3D = ps.instantiate()
	n.position = pos
	n.rotation.y = rot_y
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
	if vis_end > 0.0 or not shadows:
		for g in n.find_children("*", "GeometryInstance3D", true, false):
			if vis_end > 0.0:
				g.visibility_range_end = vis_end
				g.visibility_range_end_margin = 4.0
				g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			if not shadows:
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

# ---------------- MultiMesh batch ----------------
class Batch:
	var mesh: Mesh
	var material: Material
	var xforms: Array[Transform3D] = []
	var shadows := true

static var batches: Dictionary = {}

static func batch_add(key: String, mesh: Mesh, m: Material, xf: Transform3D, shadows: bool = true) -> void:
	if not batches.has(key):
		var b := Batch.new()
		b.mesh = mesh
		b.material = m
		b.shadows = shadows
		batches[key] = b
	batches[key].xforms.append(xf)

static func flush_batches(parent: Node) -> int:
	var n := 0
	for k in batches:
		var b: Batch = batches[k]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = b.mesh
		mm.instance_count = b.xforms.size()
		for i in b.xforms.size():
			mm.set_instance_transform(i, b.xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "MM_" + k
		mmi.multimesh = mm
		mmi.material_override = b.material
		if not b.shadows:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
		n += b.xforms.size()
	batches.clear()
	return n

static func box_mesh(size: Vector3) -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = size
	return bm

## Batching statico: i box e i cilindri figli diretti di parent (decorazioni fisse) diventano MultiMesh
## raggruppati per materiale e per zona di 48 m. Le collisioni restano nei loro StaticBody.
## Riduce le draw call di circa 3-4 volte (budget mobile/web).
static func static_batch(parent: Node) -> int:
	var unit_box := box_mesh(Vector3.ONE)
	var cyl_units := {}
	var groups := {}
	var n := 0
	for c in parent.get_children():
		if not (c is MeshInstance3D) or not c.visible or c.material_override == null:
			continue
		var mi: MeshInstance3D = c
		var mesh: Mesh = null
		var scale := Vector3.ONE
		var key := ""
		if mi.mesh is BoxMesh:
			mesh = unit_box
			scale = (mi.mesh as BoxMesh).size
			key = "b"
		elif mi.mesh is CylinderMesh and absf((mi.mesh as CylinderMesh).top_radius - (mi.mesh as CylinderMesh).bottom_radius) < 0.0001:
			var cm: CylinderMesh = mi.mesh
			var segs := cm.radial_segments
			if not cyl_units.has(segs):
				var u := CylinderMesh.new()
				u.top_radius = 1.0; u.bottom_radius = 1.0; u.height = 1.0; u.radial_segments = segs; u.rings = 1
				cyl_units[segs] = u
			mesh = cyl_units[segs]
			scale = Vector3(cm.top_radius, cm.height, cm.top_radius)
			key = "c%d" % segs
		elif mi.mesh is SphereMesh:
			var sm: SphereMesh = mi.mesh
			if not cyl_units.has("s"):
				var us := SphereMesh.new()
				us.radius = 0.5; us.height = 1.0; us.radial_segments = 12; us.rings = 6
				cyl_units["s"] = us
			mesh = cyl_units["s"]
			scale = Vector3(sm.radius * 2.0, sm.height, sm.radius * 2.0)
			key = "s"
		else:
			continue
		var chunk := Vector2i(floori(mi.position.x / 48.0), floori(mi.position.z / 48.0))
		var shadows := mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var gk := "%s|%d|%s|%s" % [key, mi.material_override.get_instance_id(), chunk, shadows]
		if not groups.has(gk):
			groups[gk] = {"mesh": mesh, "mat": mi.material_override, "shadows": shadows, "xf": []}
		groups[gk]["xf"].append(Transform3D(mi.transform.basis.scaled(scale), mi.position))
		parent.remove_child(mi)
		mi.queue_free()
		n += 1
	for gk in groups:
		var g: Dictionary = groups[gk]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = g["mesh"]
		mm.instance_count = g["xf"].size()
		for i in g["xf"].size():
			mm.set_instance_transform(i, g["xf"][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = g["mat"]
		if not g["shadows"]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
	return n

## LOD a distanza automatico: gli oggetti piccoli spariscono da lontano (budget draw call mobile).
static func auto_lod(parent: Node) -> int:
	var n := 0
	var stack: Array[Node] = [parent]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			stack.append(c)
		if not node is GeometryInstance3D or node is MultiMeshInstance3D:
			continue   # i MultiMesh hanno l'origine in (0,0,0): la distanza non sarebbe quella vera
		var g: GeometryInstance3D = node
		var box: AABB = g.get_aabb()
		var s: Vector3 = g.global_transform.basis.get_scale()
		var d: float = maxf(box.size.x * s.x, maxf(box.size.y * s.y, box.size.z * s.z))
		if d < 0.9:
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # ombre solo per oggetti grandi
		if g.visibility_range_end > 0.0:
			continue
		var r := 0.0
		if d < 0.6:
			r = 22.0
		elif d < 1.6:
			r = 34.0
		elif d < 4.0:
			r = 55.0
		if r > 0.0:
			g.visibility_range_end = r
			g.visibility_range_end_margin = 2.0
			n += 1
	return n
