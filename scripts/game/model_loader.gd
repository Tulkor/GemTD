class_name ModelLoader
extends RefCounted
## Lädt optionale 3D-Modelle für Tower und Gegner.
## In den JSON-Daten: "model": "res://assets/models/rubin.glb" und optional "model_scale": 1.0
## (bei Towern auch pro Stufe). Fehlt das Modell, wird die eingebaute einfache Form gezeichnet.
## Modelle sollten mit dem Fußpunkt auf Y = 0 liegen; 1 Einheit = 1 Feld.

static var _cache := {}


static func instantiate(path: String, scale := 1.0) -> Node3D:
	if path == "":
		return null
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
		if _cache[path] == null:
			push_warning("Modell nicht gefunden: " + path)
	var res = _cache[path]
	if not res is PackedScene:
		return null
	var node = res.instantiate()
	if not node is Node3D:
		node.free()
		return null
	node.scale = Vector3.ONE * scale
	return node
