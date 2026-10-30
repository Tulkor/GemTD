class_name Wc3Theme
extends RefCounted
## Hauptmenü (Hub) im Warcraft-III-Stil (Lukas, 2026-10-30, Mockup v10 unter /mnt/project-files/mockups/wc3-menu/):
## Steinsäule mit doppeltem Messingrahmen und verschraubten Eckbeschlägen, spitze Knöpfe mit Stein- bzw.
## Felstextur, Cinzel als Schrift. Messington wie die Linien in Shopping Maul, kaum Farbverlauf.
## Die Unterseiten (Einzelspieler, Lobby, Laden …) bleiben Art déco (DecoTheme).

const GOLD := Color("c9a36a")
const GOLD_HI := Color("d8b97f")
const GOLD_LO := Color("7d6440")
## Dunkle Kontur um alles aus Messing.
const INK := Color("140c04")
const SCREW := Color("8f7440")
## Grün für „verbunden“ unten links.
const HAVE := Color("9fd3b6")
const TEXT := Color("d8b97f")
## Schrift beim Überfahren und Hotkey-Buchstabe.
const HOT := Color("f6ead2")
const CREAM := Color("e6d3a3")
const MODES := Color("cdb886")
const MUTED := Color("a69676")
## Flächen der Knöpfe über der Textur: rot = Hauptknopf, dunkel = kleiner Knopf.
const RED := Color(0.42, 0.086, 0.055, 0.8)
const RED_HOVER := Color(0.63, 0.157, 0.07, 0.8)
const DARK := Color(0.133, 0.118, 0.102, 0.72)
const DARK_HOVER := Color(0.25, 0.2, 0.16, 0.72)
## Abdunklung der Steinsäule.
const PILLAR_SHADE := Color(0.07, 0.055, 0.047, 0.66)

const STONE := "res://assets/models/scenery/church_Stone.png"
const ROCK := "res://assets/models/scenery/mine_rocks_1_rock1.png"
const FONT := "res://assets/fonts/Cinzel-Bold.ttf"

static var _fonts: Dictionary = {}


## Cinzel Bold mit Buchstabenabstand; Zeichen, die Cinzel nicht hat (◆, ·), kommen aus Federo bzw. DejaVu.
static func font(spacing := 0) -> Font:
	if _fonts.has(spacing):
		return _fonts[spacing]
	var base: FontFile = load(FONT)
	if base.fallbacks.is_empty():
		base.fallbacks = [load(DecoTheme.FONT), load(DecoTheme.FONT_FALLBACK)]
	var f := FontVariation.new()
	f.base_font = base
	f.spacing_glyph = spacing
	_fonts[spacing] = f
	return f


## Schrift über dem 3D-Hintergrund: harter dunkler Schatten nach unten plus weicher dunkler Rand, damit sie
## auch über hellen Stellen (Mond, Kristall) lesbar bleibt.
static func label(text: String, parent: Node, size: int, color: Color, spacing := 0) -> Label:
	var l := UiUtil.label(text, parent, size)
	l.add_theme_font_override("font", font(spacing))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)
	return l


## Spitzes Sechseck in r (Spitzen links und rechts, tip = Länge der Spitze).
static func hex(r: Rect2, tip: float) -> PackedVector2Array:
	var y := r.position.y + r.size.y / 2
	return PackedVector2Array([Vector2(r.position.x + tip, r.position.y), Vector2(r.end.x - tip, r.position.y),
		Vector2(r.end.x, y), Vector2(r.end.x - tip, r.end.y), Vector2(r.position.x + tip, r.end.y), Vector2(r.position.x, y)])


## Achteck mit abgeschnittenen Ecken (Säule).
static func cut_rect(r: Rect2, cut: float) -> PackedVector2Array:
	var a := r.position
	var b := r.end
	return PackedVector2Array([Vector2(a.x, a.y + cut), Vector2(a.x + cut, a.y), Vector2(b.x - cut, a.y), Vector2(b.x, a.y + cut),
		Vector2(b.x, b.y - cut), Vector2(b.x - cut, b.y), Vector2(a.x + cut, b.y), Vector2(a.x, b.y - cut)])


## Fläche mit Kacheltextur füllen (tile = Kachelgröße in Pixeln); der CanvasItem braucht texture_repeat.
static func fill_textured(ci: CanvasItem, pts: PackedVector2Array, tex: Texture2D, tile: float, tint: Color) -> void:
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append(p / tile)
	ci.draw_colored_polygon(pts, Color.WHITE, uvs, tex)
	ci.draw_colored_polygon(pts, tint)


static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


## Geschlitzte Messingschraube.
static func screw(ci: CanvasItem, pos: Vector2, angle: float) -> void:
	ci.draw_circle(pos, 6.5, INK)
	ci.draw_circle(pos, 5.5, SCREW)
	ci.draw_circle(pos - Vector2(0.8, 0.8), 4.0, Color(GOLD_HI, 0.55))
	var d := Vector2.from_angle(angle) * 4.2
	ci.draw_line(pos - d, pos + d, INK, 1.8)


## Eckbeschlag mit drei Schrauben an der abgeschnittenen Ecke (80 × 80, Ursprung = Ecke, x/y zeigen nach innen).
static func corner(ci: CanvasItem, origin: Vector2, x: Vector2, y: Vector2) -> void:
	var t := func(p: Vector2) -> Vector2: return origin + x * p.x + y * p.y
	var plate := PackedVector2Array()
	for p in [Vector2(0, 30), Vector2(30, 0), Vector2(80, 0), Vector2(80, 17), Vector2(39, 17), Vector2(17, 39), Vector2(17, 80), Vector2(0, 80)]:
		plate.append(t.call(p))
	ci.draw_colored_polygon(plate, GOLD)
	ci.draw_polyline(closed(plate), INK, 2.0, true)
	ci.draw_polyline(PackedVector2Array([t.call(Vector2(3, 31)), t.call(Vector2(31, 3)), t.call(Vector2(77, 3))]), GOLD_HI, 2.0, true)
	ci.draw_polyline(PackedVector2Array([t.call(Vector2(77, 14)), t.call(Vector2(38, 14)), t.call(Vector2(14, 38)), t.call(Vector2(14, 77))]), GOLD_LO, 2.0, true)
	var faint := Color(GOLD_LO, 0.7)
	ci.draw_line(t.call(Vector2(8, 36)), t.call(Vector2(36, 8)), faint, 1.0, true)
	ci.draw_line(t.call(Vector2(8, 44)), t.call(Vector2(8, 72)), faint, 1.0, true)
	ci.draw_line(t.call(Vector2(44, 8)), t.call(Vector2(72, 8)), faint, 1.0, true)
	screw(ci, t.call(Vector2(21, 21)), deg_to_rad(35))
	screw(ci, t.call(Vector2(62, 8.5)), deg_to_rad(-20))
	screw(ci, t.call(Vector2(8.5, 62)), deg_to_rad(70))


## Trennlinie mit Raute in der Mitte (zwischen den Knopfgruppen der Säule).
class Divider extends Control:
	func _init() -> void:
		custom_minimum_size.y = 20
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y / 2
		var m := size.x / 2
		draw_line(Vector2(0, y), Vector2(m - 12, y), GOLD_LO, 2.0)
		draw_line(Vector2(m + 12, y), Vector2(size.x, y), GOLD_LO, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(m, y - 6), Vector2(m + 6, y), Vector2(m, y + 6), Vector2(m - 6, y)]), GOLD)
