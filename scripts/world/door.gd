class_name Door
extends Node3D
## Porta vera: anta su cerniera con collisione che si apre/chiude con Interagisci.
## lock_fn(outside: bool) -> String : motivo per cui è chiusa a chiave ("" = si apre).

signal opened(door)
signal closed(door)

var id := ""
var label := "Porta"
var is_open := false
var lock_fn: Callable
var hinge: Node3D
var body: AnimatableBody3D
var width := 1.2
var auto_close_s := 6.0
var _timer := 0.0
var _tween: Tween
var interact_point: Interactable
var outward_sign := 1.0   # direzione locale +Z = esterno

func setup(p_id: String, p_label: String, w: float, h: float, mat_panel: Material, mat_frame: Material, glass: Material = null) -> void:
	id = p_id
	label = p_label
	width = w
	name = "Door_" + id
	hinge = Node3D.new()
	hinge.position = Vector3(-w / 2.0, 0, 0)
	add_child(hinge)
	body = AnimatableBody3D.new()
	body.sync_to_physics = false
	body.collision_layer = 1
	hinge.add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(w - 0.04, h, 0.07)
	cs.shape = sh
	cs.position = Vector3(w / 2.0, h / 2.0, 0)
	body.add_child(cs)
	var panel := MeshInstance3D.new()
	panel.mesh = Build.box_mesh(Vector3(w - 0.04, h, 0.06))
	panel.material_override = mat_panel
	panel.position = Vector3(w / 2.0, h / 2.0, 0)
	body.add_child(panel)
	if glass:
		var g := MeshInstance3D.new()
		g.mesh = Build.box_mesh(Vector3(w - 0.3, h * 0.55, 0.08))
		g.material_override = glass
		g.position = Vector3(w / 2.0, h * 0.58, 0)
		body.add_child(g)
	var handle := MeshInstance3D.new()
	handle.mesh = Build.box_mesh(Vector3(0.14, 0.03, 0.16))
	handle.material_override = Build.flat("handle", Color(0.75, 0.75, 0.72), 0.3, 0.9)
	handle.position = Vector3(w - 0.14, 1.0, 0)
	body.add_child(handle)
	# telaio
	for x in [-w / 2.0 - 0.05, w / 2.0 + 0.05]:
		var fr := MeshInstance3D.new()
		fr.mesh = Build.box_mesh(Vector3(0.1, h + 0.1, 0.3))
		fr.material_override = mat_frame
		fr.position = Vector3(x, (h + 0.1) / 2.0, 0)
		add_child(fr)
	var top := MeshInstance3D.new()
	top.mesh = Build.box_mesh(Vector3(w + 0.2, 0.1, 0.3))
	top.material_override = mat_frame
	top.position = Vector3(0, h + 0.05, 0)
	add_child(top)
	interact_point = Interactable.make(self, Vector3(0, 1.0, 0), "door_" + id, _prompt, _toggle, 1.9)

func _player_outside() -> bool:
	if Game.player == null:
		return true
	var local := to_local(Game.player.global_position)
	return local.z * outward_sign > 0.0

func _prompt() -> String:
	if is_open:
		return "Chiudi: " + label
	var lock := _lock_reason()
	if lock != "":
		return "%s · %s" % [label, lock]
	return "Apri: " + label

func _lock_reason() -> String:
	if lock_fn.is_valid():
		return lock_fn.call(_player_outside())
	return ""

func _toggle() -> void:
	if is_open:
		close()
	else:
		var lock := _lock_reason()
		if lock != "":
			Game.toast(lock, "warn")
			Sfx.play("error")
			return
		open()

func open() -> void:
	if is_open:
		return
	is_open = true
	_timer = auto_close_s
	# si apre verso l'interno (lontano dal giocatore)
	var ang := PI / 2.0 if _player_outside() else -PI / 2.0
	ang *= outward_sign
	_anim(ang)
	Sfx.play("door_open", global_position)
	opened.emit(self)

func close() -> void:
	if not is_open:
		return
	is_open = false
	_anim(0.0)
	Sfx.play("door_close", global_position)
	closed.emit(self)

func _anim(target: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(hinge, "rotation:y", target, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Usato dai test: apertura/chiusura istantanea senza animazione.
func set_open_immediate(v: bool) -> void:
	is_open = v
	if _tween:
		_tween.kill()
	hinge.rotation.y = (PI / 2.0 * outward_sign) if v else 0.0

func _process(delta: float) -> void:
	if is_open and auto_close_s > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			if Game.player and Game.player.global_position.distance_to(global_position) < 1.6:
				_timer = 1.0
			else:
				close()
