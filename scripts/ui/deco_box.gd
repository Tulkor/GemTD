class_name DecoBox
extends StyleBox
## Art-déco-Kasten (deco_theme.gd): Fläche, Messingrahmen, optional zweiter Rahmen innen,
## abgeschnittene Ecken (cut, Achteck) oder spitze Enden links und rechts (point), Messing-Dreiecke in den Ecken (corners).

@export var bg := Color.TRANSPARENT
@export var line := Color.TRANSPARENT
## Zweiter, dünner Rahmen innen (transparent = keiner).
@export var inner := Color.TRANSPARENT
@export var width := 2.0
@export var inset := 7.0
@export var cut := 0
@export var point := false
@export var corners := 0


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var outer := _shape(rect.grow(-width / 2.0), cut)
	if bg.a > 0.0:
		RenderingServer.canvas_item_add_polygon(to_canvas_item, _shape(rect, cut), [bg])
	if line.a > 0.0:
		_outline(to_canvas_item, outer, line, width)
	if inner.a > 0.0:
		_outline(to_canvas_item, _shape(rect.grow(-inset - width), maxi(cut - int(inset / 2), 0)), inner, 1.0)
	if corners > 0 and line.a > 0.0:
		var c := float(corners)
		var p := rect.position
		var e := rect.end
		for tri in [[p, p + Vector2(c, 0), p + Vector2(0, c)],
				[Vector2(e.x, p.y), Vector2(e.x - c, p.y), Vector2(e.x, p.y + c)],
				[Vector2(p.x, e.y), Vector2(p.x + c, e.y), Vector2(p.x, e.y - c)],
				[e, e - Vector2(c, 0), e - Vector2(0, c)]]:
			RenderingServer.canvas_item_add_polygon(to_canvas_item, PackedVector2Array(tri), [line])


## Linien bis 1 px zeichnet Godot als Haarlinie (Breite -1): immer genau ein Bildschirmpixel. Als Fläche
## (Breite 1) wären sie bei UI-Größe unter 100 % schmaler als ein Pixel und fielen je nach Lage ganz weg.
func _outline(item: RID, pts: PackedVector2Array, c: Color, w: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	if w > 1.0:
		closed.append(pts[1])
	RenderingServer.canvas_item_add_polyline(item, closed, [c], w if w > 1.0 else -1.0, false)


func _shape(r: Rect2, k: int) -> PackedVector2Array:
	var p := r.position
	var e := r.end
	if point:
		var m := minf(r.size.y / 2.0, 18.0)
		var y := p.y + r.size.y / 2.0
		return PackedVector2Array([Vector2(p.x + m, p.y), Vector2(e.x - m, p.y), Vector2(e.x, y),
			Vector2(e.x - m, e.y), Vector2(p.x + m, e.y), Vector2(p.x, y)])
	var c := minf(float(k), minf(r.size.x, r.size.y) / 2.0)
	if c <= 0.0:
		return PackedVector2Array([p, Vector2(e.x, p.y), e, Vector2(p.x, e.y)])
	return PackedVector2Array([Vector2(p.x + c, p.y), Vector2(e.x - c, p.y), Vector2(e.x, p.y + c), Vector2(e.x, e.y - c),
		Vector2(e.x - c, e.y), Vector2(p.x + c, e.y), Vector2(p.x, e.y - c), Vector2(p.x, p.y + c)])
