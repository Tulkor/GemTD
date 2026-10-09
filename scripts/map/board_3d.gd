class_name Board3D
extends Node3D
## 3D-Darstellung einer Map: Boden, Mauern, Steine, Wegpunkte, Weg und Hover-Markierung.
## Wird vom Spiel und vom Map-Editor benutzt. Tower und Gegner hängen als Kinder darunter.
##
## Koordinaten: 1 Feld = 1 Einheit. Feld (x, y) liegt bei X = x..x+1, Z = y..y+1, Boden bei Y = 0.

const COL_FLOOR_A := Color("2f4a29")
const COL_FLOOR_B := Color("2a4325")
const COL_WALK := Color("54462f")
const COL_ZONE := Color("4b5530")
const COL_WALL := Color("2a2b31")
const COL_ROCK := Color("5c5c63")
const WALL_HEIGHT := 0.8
const ROCK_HEIGHT := 0.55

var map: MapData
var rocks: Dictionary = {}
var path_points := PackedVector2Array()
var path_color := Color(1, 1, 1, 0.6)
var hover_cell := Vector2i(-1, -1)
var hover_ok := true

var _ground: MultiMeshInstance3D
var _walls: MultiMeshInstance3D
var _rocks: MultiMeshInstance3D
var _path: MultiMeshInstance3D
var _markers: Node3D
var _hover: MeshInstance3D
var _hover_mat: StandardMaterial3D


static func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c) + Vector2(0.5, 0.5)


static func to_3d(p: Vector2, height := 0.0) -> Vector3:
	return Vector3(p.x, height, p.y)


static func make_material(col: Color, unshaded := false, transparent := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent or col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _ready() -> void:
	_ground = _multimesh(_box(Vector3(1, 0.1, 1)), true)
	_walls = _multimesh(_box(Vector3(1, WALL_HEIGHT, 1)), false, COL_WALL)
	_rocks = _multimesh(_box(Vector3(0.82, ROCK_HEIGHT, 0.82)), false, COL_ROCK)
	var dot := CylinderMesh.new()
	dot.top_radius = 0.12
	dot.bottom_radius = 0.12
	dot.height = 0.02
	dot.radial_segments = 8
	_path = _multimesh(dot, false, path_color, true)
	_markers = Node3D.new()
	add_child(_markers)
	_hover = MeshInstance3D.new()
	_hover.mesh = _box(Vector3(1, 0.12, 1))
	_hover_mat = make_material(Color(0, 1, 0, 0.35), true)
	_hover.material_override = _hover_mat
	_hover.visible = false
	add_child(_hover)
	if map != null:
		rebuild()


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _multimesh(mesh: Mesh, colors: bool, col := Color.WHITE, unshaded := false) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mmi.multimesh = mm
	var mat := make_material(col, unshaded)
	if colors:
		mat.vertex_color_use_as_albedo = true
	mmi.material_override = mat
	add_child(mmi)
	return mmi


## Alles neu aufbauen, z. B. nach einer Änderung der Kacheln oder Größe.
func rebuild() -> void:
	if map == null or _ground == null:
		return
	var ground: Array = []
	var walls: Array = []
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			match map.get_tile(c):
				MapData.BLOCKED:
					walls.append(c)
				MapData.WALK_ONLY:
					ground.append([c, COL_WALK])
				_:
					var col := COL_FLOOR_A if (x + y) % 2 == 0 else COL_FLOOR_B
					if map.is_marker_zone(c):
						col = COL_ZONE
					ground.append([c, col])
	var gm := _ground.multimesh
	gm.instance_count = ground.size()
	for i in ground.size():
		gm.set_instance_transform(i, Transform3D(Basis(), to_3d(cell_center(ground[i][0]), -0.05)))
		gm.set_instance_color(i, ground[i][1])
	var wm := _walls.multimesh
	wm.instance_count = walls.size()
	for i in walls.size():
		wm.set_instance_transform(i, Transform3D(Basis(), to_3d(cell_center(walls[i]), WALL_HEIGHT / 2.0 - 0.1)))
	_rebuild_markers()
	refresh_rocks()
	refresh_path()
	refresh_hover()


func refresh_rocks() -> void:
	if _rocks == null:
		return
	var mm := _rocks.multimesh
	var cells := rocks.keys()
	mm.instance_count = cells.size()
	for i in cells.size():
		var c: Vector2i = cells[i]
		# leicht gedreht, damit Steine nicht wie Kisten aussehen
		var basis := Basis(Vector3.UP, float((c.x * 7 + c.y * 13) % 10) * 0.08)
		mm.set_instance_transform(i, Transform3D(basis, to_3d(cell_center(c), ROCK_HEIGHT / 2.0)))


func refresh_path() -> void:
	if _path == null:
		return
	(_path.material_override as StandardMaterial3D).albedo_color = path_color
	var mm := _path.multimesh
	mm.instance_count = path_points.size()
	for i in path_points.size():
		mm.set_instance_transform(i, Transform3D(Basis(), to_3d(path_points[i], 0.02)))


func refresh_hover() -> void:
	if _hover == null:
		return
	_hover.visible = map != null and map.in_bounds(hover_cell)
	if _hover.visible:
		_hover.position = to_3d(cell_center(hover_cell), 0.0)
		_hover_mat.albedo_color = Color(0.2, 1, 0.2, 0.4) if hover_ok else Color(1, 0.2, 0.2, 0.4)


func _rebuild_markers() -> void:
	for c in _markers.get_children():
		c.queue_free()
	_add_marker(map.spawn, "S", Color("2ecc71"))
	for i in map.checkpoints.size():
		_add_marker(map.checkpoints[i], str(i + 1), Color("f1c40f"))
	_add_marker(map.goal, "Z", Color("e74c3c"))


func _add_marker(c: Vector2i, text: String, col: Color) -> void:
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.42
	cyl.height = 0.06
	disc.mesh = cyl
	disc.material_override = make_material(col)
	disc.position = to_3d(cell_center(c), 0.03)
	_markers.add_child(disc)
	var label := Label3D.new()
	label.text = text
	label.font_size = 96
	label.pixel_size = 0.006
	label.outline_size = 24
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = to_3d(cell_center(c), 0.9)
	_markers.add_child(label)


## Feld unter dem Mauszeiger (Strahl von der Kamera auf die Bodenebene).
func mouse_cell(camera: Camera3D) -> Vector2i:
	if camera == null:
		return Vector2i(-1, -1)
	var mp := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mp)
	var dir := camera.project_ray_normal(mp)
	if absf(dir.y) < 0.0001:
		return Vector2i(-1, -1)
	var t := -from.y / dir.y
	if t < 0.0:
		return Vector2i(-1, -1)
	var hit := from + dir * t
	return Vector2i(floori(hit.x), floori(hit.z))
