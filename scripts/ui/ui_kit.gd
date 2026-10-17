class_name UIKit
extends RefCounted
## Stile UI di Spark: pannelli scuri semitrasparenti, angoli 12 px, accento corallo, font Inter.

const CORAL := Color("#E8664A")
const PANEL := Color(0.102, 0.102, 0.102, 0.86)
const GREEN := Color("#5BC17A")
const RED := Color("#F06A5A")
const MUTED := Color(1, 1, 1, 0.65)

static func sb(c: Color, r: int = 12, pad: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(r)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	return s

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = load("res://assets/fonts/Inter.ttf")
	t.default_font_size = 22
	t.set_stylebox("normal", "Button", sb(Color(0.24, 0.24, 0.24, 0.95)))
	t.set_stylebox("hover", "Button", sb(Color(0.32, 0.32, 0.32, 0.95)))
	t.set_stylebox("pressed", "Button", sb(CORAL.darkened(0.2)))
	t.set_stylebox("disabled", "Button", sb(Color(0.2, 0.2, 0.2, 0.6)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.4))
	t.set_stylebox("panel", "PanelContainer", sb(PANEL, 16, 16))
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_stylebox("background", "ProgressBar", sb(Color(1, 1, 1, 0.15), 6, 0))
	t.set_stylebox("fill", "ProgressBar", sb(CORAL, 6, 0))
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	return t

static func label(text: String, size: int = 22, col: Color = Color.WHITE, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func button(text: String, cb: Callable, accent: bool = false, min_h: int = 56) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	if accent:
		b.add_theme_stylebox_override("normal", sb(CORAL))
		b.add_theme_stylebox_override("hover", sb(CORAL.lightened(0.1)))
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b

static func bar(value: float, col: Color) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0
	p.max_value = 100
	p.value = value
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, 12)
	p.add_theme_stylebox_override("fill", sb(col, 6, 0))
	return p
