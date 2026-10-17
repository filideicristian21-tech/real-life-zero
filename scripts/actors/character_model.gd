class_name CharacterModel
extends Node3D
## Wrapper di un personaggio GLB rigged (Quaternius, CC0): animazioni idle/walk/run/interact in loop.

var ap: AnimationPlayer
var anims := {}
var current := ""
var one_shot := false

func load_model(path: String, recolor: Dictionary = {}) -> void:
	var inst: Node3D = load(path).instantiate()
	add_child(inst)
	ap = inst.find_children("*", "AnimationPlayer", true, false)[0]
	for a in ap.get_animation_list():
		var short: String = a.split("|")[-1].replace("Man_", "").replace("Female_", "").to_lower()
		anims[short] = a
	for k in ["idle", "walk", "run", "standing"]:
		if anims.has(k):
			var anim: Animation = ap.get_animation(anims[k])
			anim.loop_mode = Animation.LOOP_LINEAR
	if not anims.has("interact"):
		for alt in ["pickup", "clapping", "wave", "yes"]:
			if anims.has(alt):
				anims["interact"] = anims[alt]
				break
	ap.animation_finished.connect(func(_n): one_shot = false)
	if not recolor.is_empty():
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				var m = mi.mesh.surface_get_material(i)
				if m and recolor.has(m.resource_name):
					var nm: StandardMaterial3D = m.duplicate()
					nm.albedo_color = recolor[m.resource_name]
					mi.set_surface_override_material(i, nm)
	play("idle")

func play(state: String, speed: float = 1.0) -> void:
	if one_shot and state != "interact":
		return
	if not anims.has(state):
		state = "idle"
	if state == current and ap.is_playing():
		ap.speed_scale = speed
		return
	current = state
	ap.play(anims[state], 0.2)
	ap.speed_scale = speed

func play_once(state: String) -> void:
	if not anims.has(state):
		return
	one_shot = true
	current = state
	ap.play(anims[state], 0.1)
	ap.speed_scale = 1.4
