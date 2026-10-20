class_name MaulGlassRoof
extends Node3D
## Glasdächer über den Gängen von Shopping Maul (wo Gegner laufen, aber nicht gebaut wird): ein
## hohes Tonnengewölbe aus Glas wie im Grand Palais, durchsichtig, mit grünem Eisenrahmen, getragen
## von schlanken grünen Säulen am Rand. Gänge kommen aus MaulCity.corridor, das Gewölbe aus dem Abstand
## jedes Gangfelds zum Rand (assets/shaders/glass_roof.gdshader hebt die Ebene danach an).

const SHADER := preload("res://assets/shaders/glass_roof.gdshader")
## Höhe der Dachkante über dem Boden, Gewölbe-Stich obendrauf (Einheiten)
const HEIGHT := 1.3
const RISE := 1.5
## Ab so vielen Feldern Abstand zum Rand ist das Gewölbe oben
const VAULT_CELLS := 6.0
## Säulen: an Randfeldern, jedes POST_EVERY-te Feld
const POST_EVERY := 4
const POST_COLOR := Color("4c7466")

var _mat: ShaderMaterial


func build(map: MapData, corridor: PackedByteArray) -> void:
	for c in get_children():
		c.queue_free()
	var w := map.width
	var h := map.height
	if corridor.size() != w * h:
		return
	# Abstand zum Rand (Felder, Chamfer 1/1.41), 0 außerhalb der Gänge
	var d := PackedFloat32Array()
	d.resize(w * h)
	for k in w * h:
		d[k] = 1e6 if corridor[k] == 1 else 0.0
	const D := 1.4142
	for y in h:
		for x in w:
			var k := y * w + x
			if d[k] == 0.0:
				continue
			var v := 1.0 if x == 0 or y == 0 else d[k]
			if x > 0: v = minf(v, d[k - 1] + 1.0)
			if y > 0:
				v = minf(v, d[k - w] + 1.0)
				if x > 0: v = minf(v, d[k - w - 1] + D)
				if x < w - 1: v = minf(v, d[k - w + 1] + D)
			d[k] = v
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var k := y * w + x
			if d[k] == 0.0:
				continue
			var v := 1.0 if x == w - 1 or y == h - 1 else d[k]
			if x < w - 1: v = minf(v, d[k + 1] + 1.0)
			if y < h - 1:
				v = minf(v, d[k + w] + 1.0)
				if x < w - 1: v = minf(v, d[k + w + 1] + D)
				if x > 0: v = minf(v, d[k + w - 1] + D)
			d[k] = v
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var posts: Array[Vector2i] = []
	for y in h:
		for x in w:
			var k := y * w + x
			if corridor[k] == 0:
				continue
			# Kreisbogen: am Rand senkrecht hoch, oben flach
			var t := clampf((d[k] - 0.5) / VAULT_CELLS, 0.0, 1.0)
			var arc := sqrt(1.0 - (1.0 - t) * (1.0 - t))
			img.set_pixel(x, y, Color(1.0, arc, 0.0))
			if d[k] <= 1.0 and (x + y) % POST_EVERY == 0:
				posts.append(Vector2i(x, y))
	var tex := ImageTexture.create_from_image(img)
	var size := Vector2(w, h) * Board3D.CELL
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = w - 1
	plane.subdivide_depth = h - 1
	var roof := MeshInstance3D.new()
	roof.mesh = plane
	roof.position = Vector3(size.x / 2.0, HEIGHT, size.y / 2.0)
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Gewölbe hebt die Ebene an: Sichtbarkeitsbox groß genug halten
	roof.extra_cull_margin = RISE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("mask", tex)
	_mat.set_shader_parameter("vault", tex)
	_mat.set_shader_parameter("cells", Vector2(w, h))
	_mat.set_shader_parameter("cell", Board3D.CELL)
	_mat.set_shader_parameter("rise", RISE)
	roof.material_override = _mat
	add_child(roof)
	# Säulen
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(0.08, HEIGHT, 0.08)
	mm.mesh = box
	mm.instance_count = posts.size()
	for i in posts.size():
		var p := (Vector2(posts[i]) + Vector2(0.5, 0.5)) * Board3D.CELL
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x, HEIGHT / 2.0, p.y)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = POST_COLOR
	pm.metallic = 0.4
	pm.roughness = 0.5
	mmi.material_override = pm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
