class_name Wc3Button
extends Button
## Knopf der Steinsäule im Hauptmenü (Wc3Theme): spitzes Sechseck mit Messingrand, innen Fels (Hauptknopf, rot)
## oder Stein (klein, dunkel), eine dünne Innenlinie folgt der Außenform. Der Hotkey-Buchstabe ist hell.

const TIP := 14.0

var main := false
## Text ohne Übersetzung; gezeigt wird tr(label_text).
var label_text := ""
## Stelle des Hotkey-Buchstabens im übersetzten Text, -1 = keiner.
var hotkey := -1
## Erklärung für die Hinweiszeile unter dem Logo.
var description := ""

var _tex: Texture2D


func _init(text_de: String, is_main: bool) -> void:
	label_text = text_de
	main = is_main
	custom_minimum_size.y = 56 if main else 46
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	for s in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	_tex = load(Wc3Theme.ROCK if main else Wc3Theme.STONE)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func shown_text() -> String:
	return tr(label_text)


func font_size() -> int:
	if main:
		return 22
	return 16 if size.x < 260 else 18


func _draw() -> void:
	var hover := is_hovered() and not disabled
	var down := is_pressed() or button_pressed
	var r := Rect2(Vector2.ZERO, size)
	var outer := Wc3Theme.hex(r, TIP)
	if hover and main:
		# Glühen um den roten Knopf
		for i in 4:
			draw_polyline(Wc3Theme.closed(Wc3Theme.hex(r.grow(1.5 + i * 1.5), TIP + 1 + i)), Color(1.0, 0.45, 0.2, 0.12 - i * 0.025), 2.0, true)
	draw_colored_polygon(outer, Wc3Theme.GOLD_HI if hover else Wc3Theme.GOLD)
	draw_line(Vector2(TIP, 1), Vector2(size.x - TIP, 1), Wc3Theme.GOLD_HI, 2.0)
	draw_line(Vector2(TIP, size.y - 1), Vector2(size.x - TIP, size.y - 1), Wc3Theme.GOLD_LO, 2.0)
	var fr := r.grow(-3)
	var face := Wc3Theme.hex(fr, TIP - 2)
	var tint: Color
	if main:
		tint = Wc3Theme.RED_HOVER if hover else Wc3Theme.RED
	else:
		tint = Wc3Theme.DARK_HOVER if hover else Wc3Theme.DARK
	if down:
		tint = tint.darkened(0.25)
	Wc3Theme.fill_textured(self, face, _tex, 180.0 if main else 200.0, tint)
	# Innenschatten: nach innen dunkler werdende Ränder, oben ein schwacher Lichtstreif, unten Schatten
	for i in 5:
		draw_polyline(Wc3Theme.closed(Wc3Theme.hex(fr.grow(-1.5 - i * 2.0), TIP - 2 - i)), Color(0, 0, 0, 0.22 - i * 0.04), 2.0, true)
	draw_line(Vector2(TIP + 2, 5), Vector2(size.x - TIP - 2, 5), Color(1.0, 0.86, 0.63, 0.1), 2.0)
	draw_line(Vector2(TIP + 2, size.y - 6), Vector2(size.x - TIP - 2, size.y - 6), Color(0, 0, 0, 0.35), 3.0)
	draw_polyline(Wc3Theme.closed(face), Wc3Theme.INK, 1.0, true)
	# Innenlinie folgt der spitzen Außenform, 6 px nach innen versetzt
	var i := 6.0
	var tip := TIP - 2
	var w := size.x
	var h := size.y
	var inner := PackedVector2Array([Vector2(tip + i * 0.6, i), Vector2(w - tip - i * 0.6, i), Vector2(w - i * 1.3, h / 2),
		Vector2(w - tip - i * 0.6, h - i), Vector2(tip + i * 0.6, h - i), Vector2(i * 1.3, h / 2)])
	draw_polyline(Wc3Theme.closed(inner), Color(Wc3Theme.GOLD_HI, 0.45), 1.0, true)
	_draw_text(hover, down)


func _draw_text(hover: bool, down: bool) -> void:
	var text := shown_text()
	var fs := font_size()
	var f := Wc3Theme.font(2 if main else 1)
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2((size.x - tw) / 2, (size.y + f.get_ascent(fs) - f.get_descent(fs)) / 2)
	if down:
		pos += Vector2(0, 1)
	var col := Wc3Theme.HOT if hover else Wc3Theme.TEXT
	if disabled:
		col = Wc3Theme.MUTED
	# Schatten, dann Text in drei Teilen, damit der Hotkey-Buchstabe heller sein kann
	f.draw_string(get_canvas_item(), pos + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.BLACK)
	if hotkey < 0 or hotkey >= text.length():
		f.draw_string(get_canvas_item(), pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	else:
		var x := pos.x
		for part in [[text.substr(0, hotkey), col], [text.substr(hotkey, 1), Wc3Theme.HOT], [text.substr(hotkey + 1), col]]:
			f.draw_string(get_canvas_item(), Vector2(x, pos.y), part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, part[1])
			x += f.get_string_size(part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
