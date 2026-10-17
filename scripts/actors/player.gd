class_name Player
extends CharacterBody3D
## Luca Ferraro: terza persona, joystick/tastiera, corsa se l'energia lo consente, camera SpringArm.

var model: CharacterModel
var cam_yaw_node: Node3D
var cam_pitch_node: Node3D
var spring: SpringArm3D
var camera: Camera3D
var move_input := Vector2.ZERO        # dal joystick virtuale
var run_toggle := false               # dal pulsante Corri
var input_enabled := true
var current_target: Interactable = null
var walk_speed := 2.4
var run_speed := 5.2
var _step_t := 0.0
var _step_i := 0
var is_running := false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var moved_distance := 0.0

func _ready() -> void:
	var pc: Dictionary = Data.balance["player"]
	walk_speed = float(pc["walk_speed"])
	run_speed = float(pc["run_speed"])
	collision_layer = 2
	collision_mask = 1 | 4
	floor_max_angle = deg_to_rad(60)
	floor_snap_length = 0.35
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	model = CharacterModel.new()
	add_child(model)
	# Spark: felpa grigia, jeans blu scuro, sneakers bianche
	model.load_model("res://assets/characters/luca.glb", {"Purple": Color("#6E6F72"), "LightBlue": Color("#2B3A55")})
	# camera
	cam_yaw_node = Node3D.new()
	cam_yaw_node.top_level = true
	add_child(cam_yaw_node)
	cam_pitch_node = Node3D.new()
	cam_yaw_node.add_child(cam_pitch_node)
	spring = SpringArm3D.new()
	spring.spring_length = float(Data.balance["camera"]["distance"])
	spring.collision_mask = 1
	spring.margin = 0.25
	var sph := SphereShape3D.new()
	sph.radius = 0.22
	spring.shape = sph
	spring.add_excluded_object(get_rid())
	cam_pitch_node.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 65
	camera.near = 0.08
	camera.far = 260
	spring.add_child(camera)
	cam_pitch_node.rotation.x = deg_to_rad(-16)

func set_yaw(y: float) -> void:
	model.rotation.y = y
	cam_yaw_node.rotation.y = y + PI

func get_yaw() -> float:
	return model.rotation.y

func rotate_camera(delta: Vector2) -> void:
	var c: Dictionary = Data.balance["camera"]
	cam_yaw_node.rotation.y -= delta.x
	cam_pitch_node.rotation.x = clampf(cam_pitch_node.rotation.x - delta.y, deg_to_rad(float(c["min_pitch_deg"])), deg_to_rad(float(c["max_pitch_deg"])))

func _physics_process(delta: float) -> void:
	cam_yaw_node.global_position = global_position + Vector3(0, 1.55, 0)
	var dir2 := Vector2.ZERO
	if input_enabled and Game.playing:
		dir2 = move_input
		var k := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if k.length() > 0.1:
			dir2 = k
	if dir2.length() > 1.0:
		dir2 = dir2.normalized()
	var yaw := cam_yaw_node.rotation.y
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var dir := right * dir2.x + fwd * -dir2.y
	var want_run := (run_toggle or Input.is_action_pressed("run")) and dir.length() > 0.2
	if want_run and not Needs.can_run():
		want_run = false
		if run_toggle:
			run_toggle = false
			Game.toast(Data.t("feedback.too_tired_run"), "warn")
	is_running = want_run
	var speed := (run_speed if is_running else walk_speed) * clampf(dir2.length(), 0.0, 1.0)
	var target_v := dir.normalized() * speed if dir.length() > 0.05 else Vector3.ZERO
	var accel := float(Data.balance["player"]["accel"])
	velocity.x = lerpf(velocity.x, target_v.x, clampf(accel * delta, 0, 1))
	velocity.z = lerpf(velocity.z, target_v.z, clampf(accel * delta, 0, 1))
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.5
	var before := global_position
	move_and_slide()
	var hv := Vector2(velocity.x, velocity.z)
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	moved_distance += moved
	if moved_distance > 3.0:
		Game.tutorial_event("moved")
	if hv.length() > 0.3:
		var target_yaw := atan2(velocity.x, velocity.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, clampf(float(Data.balance["player"]["turn_speed"]) * delta, 0, 1))
		model.play("run" if is_running else "walk", 1.0 if is_running else clampf(hv.length() / walk_speed, 0.6, 1.3))
		_step_t -= delta * (1.6 if is_running else 1.0)
		if _step_t <= 0.0:
			_step_t = 0.42
			_step_i = 1 - _step_i
			Sfx.play("step%d" % _step_i, Vector3.INF, -16.0)
	else:
		model.play("idle")
	if Jobs.in_shift:
		Needs.activity = "work"
	elif not Game.sleeping:
		Needs.activity = "run" if is_running else ("walk" if hv.length() > 0.3 else "idle")
	_update_target()

func _update_target() -> void:
	var best: Interactable = null
	var best_score := 1e9
	var fwd := Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Interactable
		if it == null or not it.is_visible_in_tree():
			continue
		var to := it.global_position - global_position
		to.y = 0
		var d := to.length()
		if d > it.radius:
			continue
		var facing := fwd.dot(to.normalized()) if d > 0.1 else 1.0
		var score := d - facing * 0.6
		if score < best_score:
			best_score = score
			best = it
	current_target = best

func try_interact() -> void:
	if current_target and input_enabled:
		model.play_once("interact")
		current_target.interact()

func teleport(pos: Vector3, yaw: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	set_yaw(yaw)
	cam_yaw_node.global_position = global_position + Vector3(0, 1.55, 0)
