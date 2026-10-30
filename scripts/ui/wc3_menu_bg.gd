class_name Wc3MenuBg
extends Node3D
## 3D-Hintergrund des Hauptmenüs (Wc3Theme): Lichtung im Nachtwald mit Kristallschrein. Großer blauer Kristall,
## halb durchsichtig, mit leuchtendem Kern, Säulenring, kleine bunte Kristalle, Kirche, Grabsteine, zwei Laternen
## mit flackerndem Licht. Himmel = Nacht-Panorama mit Mond (assets/textures/menu/).

const M := "res://assets/models/"
const SKY := "res://assets/textures/menu/nachthimmel_mond.jpg"
## Stelle des Monds im Bild (Anteil der Breite/Höhe), daraus kommt die Richtung des Mondlichts.
const MOON_SCREEN := Vector2(0.56, 0.13)
## Flackern und Pulsieren wiederholen sich nach dieser Zeit (Sekunden).
const LOOP := 4.0

var rng := RandomNumberGenerator.new()
var camera: Camera3D
var moon: DirectionalLight3D
var _flames: Array = []   ## [OmniLight3D, MeshInstance3D, Phase]
var _core_light: OmniLight3D
var _core_mat: StandardMaterial3D
var _time := 0.0


func _ready() -> void:
	rng.seed = 7
	_environment()
	_ground()
	_shrine()
	_surroundings()
	camera = Camera3D.new()
	camera.fov = 45
	add_child(camera)
	camera.position = Vector3(5.5, 4.2, 20)
	camera.look_at(Vector3(0.5, 2.2, -2), Vector3.UP)
	camera.make_current()
	# Mondlicht kommt aus der Richtung, in der der Mond im Bild steht
	var vs := get_viewport().get_visible_rect().size
	var to_moon := camera.project_ray_normal(vs * MOON_SCREEN)
	moon.look_at_from_position(Vector3.ZERO, -to_moon, Vector3.UP)
	_animate(0.0)


func _process(delta: float) -> void:
	_time = fmod(_time + delta, LOOP)
	_animate(_time / LOOP)


func _animate(t: float) -> void:
	var pulse := 0.85 + 0.15 * sin(TAU * t)
	_core_light.light_energy = 3.0 * pulse
	_core_mat.emission_energy_multiplier = 1.8 * pulse
	for f in _flames:
		var k := _flicker(t, f[2])
		f[0].light_energy = 2.4 * k
		f[1].scale = Vector3.ONE * (0.8 + 0.25 * k)


## Flackern aus drei Sinuswellen mit ganzzahligen Perioden je LOOP.
func _flicker(t: float, ph: float) -> float:
	return 1.0 + 0.16 * sin(TAU * 3.0 * t + ph) + 0.10 * sin(TAU * 7.0 * t + ph * 2.3) + 0.07 * sin(TAU * 13.0 * t + ph * 0.7)


func _environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load(SKY)
	pano.energy_multiplier = 1.6
	sky.sky_material = pano
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3b4a78")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.glow_enabled = Display.q("glow")
	env.glow_intensity = 0.7
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color("2a3050")
	env.fog_density = 0.045
	env.fog_sky_affect = 0.12
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	moon = DirectionalLight3D.new()
	moon.light_color = Color("b8d8e8")
	moon.light_energy = 0.45
	moon.shadow_enabled = true
	add_child(moon)


func _ground() -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	g.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://assets/textures/ground/grass_a.jpg")
	gm.normal_enabled = true
	gm.normal_texture = load("res://assets/textures/ground/grass_a_normal.jpg")
	gm.uv1_scale = Vector3(150, 150, 1)
	gm.albedo_color = Color(0.35, 0.42, 0.36)
	g.material_override = gm
	add_child(g)
	# Weg aus Erde zum Schrein
	var w := MeshInstance3D.new()
	var wm := PlaneMesh.new()
	wm.size = Vector2(3.2, 30)
	w.mesh = wm
	var dm := StandardMaterial3D.new()
	dm.albedo_texture = load("res://assets/textures/ground/dirt.jpg")
	dm.uv1_scale = Vector3(2, 18, 1)
	dm.albedo_color = Color(0.42, 0.36, 0.3)
	w.material_override = dm
	w.position = Vector3(-1.5, 0.01, 14)
	w.rotation.y = 0.35
	add_child(w)


## Schrein: großer Kristall auf Sockel mit leuchtendem Kern, Säulenring, kleine Kristalle.
func _shrine() -> void:
	var c := Vector3(-3.5, 0, 0)
	_place("nature/statue_block.glb", c, 1.0)
	var shell := _place("crystals/quaternius_big_crystal.glb", c + Vector3(0, 1.0, 0), 3.2, 0.4)
	var sm := _glow_mat(Color(0.18, 0.52, 0.82, 0.5), 0.8)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.rim_enabled = true
	sm.rim = 0.8
	sm.rim_tint = 0.6
	_recolor(shell, sm)
	_light(c + Vector3(0, 2.5, 0), Color("6cc8ff"), 5.0, 12.0)
	# Leuchtender Kern (Lukas, 2026-10-28): kleinere Kopie, scheint durch die Hülle
	var core := _place("crystals/quaternius_big_crystal.glb", c + Vector3(0, 1.55, 0), 1.7, 1.3)
	_core_mat = StandardMaterial3D.new()
	_core_mat.albedo_color = Color(0.3, 0.6, 0.8)
	_core_mat.emission_enabled = true
	_core_mat.emission = Color("7fd4ff")
	_core_mat.emission_energy_multiplier = 1.8
	_core_mat.rim_enabled = true
	_core_mat.rim = 1.0
	_recolor(core, _core_mat)
	_core_light = _light(c + Vector3(0, 2.4, 0), Color("8fd8ff"), 3.0, 7.0)
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		var p := c + Vector3(cos(a) * 4.6, 0, sin(a) * 4.6)
		if i % 3 == 1:
			_place("nature/statue_column_damaged.glb", p, 2.2, -a)
		else:
			_place("nature/statue_column.glb", p, 3.6, -a)
	var cols := [Color("ff4f9a"), Color("9a6cff"), Color("4fffb0"), Color("ffcc4f")]
	for i in 7:
		var p := c + Vector3(rng.randf_range(-7, 6), 0, rng.randf_range(-4, 6))
		var k := _place("crystals/crystal_%02d.glb" % rng.randi_range(0, 27), p, rng.randf_range(0.5, 1.1), rng.randf() * TAU)
		var col: Color = cols[i % cols.size()]
		_recolor(k, _glow_mat(col.darkened(0.3), 0.8))
		_light(p + Vector3(0, 0.6, 0), col, 1.2, 4.0)


## Kirche, Grabsteine, Laternen, Wald, Felsen und Pflanzen.
func _surroundings() -> void:
	var c := Vector3(-3.5, 0, 0)
	_place("scenery/church.glb", Vector3(-2, 0, -26), 13.0, 0.25)
	_light(Vector3(-2, 4, -22), Color("ffaa55"), 4.0, 10.0)
	var stones := ["round", "cross", "bevel", "broken", "wide", "decorative"]
	for i in 6:
		var p := Vector3(rng.randf_range(2, 9), 0, rng.randf_range(-12, -2))
		_place("scenery/gravestone_%s.glb" % stones[i], p, rng.randf_range(0.7, 1.1), rng.randf_range(-0.4, 0.4))
	for p in [Vector3(-8.5, 0, 3.5), Vector3(1.0, 0, 3.5)]:
		_place("scenery/lightpost_single.glb", p, 2.6)
		_flame(p + Vector3(0, 2.1, 0.57))
	var trees := ["pine_1", "pine_2", "pine_3", "pine_5", "common_tree_3", "common_tree_4"]
	for i in 90:
		var a := rng.randf() * TAU
		var r := rng.randf_range(13, 45)
		var p := Vector3(cos(a) * r - 3, 0, sin(a) * r - 6)
		if p.z > 6 and absf(p.x + 1) < 10:
			continue
		_place("nature/%s.glb" % trees[rng.randi() % trees.size()], p, rng.randf_range(7, 13), rng.randf() * TAU)
	for i in 14:
		var p := Vector3(rng.randf_range(-14, 10), 0, rng.randf_range(-10, 8))
		if p.distance_to(c) < 5.5:
			continue
		_place("nature/rock_medium_%d.glb" % rng.randi_range(1, 3), p, rng.randf_range(0.4, 0.9), rng.randf() * TAU)
	var plants := ["hp_bush011", "fern_1", "bush_common", "mushroom_red_group", "hp_weed011"]
	for i in 30:
		var p := Vector3(rng.randf_range(-16, 12), 0, rng.randf_range(-12, 10))
		if p.distance_to(c) < 4.8:
			continue
		_place("nature/%s.glb" % plants[i % plants.size()], p, rng.randf_range(0.5, 1.2), rng.randf() * TAU)


## Modell auf Höhe h skaliert, mit der Unterkante auf pos.
func _place(path: String, pos: Vector3, h: float, rot := 0.0) -> Node3D:
	var n: Node3D = load(M + path).instantiate()
	add_child(n)
	var ab := _aabb(n)
	var s: float = h / maxf(ab.size.y, 0.001)
	n.scale = Vector3.ONE * s
	n.rotation.y = rot
	n.position = pos - Vector3(0, ab.position.y * s, 0)
	return n


func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (n.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _glow_mat(col: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = e
	m.metallic = 0.3
	m.roughness = 0.2
	return m


func _recolor(n: Node, mat: Material) -> void:
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat


func _light(pos: Vector3, col: Color, energy: float, range_: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = range_
	l.omni_attenuation = 1.4
	add_child(l)
	return l


## Flamme in der Laterne: Glühen als Billboard ohne Tiefentest (die Laterne ist geschlossen) plus warmes Licht.
func _flame(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = true
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.72, 0.32, 1.0))
	g.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	g.add_point(0.18, Color(1.0, 0.55, 0.18, 0.85))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 128
	gt.height = 128
	m.albedo_texture = gt
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var l := _light(pos + Vector3(0, 0.05, 0), Color("ff9a40"), 2.4, 6.5)
	_flames.append([l, mi, rng.randf() * TAU])
