class_name MapPreview
extends Control
## Kleine Draufsicht einer Map: Kacheln, Laufwege, Spawns, Checkpoints, Ziel und (Maul-Maps) die Zonen der Spieler.

const COL_FLOOR := Color("2d4a30")
const COL_BLOCKED := Color("23262e")
const COL_WALK := Color("8a6a40")
const COL_PATH := Color(0.95, 0.85, 0.55, 0.85)

var map: MapData:
	set(value):
		map = value
		_paths = []
		if map != null:
			var pf := Pathfinder.new(map)
			for i in map.lane_count():
				_paths.append(pf.compute_path(i))
		queue_redraw()
var _paths: Array = []
## Hintergrund neben der Map (Art-déco-Menü: Petrol).
var bg := UiTheme.BG


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), bg)
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
	for z in map.zones:
		var col: Color = Board3D.PLAYER_COLORS[z.player % Board3D.PLAYER_COLORS.size()] if z.player >= 0 else UiTheme.MUTED
		draw_rect(Rect2(origin + Vector2(z.rect.position) * cell, Vector2(z.rect.size) * cell), col, false, maxf(cell * 0.5, 1.0))
	for path in _paths:
		var pts := PackedVector2Array()
		for c in path:
			pts.append(origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell)
		if pts.size() > 1:
			draw_polyline(pts, COL_PATH, maxf(cell * 0.6, 1.5))
	var r := maxf(cell * 1.6, 4.0)
	for lane in map.lane_count():
		var wp := map.waypoints(lane)
		for i in range(1, wp.size() - 1):
			draw_circle(origin + (Vector2(wp[i]) + Vector2(0.5, 0.5)) * cell, r, UiTheme.GOLD)
		draw_circle(origin + (Vector2(wp[0]) + Vector2(0.5, 0.5)) * cell, r, UiTheme.HAVE)
	draw_circle(origin + (Vector2(map.goal) + Vector2(0.5, 0.5)) * cell, r, UiTheme.MISSING)


## Felder aller Wege zusammen (ohne Labyrinth).
func path_length() -> int:
	return _paths.reduce(func(a, p): return a + p.size(), 0)
