class_name EeveBonusTiles
extends Node3D
## Bonusfelder von eeveTD auf dem Boden: Lava (glühende Risse), Eis (hell, glänzend) und schwarzer Marmor
## (weiße Adern). Jedes Feld ist 2 × 2 Rasterfelder groß wie ein Tower. Die Lage kommt aus eeve_game.gd
## (bonus_tiles: Anker -> Sorte), hier wird nur gezeichnet.

const SIZE := Board3D.TOWER_CELLS * Board3D.CELL
const LIFT := 0.012  ## knapp über dem Boden, unter Weg und Auswahl

var _meshes := {}  ## Sorte -> MultiMeshInstance3D


## Alle Bonusfelder neu setzen. tiles: Vector2i (Anker) -> Sorte ("lava", "ice", "marble").
func show_tiles(tiles: Dictionary) -> void:
	var by_kind := {}
	for a in tiles:
		var kind := str(tiles[a])
		if not by_kind.has(kind):
			by_kind[kind] = []
		by_kind[kind].append(a)
	for kind in _meshes:
		if not by_kind.has(kind):
			_meshes[kind].multimesh.instance_count = 0
	for kind in by_kind:
		var mm := _mesh_for(kind).multimesh
		var list: Array = by_kind[kind]
		mm.instance_count = list.size()
		for i in list.size():
			var a: Vector2i = list[i]
			# Vierteldrehung je Feld, damit die Muster nicht alle gleich liegen
			var turn := Basis(Vector3.UP, float((a.x * 5 + a.y * 3) % 4) * PI / 2.0)
			mm.set_instance_transform(i, Transform3D(turn, Board3D.to_3d(Board3D.footprint_center(a), LIFT)))


func _mesh_for(kind: String) -> MultiMeshInstance3D:
	if _meshes.has(kind):
		return _meshes[kind]
	var box := PlaneMesh.new()
	box.size = Vector2(SIZE * 0.94, SIZE * 0.94)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _material(kind)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = 3  # Ebene 2 wie der Boden: die Laternen leuchten auch die Bonusfelder an
	add_child(mi)
	_meshes[kind] = mi
	return mi


## Rauschbild über eine Farbrampe als Textur, gleich fertig (NoiseTexture2D rechnet im Hintergrund und ist im
## ersten Bild noch leer). stops: [[Wert 0..1, Farbe], …] aufsteigend.
static func _noise(seed: int, freq: float, stops: Array, cellular := false, ridged := false) -> ImageTexture:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq
	if cellular:
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	if ridged:
		n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	var src := n.get_seamless_image(128, 128)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array(stops.map(func(s): return float(s[0])))
	ramp.colors = PackedColorArray(stops.map(func(s): return s[1]))
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			img.set_pixel(x, y, ramp.sample(src.get_pixel(x, y).r))
	return ImageTexture.create_from_image(img)


static func _material(kind: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	match kind:
		"lava":
			# dunkle Kruste, die Risse dazwischen glühen
			m.albedo_color = Color(0.3, 0.09, 0.05)
			m.emission_enabled = true
			m.emission_texture = _noise(11, 0.06, [[0.0, Color(1.0, 0.75, 0.25)], [0.05, Color(0.9, 0.3, 0.04)],
				[0.13, Color(0.12, 0.02, 0.0)], [1.0, Color(0.0, 0.0, 0.0)]], true)
			m.emission = Color.BLACK  # Textur wird zur Farbe addiert: nur die Risse leuchten
			m.emission_energy_multiplier = 1.6
			m.roughness = 0.85
		"ice":
			m.albedo_texture = _noise(23, 0.05, [[0.0, Color(0.55, 0.8, 0.95)], [1.0, Color(0.9, 0.97, 1.0)]])
			m.roughness = 0.12
			m.metallic_specular = 0.9
			m.emission_enabled = true
			m.emission = Color(0.35, 0.6, 0.75)
			m.emission_energy_multiplier = 0.25
		_:
			# schwarzer Marmor mit feinen hellen Adern
			m.albedo_texture = _noise(37, 0.02, [[0.0, Color(0.06, 0.06, 0.08)], [0.6, Color(0.1, 0.1, 0.12)],
				[0.8, Color(0.35, 0.34, 0.33)], [1.0, Color(0.85, 0.83, 0.78)]], false, true)
			m.roughness = 0.15
			m.metallic_specular = 0.8
	m.uv1_scale = Vector3(0.5, 0.5, 0.5)
	return m
