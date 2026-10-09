class_name Pathfinder
extends RefCounted
## Wegfindung über das Raster: spawn -> alle Checkpoints -> goal.
## Diagonale Schritte sind erlaubt, aber nicht zwischen zwei Hindernissen hindurch.

var map: MapData
var astar := AStarGrid2D.new()


func _init(m: MapData) -> void:
	map = m
	astar.region = Rect2i(0, 0, m.width, m.height)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in m.height:
		for x in m.width:
			var c := Vector2i(x, y)
			astar.set_point_solid(c, not m.is_walkable(c))


## Markiert ein Feld als belegt (Tower/Stein) oder frei.
func set_solid(c: Vector2i, solid: bool) -> void:
	astar.set_point_solid(c, solid or not map.is_walkable(c))


func set_solid_cells(cells: Array[Vector2i], solid: bool) -> void:
	for c in cells:
		set_solid(c, solid)


## Kompletter Weg als Liste von Feldern. Leer, wenn irgendein Abschnitt blockiert ist.
func compute_path() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var pts := map.waypoints()
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		if not astar.is_in_boundsv(a) or not astar.is_in_boundsv(b) \
				or astar.is_point_solid(a) or astar.is_point_solid(b):
			result.clear()
			return result
		var seg := astar.get_id_path(a, b)
		if seg.is_empty():
			result.clear()
			return result
		var start := 0 if result.is_empty() else 1
		for j in range(start, seg.size()):
			result.append(seg[j])
	return result


## Würde ein Hindernis auf c den Weg komplett versperren?
func would_block(c: Vector2i) -> bool:
	var cells: Array[Vector2i] = [c]
	return would_block_cells(cells)


## Würden Hindernisse auf allen diesen Feldern (z. B. ein 2×2-Tower) den Weg versperren?
func would_block_cells(cells: Array[Vector2i]) -> bool:
	var changed: Array[Vector2i] = []
	for c in cells:
		if astar.is_in_boundsv(c) and not astar.is_point_solid(c):
			astar.set_point_solid(c, true)
			changed.append(c)
	if changed.is_empty():
		return false
	var blocked := compute_path().is_empty()
	for c in changed:
		astar.set_point_solid(c, false)
	return blocked
