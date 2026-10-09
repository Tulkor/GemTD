class_name UiUtil
extends RefCounted
## Kleine Helfer, um Oberflächen im Code zu bauen.


static func label(text: String, parent: Node = null, font_size := 0) -> Label:
	var l := Label.new()
	l.text = text
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	if parent:
		parent.add_child(l)
	return l


static func wrap_label(text: String, parent: Node, width: float) -> Label:
	var l := label(text, parent)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


static func button(text: String, parent: Node, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	return b


static func spin(parent: Node, value: float, min_v: float, max_v: float, step: float, on_changed: Callable) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.allow_greater = true
	s.value = value
	s.custom_minimum_size.x = 96
	s.value_changed.connect(on_changed)
	parent.add_child(s)
	return s


static func row(text: String, parent: Node, label_width := 150.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := label(text, h)
	l.custom_minimum_size.x = label_width
	parent.add_child(h)
	return h


## Seitenpanel rechts am Bildschirmrand, gibt die VBox für den Inhalt zurück.
static func side_panel(layer: CanvasLayer, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -width
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	return box
