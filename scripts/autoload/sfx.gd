extends Node
## Effetti sonori (Kenney, CC0). Pool semplice, niente musica commerciale.

var streams: Dictionary = {}
var pool: Array[AudioStreamPlayer] = []
var muted := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in ["door_open", "door_close", "coins", "step0", "step1", "click", "error", "confirm", "phone_open", "phone_close", "cup", "notify"]:
		streams[n] = load("res://assets/audio/%s.ogg" % n)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)

func play(name: String, at: Vector3 = Vector3.INF, vol_db: float = 0.0) -> void:
	if muted or not streams.has(name):
		return
	var v := vol_db
	if at != Vector3.INF and Game.player:
		var d: float = Game.player.global_position.distance_to(at)
		if d > 25.0:
			return
		v -= d * 0.6
	for p in pool:
		if not p.playing:
			p.stream = streams[name]
			p.volume_db = v
			p.play()
			return
