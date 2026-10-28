class_name RgVandal
extends Control
## Verschmierungen über einem Panel der Plakatwand (Randgruppen TD), je nach Rasse des Spielers
## (data/randgruppen.json → races[].look): „graffiti“ (Tags mit Sprühnebel und Farbnasen), „punk“ (Klebeband,
## Sticker, Parolen in tropfender Schrift), „emo“ (Herzen, Sterne, Kritzeleien in Schwarz und Pink).
## vandal 0–3 bestimmt, wie viel. Liegt als letztes Kind im Panel, fängt keine Maus und zeichnet nur.
## Fester Zufallsstartwert je Panel: das Bild bleibt beim Neuzeichnen gleich.

const FONTS := {
	"graffiti": "res://assets/fonts/SedgwickAveDisplay-Regular.ttf",
	"punk": "res://assets/fonts/RubikWetPaint-Regular.ttf",
	"emo": "res://assets/fonts/PirataOne-Regular.ttf",
}
const WORDS := {
	"graffiti": ["RG CREW", "WAR HIER", "KIEZ", "TOY", "ZONE 1", "BASS"],
	"punk": ["NO FUTURE", "OI!", "PUNK", "LAUT", "DIY", "ANTI"],
	"emo": ["xoxo", "<3", "allein", "schwarz", "sad", "*seufz*"],
}
const PAINT := {
	"graffiti": [Color("ff3fa4"), Color("27c4ff"), Color("ffd83a"), Color("35d46a")],
	"punk": [Color("9bff2a"), Color("ff2a2a"), Color("151515"), Color("ff8a00")],
	"emo": [Color("151515"), Color("ff3fa4"), Color("7a2bd0"), Color("151515")],
}
const TAPE := Color(0.82, 0.8, 0.72, 0.85)

var style := "clean"
var level := 0
var seed_value := 1


## Panel mit Verschmierungen versehen (oder vorhandene anpassen). Gibt die Ebene zurück.
static func apply(panel: Control, look: Dictionary, seed_value := 1) -> RgVandal:
	var v: RgVandal = null
	for c in panel.get_children():
		if c is RgVandal:
			v = c
	if v == null:
		v = RgVandal.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.add_child(v)
	v.style = str(look.get("style", "clean"))
	v.level = int(look.get("vandal", 0))
	v.seed_value = seed_value
	v.visible = v.level > 0 and FONTS.has(v.style)
	v.queue_redraw()
	return v


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	# nur auf größeren Fenstern, kleine Kästchen bleiben lesbar
	if level <= 0 or not FONTS.has(style) or size.x < 200 or size.y < 70:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + level * 31 + style.hash()
	var font: Font = load(FONTS[style])
	var paint: Array = PAINT[style]
	match style:
		"graffiti":
			for i in level:
				_tag(rng, font, paint[rng.randi() % paint.size()])
			for i in level * 2:
				_spray_dots(rng, paint[rng.randi() % paint.size()])
		"punk":
			for i in mini(level + 1, 4):
				_tape(rng, i)
			for i in level:
				_tag(rng, font, paint[rng.randi() % paint.size()])
			for i in level - 1:
				_sticker(rng, paint[rng.randi() % paint.size()])
		"emo":
			for i in level + 1:
				_heart(rng, paint[rng.randi() % paint.size()])
			for i in level:
				_star(rng, Color("151515"))
			for i in level:
				_tag(rng, font, paint[rng.randi() % paint.size()])
			_scribble(rng, Color("151515"))


## Wort schräg an den Rand, mit schwarzer Kontur und Farbnasen nach unten.
func _tag(rng: RandomNumberGenerator, font: Font, col: Color) -> void:
	var words: Array = WORDS[style]
	var text := tr(str(words[rng.randi() % words.size()]))
	var fs := int(clampf(size.y * 0.12, 15, 22))
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# auf den Rahmen oben oder unten, damit der Inhalt lesbar bleibt
	var x := rng.randf_range(size.x * 0.35, maxf(size.x - w - 6.0, size.x * 0.35 + 1.0))
	var y := (rng.randf_range(fs * 0.45, fs * 0.6) if rng.randf() < 0.5 else rng.randf_range(size.y + fs * 0.1, size.y + fs * 0.3))
	var angle := rng.randf_range(-0.15, 0.15)
	draw_set_transform(Vector2(x, y), angle)
	var c := Color(col, 0.78)
	draw_string_outline(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.08, 0.08, 0.08, 0.7))
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	if style != "emo":
		for i in rng.randi_range(1, 3):
			var dx := rng.randf_range(4.0, maxf(w - 4.0, 5.0))
			var len := rng.randf_range(6.0, 20.0)
			draw_line(Vector2(dx, 2), Vector2(dx, 2 + len), c, 2.0)
			draw_circle(Vector2(dx, 3 + len), 2.0, c)
	draw_set_transform(Vector2.ZERO, 0.0)


func _spray_dots(rng: RandomNumberGenerator, col: Color) -> void:
	var p := _edge_point(rng)
	for i in 14:
		var d := Vector2(rng.randfn(0.0, 7.0), rng.randfn(0.0, 7.0))
		draw_circle(p + d, rng.randf_range(0.6, 1.6), Color(col, rng.randf_range(0.3, 0.7)))


## Klebeband über eine Ecke.
func _tape(rng: RandomNumberGenerator, corner: int) -> void:
	var at: Vector2 = [Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)][corner % 4]
	var angle: float = [-0.75, 0.75, -0.75, 0.75][corner % 4] + rng.randf_range(-0.15, 0.15)
	draw_set_transform(at, angle)
	var w := rng.randf_range(46.0, 70.0)
	var rect := Rect2(-w / 2.0, -9.0, w, 18.0)
	draw_rect(rect, TAPE)
	# gezackte Enden
	for e in [rect.position.x, rect.end.x]:
		for k in 4:
			draw_line(Vector2(e, -9 + k * 4.5), Vector2(e + (2 if e < 0 else -2), -7 + k * 4.5), Color(0.6, 0.58, 0.5, 0.9), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0)


func _sticker(rng: RandomNumberGenerator, col: Color) -> void:
	var p := _edge_point(rng)
	var r := rng.randf_range(9.0, 14.0)
	draw_set_transform(p, rng.randf_range(-0.4, 0.4))
	draw_rect(Rect2(-r, -r * 0.7, r * 2, r * 1.4), Color(col, 0.85))
	draw_rect(Rect2(-r, -r * 0.7, r * 2, r * 1.4), Color(0.08, 0.08, 0.08, 0.8), false, 1.5)
	draw_line(Vector2(-r * 0.6, 0), Vector2(r * 0.6, 0), Color(0.08, 0.08, 0.08, 0.8), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0)


func _heart(rng: RandomNumberGenerator, col: Color) -> void:
	var p := _edge_point(rng)
	var s := rng.randf_range(6.0, 11.0)
	var pts := PackedVector2Array()
	for i in 25:
		var t := TAU * i / 24.0
		pts.append(p + Vector2(16 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))) * s / 16.0)
	draw_polyline(pts, Color(col, 0.8), 2.0)
	# manche gebrochen
	if rng.randf() < 0.5:
		draw_polyline(PackedVector2Array([p + Vector2(0, -s * 0.3), p + Vector2(-s * 0.2, 0), p + Vector2(s * 0.15, s * 0.3), p + Vector2(0, s * 0.8)]),
				Color(col, 0.8), 1.5)


func _star(rng: RandomNumberGenerator, col: Color) -> void:
	var p := _edge_point(rng)
	var r := rng.randf_range(5.0, 9.0)
	var pts := PackedVector2Array()
	for i in 11:
		var a := -PI / 2.0 + i * TAU * 2.0 / 5.0
		pts.append(p + Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts, Color(col, 0.75), 1.5)


func _scribble(rng: RandomNumberGenerator, col: Color) -> void:
	var p := _edge_point(rng)
	var pts := PackedVector2Array()
	for i in 18:
		pts.append(p + Vector2(i * 2.2, sin(i * 1.7) * 5.0 + rng.randf_range(-1.5, 1.5)))
	draw_polyline(pts, Color(col, 0.6), 1.5)


## Zufälliger Punkt nahe am Rand (innen), damit Text in der Mitte lesbar bleibt.
func _edge_point(rng: RandomNumberGenerator) -> Vector2:
	var m := 4.0
	match rng.randi() % 4:
		0:
			return Vector2(rng.randf_range(m, size.x - m), rng.randf_range(0, m + 4))
		1:
			return Vector2(rng.randf_range(m, size.x - m), rng.randf_range(size.y - m - 4, size.y))
		2:
			return Vector2(rng.randf_range(0, m + 6), rng.randf_range(m, size.y - m))
	return Vector2(rng.randf_range(size.x - m - 6, size.x), rng.randf_range(m, size.y - m))
