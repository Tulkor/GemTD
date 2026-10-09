class_name MapData
extends RefCounted
## Datenmodell einer Map, gespeichert als JSON (siehe data/maps/).
##
## Ein Feld ist eine halbe Towerbreite (Board3D.CELL), ein Tower belegt 2×2 Felder.
## Dadurch lassen sich Tower um eine halbe Breite versetzen und Gegner passen durch Lücken von einem Feld.
## Maps im alten Format (format 1, ein Feld = ein Tower) werden beim Laden verdoppelt.
##
## Kacheln (eine Zeile pro String in "tiles"):
##   "."  Boden: begehbar und bebaubar
##   "#"  blockiert: weder begehbar noch bebaubar
##   "_"  nur Weg: begehbar, aber nicht bebaubar
## Gegner laufen spawn -> checkpoints[0] -> ... -> goal.
## Um Spawn, Ziel und Checkpoints herum ist im Umkreis marker_radius nicht bebaubar.

const FLOOR := "."
const BLOCKED := "#"
const WALK_ONLY := "_"
const FORMAT := 2

var id := "neue_map"
var name := "Neue Map"
var width := 30
var height := 30
var rows := PackedStringArray()
var spawn := Vector2i(1, 1)
var goal := Vector2i(2, 2)
var checkpoints: Array[Vector2i] = []
var marker_radius := 1
var wave_set := "classic"
var lives := 50
var start_gold := 0
## Zufallselemente beim Spielstart. random_rocks: Anzahl Steine, seed: -1 = jedes Mal anders.
var variance := {"random_rocks": 0, "seed": -1}


static func create_empty(w: int, h: int) -> MapData:
	var m := MapData.new()
	m.width = w
	m.height = h
	for y in h:
		m.rows.append(FLOOR.repeat(w))
	m.spawn = Vector2i(4, 4)
	m.goal = Vector2i(w - 5, h - 5)
	return m


static func load_file(path: String) -> MapData:
	var d = Database.load_json(path)
	if typeof(d) != TYPE_DICTIONARY:
		return null
	return from_dict(d)


static func from_dict(d: Dictionary) -> MapData:
	var m := MapData.new()
	m.id = str(d.get("id", "map"))
	m.name = str(d.get("name", m.id))
	m.width = int(d.get("width", 20))
	m.height = int(d.get("height", 20))
	var tiles: Array = d.get("tiles", [])
	for y in m.height:
		var row: String = str(tiles[y]) if y < tiles.size() else ""
		m.rows.append(row.rpad(m.width, FLOOR).substr(0, m.width))
	m.spawn = _vec(d.get("spawn", [0, 0]))
	m.goal = _vec(d.get("goal", [m.width - 1, m.height - 1]))
	for c in d.get("checkpoints", []):
		m.checkpoints.append(_vec(c))
	m.marker_radius = int(d.get("marker_radius", 1))
	m.wave_set = str(d.get("waves", "classic"))
	m.lives = int(d.get("lives", 50))
	m.start_gold = int(d.get("start_gold", 0))
	m.variance = d.get("variance", {"random_rocks": 0, "seed": -1})
	if int(d.get("format", 1)) < FORMAT:
		m._upscale()
	return m


## Altes Format: jedes Feld wird zu 2×2 Feldern, Sperrzonen wachsen mit.
func _upscale() -> void:
	var new_rows := PackedStringArray()
	for row in rows:
		var wide := ""
		for ch in row:
			wide += ch + ch
		new_rows.append(wide)
		new_rows.append(wide)
	rows = new_rows
	width *= 2
	height *= 2
	spawn *= 2
	goal *= 2
	for i in checkpoints.size():
		checkpoints[i] *= 2
	marker_radius = maxi(marker_radius * 2 - 1, 0)


func to_dict() -> Dictionary:
	var cps := []
	for c in checkpoints:
		cps.append([c.x, c.y])
	return {
		"format": FORMAT,
		"id": id,
		"name": name,
		"width": width,
		"height": height,
		"tiles": Array(rows),
		"spawn": [spawn.x, spawn.y],
		"goal": [goal.x, goal.y],
		"checkpoints": cps,
		"marker_radius": marker_radius,
		"waves": wave_set,
		"lives": lives,
		"start_gold": start_gold,
		"variance": variance,
	}


func save_file(path: String) -> bool:
	return Database.save_json(path, to_dict())


func duplicate_map() -> MapData:
	return MapData.from_dict(to_dict())


static func _vec(v) -> Vector2i:
	if v is Array and v.size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	return Vector2i.ZERO


# --- Abfragen ----------------------------------------------------------------

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func get_tile(c: Vector2i) -> String:
	return rows[c.y][c.x]


func set_tile(c: Vector2i, t: String) -> void:
	var r := rows[c.y]
	rows[c.y] = r.substr(0, c.x) + t + r.substr(c.x + 1)


func waypoints() -> Array[Vector2i]:
	var pts: Array[Vector2i] = [spawn]
	pts.append_array(checkpoints)
	pts.append(goal)
	return pts


func is_marker_zone(c: Vector2i) -> bool:
	for p in waypoints():
		if maxi(absi(p.x - c.x), absi(p.y - c.y)) <= marker_radius:
			return true
	return false


func is_walkable(c: Vector2i) -> bool:
	return in_bounds(c) and get_tile(c) != BLOCKED


func is_buildable(c: Vector2i) -> bool:
	return in_bounds(c) and get_tile(c) == FLOOR and not is_marker_zone(c)


func resize(w: int, h: int) -> void:
	var new_rows := PackedStringArray()
	for y in h:
		var row := rows[y] if y < rows.size() else ""
		new_rows.append(row.rpad(w, FLOOR).substr(0, w))
	rows = new_rows
	width = w
	height = h
	var clamp_c := func(c: Vector2i) -> Vector2i: return Vector2i(clampi(c.x, 0, w - 1), clampi(c.y, 0, h - 1))
	spawn = clamp_c.call(spawn)
	goal = clamp_c.call(goal)
	for i in checkpoints.size():
		checkpoints[i] = clamp_c.call(checkpoints[i])
