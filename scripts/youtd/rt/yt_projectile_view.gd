class_name YtProjectileView
extends MultiMeshInstance3D
## Zeichnet alle Geschosse der Fähigkeiten und Angriffe (YtProjectile) als leuchtende Kugeln in einem MultiMesh,
## Farbe nach Element des Towers oder der Farbe, die ein Skript setzt. Ohne Bildschirm (Tests) nichts.
## Koop: der Host meldet die Geschosse 15 Mal pro Sekunde (packet), Mitspieler zeichnen sie mit remote_step und
## lassen sie dazwischen mit dem gemessenen Tempo weiterfliegen.

const MAX := 512
const RADIUS := 0.09

var _headless := false
var remote := {}   ## Mitspieler: uid -> {p: Punkt, v: Tempo je Sekunde, c: Farbe, s: Größe}


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		return
	var mesh := SphereMesh.new()
	mesh.radius = RADIUS
	mesh.height = RADIUS * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mesh.material = mat
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = MAX
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Host: alle Geschosse auf diesem Feld als [uid, Punkt, Farbe, Größe].
func packet() -> Array:
	var out := []
	var field := get_parent().get_parent()
	for p in get_tree().get_nodes_in_group("yt_projectiles"):
		if out.size() >= MAX:
			break
		if not is_instance_valid(p) or p.is_queued_for_deletion() or not p.visible or not field.is_ancestor_of(p):
			continue
		out.append([p._uid, YtWorld.to_3d(p.get_position_wc3()), _color(p), snappedf(clampf(p._scale, 0.3, 3.0), 0.1)])
	return out


## Mitspieler: neue Meldung vom Host (age: wie alt sie ist, in Sekunden Spielzeit).
func set_remote(list: Array, age := 0.0) -> void:
	var seen := {}
	for e in list:
		var uid := int(e[0])
		seen[uid] = true
		var pos: Vector3 = e[1]
		var old: Dictionary = remote.get(uid, {})
		var v := Vector3.ZERO
		if not old.is_empty():
			var dt := maxf(Time.get_ticks_msec() / 1000.0 - float(old.t), 0.02)
			v = (pos - Vector3(old.at)) / dt
		remote[uid] = {"p": pos + v * age, "at": pos, "t": Time.get_ticks_msec() / 1000.0, "v": v, "c": e[2], "s": float(e[3])}
	for uid in remote.keys():
		if not seen.has(uid):
			remote.erase(uid)


## Mitspieler: Geschosse weiterfliegen lassen und zeichnen (jedes Bild, YtWorld steht bei ihm still).
func remote_step(delta: float) -> void:
	if _headless or multimesh == null:
		return
	var n := 0
	for uid in remote:
		if n >= MAX:
			break
		var r: Dictionary = remote[uid]
		r.p += r.v * delta
		multimesh.set_instance_transform(n, Transform3D(Basis().scaled(Vector3.ONE * float(r.s)), r.p))
		multimesh.set_instance_color(n, r.c)
		n += 1
	multimesh.visible_instance_count = n


func _color(p) -> Color:
	var col: Color = p.modulate
	if col == Color.WHITE and p.get_caster() is YtTower:
		col = YtElement.get_color(p.get_caster().get_element())
	return col


func refresh() -> void:
	if _headless or multimesh == null:
		return
	var n := 0
	for p in get_tree().get_nodes_in_group("yt_projectiles"):
		if n >= MAX:
			break
		if not is_instance_valid(p) or p.is_queued_for_deletion() or not p.visible:
			continue
		var col := _color(p)
		var s: float = clampf(p._scale, 0.3, 3.0)
		multimesh.set_instance_transform(n, Transform3D(Basis().scaled(Vector3.ONE * s), YtWorld.to_3d(p.get_position_wc3())))
		multimesh.set_instance_color(n, col)
		n += 1
	multimesh.visible_instance_count = n
