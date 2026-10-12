class_name RemoteField
extends Node3D
## Zuschauer-Ansicht: zeigt das Feld eines Mitspielers aus den Daten von net_sync.gd.
## Tower und Steine werden bei jeder Meldung abgeglichen. Gegner laufen lokal auf dem
## gemeldeten Weg weiter und werden nur nachkorrigiert (enemy.gd → _remote_step).

var peer := 0
var time_scale := 1.0   ## Spieltempo des Mitspielers
var _clock_offset := INF  ## kleinster Abstand Ortszeit − Sendezeit einer Meldung (ms): die schnellste Meldung
var map: MapData
var map_id := 0
var field: Dictionary = {}
var board: Board3D
var effects: Effects

var rocks: Dictionary = {}
var towers: Dictionary = {}    ## Schlüssel aus Position, Typ, Stufe -> Tower
var enemies: Dictionary = {}   ## net_id -> Enemy
## Wege je Bahn (Maul-Maps haben mehrere): {paths: {flying: Punkte}, cum: {flying: Strecke bis Punkt i}}
var _lanes: Array = [_new_lane()]


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
	set_paths(f.get("ground", PackedVector2Array()), f.get("air", PackedVector2Array()))
	var extra: Array = f.get("lanes", [])
	_lanes.resize(1 + extra.size())
	var dots := path_for(false)
	for i in extra.size():
		set_paths(extra[i][0], extra[i][1], i + 1)
		dots.append_array(extra[i][0])
	board.path_points = dots
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


## Wie alt eine Meldung schon ist, in Spielzeit des Mitspielers. Gemessen an der schnellsten Meldung
## bisher, denn die Uhren beider Rechner kennen einander nicht. Ohne das liefen Gegner nach einer
## verspäteten Meldung zurück; im 8×-Schnelllauf wären das schnell ein, zwei Towerbreiten.
func packet_age(packet: Dictionary) -> float:
	if not packet.has("now"):
		return 0.0
	var diff := float(Time.get_ticks_msec() - int(packet.now))
	# langsam nachgeben, falls eine Uhr etwas schneller geht
	_clock_offset = minf(_clock_offset + 0.05, diff)
	return clampf((diff - _clock_offset) / 1000.0, 0.0, 0.5) * time_scale


func apply_enemies(packet: Dictionary) -> void:
	time_scale = float(packet.get("ts", 1.0))
	var age := packet_age(packet)
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
			e.lane = int(s[9]) if s.size() > 9 else 0
			e.setup(null, def, o, path_for(bool(def.get("flying", false)), e.lane))
			e.traveled = float(s[2])
			enemies[id] = e
		e.apply_net_state(s, age)
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


static func _new_lane() -> Dictionary:
	return {"paths": {false: PackedVector2Array(), true: PackedVector2Array()},
		"cum": {false: PackedFloat32Array(), true: PackedFloat32Array()}}


## Wege einer Bahn setzen (Koop: coop_sync.gd übernimmt sie vom eigenen Feld, ohne Map).
func set_paths(ground: PackedVector2Array, air: PackedVector2Array, lane := 0) -> void:
	while _lanes.size() <= lane:
		_lanes.append(_new_lane())
	if _lanes[lane] == null:
		_lanes[lane] = _new_lane()
	_set_path(false, ground, lane)
	_set_path(true, air, lane)


func path_for(flying: bool, lane := 0) -> PackedVector2Array:
	return _lane(lane).paths[flying]


func _lane(i: int) -> Dictionary:
	return _lanes[i] if i >= 0 and i < _lanes.size() and _lanes[i] != null else _lanes[0]


func _set_path(flying: bool, p: PackedVector2Array, lane: int) -> void:
	_lanes[lane].paths[flying] = p
	var cum := PackedFloat32Array()
	var total := 0.0
	for i in p.size():
		if i > 0:
			total += p[i - 1].distance_to(p[i])
		cum.append(total)
	_lanes[lane].cum[flying] = cum


func path_length(flying: bool, lane := 0) -> float:
	var cum: PackedFloat32Array = _lane(lane).cum[flying]
	return cum[cum.size() - 1] if not cum.is_empty() else 0.0


## Punkt auf dem Weg (Bahn lane) nach dist Towerbreiten.
func point_at(flying: bool, dist: float, lane := 0) -> Vector2:
	var p: PackedVector2Array = _lane(lane).paths[flying]
	var cum: PackedFloat32Array = _lane(lane).cum[flying]
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
