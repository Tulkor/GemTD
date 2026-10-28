class_name ItemIcon
extends Control
## Gezeichnetes Symbol eines eeveTD-Items (Klinge, Ärmel, Klaue, Hammer, Kette, Kugel, Schild, Trank, Phiole,
## Holz) in einem Kästchen mit der Stufe als römische Zahl unten rechts. Leer = freier Platz.
## Farben aus UiTheme (Druidenhain), Kugeln in ihrer Farbe aus den Daten.

const ROMAN := ["", "I", "II", "III", "IV"]

var item_id := ""
var selected := false
var empty_text := ""   ## Text in einem leeren Platz (z. B. "+")


func _init(size_px := 52.0) -> void:
	custom_minimum_size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_item(id: String, sel := false) -> void:
	item_id = id
	selected = sel
	queue_redraw()


## Farbe nach Stufe: Verbrauchs-Items hell-messing, sonst von Stufe 1 bis 4 heller und edler.
static func tint(id: String) -> Color:
	var it := EeveItems.item(id)
	if it.has("color"):
		return Color(str(it.color))
	match int(it.get("stage", 0)):
		1:
			return UiTheme.TEXT
		2:
			return UiTheme.HAVE
		3:
			return UiTheme.PURPLE_LIGHT
		4:
			return UiTheme.COIN
	return UiTheme.CYAN


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, UiTheme.PANEL_2)
	var edge := UiTheme.CYAN if selected else UiTheme.BORDER
	draw_rect(r.grow(-0.5), edge, false, 2.0 if selected else 1.0)
	if item_id == "":
		if empty_text != "":
			var f := UiTheme.font()
			var fs := int(size.y * 0.4)
			var w := f.get_string_size(empty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, Vector2((size.x - w) / 2.0, size.y / 2.0 + fs * 0.35), empty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.BORDER)
		return
	var c := tint(item_id)
	var s := size.x
	var m := Vector2(s, s) / 2.0
	var u := s / 52.0  # Strichstärke wächst mit der Größe
	match str(EeveItems.item(item_id).get("icon", "")):
		"blade":
			draw_line(m + Vector2(-12, 12) * u, m + Vector2(13, -13) * u, c, 4.0 * u)
			draw_line(m + Vector2(-13, 5) * u, m + Vector2(-5, 13) * u, UiTheme.GOLD, 3.0 * u)
			draw_line(m + Vector2(-12, 12) * u, m + Vector2(-17, 17) * u, UiTheme.MUTED, 3.0 * u)
		"sleeve":
			draw_colored_polygon(PackedVector2Array([m + Vector2(-9, -14) * u, m + Vector2(9, -14) * u,
				m + Vector2(14, 13) * u, m + Vector2(-14, 13) * u]), c)
			draw_line(m + Vector2(-14, 8) * u, m + Vector2(14, 8) * u, UiTheme.GOLD, 3.0 * u)
		"claw":
			for i in 3:
				var x := (i - 1) * 8.0
				draw_arc(m + Vector2(x - 6, 2) * u, 12.0 * u, -0.6, 0.9, 8, c, 3.0 * u)
		"hammer":
			draw_line(m + Vector2(0, -6) * u, m + Vector2(0, 16) * u, UiTheme.MUTED, 3.5 * u)
			draw_rect(Rect2(m + Vector2(-13, -15) * u, Vector2(26, 11) * u), c)
		"chain":
			for i in 3:
				draw_arc(m + Vector2((i - 1) * 10.0, (i - 1) * -4.0) * u, 6.5 * u, 0.0, TAU, 14, c, 2.5 * u)
		"orb":
			draw_circle(m, 13.0 * u, c)
			draw_circle(m + Vector2(-4, -4) * u, 4.0 * u, Color(UiTheme.TEXT, 0.55))
			draw_arc(m, 13.0 * u, 0.0, TAU, 20, UiTheme.GOLD, 1.5 * u)
		"shield":
			draw_colored_polygon(PackedVector2Array([m + Vector2(-12, -14) * u, m + Vector2(12, -14) * u,
				m + Vector2(12, 0) * u, m + Vector2(0, 15) * u, m + Vector2(-12, 0) * u]), c)
			draw_line(m + Vector2(0, -14) * u, m + Vector2(0, 15) * u, UiTheme.GOLD, 2.0 * u)
		"potion", "vial":
			var body := c if item_id != "xp_vial" else UiTheme.PANEL
			draw_circle(m + Vector2(0, 5) * u, 10.0 * u, body)
			draw_arc(m + Vector2(0, 5) * u, 10.0 * u, 0.0, TAU, 18, UiTheme.GOLD, 1.5 * u)
			draw_rect(Rect2(m + Vector2(-3.5, -15) * u, Vector2(7, 11) * u), UiTheme.GOLD)
		"wood":
			draw_rect(Rect2(m + Vector2(-14, -7) * u, Vector2(26, 14) * u), UiTheme.GOLD.darkened(0.35))
			draw_circle(m + Vector2(12, 0) * u, 7.0 * u, UiTheme.GOLD)
			draw_arc(m + Vector2(12, 0) * u, 3.5 * u, 0.0, TAU, 10, UiTheme.GOLD.darkened(0.4), 1.2 * u)
		_:
			draw_circle(m, 10.0 * u, c)
	var stage := int(EeveItems.item(item_id).get("stage", 0))
	if stage > 0 and stage < ROMAN.size():
		var f := QualityBadge.roman_font()
		var fs := int(maxf(11.0, 12.0 * u))
		var w := f.get_string_size(ROMAN[stage], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(s - w - 3.0, s - 3.0), ROMAN[stage], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.COIN)
