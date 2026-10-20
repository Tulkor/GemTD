class_name MaulBoard
extends Board3D
## Spielfeld von Shopping Maul: wie Board3D, aber mit eigenen Markierungen (Spawns, Teleports,
## Mall, Leak-Fläche), den 11 Spielergebieten und der Blockstadt (MaulCity) rundherum.
## Das eigene Gebiet leuchtet, die anderen sind blass.

const COL_LEAK := Color("ff5d7a")
const COL_TELEPORT := Color("b38cff")

var own_zone := 0
var city: MaulCity


func _rebuild_markers() -> void:
	for c in _markers.get_children():
		c.queue_free()
	var mm: MaulMap = map as MaulMap
	if mm == null:
		return
	var spawn_cells := {}
	for s in mm.maul.get("spawns", []):
		var c := MaulMap.cell(s.cell)
		_add_marker(c, "S", style.marker)
		spawn_cells[c] = true
	# Teleport-Ziele: erster Wegpunkt jedes weiteren Abschnitts
	var done := {}
	for r in mm.maul.get("routes", {}).values():
		var all_legs: Array = []
		for i in range(1, r.get("legs", []).size()):
			all_legs.append(r.legs[i])
		for ch in r.get("choices", []):
			all_legs.append_array(ch.get("legs", []))
		for leg in all_legs:
			var c := MaulMap.cell(leg[0])
			if not done.has(c):
				done[c] = true
				_add_marker(c, "", style.get("zone_other", COL_TELEPORT))
	var mall: Array = mm.maul.get("mall", [])
	if mall.size() == 2:
		_add_marker(MaulMap.cell(mall), "MALL", style.get("zone_leak", COL_LEAK))
	var leak: Array = mm.maul.get("leak", [])
	if leak.size() == 4:
		_add_zone(Rect2i(int(leak[0]), int(leak[1]), int(leak[2]), int(leak[3])), style.get("zone_leak", COL_LEAK))
	for i in map.zones.size():
		var col: Color = style.get("zone_own", PLAYER_COLORS[0]) if i == own_zone else style.get("zone_other", Color(0.45, 0.4, 0.6))
		_add_zone(map.zones[i].rect, col)



## Wie Board3D, dazu die Blockstadt auf allem, was Gegner nie erreichen (vor dem Boden, der
## unter der Stadt ohne Gitter gezeichnet wird).
func rebuild() -> void:
	var mm: MaulMap = map as MaulMap
	if mm != null and _ground != null:
		if city == null:
			city = MaulCity.new()
			add_child(city)
		city.build(mm)
	super()


func _floor_plain(c: Vector2i) -> bool:
	return city != null and city.is_city(c)
