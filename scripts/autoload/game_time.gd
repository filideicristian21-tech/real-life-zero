extends Node
## Unica fonte di tempo del gioco. total_minutes = minuti di gioco dal giorno 1 alle 00:00.

signal minute_passed(delta_min: float)
signal hour_changed(hour: int)
signal day_changed(day: int)

var total_minutes: float = 0.0
var running: bool = false
var speed_mult: float = 1.0
var _last_hour: int = -1
var _last_day: int = -1
var _pending: float = 0.0

func game_minutes_per_real_second() -> float:
	var rs: float = float(Data.balance.get("time", {}).get("real_seconds_per_game_day", 1200))
	return 1440.0 / max(rs, 1.0)

func reset_new_game() -> void:
	var tcfg: Dictionary = Data.balance.get("time", {})
	var start_day: int = int(tcfg.get("start_day", 1))
	total_minutes = float((start_day - 1) * 1440 + Data.hhmm_to_min(str(tcfg.get("start_time", "07:00"))))
	speed_mult = 1.0
	_sync_marks()

func _sync_marks() -> void:
	_last_hour = hour()
	_last_day = day()

func _process(delta: float) -> void:
	if not running:
		return
	_pending += delta * game_minutes_per_real_second() * speed_mult
	if _pending >= 1.0:
		var step := floorf(_pending)
		_pending -= step
		advance(step)

## Avanza il tempo di dm minuti (usato da _process, dal sonno e dai test).
func advance(dm: float) -> void:
	var remaining := dm
	while remaining > 0.0:
		var step: float = min(remaining, 60.0)
		total_minutes += step
		remaining -= step
		minute_passed.emit(step)
		var h := hour()
		var d := day()
		if d != _last_day:
			_last_day = d
			_last_hour = h
			day_changed.emit(d)
		elif h != _last_hour:
			_last_hour = h
			hour_changed.emit(h)

func day() -> int:
	return int(total_minutes / 1440.0) + 1

func minute_of_day() -> int:
	return int(total_minutes) % 1440

func hour() -> int:
	return minute_of_day() / 60

func weekday_index(d: int = -1) -> int:
	if d < 0:
		d = day()
	return (d - 1) % 7

func weekday_code(d: int = -1) -> String:
	return Data.balance["time"]["weekdays"][weekday_index(d)]

func weekday_name(d: int = -1) -> String:
	return Data.balance["time"]["weekday_names"][weekday_index(d)]

func clock_text() -> String:
	return Data.min_to_hhmm(minute_of_day())

func short_label() -> String:
	return "%s %s" % [weekday_code().capitalize(), clock_text()]

## Ritorna true se un luogo con orari {open, close, closed_days} è aperto adesso.
func is_open(hours: Dictionary, at_total: float = -1.0) -> bool:
	var tm: float = total_minutes if at_total < 0.0 else at_total
	var d := int(tm / 1440.0) + 1
	var m := int(tm) % 1440
	if weekday_code(d) in hours.get("closed_days", []):
		return false
	return m >= Data.hhmm_to_min(hours["open"]) and m < Data.hhmm_to_min(hours["close"])

## Testo dell'orario di riapertura.
func next_open_text(hours: Dictionary) -> String:
	var t := total_minutes
	for i in range(0, 8 * 24 * 4):
		t += 15.0
		if is_open(hours, t):
			var d := int(t / 1440.0) + 1
			var label := Data.min_to_hhmm(Data.hhmm_to_min(hours["open"]))
			if d == day():
				return label
			elif d == day() + 1:
				return "domani alle " + label
			return "%s alle %s" % [weekday_name(d).to_lower(), label]
	return "?"

func to_dict() -> Dictionary:
	return {"total_minutes": total_minutes}

func from_dict(d: Dictionary) -> void:
	total_minutes = float(d.get("total_minutes", 420.0))
	speed_mult = 1.0
	_pending = 0.0
	_sync_marks()
