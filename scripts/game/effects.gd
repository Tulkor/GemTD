class_name Effects
extends MeshInstance3D
## Kurze Schusslinien von Tower zu Gegner.

const BEAM_TIME := 0.12

var beams: Array = []
var _mesh := ImmediateMesh.new()


func _ready() -> void:
	mesh = _mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func add_beam(from: Vector3, to: Vector3, col: Color) -> void:
	beams.append({"from": from, "to": to, "color": col, "t": BEAM_TIME})


func clear() -> void:
	beams.clear()
	_mesh.clear_surfaces()


func _process(delta: float) -> void:
	if beams.is_empty():
		return
	for b in beams:
		b.t -= delta
	beams = beams.filter(func(b): return b.t > 0.0)
	_mesh.clear_surfaces()
	if beams.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for b in beams:
		var c: Color = b.color
		c.a = b.t / BEAM_TIME
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(b.from)
		_mesh.surface_add_vertex(b.to)
	_mesh.surface_end()
