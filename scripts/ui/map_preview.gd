class_name MapPreview
extends Control
## Kleine Draufsicht einer Map: Kacheln, Laufweg, Spawn, Checkpoints und Ziel.

const COL_FLOOR := Color("2d4a30")
const COL_BLOCKED := Color("23262e")
const COL_WALK := Color("8a6a40")
const COL_PATH := Color(0.95, 0.85, 0.55, 0.85)

var map: MapData:
	set(value):
		map = value
		_path = Pathfinder.new(map).compute_path() if map != null else []
		queue_redraw()
var _path: Array = []


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)
	if map == null:
		return
	var cell := minf(size.x / map.width, size.y / map.height)
	var origin := (size - Vector2(map.width, map.height) * cell) / 2.0
	draw_rect(Rect2(origin, Vector2(map.width, map.height) * cell), COL_FLOOR)
	for y in map.height:
		for x in map.width:
			var t := map.get_tile(Vector2i(x, y))
			if t == MapData.FLOOR:
				continue
			draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), COL_BLOCKED if t == MapData.BLOCKED else COL_WALK)
	var pts := PackedVector2Array()
	for c in _path:
		pts.append(origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell)
	if pts.size() > 1:
		draw_polyline(pts, COL_PATH, maxf(cell * 0.6, 1.5))
	var r := maxf(cell * 1.6, 4.0)
	for c in map.checkpoints:
		draw_circle(origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell, r, UiTheme.GOLD)
	draw_circle(origin + (Vector2(map.spawn) + Vector2(0.5, 0.5)) * cell, r, UiTheme.HAVE)
	draw_circle(origin + (Vector2(map.goal) + Vector2(0.5, 0.5)) * cell, r, UiTheme.MISSING)


func path_length() -> int:
	return _path.size()
