class_name Board3D
extends Node3D
## 3D-Darstellung einer Map: Neon-Gitter als Boden, Steine, Wegpunkte, Weg und Hover-Markierung.
## Blockierte Felder (Mauern) werden nicht gezeichnet, nur ihr Rand als Neonlinie.
## Andere Modi (eeveTD, Shopping Maul) bekommen über FieldStyle ihren eigenen Look (Gras, Marmor …).
## Wird vom Spiel und vom Map-Editor benutzt. Tower und Gegner hängen als Kinder darunter.
##
## Koordinaten: 1 Einheit = 1 Towerbreite (128 WC3-Einheiten). Das Raster ist halb so fein:
## Feld (x, y) liegt bei X = x*CELL..(x+1)*CELL, Z entsprechend, Boden bei Y = 0.
## Tower und Steine belegen TOWER_CELLS × TOWER_CELLS Felder, angegeben über das Feld oben links (Anker).

const COL_ROCK := Color("5c5c63")
const ROCK_HEIGHT := 0.55
## Modelle für Steine (werden reihum verteilt). Fehlen sie, werden einfache Blöcke gezeichnet.
const ROCK_MODELS := [
	"res://assets/models/rocks/rock_b.glb",
	"res://assets/models/rocks/rock_c.glb",
	"res://assets/models/rocks/rock_large_a.glb",
	"res://assets/models/rocks/rock_large_b.glb",
	"res://assets/models/rocks/rock_large_c.glb",
]
## Steine füllen ihre 2×2 Felder (breiteste waagrechte Kante in Towerbreiten), höchstens so hoch
const ROCK_SIZE := 0.94
const ROCK_MAX_HEIGHT := 0.75
const ROCK_SHADER := preload("res://assets/shaders/rock.gdshader")
## Neon: Shader für Röhren (innen weiß, außen farbig) und das Gitter-Feld.
const NEON_SHADER := preload("res://assets/shaders/neon.gdshader")
const NEON_FLOOR_SHADER := preload("res://assets/shaders/neon_floor.gdshader")
const COL_WAYPOINT := Color("ff36d8")
const COL_PATH := Color("2ef2e0")
## Boden-Shader und seine Texturen (zwei Grasarten, Erde). Erde liegt auf dem Laufweg der leeren Map,
## um Spawn, Ziel und Checkpoints und auf "_"-Feldern; sonst Gras.
## Liegt unter dem Neon-Gitter und ist mit ground_alpha = 0 (Standard) ausgeblendet.
const GROUND_SHADER := "res://assets/shaders/ground.gdshader"
const GROUND_TEXTURES := {
	"grass_a": "res://assets/textures/ground/grass_a.jpg",
	"grass_b": "res://assets/textures/ground/grass_b.jpg",
	"dirt": "res://assets/textures/ground/dirt.jpg",
	"grass_a_normal": "res://assets/textures/ground/grass_a_normal.jpg",
	"grass_b_normal": "res://assets/textures/ground/grass_b_normal.jpg",
	"dirt_normal": "res://assets/textures/ground/dirt_normal.jpg",
}
## Erde: voller Anteil bis DIRT_CORE Felder Abstand vom Weg, dann Auslaufen über DIRT_FADE Felder.
const DIRT_CORE := 0.8
const DIRT_FADE := 2.2
## Um Spawn, Ziel und Checkpoints ist der Erdfleck so viele Felder größer als die Sperrzone.
const DIRT_ZONE_EXTRA := 1.5
## Kantenlänge eines Rasterfelds in Einheiten.
const CELL := 0.5
## Farben der Spieler (Zonen auf Maul-Maps), Spieler 1 zuerst.
const PLAYER_COLORS := [Color("22c4ee"), Color("ff4fd8"), Color("5fe08a"), Color("ffd166"), Color("b38cff"), Color("ff8a4f")]
## Ein Tower ist so viele Felder breit und tief.
const TOWER_CELLS := 2
## Fallen sind größer (Trefferfläche).
const TRAP_CELLS := 3

var map: MapData
var rocks: Dictionary = {}
var path_points := PackedVector2Array()
var path_color := COL_PATH
var hover_cell := Vector2i(-1, -1)  ## Anker (oben links) der Hover-Markierung
var hover_size := TOWER_CELLS       ## Kantenlänge der Hover-Markierung in Feldern
var hover_ok := true
## Ausgewählte Steine (Anker), werden türkis umrandet.
var selected_rocks: Array = []
var _selection: MultiMeshInstance3D
## Deckkraft des Gras-/Erdbodens unter dem Gitter: 0 = aus.
var ground_alpha := 0.0:
	set(v):
		ground_alpha = v
		if _ground_mat != null:
			_ground_mat.set_shader_parameter("ground_alpha", v)
			_ground.visible = ground_alpha > 0.0
## Feine Linien je Feld zusätzlich zum Towergitter (0 = aus), z. B. im Map-Editor.
var grid_strength := 0.0:
	set(v):
		grid_strength = v
		if _floor_mat != null:
			_floor_mat.set_shader_parameter("fine_strength", v)

var _ground: MeshInstance3D
var _ground_mat: ShaderMaterial
var _floor: MeshInstance3D
var _floor_mat: ShaderMaterial
var _rocks: Array = []  ## je Variante ein MultiMeshInstance3D
var _rock_fits: Array = []  ## je Variante die Transformation, die das Modell auf Feldgröße bringt
var _rock_outlines: Array = []  ## je Variante die Kontur-Hülle (oder null)
var _path: MultiMeshInstance3D
var _markers: Node3D
var _hover: MeshInstance3D
var _hover_mat: StandardMaterial3D
## Aussehen nach dem Oberflächen-Stil beim Anlegen (FieldStyle.current()).
var style: Dictionary = FieldStyle.STYLES[FieldStyle.NEON]


static func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL


## Mitte eines Towers/Steins mit Anker a.
static func footprint_center(a: Vector2i, size := TOWER_CELLS) -> Vector2:
	return (Vector2(a) + Vector2.ONE * size / 2.0) * CELL


## Alle Felder, die ein Tower/Stein mit Anker a belegt.
static func footprint(a: Vector2i, size := TOWER_CELLS) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dy in size:
		for dx in size:
			cells.append(a + Vector2i(dx, dy))
	return cells


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
	style = FieldStyle.current()
	if path_color == COL_PATH:
		path_color = style.path
	_ground = MeshInstance3D.new()
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = load(GROUND_SHADER)
	for key in GROUND_TEXTURES:
		_ground_mat.set_shader_parameter(key, load(GROUND_TEXTURES[key]))
	_ground_mat.set_shader_parameter("cell", CELL)
	_ground_mat.set_shader_parameter("ground_alpha", ground_alpha)
	for key in style.get("ground", {}):
		_ground_mat.set_shader_parameter(key, style.ground[key])
	_ground.material_override = _ground_mat
	_ground.visible = ground_alpha > 0.0
	add_child(_ground)
	_floor = MeshInstance3D.new()
	_floor_mat = ShaderMaterial.new()
	_floor_mat.shader = NEON_FLOOR_SHADER
	_floor_mat.set_shader_parameter("cell", CELL)
	_floor_mat.set_shader_parameter("grid_cells", float(TOWER_CELLS))
	_floor_mat.set_shader_parameter("fine_strength", grid_strength)
	for key in style.floor:
		_floor_mat.set_shader_parameter(key, style.floor[key])
	_floor.material_override = _floor_mat
	_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_floor)
	ground_alpha = maxf(ground_alpha, style.ground_alpha)
	for path in ROCK_MODELS:
		var m := ModelLoader.mesh_with_transform(path, ROCK_SIZE, true, ROCK_MAX_HEIGHT)
		if m.is_empty():
			continue
		var mmi := _multimesh(m[0], false)
		mmi.material_override = _rock_material()
		_rocks.append(mmi)
		_rock_fits.append(m[1])
		# Kontur: eigene Hülle mit geglätteten Normalen (die Modelle sind flach schattiert); Druidenhain ohne
		if not ModelLoader.has_outline():
			_rock_outlines.append(null)
			continue
		var hull := _multimesh(ModelLoader.smooth_normals(m[0]), false)
		hull.material_override = ModelLoader.outline_material()
		hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rock_outlines.append(hull)
	if _rocks.is_empty():
		_rocks.append(_multimesh(_box(Vector3(0.82, ROCK_HEIGHT, 0.82)), false, COL_ROCK))
		_rock_outlines.append(null)
		_rock_fits.append(Transform3D(Basis(), Vector3(0, ROCK_HEIGHT / 2.0, 0)))
	var dot := SphereMesh.new()
	dot.radius = 0.055
	dot.height = 0.11
	dot.radial_segments = 12
	dot.rings = 6
	_path = _multimesh(dot, false)
	_path.material_override = FieldStyle.line_material(path_color, style.path_energy)
	_path.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_markers = Node3D.new()
	add_child(_markers)
	_hover = MeshInstance3D.new()
	_hover.mesh = _box(Vector3(CELL, 0.12, CELL))
	_hover_mat = make_material(Color(0, 1, 0, 0.35), true)
	_hover.material_override = _hover_mat
	_hover.visible = false
	add_child(_hover)
	if map != null:
		rebuild()


## Felsbrocken: rauchiges Glas (Neon), bemooster Stein (Druidenhain) oder dunkler Marmor (Art déco).
func _rock_material() -> Material:
	match style.rock:
		"stone":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color("4f5346")
			m.roughness = 0.95
			m.metallic_specular = 0.12
			return m
		"marble":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color("16393b")
			m.roughness = 0.25
			m.metallic_specular = 0.8
			return m
	var glass := ShaderMaterial.new()
	glass.shader = ROCK_SHADER
	return glass


## Material für Neonröhren: innen weiß, außen col, energy > 1 leuchtet im Glow.
static func neon_material(col: Color, energy := 3.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = NEON_SHADER
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("energy", energy)
	return m


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
	_rebuild_ground()
	_rebuild_floor()
	_rebuild_markers()
	refresh_rocks()
	refresh_path()
	refresh_hover()


## Bodenfläche und Erde-Verteilung (ein Pixel pro Feld) neu berechnen.
func _rebuild_ground() -> void:
	var size := Vector2(map.width, map.height) * CELL
	var plane := PlaneMesh.new()
	plane.size = size
	_ground.mesh = plane
	_ground.position = to_3d(size / 2.0)
	_ground_mat.set_shader_parameter("map_size", size)
	# Abstand jedes Felds zur nächsten Erde-Quelle (Chamfer-Distanz, zwei Durchläufe)
	var w := map.width
	var h := map.height
	var dist := PackedFloat32Array()
	dist.resize(w * h)
	dist.fill(1e6)
	var pf := Pathfinder.new(map)
	for lane in map.lane_count():
		for c in pf.compute_path(lane):
			dist[c.y * w + c.x] = 0.0
	for p in map.all_waypoints():
		var r := map.marker_radius
		for y in range(maxi(p.y - r, 0), mini(p.y + r + 1, h)):
			for x in range(maxi(p.x - r, 0), mini(p.x + r + 1, w)):
				dist[y * w + x] = -DIRT_ZONE_EXTRA
	for y in h:
		for x in w:
			if map.get_tile(Vector2i(x, y)) == MapData.WALK_ONLY:
				dist[y * w + x] = 0.0
	const D := 1.4142
	for y in h:
		for x in w:
			var i := y * w + x
			var v := dist[i]
			if x > 0: v = minf(v, dist[i - 1] + 1.0)
			if y > 0:
				v = minf(v, dist[i - w] + 1.0)
				if x > 0: v = minf(v, dist[i - w - 1] + D)
				if x < w - 1: v = minf(v, dist[i - w + 1] + D)
			dist[i] = v
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			var v := dist[i]
			if x < w - 1: v = minf(v, dist[i + 1] + 1.0)
			if y < h - 1:
				v = minf(v, dist[i + w] + 1.0)
				if x < w - 1: v = minf(v, dist[i + w + 1] + D)
				if x > 0: v = minf(v, dist[i + w - 1] + D)
			dist[i] = v
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)  # RGBA8: L8 mit ungerader Breite wird im GL-Renderer verschoben hochgeladen
	for y in h:
		for x in w:
			var a := clampf(1.0 - (dist[y * w + x] - DIRT_CORE) / DIRT_FADE, 0.0, 1.0)
			img.set_pixel(x, y, Color(a, a, a))
	_ground_mat.set_shader_parameter("splat", ImageTexture.create_from_image(img))


## Neon-Feld: Fläche über die ganze Map, blockierte Felder (R) und Sperrzonen um die
## Wegpunkte (G) als Maske, ein Pixel pro Feld.
func _rebuild_floor() -> void:
	var size := Vector2(map.width, map.height) * CELL
	var plane := PlaneMesh.new()
	plane.size = size
	_floor.mesh = plane
	_floor.position = to_3d(size / 2.0, 0.001)
	var img := Image.create(map.width, map.height, false, Image.FORMAT_RGBA8)  # RGBA8: L8 mit ungerader Breite wird im GL-Renderer verschoben hochgeladen
	var origin := Vector2i(map.width, map.height)  # erstes freies Feld (oben links)
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			if map.get_tile(c) == MapData.BLOCKED:
				img.set_pixel(x, y, Color.WHITE)
			else:
				origin = origin.min(c)
				# G = Sperrzone um Spawn, Ziel und Checkpoints (nicht bebaubar)
				if map.is_marker_zone(c):
					img.set_pixel(x, y, Color(0, 1, 0))
	_floor_mat.set_shader_parameter("grid_origin", Vector2(origin))
	_floor_mat.set_shader_parameter("blocked", ImageTexture.create_from_image(img))
	_floor_mat.set_shader_parameter("cells", Vector2(map.width, map.height))


func refresh_rocks() -> void:
	if _rocks.is_empty():
		return
	var buckets := []
	for i in _rocks.size():
		buckets.append([])
	for c in rocks.keys():
		buckets[absi(c.x * 7 + c.y * 13) % _rocks.size()].append(c)
	for i in _rocks.size():
		var mm: MultiMesh = _rocks[i].multimesh
		mm.instance_count = buckets[i].size()
		var om: MultiMesh = _rock_outlines[i].multimesh if _rock_outlines[i] != null else null
		if om != null:
			om.instance_count = buckets[i].size()
		for j in buckets[i].size():
			var c: Vector2i = buckets[i][j]
			# leicht gedreht, damit nicht alle Steine gleich aussehen
			var turn := Basis(Vector3.UP, float((c.x * 7 + c.y * 13) % 4) * PI / 2.0)  # nur Vierteldrehungen: Stein bleibt in seinen Feldern
			var place := Transform3D(turn, to_3d(footprint_center(c)))
			mm.set_instance_transform(j, place * _rock_fits[i])
			if om != null:
				om.set_instance_transform(j, place * _rock_fits[i])


func refresh_selection() -> void:
	if _selection == null:
		_selection = _multimesh(_box(Vector3(TOWER_CELLS * CELL, 0.04, TOWER_CELLS * CELL)), false, Color(0.13, 0.77, 0.93, 0.45), true)
		var mat := _selection.material_override as StandardMaterial3D
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mm := _selection.multimesh
	mm.instance_count = selected_rocks.size()
	for i in selected_rocks.size():
		mm.set_instance_transform(i, Transform3D(Basis(), to_3d(footprint_center(selected_rocks[i]), 0.03)))


func refresh_path() -> void:
	if _path == null:
		return
	var pm := _path.material_override
	if pm is ShaderMaterial:
		pm.set_shader_parameter("color", path_color)
	elif pm is StandardMaterial3D:
		pm.albedo_color = path_color
		pm.emission = path_color
	var mm := _path.multimesh
	mm.instance_count = path_points.size()
	for i in path_points.size():
		mm.set_instance_transform(i, Transform3D(Basis(), to_3d(path_points[i], 0.02)))


func refresh_hover() -> void:
	if _hover == null:
		return
	_hover.visible = map != null and map.in_bounds(hover_cell)
	if _hover.visible:
		_hover.position = to_3d(footprint_center(hover_cell, hover_size), 0.0)
		_hover.scale = Vector3(hover_size, 1, hover_size)
		_hover_mat.albedo_color = Color(0.2, 1, 0.2, 0.4) if hover_ok else Color(1, 0.2, 0.2, 0.4)


func _rebuild_markers() -> void:
	for c in _markers.get_children():
		c.queue_free()
	# Maul-Maps: Spawn und Checkpoints jeder Bahn, Spawns mit Nummer ("S2"), Checkpoints z. B. "2.1"
	# (teilen sich Bahnen einen Punkt, steht dort ein Ring mit beiden Namen)
	var labels := {}
	var order: Array[Vector2i] = []
	var many := map.lane_count() > 1
	for lane in map.lane_count():
		var pts := map.waypoints(lane)
		for i in pts.size() - 1:
			var text := ("S%d" % (lane + 1) if many else "S") if i == 0 else ("%d.%d" % [lane + 1, i] if many else str(i))
			if not labels.has(pts[i]):
				labels[pts[i]] = []
				order.append(pts[i])
			labels[pts[i]].append(text)
	for c in order:
		_add_marker(c, " / ".join(labels[c]), style.marker)
	_add_marker(map.goal, "Z", style.marker)
	for z in map.zones:
		_add_zone(z.rect, PLAYER_COLORS[z.player % PLAYER_COLORS.size()] if z.player >= 0 else style.marker)


## Rand einer Zone (Maul-Maps) als dünne Neonlinie in der Farbe ihres Spielers.
func _add_zone(r: Rect2i, col: Color) -> void:
	var a := Vector2(r.position) * CELL
	var b := Vector2(r.end) * CELL
	var mat := FieldStyle.line_material(col, 2.4)
	for side in [[a, Vector2(b.x, a.y)], [Vector2(b.x, a.y), b], [b, Vector2(a.x, b.y)], [Vector2(a.x, b.y), a]]:
		var from: Vector2 = side[0]
		var to: Vector2 = side[1]
		var line := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(maxf(absf(to.x - from.x), 0.12), 0.02, maxf(absf(to.y - from.y), 0.12))
		line.mesh = box
		line.material_override = mat
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		line.position = Vector3((from.x + to.x) / 2.0, 0.03, (from.y + to.y) / 2.0)
		_markers.add_child(line)


## Wegpunkt als Neonröhren-Ring: nur die Kontur, mit überhelltem Kern, der im Glow leuchtet.
func _add_marker(c: Vector2i, text: String, col: Color) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.38
	torus.outer_radius = 0.48
	torus.rings = 48
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = FieldStyle.line_material(col, style.marker_energy)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = to_3d(cell_center(c), 0.04)
	_markers.add_child(ring)
	var label := Label3D.new()
	label.text = text
	label.font_size = 96
	label.pixel_size = 0.006
	label.outline_size = 24
	label.modulate = col.lerp(Color.WHITE, 0.5)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = to_3d(cell_center(c), 0.9)
	_markers.add_child(label)


## Feld unter dem Mauszeiger (Strahl von der Kamera auf die Bodenebene).
func mouse_cell(camera: Camera3D) -> Vector2i:
	var hit = _mouse_ground(camera)
	if hit == null:
		return Vector2i(-1, -1)
	return Vector2i(floori(hit.x / CELL), floori(hit.y / CELL))


## Anker für etwas mit size × size Feldern, dessen Mitte möglichst nah am Mauszeiger liegt.
func mouse_anchor(camera: Camera3D, size := TOWER_CELLS) -> Vector2i:
	var hit = _mouse_ground(camera)
	if hit == null:
		return Vector2i(-1, -1)
	return Vector2i(roundi(hit.x / CELL - size / 2.0), roundi(hit.y / CELL - size / 2.0))


## Schnittpunkt des Mausstrahls mit dem Boden als Vector2 (X, Z) oder null.
func _mouse_ground(camera: Camera3D):
	if camera == null:
		return null
	var mp := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mp)
	var dir := camera.project_ray_normal(mp)
	if absf(dir.y) < 0.0001:
		return null
	var t := -from.y / dir.y
	if t < 0.0:
		return null
	var hit := from + dir * t
	return Vector2(hit.x, hit.z)
