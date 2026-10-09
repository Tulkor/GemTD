class_name WaveIcon
extends Control
## Symbol für den Wellentyp, passend zu den Gegnerformen: Würfel = Boden, Kugel = Flieger,
## Pyramide = Masse, großer Quader = Boss.

const COLORS := {
	"Boden": Color("9fb4d0"),
	"Flieger": Color("6fc8ff"),
	"Masse": Color("f0a050"),
	"Boss": Color("ef6b6b"),
	"Gemischt": Color("c9a8ff"),
}

var kind := "Boden"


func _draw() -> void:
	var col: Color = COLORS.get(kind, UiTheme.TEXT)
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0
	draw_rect(Rect2(Vector2.ZERO, size), Color(col, 0.15))
	match kind:
		"Flieger":
			draw_circle(c, r * 0.55, col)
		"Masse":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.6), c + Vector2(r * 0.6, r * 0.5), c + Vector2(-r * 0.6, r * 0.5)]), col)
		"Boss":
			draw_rect(Rect2(c - Vector2(r * 0.75, r * 0.6), Vector2(r * 1.5, r * 1.2)), col)
		"Gemischt":
			draw_rect(Rect2(c - Vector2(r * 0.6, r * 0.1), Vector2(r * 0.6, r * 0.6)), col)
			draw_circle(c + Vector2(r * 0.3, -r * 0.25), r * 0.3, col)
		_:
			draw_rect(Rect2(c - Vector2(r * 0.45, r * 0.45), Vector2(r * 0.9, r * 0.9)), col)
