class_name FogFx
extends GPUParticles3D
## Bodennebel aus der Nebelmaschine: weiche Rauchwolken (Kenney Particle Pack, CC0), die flach über den Sockel
## quellen, langsam steigen und verblassen. In den Tower-Daten: "fog": Größe in Towerbreiten (z. B. 1.0);
## ohne Modell zeigt der Tower nur Sockel und Nebel.
## GPU-Partikel: CPU-Partikel würfeln mit dem globalen Zufall und verschöben die Würfe der Tower.

const SHEET := "res://assets/fx/kenney/smoke_02.png"


static func make(size: float, col := Color(0.92, 0.88, 1.0)) -> FogFx:
	var p := FogFx.new()
	p.amount = 28
	p.lifetime = 3.6
	p.preprocess = 3.6
	p.randomness = 0.5
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = size * 0.32
	pm.emission_ring_inner_radius = 0.0
	pm.emission_ring_height = 0.02
	pm.direction = Vector3.UP
	pm.spread = 75.0
	pm.gravity = Vector3(0, size * 0.04, 0)
	pm.initial_velocity_min = size * 0.06
	pm.initial_velocity_max = size * 0.16
	pm.damping_min = size * 0.02
	pm.damping_max = size * 0.04
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -12.0
	pm.angular_velocity_max = 12.0
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.45))
	grow.add_point(Vector2(1.0, 1.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	pm.scale_curve = grow_tex
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(col, 0.0), Color(col, 0.9), Color(col, 0.6), Color(col, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size * 0.8
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = load(SHEET)
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = m
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-1.5, -0.2, -1.5) * size, Vector3(3, 2, 3) * size)
	return p
