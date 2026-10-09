class_name SpeechBubble
extends Control
## Sprechblase mit Spitze nach oben, die auf einen anderen Knopf zeigt.
## Klick auf den Text löst `pressed` aus, das × schließt sie (`dismissed`).

signal pressed
signal dismissed

const TAIL := 13.0
const COLOR := Color("e2b54a")

var target: Control
var label: Label
var _panel: PanelContainer
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.position.y = TAIL
	_panel.add_theme_stylebox_override("panel", UiTheme.box(COLOR, UiTheme.GOLD_DARK, 10, 0, 10))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_panel.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit())
	add_child(_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(h)
	label = Label.new()
	label.add_theme_color_override("font_color", UiTheme.GOLD_DARK)
	label.add_theme_font_size_override("font_size", 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(label)
	var close := Button.new()
	close.text = "×"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.tooltip_text = "Bis zur nächsten Stufe ausblenden"
	close.add_theme_font_size_override("font_size", 16)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		close.add_theme_color_override(k, UiTheme.GOLD_DARK)
	close.pressed.connect(func(): dismissed.emit())
	h.add_child(close)


func set_text(text: String) -> void:
	label.text = text


func _process(delta: float) -> void:
	if not visible or target == null:
		return
	_t += delta / maxf(Engine.time_scale, 0.01)  # gleich schnell bei jedem Spieltempo
	size = _panel.get_combined_minimum_size() + Vector2(0, TAIL)
	_panel.size = _panel.get_combined_minimum_size()
	var r := target.get_global_rect()
	var x := clampf(r.get_center().x - size.x / 2.0, 8.0, get_viewport_rect().size.x - size.x - 8.0)
	global_position = Vector2(x, r.end.y + 4.0 + 3.0 * sin(_t * 4.0))
	queue_redraw()


func _draw() -> void:
	if target == null:
		return
	# Spitze zeigt auf die Mitte des Zielknopfs
	var tip_x := clampf(target.get_global_rect().get_center().x - global_position.x, 16.0, size.x - 16.0)
	draw_colored_polygon(PackedVector2Array([Vector2(tip_x - TAIL, TAIL + 1), Vector2(tip_x, 0), Vector2(tip_x + TAIL, TAIL + 1)]), COLOR)
