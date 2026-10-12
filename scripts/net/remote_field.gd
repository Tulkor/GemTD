class_name RemoteField
extends Node3D
## Zuschauer-Ansicht: zeigt das Feld eines Mitspielers aus den Daten von net_sync.gd.
## Tower und Steine werden bei jeder Meldung abgeglichen. Gegner laufen lokal auf dem
## gemeldeten Weg weiter und werden nur nachkorrigiert (enemy.gd → _remote_step).

var peer := 0
var time_scale := 1.0   ## Spieltempo des Mitspielers
var map: MapData
var map_id := 0
var field: Dictionary = {}
var board: Board3D
var effects: Effects

var rocks: Dictionary = {}
var towers: Dictionary = {}    ## Schlüssel aus Position, Typ, Stufe -> Tower
var enemies: Dictionary = {}   ## net_id -> Enemy
var _paths := {false: PackedVector2Array(), true: PackedVector2Array()}
var _cum := {false: PackedFloat32Array(), true: PackedFloat32Array()}


func has_map() -> bool:
	return map != null


func apply_map(packet: Dictionary) -> void:
	if int(packet.get("id", 0)) == map_id and map != null:
		return
	map_id = int(packet.get("id", 0))
	map = MapData.from_dict(packet.get("map", {}))
	if board != null:
		board.queue_free()
	_clear_units()
	rocks = {}
	board = Board3D.new()
	board.map = map
	board.rocks = rocks
	add_child(board)
	effects = Effects.new()
	board.add_child(effects)
	if not field.is_empty():
		apply_field(field)


func apply_field(f: Dictionary) -> void:
	field = f
	if map == null or int(f.get("map_id", 0)) != map_id:
		return
	rocks.clear()
	var rs: PackedInt32Array = f.get("rocks", PackedInt32Array())
	for i in range(0, rs.size() - 1, 2):
		rocks[Vector2i(rs[i], rs[i + 1])] = true
	board.refresh_rocks()
	_set_path(false, f.get("ground", PackedVector2Array()))
	_set_path(true, f.get("air", PackedVector2Array()))
	board.path_points = _paths[false]
	board.refresh_path()

	var wanted := {}
	for t in f.get("towers", []):
		wanted["%d,%d,%s,%d,%s" % [t[0], t[1], t[2], t[3], t[4]]] = t
	for k in towers.keys():
		if not wanted.has(k):
			towers[k].queue_free()
			towers.erase(k)
	for k in wanted:
		if towers.has(k) or not Database.towers.has(str(wanted[k][2])):
			continue
		var d: Array = wanted[k]
		var t := Tower.new()
		t.is_new = bool(d[4])
		add_child(t)
		t.setup(null, Vector2i(int(d[0]), int(d[1])), str(d[2]), int(d[3]))
		towers[k] = t


func apply_enemies(packet: Dictionary) -> void:
	time_scale = float(packet.get("ts", 1.0))
	if map == null:
		return
	var seen := {}
	for s in packet.get("e", []):
		var id := int(s[0])
		seen[id] = true
		var e: Enemy = enemies.get(id)
		if e == null:
			var def: Dictionary = Database.enemies.get(str(s[1]), {})
			if def.is_empty():
				continue
			e = Enemy.new()
			e.remote = true
			e.remote_field = self
			e.net_id = id
			add_child(e)
			var o := {"shape": str(s[7]), "size": float(s[8])} if s.size() > 8 else {}
			e.setup(null, def, o, _paths[bool(def.get("flying", false))])
			e.traveled = float(s[2])
			enemies[id] = e
		e.apply_net_state(s)
	for id in enemies.keys():
		if not seen.has(id):
			enemies[id].queue_free()
			enemies.erase(id)
	if effects != null:
		for b in packet.get("b", []):
			effects.add_beam(b[0], b[1], b[2])


func _clear_units() -> void:
	for t in towers.values():
		t.queue_free()
	towers.clear()
	for e in enemies.values():
		e.queue_free()
	enemies.clear()


## Koop: Wege vom eigenen Feld übernehmen (coop_sync.gd nutzt nur die Wege, keine Map).
func set_paths(ground: PackedVector2Array, air: PackedVector2Array) -> void:
	_set_path(false, ground)
	_set_path(true, air)


func path_for(flying: bool) -> PackedVector2Array:
	return _paths[flying]


func _set_path(flying: bool, p: PackedVector2Array) -> void:
	_paths[flying] = p
	var cum := PackedFloat32Array()
	var total := 0.0
	for i in p.size():
		if i > 0:
			total += p[i - 1].distance_to(p[i])
		cum.append(total)
	_cum[flying] = cum


func path_length(flying: bool) -> float:
	var cum: PackedFloat32Array = _cum[flying]
	return cum[cum.size() - 1] if not cum.is_empty() else 0.0


## Punkt auf dem Weg nach dist Towerbreiten.
func point_at(flying: bool, dist: float) -> Vector2:
	var p: PackedVector2Array = _paths[flying]
	var cum: PackedFloat32Array = _cum[flying]
	if p.is_empty():
		return Vector2.ZERO
	var i := cum.bsearch(dist)
	if i <= 0:
		return p[0]
	if i >= p.size():
		return p[p.size() - 1]
	var seg := cum[i] - cum[i - 1]
	var t := (dist - cum[i - 1]) / seg if seg > 0.0 else 1.0
	return p[i - 1].lerp(p[i], t)
