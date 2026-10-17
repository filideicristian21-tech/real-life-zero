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
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.width = width
	parent.add_child(l)
	return l

## Istanzia un modello GLB (prop). Ritorna il Node3D.
static func prop(parent: Node, path: String, pos: Vector3, rot_y: float = 0.0, scale: float = 1.0) -> Node3D:
	var ps: PackedScene = load(path)
	var n: Node3D = ps.instantiate()
	n.position = pos
	n.rotation.y = rot_y
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
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
