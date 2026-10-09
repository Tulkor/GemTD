class_name MapView
extends Node2D
## Zeichnet eine Map: Kacheln, Steine, Wegpunkte, Weg und Hover-Markierung.
## Wird vom Spiel und vom Map-Editor benutzt. Tower und Gegner hängen als Kinder darunter.

const CELL := 32.0

const COL_FLOOR_A := Color("2f4a2b")
const COL_FLOOR_B := Color("2a4426")
const COL_BLOCKED := Color("17181c")
const COL_WALK := Color("5a4a33")
const COL_ZONE := Color(0.95, 0.85, 0.4, 0.13)
const COL_ROCK := Color("7d7d84")

var map: MapData
var rocks: Dictionary = {}
var path_points := PackedVector2Array()
var path_color := Color(1, 1, 1, 0.35)
var hover_cell := Vector2i(-1, -1)
var hover_ok := true


static func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL


static func cell_rect(c: Vector2i, inset := 0.0) -> Rect2:
	return Rect2(Vector2(c) * CELL + Vector2(inset, inset), Vector2(CELL - 2 * inset, CELL - 2 * inset))


func mouse_cell() -> Vector2i:
	var p := get_local_mouse_position()
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


## Skaliert und zentriert die Map in der Fläche links vom Seitenpanel.
func fit_into(area: Rect2) -> void:
	if map == null:
		return
	var size := Vector2(map.width, map.height) * CELL
	var s := minf(area.size.x / size.x, area.size.y / size.y)
	scale = Vector2(s, s)
	position = area.position + (area.size - size * s) / 2.0


func _draw() -> void:
	if map == null:
		return
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			var col := COL_FLOOR_A if (x + y) % 2 == 0 else COL_FLOOR_B
			match map.get_tile(c):
				MapData.BLOCKED:
					col = COL_BLOCKED
				MapData.WALK_ONLY:
					col = COL_WALK
			draw_rect(cell_rect(c), col)
			if map.get_tile(c) == MapData.FLOOR and map.is_marker_zone(c):
				draw_rect(cell_rect(c), COL_ZONE)

	for c in rocks:
		draw_rect(cell_rect(c, 2), COL_ROCK)
		draw_rect(cell_rect(c, 2), COL_ROCK.darkened(0.4), false, 1.5)

	if path_points.size() > 1:
		draw_polyline(path_points, path_color, 3.0)

	_draw_marker(map.spawn, "S", Color("2ecc71"))
	for i in map.checkpoints.size():
		_draw_marker(map.checkpoints[i], str(i + 1), Color("f1c40f"))
	_draw_marker(map.goal, "Z", Color("e74c3c"))

	if map.in_bounds(hover_cell):
		var hc := Color(0.2, 1, 0.2, 0.35) if hover_ok else Color(1, 0.2, 0.2, 0.35)
		draw_rect(cell_rect(hover_cell), hc)


func _draw_marker(c: Vector2i, text: String, col: Color) -> void:
	var center := cell_center(c)
	draw_circle(center, CELL * 0.42, col)
	var font := ThemeDB.fallback_font
	draw_string(font, center + Vector2(-CELL * 0.5, 6), text, HORIZONTAL_ALIGNMENT_CENTER, CELL, 16, Color.BLACK)
