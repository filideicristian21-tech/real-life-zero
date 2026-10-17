class_name TouchButton
extends Button
## Pulsante multi-touch: reagisce a InputEventScreenTouch anche mentre un altro dito tiene il joystick.
## Il mouse (desktop) funziona tramite 'pressed'; un doppio evento touch+mouse viene filtrato.

signal activated()
var _last_fire_ms := -1000
var active_touches := {}

func _ready() -> void:
	pressed.connect(_from_mouse)
	focus_mode = Control.FOCUS_NONE

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or disabled:
		return
	if event is InputEventScreenTouch and event.pressed and get_global_rect().has_point(event.position):
		_fire()
		get_viewport().set_input_as_handled()

func _from_mouse() -> void:
	if Time.get_ticks_msec() - _last_fire_ms > 350:
		_fire()

func _fire() -> void:
	_last_fire_ms = Time.get_ticks_msec()
	activated.emit()
