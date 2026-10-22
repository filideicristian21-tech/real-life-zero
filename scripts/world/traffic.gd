class_name Traffic
extends Node3D
## Traffico d'ambiente su Via Roma Vecchia: poche auto (budget mobile), 30 km/h, si fermano per
## pedoni, giocatore e auto davanti. Arrivate in fondo al paese girano dietro le transenne e tornano.

const LANE_E := 0.95      # corsia verso est (+x)
const LANE_W := -1.9      # corsia verso ovest (−x)
const X_END := 93.0
var cars: Array = []      # {node, dir, x, v, wait}

func build(n: int = 4) -> void:
	var kinds := ["sedan", "hatch", "suv", "van", "corallo", "ginestra"]
	for i in n:
		var root := Node3D.new()
		add_child(root)
		CarKit.model(root, kinds[i % kinds.size()], CarKit.PALETTE[(i * 3 + 1) % CarKit.PALETTE.size()], 75.0)
		var dir := 1 if i % 2 == 0 else -1
		var c := {"node": root, "dir": dir, "x": -80.0 + i * 47.0, "v": 0.0, "wait": 0.0}
		cars.append(c)
		_place(c)

func _place(c: Dictionary) -> void:
	var n: Node3D = c["node"]
	n.position = Vector3(c["x"], 0.02, LANE_E if c["dir"] > 0 else LANE_W)
	n.rotation.y = -PI / 2.0 if c["dir"] > 0 else PI / 2.0

func _blocked(c: Dictionary) -> bool:
	var p: Vector3 = (c["node"] as Node3D).position
	var dir: int = c["dir"]
	for n in get_tree().get_nodes_in_group("pedestrian"):
		if not (n as Node3D).is_visible_in_tree():
			continue
		var q := (n as Node3D).global_position
		var ahead := (q.x - p.x) * dir
		if ahead > 1.0 and ahead < 8.5 and absf(q.z - p.z) < 1.9:
			return true
	for o in cars:
		if o == c or o["dir"] != dir:
			continue
		var ahead2 := (float(o["x"]) - float(c["x"])) * dir
		if ahead2 > 0.0 and ahead2 < 7.5:
			return true
	var pc: Node3D = Game.player.car if Game.player and "car" in Game.player else null
	if pc:
		var a3: float = (pc.global_position.x - p.x) * dir
		if a3 > 0.0 and a3 < 8.0 and absf(pc.global_position.z - p.z) < 1.8:
			return true
	return false

func _physics_process(dt: float) -> void:
	for c in cars:
		if float(c["wait"]) > 0.0:
			c["wait"] = float(c["wait"]) - dt
			(c["node"] as Node3D).visible = false
			if float(c["wait"]) <= 0.0:
				c["dir"] = -int(c["dir"])
				c["x"] = X_END * -int(c["dir"])
				(c["node"] as Node3D).visible = true
				_place(c)
			continue
		var target := 0.0 if _blocked(c) else 8.3     # 30 km/h
		c["v"] = move_toward(float(c["v"]), target, (12.0 if target == 0.0 else 3.0) * dt)
		c["x"] = float(c["x"]) + float(c["v"]) * int(c["dir"]) * dt
		if absf(float(c["x"])) > X_END:
			c["wait"] = 6.0
		_place(c)
