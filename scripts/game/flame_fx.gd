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
	f.add_child(_embers(size, f.scale))
	return f


## Funken, die aus der Flamme aufsteigen und verglühen (wenige, additiv, ohne Licht).
## GPU-Partikel: CPU-Partikel würfeln mit dem globalen Zufall und verschöben die Würfe der Tower.
static func _embers(size: float, parent_scale: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	# Maßstab der Flamme ausgleichen, die Funken rechnen in Welt-Einheiten
	p.scale = Vector3(1.0 / parent_scale.x, 1.0 / parent_scale.y, 1.0)
	p.position = Vector3(0, 0.25, 0)
	p.amount = 7
	p.lifetime = 1.1
	p.randomness = 0.6
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = size * 0.18
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.gravity = Vector3(0, size * 0.6, 0)
	pm.initial_velocity_min = size * 0.4
	pm.initial_velocity_max = size * 1.1
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	fade.colors = PackedColorArray([Color(1.0, 0.9, 0.5, 1.0), Color(1.0, 0.45, 0.1, 0.8), Color(0.8, 0.15, 0.02, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size * 0.045
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	# über 1, damit das Glow die Funken aufgreift
	m.albedo_color = Color(2.2, 1.8, 1.4)
	quad.material = m
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-2, -1, -2) * size, Vector3(4, 4, 4) * size)
	return p
