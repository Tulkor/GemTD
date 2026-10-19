class_name DecoBackdrop
extends Control
## Hintergrund der Art-déco-Menüs: Petrol, doppelter Messingrahmen am Rand, Messing-Dreiecke in den Ecken,
## optional ein Strahlenfächer von rays_from (Mitte oben, hinter dem Titel).

var rays := false
## Ursprung der Strahlen relativ zur Größe (0..1).
var rays_from := Vector2(0.5, 0.33)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DecoTheme.BG)
	var g := DecoTheme.GOLD
	if rays:
		var o := size * rays_from
		var ray := Color(g, 0.4)
		for i in range(-3, 4):
			draw_line(o, Vector2(o.x + i * size.x * 0.086, 0), ray, 1.5, true)
	var m := 18.0
	draw_rect(Rect2(Vector2(m, m), size - Vector2(m, m) * 2), g, false, 2.0)
	draw_rect(Rect2(Vector2(m + 10, m + 10), size - Vector2(m + 10, m + 10) * 2), g, false, 1.0)
	var c := 54.0
	var e := size - Vector2(m, m)
	for tri in [[Vector2(m, m), Vector2(m + c, m), Vector2(m, m + c)], [Vector2(e.x, m), Vector2(e.x - c, m), Vector2(e.x, m + c)],
			[Vector2(m, e.y), Vector2(m + c, e.y), Vector2(m, e.y - c)], [e, e - Vector2(c, 0), e - Vector2(0, c)]]:
		draw_colored_polygon(PackedVector2Array(tri), g)
