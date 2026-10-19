class_name FlameFx
extends MeshInstance3D
## Endlos flackernde Flamme (Sprite-Sheet aus dem Brackeys VFX Bundle, CC0) als Billboard.
## In den Tower-Daten: "flame": Größe in Towerbreiten (z. B. 0.5); sitzt oben auf dem Modell.

const SHEET := "res://assets/fx/brackeys/flame_01.png"
const SHADER := preload("res://assets/shaders/flipbook.gdshader")


static func make(size: float, col := Color.WHITE) -> FlameFx:
	var f := FlameFx.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.center_offset = Vector3(0, 0.5, 0)
	f.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("sheet", load(SHEET))
	mat.set_shader_parameter("offset", randf() * 64.0)
	mat.set_shader_parameter("tint", col)
	f.material_override = mat
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Ein Bild der Flamme ist doppelt so hoch wie breit
	f.scale = Vector3(size * 0.6, size * 1.2, 1.0)
	return f
