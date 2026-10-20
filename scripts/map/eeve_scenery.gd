class_name EeveScenery
extends Node3D
## Umgebung der eeveTD-Karte: Wald rund um das Spielfeld (Bäume, Unterholz, Waldboden), Laternen an
## Spawn, Wegpunkten und Ziel und die Nachtvariante (Mondlicht, leuchtende Laternen, Glühwürmchen).
## Rein optisch: läuft bei jedem Spieler gleich (fester Zufallsstartwert), nichts davon geht über das Netz.

const N := "res://assets/models/nature/%s.glb"
## Bäume: [Modell, Höhe von, Höhe bis, Gewicht]
const TREES := [
	["pine_1", 3.6, 5.6, 3.0], ["pine_2", 3.4, 5.2, 3.0], ["pine_3", 3.8, 6.0, 2.0], ["pine_5", 3.0, 4.6, 2.0],
	["common_tree_3", 3.2, 4.8, 1.5], ["common_tree_4", 3.4, 5.0, 1.5], ["common_tree_5", 3.0, 4.6, 1.5],
]
## Unterholz am Waldrand: [Modell, Größe von, Größe bis, Gewicht]
const UNDERGROWTH := [
	["bush_common", 0.9, 1.5, 3.0], ["bush_common_flowers", 0.9, 1.4, 1.5], ["fern_1", 0.7, 1.2, 3.0],
	["plant_1", 0.6, 1.0, 1.5], ["plant_7", 0.6, 1.0, 1.5], ["mushroom_red_group", 0.35, 0.55, 0.8],
	["mushroom_tan_group", 0.35, 0.55, 0.8], ["mushroom_common", 0.3, 0.5, 0.6], ["rock_medium_1", 0.6, 1.1, 0.8],
	["rock_medium_2", 0.6, 1.1, 0.8], ["flower_3_group", 0.4, 0.7, 1.0],
]
## Wie tief der Wald um die Karte reicht (Einheiten) und wie weit der Waldboden.
const DEPTH := 26.0
const FLOOR_MARGIN := 90.0
## Bis zu diesem Abstand vom Rand werfen Bäume Schatten (weiter weg sieht man sie kaum, spart Leistung).
const SHADOW_DEPTH := 6.0

## Farbe, mit der Bäume und Unterholz multipliziert werden.
const FOREST_TINT := Color(0.6, 0.66, 0.55)

const LANTERN_LIGHT := Color("ff8a2a")
const POOL_SHADER := "res://assets/shaders/lantern_pool.gdshader"

## Nacht (FieldStyle.night): Licht und Nebel stehen in FieldStyle ("env_night" von Druidenhain), dazu hier
## Bodennebel und kühlerer, dunklerer Boden und Wald (Faktoren auf die Tagwerte).
const NIGHT_EXTRA := {
	"fog_height": 0.6, "fog_height_density": 0.05,
	"ground_tint": Vector3(0.72, 0.8, 1.0), "ground_brightness": 0.8, "forest_tint": Color(0.5, 0.56, 0.78),
}

var board: Board3D
var map: MapData
var _env: Environment
var _lights_env: Array = []  ## Sonne/Mond und Gegenlicht aus CameraRig.add_environment
var _ground_day := []   ## [tint, brightness] des Spielfeldbodens am Tag
var _forest_mats := []  ## [Material, Tagesfarbe] der Bäume und Büsche
var _lights: Array[OmniLight3D] = []
var _pools: Array[MeshInstance3D] = []
var _glass_mat: StandardMaterial3D
var _fireflies: CPUParticles3D
var _rng := RandomNumberGenerator.new()


## Wald und Laternen neben das Spielfeld von game setzen und Tag oder Nacht einstellen.
static func add_to(game: Node) -> EeveScenery:
	var s := EeveScenery.new()
	s.board = game.board
	s.map = game.map
	for c in game.get_children():
		if c is WorldEnvironment:
			s._env = c.environment
		elif c is DirectionalLight3D:
			s._lights_env.append(c)
	game.add_child(s)
	return s


func _ready() -> void:
	_rng.seed = hash(map.id) if map.id != "" else 7
	var gm: ShaderMaterial = board._ground_mat
	var tint = gm.get_shader_parameter("tint")
	var bright = gm.get_shader_parameter("brightness")
	_ground_day = [tint if tint is Vector3 else Vector3.ONE, float(bright) if bright != null else 0.72]
	_add_forest_floor()
	_add_forest()
	_add_lanterns()
	_add_fireflies()
	# Laternen beleuchten Tower und Gegner, den Boden nur über ihren Lichtfleck (Ebene 2 ausgenommen)
	board._ground.layers = 2
	_apply(FieldStyle.night)


## Zwischen Tag und Nacht umschalten (Debug-Menü, später z. B. Einstellungen oder Tageszeit-Wechsel):
## Licht und Himmel baut CameraRig.add_environment neu aus FieldStyle.env().
func set_night(on: bool) -> void:
	if on != FieldStyle.night:
		FieldStyle.night = on
		var game := get_parent()
		for c in game.get_children():
			if c is WorldEnvironment or c is DirectionalLight3D:
				game.remove_child(c)
				c.queue_free()
		var made: Dictionary = CameraRig.add_environment(game)
		_env = made.env
		_lights_env = [made.sun]
		if made.get("fill") != null:
			_lights_env.append(made.fill)
	_apply(on)


## Sonne bzw. Mond (das Licht mit Schatten) für Tests und Debug.
func sun() -> DirectionalLight3D:
	for l in _lights_env:
		if l.shadow_enabled:
			return l
	return null


func _apply(on: bool) -> void:
	var look: Dictionary = NIGHT_EXTRA if on else {}
	if _env != null:
		_env.fog_height = look.get("fog_height", 0.0)
		_env.fog_height_density = look.get("fog_height_density", 0.0)
	var gm: ShaderMaterial = board._ground_mat
	gm.set_shader_parameter("tint", _ground_day[0] * look.get("ground_tint", Vector3.ONE))
	gm.set_shader_parameter("brightness", _ground_day[1] * look.get("ground_brightness", 1.0))
	for m in _forest_mats:
		m[0].albedo_color = m[1] * look.get("forest_tint", Color.WHITE)
	for l in _lights:
		l.visible = on
	for p in _pools:
		p.visible = on
	_glass_mat.emission_energy_multiplier = 3.2 if on else 0.35
	_fireflies.emitting = on
	_fireflies.visible = on


func _size() -> Vector2:
	return Vector2(map.width, map.height) * Board3D.CELL


## Waldboden um die Karte: derselbe Boden-Shader wie das Spielfeld, nur Gras und etwas dunkler.
func _add_forest_floor() -> void:
	var size := _size()
	var plane := PlaneMesh.new()
	plane.size = size + Vector2.ONE * FLOOR_MARGIN * 2.0
	var floor := MeshInstance3D.new()
	floor.mesh = plane
	var mat: ShaderMaterial = board._ground_mat.duplicate()
	var none := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	none.fill(Color.BLACK)
	mat.set_shader_parameter("splat", ImageTexture.create_from_image(none))
	mat.set_shader_parameter("ground_alpha", 1.0)
	mat.set_shader_parameter("brightness", float(mat.get_shader_parameter("brightness")) * 0.72)
	mat.set_shader_parameter("tint", Vector3(0.82, 0.95, 0.72))
	floor.material_override = mat
	floor.position = Vector3(size.x / 2.0, -0.02, size.y / 2.0)
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	floor.layers = 2
	add_child(floor)


## Abstand eines Punkts zum Rand der Karte (0 innerhalb).
func _outside(p: Vector2) -> float:
	var size := _size()
	var dx := maxf(maxf(-p.x, p.x - size.x), 0.0)
	var dy := maxf(maxf(-p.y, p.y - size.y), 0.0)
	return Vector2(dx, dy).length()


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


func _add_forest() -> void:
	var size := _size()
	# Pro Modell zwei Listen (nah mit Schatten, fern ohne): [Transform3D, ...]
	var trees := {}
	var step := 1.45
	var y := -DEPTH
	while y < size.y + DEPTH:
		var x := -DEPTH
		while x < size.x + DEPTH:
			var p := Vector2(x, y) + Vector2(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.6, 0.6)) * step
			var d := _outside(p)
			x += step
			# erste Reihe dicht am Rand, nach außen lichter; ganz am Rand Platz fürs Unterholz
			if d < 0.9 or d > DEPTH:
				continue
			if _rng.randf() > lerpf(0.9, 0.45, d / DEPTH):
				continue
			var i := _pick(TREES)
			# am Rand niedrig, damit Bäume Spawn, Ziel und Tower am Kartenrand nicht verdecken, nach außen höher
			var h := _rng.randf_range(TREES[i][1], TREES[i][2]) * lerpf(0.45, 1.0, clampf((d - 1.0) / 6.0, 0.0, 1.0)) \
					* lerpf(1.0, 1.35, d / DEPTH)
			var key := "%s|%d" % [TREES[i][0], 1 if d < SHADOW_DEPTH else 0]
			trees.get_or_add(key, []).append(_place(p, h))
		y += step
	# Unterholz in einem schmalen Streifen direkt am Rand
	step = 0.75
	y = -4.0
	while y < size.y + 4.0:
		var x := -4.0
		while x < size.x + 4.0:
			var p := Vector2(x, y) + Vector2(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5)) * step
			var d := _outside(p)
			x += step
			if d < 0.25 or d > 4.0 or _rng.randf() > lerpf(0.75, 0.15, d / 4.0):
				continue
			var i := _pick(UNDERGROWTH)
			var key := "%s|1" % UNDERGROWTH[i][0]
			trees.get_or_add(key, []).append(_place(p, _rng.randf_range(UNDERGROWTH[i][1], UNDERGROWTH[i][2])))
		y += step
	for key in trees:
		var parts: PackedStringArray = key.split("|")
		_add_multimesh(N % parts[0], trees[key], parts[1] == "1")


## Lage eines Modells mit Höhe (bzw. größter Kante) h: gedreht, leicht schief.
func _place(p: Vector2, h: float) -> Transform3D:
	var b := Basis(Vector3.UP, _rng.randf() * TAU)
	b = Basis(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized(), _rng.randf_range(0.0, 0.06)) * b
	return Transform3D(b.scaled(Vector3.ONE * h), Vector3(p.x, 0.0, p.y))


func _add_multimesh(path: String, xfs: Array, shadows: bool) -> void:
	var m := ModelLoader.mesh_with_transform(path, 1.0)
	if m.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _muted(m[0])
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i] * m[1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Kopie des Meshes mit abgedunkelten Materialien: die Modelle sind satter als der Boden (Druidenhain
## entsättigt), der Wald soll hinter Spielfeld und Towern zurücktreten.
func _muted(mesh: Mesh) -> Mesh:
	var copy: Mesh = mesh.duplicate()
	for i in copy.get_surface_count():
		var mat := copy.surface_get_material(i)
		if mat is BaseMaterial3D:
			var dark: BaseMaterial3D = mat.duplicate()
			dark.albedo_color *= FOREST_TINT
			_forest_mats.append([dark, dark.albedo_color])
			copy.surface_set_material(i, dark)
	return copy


## Eine Laterne an jedem Wegpunkt (Spawn, Checkpoints, Ziel): Holzpfosten mit Messinglaterne in der Ecke
## des Wegpunkts, die von den Wegen wegzeigt.
func _add_lanterns() -> void:
	# schwarzes Eisen wie die Laternenpfähle in Duskwood
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("1e1c22")
	wood.metallic = 0.6
	wood.roughness = 0.55
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("2a2620")
	brass.metallic = 0.75
	brass.roughness = 0.4
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.albedo_color = Color("ffb870")
	_glass_mat.emission_enabled = true
	_glass_mat.emission = LANTERN_LIGHT
	var pool_shader: Shader = load(POOL_SHADER)
	var pts := map.all_waypoints()
	var lanes: Array = []
	for lane in map.lane_count():
		lanes.append(map.waypoints(lane))
	var n := 0
	for c in pts:
		var at := board.cell_center(c)
		var corner := _free_corner(c, lanes)
		var foot: Vector2 = at + corner * (float(map.marker_radius) + 0.5) * Board3D.CELL * 1.15
		var root := Node3D.new()
		root.position = Vector3(foot.x, 0, foot.y)
		add_child(root)
		_part(root, _cyl(0.05, 0.065, 1.3), wood, Vector3(0, 0.65, 0))
		_part(root, _box(Vector3(0.2, 0.05, 0.2)), brass, Vector3(0, 1.32, 0))
		_part(root, _box(Vector3(0.13, 0.2, 0.13)), _glass_mat, Vector3(0, 1.45, 0))
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				_part(root, _box(Vector3(0.025, 0.22, 0.025)), brass, Vector3(sx * 0.075, 1.45, sz * 0.075))
		_part(root, _cyl(0.0, 0.13, 0.12), brass, Vector3(0, 1.61, 0))
		var light := OmniLight3D.new()
		light.light_color = LANTERN_LIGHT
		light.light_energy = 2.2
		light.omni_range = 3.6
		light.omni_attenuation = 1.4
		light.light_cull_mask = 1
		light.shadow_enabled = false
		light.position = Vector3(0, 1.45, 0)
		root.add_child(light)
		_lights.append(light)
		var pool := MeshInstance3D.new()
		var quad := PlaneMesh.new()
		quad.size = Vector2.ONE * 5.2
		pool.mesh = quad
		var pm := ShaderMaterial.new()
		pm.shader = pool_shader
		pm.set_shader_parameter("light_color", Color(1.0, 0.66, 0.22))
		pm.set_shader_parameter("phase", float(n) * 2.3)
		# Der Boden ist durchsichtig (ALPHA) und wird nach Abstand sortiert: Lichtflecken immer danach zeichnen
		pm.render_priority = 2
		pool.material_override = pm
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pool.position = Vector3(foot.x, 0.03, foot.y)
		add_child(pool)
		_pools.append(pool)
		n += 1


## Ecke (diagonale Richtung) eines Wegpunkts, die am weitesten von den Wegen dorthin und von dort weg liegt.
func _free_corner(c: Vector2i, lanes: Array) -> Vector2:
	var dirs: Array[Vector2] = []
	for pts in lanes:
		var i: int = pts.find(c)
		if i < 0:
			continue
		if i > 0:
			dirs.append(Vector2(pts[i - 1] - c).normalized())
		if i < pts.size() - 1:
			dirs.append(Vector2(pts[i + 1] - c).normalized())
	if c == map.goal or dirs.is_empty():
		# ohne Weg: die Ecke zur Kartenmitte hin
		dirs.append((Vector2(c) - Vector2(map.width, map.height) / 2.0).normalized())
	var best := Vector2(1, -1)
	var best_score := INF
	for corner in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		var score := -INF
		for d in dirs:
			score = maxf(score, corner.normalized().dot(d))
		# nicht über den Kartenrand hinaus
		var p: Vector2 = Vector2(c) + corner * (map.marker_radius + 1)
		if p.x < 1 or p.y < 1 or p.x > map.width - 2 or p.y > map.height - 2:
			score += 3.0
		if score < best_score:
			best_score = score
			best = corner
	return best


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	# Die Laterne ist selbst die Lichtquelle: ihr Mond-/Sonnenschatten liefe quer durch den eigenen Lichtfleck
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 8
	c.rings = 1
	return c


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## Glühwürmchen am Waldrand unter den Bäumen hervor (nur nachts), nicht mitten über dem Spielfeld,
## damit sie nicht wie die Wegpunkte aussehen.
func _add_fireflies() -> void:
	var size := _size()
	var pts := PackedVector3Array()
	while pts.size() < 400:
		var p := Vector2(_rng.randf_range(-8.0, size.x + 8.0), _rng.randf_range(-8.0, size.y + 8.0))
		var inside := minf(minf(p.x, size.x - p.x), minf(p.y, size.y - p.y))
		var d := _outside(p) if inside < 0.0 else -inside
		if d > -2.0 and d < 2.5:
			pts.append(Vector3(p.x, _rng.randf_range(0.3, 2.4), p.y))
	_fireflies = CPUParticles3D.new()
	_fireflies.amount = 140
	_fireflies.lifetime = 5.0
	_fireflies.preprocess = 5.0
	_fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	_fireflies.emission_points = pts
	_fireflies.direction = Vector3(0, 1, 0)
	_fireflies.spread = 180.0
	_fireflies.gravity = Vector3.ZERO
	_fireflies.initial_velocity_min = 0.05
	_fireflies.initial_velocity_max = 0.25
	var fade := Gradient.new()
	fade.set_offset(0, 0.0)
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_offset(1, 1.0)
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 1))
	fade.add_point(0.7, Color(1, 1, 1, 1))
	_fireflies.color_ramp = fade
	var dot := SphereMesh.new()
	dot.radius = 0.05
	dot.height = 0.1
	dot.radial_segments = 6
	dot.rings = 3
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color("e8f080")
	m.emission_enabled = true
	m.emission = Color("d8f060")
	m.emission_energy_multiplier = 5.0
	dot.material = m
	_fireflies.mesh = dot
	_fireflies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fireflies)
