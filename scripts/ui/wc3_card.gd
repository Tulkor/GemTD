class_name Wc3Card
extends Button
## Map-Karte im Warcraft-III-Stil (Wc3Theme): dunkle Steinfläche, Rahmen aus Messing-Rundstäben mit Schrauben
## in den Ecken (3D-Renders). Gewählt: helles Messing und warmes Glühen; sonst dunkler.

var _stone: Texture2D
var _brass: Wc3Theme.BrassLayer


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
	_brass = Wc3Theme.BrassLayer.new(_draw_brass)
	add_child(_brass)
	resized.connect(_brass.queue_redraw)


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
	_brass.modulate = Color(1.2, 1.15, 1.05) if on else (Color(0.95, 0.95, 0.95) if hover else Color(0.62, 0.6, 0.58))


func _draw_brass(ci: CanvasItem) -> void:
	Wc3Theme.frame(ci, Rect2(Vector2.ZERO, size), 7.0, 8.0)
	for p in [Vector2(8, 8), Vector2(size.x - 8, 8), Vector2(size.x - 8, size.y - 8), Vector2(8, size.y - 8)]:
		Wc3Theme.screw(ci, p, deg_to_rad(30 + p.x), 15.0)
