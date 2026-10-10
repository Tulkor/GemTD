class_name ModelLoader
extends RefCounted
## Lädt optionale 3D-Modelle für Tower, Gegner und Steine.
## In den JSON-Daten: "model": "res://assets/models/….glb" und optional "model_scale" (Größe in Towerbreiten).
## Modelle werden automatisch auf die Größe gebracht (längste Kante = model_scale),
## mittig auf den Boden gestellt und können eingefärbt werden.
## Fehlt das Modell, zeichnet das Spiel eine eingebaute einfache Form.

static var _cache := {}


static func _load(path: String) -> PackedScene:
	if path == "":
		return null
	if not _cache.has(path):
		var res = load(path) if ResourceLoader.exists(path) else null
		_cache[path] = res if res is PackedScene else null
		if _cache[path] == null:
			push_warning("Modell nicht gefunden: " + path)
	return _cache[path]


## Modell als Knoten, normalisiert auf `size` Towerbreiten. tint != null färbt alle Flächen ein.
static func instantiate(path: String, size := 1.0, tint: Material = null) -> Node3D:
	var scene := _load(path)
	if scene == null:
		return null
	var model = scene.instantiate()
	if not model is Node3D:
		model.free()
		return null
	var holder := Node3D.new()
	holder.add_child(model)
	var box := aabb(model, Transform3D())
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest > 0.0:
		var s := size / longest
		model.scale = Vector3.ONE * s
		model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * s
	if tint != null:
		_apply_material(model, tint)
	return holder


## Wie instantiate, aber auf eine Grundfläche skaliert: breiteste waagrechte Kante = width,
## höchstens max_height hoch.
static func instantiate_fit(path: String, width: float, max_height: float, tint: Material = null) -> Node3D:
	var holder := instantiate(path, 1.0, tint)
	if holder == null:
		return null
	var model: Node3D = holder.get_child(0)
	var box := aabb(holder, Transform3D())
	var flat := maxf(box.size.x, box.size.z)
	if flat <= 0.0:
		return holder
	var f := width / flat
	if box.size.y * f > max_height:
		f = max_height / box.size.y
	model.scale *= f
	model.position *= f
	return holder


## Erstes Mesh eines Modells, normalisiert (für MultiMesh, z. B. Steine).
## Rückgabe: [Mesh, Transform3D] oder [] wenn nicht vorhanden.
## flat = true: breiteste waagrechte Kante = size (füllt die Grundfläche), sonst längste Kante.
## max_height > 0 begrenzt die Höhe durch Stauchen in Y (Breite bleibt).
static func mesh_with_transform(path: String, size := 1.0, flat := false, max_height := 0.0) -> Array:
	var scene := _load(path)
	if scene == null:
		return []
	var model = scene.instantiate()
	var mi := _first_mesh(model, Transform3D())
	model.free()
	if mi.is_empty():
		return []
	var mesh: Mesh = mi[0]
	var xf: Transform3D = mi[1]
	var box: AABB = xf * mesh.get_aabb()
	var longest := maxf(box.size.x, box.size.z) if flat else maxf(box.size.x, maxf(box.size.y, box.size.z))
	var s := size / longest if longest > 0.0 else 1.0
	var sy := s
	if max_height > 0.0 and box.size.y * s > max_height:
		sy = max_height / box.size.y
	var scale := Vector3(s, sy, s)
	var fit := Transform3D(Basis().scaled(scale), -Vector3(box.get_center().x, box.position.y, box.get_center().z) * scale)
	return [mesh, fit * xf]


static func aabb(n: Node, xf: Transform3D) -> AABB:
	var local: Transform3D = xf * (n.transform if n is Node3D else Transform3D())
	var box := AABB()
	var empty := true
	if n is MeshInstance3D and n.mesh != null:
		box = local * n.mesh.get_aabb()
		empty = false
	for c in n.get_children():
		var b := aabb(c, local)
		if b.size != Vector3.ZERO:
			box = b if empty else box.merge(b)
			empty = false
	return box


static func _first_mesh(n: Node, xf: Transform3D) -> Array:
	var local: Transform3D = xf * (n.transform if n is Node3D else Transform3D())
	if n is MeshInstance3D and n.mesh != null:
		return [n.mesh, local]
	for c in n.get_children():
		var r := _first_mesh(c, local)
		if not r.is_empty():
			return r
	return []


static func _apply_material(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		n.material_override = mat
	for c in n.get_children():
		_apply_material(c, mat)


## Alle Materialien des Modells leicht durchsichtig machen, Farben und Texturen bleiben.
## glow: Farbe des Lichts von unten (Sockel), schwach als Eigenleuchten.
static func make_translucent(n: Node, alpha: float, glow := Color.BLACK) -> void:
	if n is MeshInstance3D and n.mesh != null:
		for i in n.mesh.get_surface_count():
			var src: Material = n.get_active_material(i)
			if src is BaseMaterial3D:
				var m: BaseMaterial3D = src.duplicate()
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.albedo_color.a = alpha
				m.roughness = minf(m.roughness, 0.25)
				m.rim_enabled = true
				m.rim = 0.4
				if glow != Color.BLACK:
					m.emission_enabled = true
					m.emission = glow
					m.emission_energy_multiplier = 0.35
				n.set_surface_override_material(i, m)
	for c in n.get_children():
		make_translucent(c, alpha, glow)


## Kopie des Meshes mit geglätteten Normalen: Ecken an derselben Position bekommen dieselbe
## (gemittelte) Normale. Für Konturen per aufgeblähter Hülle, die sonst an harten Kanten aufreißen.
static func smooth_normals(mesh: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var sums := {}
		for i in verts.size():
			var key := (verts[i] * 1000.0).round()
			sums[key] = sums.get(key, Vector3.ZERO) + (normals[i] if i < normals.size() else Vector3.UP)
		var smooth := PackedVector3Array()
		smooth.resize(verts.size())
		for i in verts.size():
			smooth[i] = (sums[(verts[i] * 1000.0).round()] as Vector3).normalized()
		var keep := []
		keep.resize(Mesh.ARRAY_MAX)
		keep[Mesh.ARRAY_VERTEX] = verts
		keep[Mesh.ARRAY_NORMAL] = smooth
		keep[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, keep)
	return out
