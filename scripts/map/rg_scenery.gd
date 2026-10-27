class_name RgScenery
extends Node3D
## Wände der Randgruppen-Karte: auf den gesperrten Feldern stehen abwechselnd Häuserblocks und Parkbäume
## (Wunsch von Lukas: „ein Gemisch aus Bäumen und Gebäuden“). Die Karte wird in Viertel von QUARTER Feldern
## geteilt, jedes ist Stadt oder Park; in der Stadt stehen Häuser dort, wo ein ganzer 4×4-Block gesperrt ist,
## der Rest wird mit Bäumen aufgefüllt. Rein optisch, fester Zufallsstartwert: bei allen Spielern gleich.

const N := "res://assets/models/nature/%s.glb"
const C := "res://assets/models/city/%s.glb"
## Bäume: [Modell, Höhe von, Höhe bis, Gewicht]
const TREES := [
	["common_tree_3", 1.6, 2.4, 3.0], ["common_tree_4", 1.6, 2.5, 3.0], ["common_tree_5", 1.5, 2.3, 3.0],
	["pine_1", 1.8, 2.8, 1.0], ["pine_2", 1.8, 2.6, 1.0],
]
## Häuser der Wände (andere als die der Tower, siehe rg_daten.py MODELS): [Modell, Größe von, Größe bis, Gewicht]
const HOUSES := [
	["2story_2", 1.7, 1.9, 2.0], ["2story_double", 1.8, 1.95, 2.0], ["2story_gableroof", 1.7, 1.9, 2.0],
	["3story_slim", 1.7, 1.9, 1.5], ["3story_small", 1.7, 1.9, 1.5], ["4story", 1.8, 1.95, 1.2],
	["2story_center", 1.7, 1.9, 1.2], ["building_skyscraper_b", 1.9, 2.0, 0.4],
]
const QUARTER := 12      ## Kantenlänge eines Viertels in Feldern
const TOWN_SHARE := 0.5  ## Anteil der Viertel, die Stadt sind
const TREE_TINT := Color(1.0, 1.0, 1.0)

var board: Board3D
var map: MapData
var _rng := RandomNumberGenerator.new()


## Häuser und Bäume auf die gesperrten Felder der Karte von game setzen.
static func add_to(game: Node) -> RgScenery:
	var s := RgScenery.new()
	s.board = game.board
	s.map = game.map
	game.board.add_child(s)
	return s


func _ready() -> void:
	_rng.seed = 7041
	var blocked := func(c: Vector2i) -> bool:
		return c.x < 0 or c.y < 0 or c.x >= map.width or c.y >= map.height or map.get_tile(c) == MapData.BLOCKED
	var town := {}
	for qy in ceili(map.height / float(QUARTER)):
		for qx in ceili(map.width / float(QUARTER)):
			town[Vector2i(qx, qy)] = _rng.randf() < TOWN_SHARE
	var used := {}   # Felder unter Häusern
	var parts := {}  # "pfad|schatten" -> [Transform3D]
	# Häuser: ganze 4×4-Blöcke in Stadtvierteln, Front zur nächsten offenen Seite
	for y in range(0, map.height - 3, 4):
		for x in range(0, map.width - 3, 4):
			if not town[Vector2i(x / QUARTER, y / QUARTER)]:
				continue
			var full := true
			for dy in 4:
				for dx in 4:
					full = full and blocked.call(Vector2i(x + dx, y + dy))
			if not full or _rng.randf() < 0.12:
				continue
			for dy in 4:
				for dx in 4:
					used[Vector2i(x + dx, y + dy)] = true
			var i := _pick(HOUSES)
			var size := _rng.randf_range(HOUSES[i][1], HOUSES[i][2])
			var center := board.cell_center(Vector2i(x, y)) + Vector2(1.5, 1.5) * Board3D.CELL
			var rot := _facing(Vector2i(x, y), blocked)
			var b := Basis(Vector3.UP, rot).scaled(Vector3.ONE * size)
			parts.get_or_add(C % HOUSES[i][0] + "|1", []).append(Transform3D(b, Vector3(center.x, 0.0, center.y)))
	# Bäume auf allen übrigen gesperrten 2×2-Blöcken, im Park dichter
	for y in range(0, map.height - 1, 2):
		for x in range(0, map.width - 1, 2):
			var a := Vector2i(x, y)
			if used.has(a) or not (blocked.call(a) and blocked.call(a + Vector2i(1, 0)) and blocked.call(a + Vector2i(0, 1))
					and blocked.call(a + Vector2i(1, 1))):
				continue
			var park: bool = not town[Vector2i(x / QUARTER, y / QUARTER)]
			if _rng.randf() > (0.85 if park else 0.5):
				continue
			var i := _pick(TREES)
			var p := board.cell_center(a) + Vector2(0.5, 0.5) * Board3D.CELL \
					+ Vector2(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.3))
			var h := _rng.randf_range(TREES[i][1], TREES[i][2])
			var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * h)
			# Schatten nur nahe am Weg (sichtbar und günstig)
			var near_path: bool = not (blocked.call(a + Vector2i(-2, 0)) and blocked.call(a + Vector2i(3, 0))
					and blocked.call(a + Vector2i(0, -2)) and blocked.call(a + Vector2i(0, 3)))
			parts.get_or_add(N % TREES[i][0] + ("|1" if near_path else "|0"), []).append(Transform3D(b, Vector3(p.x, 0.0, p.y)))
	for key in parts:
		var k: PackedStringArray = key.split("|")
		_add_multimesh(k[0], parts[key], k[1] == "1", k[0].contains("/nature/"))


## Drehung eines Hauses mit Anker a, sodass die Front (−Z des Modells nach +Z gedreht) zur nächsten offenen Seite zeigt.
func _facing(a: Vector2i, blocked: Callable) -> float:
	var best := 0.0
	var best_d := 99
	for dir in [[Vector2i(0, 1), 0.0], [Vector2i(1, 0), PI / 2.0], [Vector2i(0, -1), PI], [Vector2i(-1, 0), -PI / 2.0]]:
		var step: Vector2i = dir[0]
		var start := a + Vector2i(1, 1) + Vector2i(maxi(step.x, 0) * 2, maxi(step.y, 0) * 2)
		for d in range(1, 12):
			if not blocked.call(start + step * d):
				if d < best_d:
					best_d = d
					best = dir[1]
				break
	return best + _rng.randf_range(-0.05, 0.05)


func _pick(list: Array) -> int:
	var total := 0.0
	for e in list:
		total += float(e[3])
	var r := _rng.randf() * total
	for i in list.size():
		r -= float(list[i][3])
		if r <= 0.0:
			return i
	return list.size() - 1


func _add_multimesh(path: String, xfs: Array, shadows: bool, tint: bool) -> void:
	var m := ModelLoader.mesh_with_transform(path, 1.0)
	if m.is_empty():
		return
	var mesh: Mesh = m[0]
	if tint:
		mesh = mesh.duplicate()
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			if mat is BaseMaterial3D:
				var t: BaseMaterial3D = mat.duplicate()
				t.albedo_color *= TREE_TINT
				mesh.surface_set_material(i, t)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i] * m[1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
