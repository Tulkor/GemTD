class_name Wc3Theme
extends RefCounted
## Hauptmenü (Hub) im Warcraft-III-Stil (Lukas, 2026-10-30, Mockup v10 unter /mnt/project-files/mockups/wc3-menu/):
## Steinsäule mit doppeltem Messingrahmen und verschraubten Eckbeschlägen, spitze Knöpfe mit Stein- bzw.
## Felstextur, Cinzel als Schrift. Messington wie die Linien in Shopping Maul, kaum Farbverlauf.
## Seit 2026-11 auch die Einzelspieler-Seite (Modus und Map wählen); Lobby, Laden usw. bleiben Art déco (DecoTheme).

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
## Map-Karte (Einzelspieler) über der Steintextur und Grund der Map-Vorschau.
const CARD := Color(0.09, 0.08, 0.07, 0.78)
const PREVIEW_BG := Color("15110c")
## Gesperrter Knopf: grauer Stein, graue Schrift.
const DISABLED := Color(0.16, 0.16, 0.16, 0.85)
const DISABLED_TEXT := Color("77736b")
## Abdunklung der Steinsäule.
const PILLAR_SHADE := Color(0.07, 0.055, 0.047, 0.66)

## Messingteile als 3D-Renders aus Blender (tools/menu/messing_blender.py), metallisch spiegelnd.
const BRASS_DIR := "res://assets/textures/menu/messing/"
## Glanz, der langsam über alles Messing läuft (Material für Wc3Theme.BrassLayer).
const GLOSS := preload("res://scripts/ui/wc3_glanz.gdshader")
const STONE := "res://assets/models/scenery/church_Stone.png"
const ROCK := "res://assets/models/scenery/mine_rocks_1_rock1.png"
const FONT := "res://assets/fonts/Cinzel-Bold.ttf"

static var _fonts: Dictionary = {}
static var _tex: Dictionary = {}


## Messing-Render aus BRASS_DIR (ecke, schraube, kante_h, kante_v, raute, rubin, knopf_rahmen).
static func brass(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(BRASS_DIR + name + ".png")
	return _tex[name]


## Glanz-Material für Messing; ein gemeinsames, damit der Lichtstreif über alle Teile gleich läuft.
static var _gloss_mat: ShaderMaterial
static func gloss_material() -> ShaderMaterial:
	if _gloss_mat == null:
		_gloss_mat = ShaderMaterial.new()
		_gloss_mat.shader = GLOSS
	return _gloss_mat


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


## Messingschraube (3D-Render), d = Durchmesser.
static func screw(ci: CanvasItem, pos: Vector2, angle: float, d := 14.0) -> void:
	ci.draw_set_transform(pos, angle)
	ci.draw_texture_rect(brass("schraube"), Rect2(-d / 2, -d / 2, d, d), false)
	ci.draw_set_transform(Vector2.ZERO)


## Eckbeschlag mit drei Schrauben (3D-Render, 80 × 80, Ursprung = Ecke, x/y zeigen nach innen).
static func corner(ci: CanvasItem, origin: Vector2, x: Vector2, _y: Vector2) -> void:
	ci.draw_set_transform(origin, x.angle())
	ci.draw_texture_rect(brass("ecke"), Rect2(-2, -2, 84, 84), false)
	ci.draw_set_transform(Vector2.ZERO)


## Messingleiste (Rundstab) waagrecht oder senkrecht von a nach b, Dicke t.
static func edge(ci: CanvasItem, a: Vector2, b: Vector2, t := 10.0) -> void:
	# Die Textur ist 20 px dick und kachelt in Längsrichtung; skaliert auf die Dicke t
	var k := t / 20.0
	if is_equal_approx(a.y, b.y):
		ci.draw_set_transform(Vector2(minf(a.x, b.x), a.y - t / 2), 0.0, Vector2(k, k))
		ci.draw_texture_rect(brass("kante_h"), Rect2(0, 0, absf(b.x - a.x) / k, 20), true)
	else:
		ci.draw_set_transform(Vector2(a.x - t / 2, minf(a.y, b.y)), 0.0, Vector2(k, k))
		ci.draw_texture_rect(brass("kante_v"), Rect2(0, 0, 20, absf(b.y - a.y) / k), true)
	ci.draw_set_transform(Vector2.ZERO)


## Messingrahmen um r: vier Leisten, Ecken offen für die Beschläge (inset = wie weit die Leisten vor der Ecke enden).
static func frame(ci: CanvasItem, r: Rect2, t := 10.0, inset := 30.0) -> void:
	var h := t / 2
	edge(ci, Vector2(r.position.x + inset, r.position.y + h), Vector2(r.end.x - inset, r.position.y + h), t)
	edge(ci, Vector2(r.position.x + inset, r.end.y - h), Vector2(r.end.x - inset, r.end.y - h), t)
	edge(ci, Vector2(r.position.x + h, r.position.y + inset), Vector2(r.position.x + h, r.end.y - inset), t)
	edge(ci, Vector2(r.end.x - h, r.position.y + inset), Vector2(r.end.x - h, r.end.y - inset), t)


## Ebene über einer Fläche, die nur das Messing zeichnet, mit dem Glanz-Material (Node2D, damit Container sie
## nicht verschieben). painter(ci) zeichnet; redraw() nach Größenänderung.
class BrassLayer extends Node2D:
	var painter: Callable

	func _init(p: Callable) -> void:
		painter = p
		material = Wc3Theme.gloss_material()

	func _draw() -> void:
		painter.call(self)


## Trennlinie mit Raute in der Mitte (zwischen den Knopfgruppen der Säule).
class Divider extends Control:
	func _init() -> void:
		custom_minimum_size.y = 20
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		material = Wc3Theme.gloss_material()

	func _draw() -> void:
		var y := size.y / 2
		var m := size.x / 2
		Wc3Theme.edge(self, Vector2(0, y), Vector2(m - 12, y), 5.0)
		Wc3Theme.edge(self, Vector2(m + 12, y), Vector2(size.x, y), 5.0)
		draw_texture_rect(Wc3Theme.brass("raute"), Rect2(m - 10, y - 10, 20, 20), false)
