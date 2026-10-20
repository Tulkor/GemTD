class_name ContactShadow
extends RefCounted
## Weicher Kontaktschatten unter Towern und Steinen (contact_shadow.gdshader). Stärke aus
## FieldStyle "contact_shadow" (0 = aus, z. B. im Neon-Stil über dem durchsichtigen Gitter).

const SHADER := preload("res://assets/shaders/contact_shadow.gdshader")
## Fläche im Verhältnis zur Grundfläche: der Schatten läuft etwas über den Rand hinaus.
const SPREAD := 1.7
const LIFT := 0.02

static var _mat: ShaderMaterial
static var _mat_strength := -1.0


static func strength() -> float:
	return float(FieldStyle.current().get("contact_shadow", 0.0))


static func material() -> ShaderMaterial:
	var s := strength()
	if _mat == null or _mat_strength != s:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
		_mat.set_shader_parameter("strength", s)
		# nach dem (durchsichtigen) Boden und seinem Raster zeichnen
		_mat.render_priority = 1
		_mat_strength = s
	return _mat


static func mesh(foot: float) -> PlaneMesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * foot * SPREAD
	return plane


## Schatten unter parent für eine quadratische Grundfläche (Kantenlänge foot), oder null wenn aus.
static func add(parent: Node3D, foot: float) -> MeshInstance3D:
	if strength() <= 0.0:
		return null
	var m := MeshInstance3D.new()
	m.mesh = mesh(foot)
	m.material_override = material()
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position.y = LIFT
	parent.add_child(m)
	return m
