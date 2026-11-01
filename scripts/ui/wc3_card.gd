class_name Wc3Card
extends Button
## Map-Karte der Einzelspieler-Seite im Warcraft-III-Stil (Wc3Theme): dunkle Steinfläche, Messingrahmen mit
## Innenlinie und kleinen Eckrauten. Gewählt: heller Messingrand, warmes Glühen, Ecken als Schrauben.

var _stone: Texture2D


func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	for s in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	_stone = load(Wc3Theme.STONE)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	toggled.connect(func(_on): queue_redraw())


func _draw() -> void:
	var hover := is_hovered()
	var on := button_pressed
	var r := Rect2(Vector2.ZERO, size)
	var shape := Wc3Theme.cut_rect(r, 8)
	if on:
		for i in 5:
			draw_polyline(Wc3Theme.closed(Wc3Theme.cut_rect(r.grow(2 + i * 2), 9 + i)), Color(1.0, 0.6, 0.25, 0.16 - i * 0.03), 3.0, true)
	Wc3Theme.fill_textured(self, shape, _stone, 220.0, Wc3Theme.DARK_HOVER if hover or on else Wc3Theme.CARD)
	draw_polyline(Wc3Theme.closed(shape), Wc3Theme.INK, 3.0, true)
	var rim := Wc3Theme.GOLD_HI if on else (Wc3Theme.GOLD if hover else Wc3Theme.GOLD_LO)
	draw_polyline(Wc3Theme.closed(Wc3Theme.cut_rect(r.grow(-2), 7)), rim, 2.0 if on else 1.5, true)
	draw_polyline(Wc3Theme.closed(Wc3Theme.cut_rect(r.grow(-6), 5)), Color(rim, 0.45), 1.0, true)
	if on:
		for p in [Vector2(9, 9), Vector2(size.x - 9, 9), Vector2(size.x - 9, size.y - 9), Vector2(9, size.y - 9)]:
			Wc3Theme.screw(self, p, deg_to_rad(30 + p.x))
