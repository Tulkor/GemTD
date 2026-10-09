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


## Erstes Mesh eines Modells, normalisiert (für MultiMesh, z. B. Steine).
## Rückgabe: [Mesh, Transform3D] oder [] wenn nicht vorhanden.
static func mesh_with_transform(path: String, size := 1.0) -> Array:
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
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var s := size / longest if longest > 0.0 else 1.0
	var fit := Transform3D(Basis().scaled(Vector3.ONE * s), -Vector3(box.get_center().x, box.position.y, box.get_center().z) * s)
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
