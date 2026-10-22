extends Node
## Bisogni 0-100 (100 = meglio): fame (sazietà), energia, sonno. Cambiano con GameTime.minute_passed.

signal needs_changed()
signal fainted()
signal warning(kind: String)

var hunger: float = 70.0
var energy: float = 80.0
var sonno: float = 85.0
var activity: String = "idle"   # idle | walk | run | work | sleep
var sleep_quality_malus: float = 0.0
var _warned := {}
var paused_decay := false

func _ready() -> void:
	GameTime.minute_passed.connect(_on_minutes)

func reset_new_game() -> void:
	hunger = float(Data.economy["start"]["hunger"])
	energy = float(Data.economy["start"]["energy"])
	sonno = float(Data.balance["sonno"]["start"])
	activity = "idle"
	sleep_quality_malus = 0.0
	_warned.clear()
	needs_changed.emit()

func _on_minutes(dm: float) -> void:
	if paused_decay or activity == "sleep":
		return
	apply_awake_hours(dm / 60.0, activity)

## Decadimento da sveglio per h ore con l'attività data.
func apply_awake_hours(h: float, act: String) -> void:
	var dec: Dictionary = Data.economy["needs_decay_per_game_hour"]
	var thr: Dictionary = Data.economy["needs_thresholds"]
	var sc: Dictionary = Data.balance["sonno"]
	hunger -= float(dec["hunger"]) * h
	var e_rate: float = float(dec["energy_working"]) if act == "work" else float(dec["energy_awake"])
	if act == "run":
		e_rate += float(dec["energy_running_extra"])
	if hunger < float(thr["hunger_warning"]):
		e_rate += float(thr["hunger_penalty_energy_per_hour"])
	if sonno < float(sc["low_threshold"]):
		e_rate += float(sc["low_energy_extra_per_hour"])
	energy -= e_rate * h
	sonno -= float(sc["decay_per_game_hour_awake"]) * h
	_clamp()
	_check_warnings()
	needs_changed.emit()
	if energy <= float(Data.balance["faint"]["energy_at_or_below"]):
		fainted.emit()

## Sonno per h ore: recupera energia e sonno, la fame scende più piano.
func apply_sleep_hours(h: float) -> void:
	var s: Dictionary = Data.economy["sleep"]
	var sc: Dictionary = Data.balance["sonno"]
	var q: float = max(0.0, 1.0 - sleep_quality_malus / 100.0)
	energy += Life.sleep_energy_per_hour() * h * q
	sonno += float(sc["recover_per_sleep_hour"]) * h * q
	hunger -= float(s["hunger_per_hour"]) * h
	sleep_quality_malus = 0.0
	_clamp()
	_warned.clear()
	needs_changed.emit()

func eat(hunger_gain: float, energy_gain: float) -> void:
	hunger += hunger_gain
	energy += energy_gain
	_clamp()
	needs_changed.emit()

func can_run() -> bool:
	return energy >= float(Data.economy["needs_thresholds"]["energy_min_to_run"])

func _clamp() -> void:
	hunger = clampf(hunger, 0.0, 100.0)
	energy = clampf(energy, 0.0, float(Life.energy_max))
	sonno = clampf(sonno, 0.0, 100.0)

func _check_warnings() -> void:
	var thr: Dictionary = Data.economy["needs_thresholds"]
	_warn_if("fame", hunger < float(thr["hunger_warning"]))
	_warn_if("energia", energy < float(thr["energy_min_to_work"]))
	_warn_if("sonno", sonno < float(Data.balance["sonno"]["low_threshold"]))

func _warn_if(k: String, cond: bool) -> void:
	if cond and not _warned.get(k, false):
		_warned[k] = true
		warning.emit(k)
	elif not cond:
		_warned[k] = false

func to_dict() -> Dictionary:
	return {"hunger": hunger, "energy": energy, "sonno": sonno, "sleep_quality_malus": sleep_quality_malus}

func from_dict(d: Dictionary) -> void:
	hunger = float(d.get("hunger", 70)); energy = float(d.get("energy", 80)); sonno = float(d.get("sonno", 85))
	sleep_quality_malus = float(d.get("sleep_quality_malus", 0))
	activity = "idle"
	_clamp()
	needs_changed.emit()
