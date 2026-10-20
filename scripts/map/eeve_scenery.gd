class_name EeveScenery
extends Node3D
## Umgebung der eeveTD-Karte: Wald rund um das Spielfeld (Bäume, Unterholz, Waldboden), Laternen an
## Spawn, Wegpunkten und Ziel und die Nachtvariante (Mondlicht, leuchtende Laternen, Glühwürmchen).
## Rein optisch: läuft bei jedem Spieler gleich (fester Zufallsstartwert), nichts davon geht über das Netz.

## Tag oder Nacht; bleibt für die nächsten Spiele dieses Programmstarts erhalten.
static var night := false

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

const LANTERN_LIGHT := Color("ffb45a")
const POOL_SHADER := "res://assets/shaders/lantern_pool.gdshader"

## Nachtlicht; der Tag kommt aus FieldStyle (Druidenhain) und wird beim Umschalten wiederhergestellt.
const NIGHT := {
	"sky_top": Color("04070f"), "sky_horizon": Color("101c2a"), "ground_bottom": Color("05080a"),
	"ambient": Color("7f98c8"), "ambient_energy": 0.4,
	"sun": Color("9fb6ff"), "sun_energy": 0.42, "sun_pitch": -52.0,
	"fog": Color("0b1420"), "fog_density": 0.012,
	"glow_threshold": 0.9, "glow_intensity": 0.85, "exposure": 1.05,
}

var board: Board3D
var map: MapData
var _env: Environment
var _sun: DirectionalLight3D
var _fills: Array[DirectionalLight3D] = []
var _day := {}
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
			# Sonne = das Licht mit Schatten, weitere (Gegenlicht) gehen nachts aus
			if s._sun == null and c.shadow_enabled:
				s._sun = c
			else:
				s._fills.append(c)
	game.add_child(s)
	return s


func _ready() -> void:
	_rng.seed = hash(map.id) if map.id != "" else 7
	_remember_day()
	_add_forest_floor()
	_add_forest()
	_add_lanterns()
	_add_fireflies()
	# Laternen beleuchten Tower und Gegner, den Boden nur über ihren Lichtfleck (Ebene 2 ausgenommen)
	board._ground.layers = 2
	set_night(night)


## Zwischen Tag und Nacht umschalten (Debug-Menü, später z. B. Einstellungen oder Tageszeit-Wechsel).
func set_night(on: bool) -> void:
	night = on
	_apply_light(NIGHT if on else _day)
	for l in _lights:
		l.visible = on
	for p in _pools:
		p.visible = on
	_glass_mat.emission_energy_multiplier = 3.2 if on else 0.35
	_fireflies.emitting = on
	_fireflies.visible = on


## Tageslicht so festhalten, wie CameraRig.add_environment es angelegt hat (zum Zurückschalten).
func _remember_day() -> void:
	if _env == null:
		return
	_day = {"ambient": _env.ambient_light_color, "ambient_energy": _env.ambient_light_energy,
			"glow_threshold": _env.glow_hdr_threshold, "glow_intensity": _env.glow_intensity,
			"exposure": _env.tonemap_exposure, "fog_on": _env.fog_enabled,
			"fog": _env.fog_light_color, "fog_density": _env.fog_density}
	if _env.sky != null and _env.sky.sky_material is ProceduralSkyMaterial:
		var sky: ProceduralSkyMaterial = _env.sky.sky_material
		_day.merge({"sky_top": sky.sky_top_color, "sky_horizon": sky.sky_horizon_color,
				"ground_bottom": sky.ground_bottom_color})
	if _sun != null:
		_day.merge({"sun": _sun.light_color, "sun_energy": _sun.light_energy, "sun_pitch": rad_to_deg(_sun.rotation.x)})


func _apply_light(look: Dictionary) -> void:
	if _env == null:
		return
	if _env.sky != null and _env.sky.sky_material is ProceduralSkyMaterial and look.has("sky_top"):
		var sky: ProceduralSkyMaterial = _env.sky.sky_material
		sky.sky_top_color = look.sky_top
		sky.sky_horizon_color = look.sky_horizon
		sky.ground_horizon_color = look.sky_horizon
		sky.ground_bottom_color = look.ground_bottom
	for f in _fills:
		f.visible = look != NIGHT
	_env.ambient_light_color = look.get("ambient", _env.ambient_light_color)
	_env.ambient_light_energy = look.get("ambient_energy", _env.ambient_light_energy)
	_env.glow_hdr_threshold = look.get("glow_threshold", _env.glow_hdr_threshold)
	_env.glow_intensity = look.get("glow_intensity", _env.glow_intensity)
	_env.tonemap_exposure = look.get("exposure", _env.tonemap_exposure)
	_env.fog_enabled = bool(look.get("fog_on", true))
	if look.has("fog"):
		_env.fog_light_color = look.fog
		_env.fog_density = look.fog_density
		_env.fog_sky_affect = 0.0
	if _sun != null and look.has("sun"):
		_sun.light_color = look.sun
		_sun.light_energy = look.sun_energy
		_sun.rotation.x = deg_to_rad(look.sun_pitch)


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
			copy.surface_set_material(i, dark)
	return copy


## Eine Laterne an jedem Wegpunkt (Spawn, Checkpoints, Ziel): Holzpfosten mit Messinglaterne in der Ecke
## des Wegpunkts, die von den Wegen wegzeigt.
func _add_lanterns() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("3b2b1d")
	wood.roughness = 0.9
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("8a6a3a")
	brass.metallic = 0.7
	brass.roughness = 0.45
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.albedo_color = Color("ffd9a0")
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
		quad.size = Vector2.ONE * 6.5
		pool.mesh = quad
		var pm := ShaderMaterial.new()
		pm.shader = pool_shader
		pm.set_shader_parameter("light_color", LANTERN_LIGHT)
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
