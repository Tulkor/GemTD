class_name YtProjectileView
extends MultiMeshInstance3D
## Zeichnet alle Geschosse der Fähigkeiten und Angriffe (YtProjectile) als leuchtende Kugeln in einem MultiMesh,
## Farbe nach Element des Towers oder der Farbe, die ein Skript setzt. Ohne Bildschirm (Tests) nichts.

const MAX := 512
const RADIUS := 0.09

var _headless := false


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
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


func refresh() -> void:
	if _headless or multimesh == null:
		return
	var n := 0
	for p in get_tree().get_nodes_in_group("yt_projectiles"):
		if n >= MAX:
			break
		if not is_instance_valid(p) or p.is_queued_for_deletion() or not p.visible:
			continue
		var col: Color = p.modulate
		if col == Color.WHITE and p.get_caster() is YtTower:
			col = YtElement.get_color(p.get_caster().get_element())
		var s: float = clampf(p._scale, 0.3, 3.0)
		multimesh.set_instance_transform(n, Transform3D(Basis().scaled(Vector3.ONE * s), YtWorld.to_3d(p.get_position_wc3())))
		multimesh.set_instance_color(n, col)
		n += 1
	multimesh.visible_instance_count = n
