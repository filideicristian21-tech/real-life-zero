class_name TouchJoystick
extends Control
## Joystick virtuale (metà sinistra): appare dove tocchi, multi-touch con indice del dito.

signal changed(v: Vector2)
var touch_index := -1
var center := Vector2.ZERO
var knob := Vector2.ZERO
var value := Vector2.ZERO
var radius := 90.0
var area_ratio := 0.42   # frazione sinistra dello schermo che attiva il joystick
var enabled := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _rest_center() -> Vector2:
	var s := get_viewport_rect().size
	return Vector2(radius + 70, s.y - radius - 70)

func _input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree():
		if touch_index != -1:
			_release()
		return
	var s := get_viewport_rect().size
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1 and event.position.x < s.x * area_ratio and event.position.y > s.y * 0.25:
			touch_index = event.index
			center = event.position
			_update(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == touch_index:
			_release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == touch_index:
		_update(event.position)
		get_viewport().set_input_as_handled()

func _update(p: Vector2) -> void:
	var d := p - center
	if d.length() > radius:
		d = d.normalized() * radius
	knob = d
	value = d / radius
	if value.length() < 0.12:
		value = Vector2.ZERO
	changed.emit(value)
	queue_redraw()

func _release() -> void:
	touch_index = -1
	value = Vector2.ZERO
	knob = Vector2.ZERO
	changed.emit(value)
	queue_redraw()

func _draw() -> void:
	var c := center if touch_index != -1 else _rest_center()
	draw_circle(c, radius, Color(1, 1, 1, 0.10))
	draw_arc(c, radius, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	draw_circle(c + knob, radius * 0.42, Color(1, 1, 1, 0.55 if touch_index != -1 else 0.3))
