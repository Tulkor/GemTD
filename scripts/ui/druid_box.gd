class_name DruidBox
extends StyleBox
## Kasten im Stil „Druidenhain“ (druid_theme.gd): einfarbige Fläche ohne Verlauf, Messingrahmen, dünner Rahmen innen,
## dunkler Ring mit graugrüner Kante außen und Triquetren (Dreiecksknoten) oben links und unten rechts.

@export var bg := Color.TRANSPARENT
@export var line := Color.TRANSPARENT
## Zweiter, dünner Rahmen innen (transparent = keiner).
@export var inner := Color.TRANSPARENT
## Dunkler Ring außen um den Rahmen (transparent = keiner), ring_edge ist seine äußere Kante.
@export var ring := Color.TRANSPARENT
@export var ring_edge := Color.TRANSPARENT
@export var width := 2.0
@export var inset := 5.0
## Triquetren in zwei Ecken (in Messing, mit schwarzem Schatten).
@export var knots := false

static var _knots: Dictionary = {}


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if ring.a > 0.0:
		if ring_edge.a > 0.0:
			RenderingServer.canvas_item_add_rect(to_canvas_item, rect.grow(5.0), ring_edge)
		RenderingServer.canvas_item_add_rect(to_canvas_item, rect.grow(4.0), ring)
	if bg.a > 0.0:
		RenderingServer.canvas_item_add_rect(to_canvas_item, rect, bg)
	if line.a > 0.0:
		_outline(to_canvas_item, rect.grow(-width / 2.0), line, width)
	if inner.a > 0.0:
		_outline(to_canvas_item, rect.grow(-inset - width - 0.5), inner, 1.0)
	if knots and line.a > 0.0:
		_knot(to_canvas_item, rect.position + Vector2(3, 3))
		_knot(to_canvas_item, rect.end - Vector2(3, 3))


func _outline(item: RID, r: Rect2, c: Color, w: float) -> void:
	var p := r.position
	var e := r.end
	var pts := PackedVector2Array([p, Vector2(e.x, p.y), e, Vector2(p.x, e.y), p, Vector2(e.x, p.y)])
	RenderingServer.canvas_item_add_polyline(item, pts, [c], w, false)


## Triquetra wie im Entwurf (34 px, Mitte bei center), als SVG gerendert und je Farbe zwischengespeichert.
func _knot(item: RID, center: Vector2) -> void:
	var tex := _knot_texture(line)
	RenderingServer.canvas_item_add_texture_rect(item, Rect2(center - Vector2(17, 17), Vector2(34, 34)), tex.get_rid())


static func _knot_texture(c: Color) -> Texture2D:
	var key := c.to_html()
	if _knots.has(key):
		return _knots[key]
	var leaf := '<path d="M0 -13 C10 -6 8 8 -2 9 C-12 8 -12 -6 0 -13 Z" transform="rotate(%d)"/>'
	var shape := leaf % 0 + leaf % 120 + leaf % 240 + '<circle r="7"/>'
	var svg := ('<svg xmlns="http://www.w3.org/2000/svg" width="34" height="34" viewBox="-17 -17 34 34">'
		+ '<g fill="none" stroke="#000000" stroke-opacity="0.85" stroke-width="2.4" transform="translate(1 1)">%s</g>'
		+ '<g fill="none" stroke="#%s" stroke-width="2.4">%s</g></svg>') % [shape, c.to_html(false), shape]
	var img := Image.new()
	img.load_svg_from_string(svg)
	var tex := ImageTexture.create_from_image(img)
	_knots[key] = tex
	return tex
