class_name Enemy
extends Node3D
## Ein Gegner. Grundwerte aus data/enemies/<id>.json, eine Welle kann sie überschreiben
## (hp, speed, armor, bounty, damage).
## Logische Position `pos` in Feldern (Vector2), die 3D-Position folgt daraus.

const FLY_HEIGHT := 1.4

var game  # game.gd
var enemy_id := ""
var max_hp := 10.0
var hp := 10.0
var speed := 2.0     ## Felder pro Sekunde
var armor := 0.0
var bounty := 1
var damage := 1      ## Leben, die der Spieler verliert, wenn der Gegner durchkommt
var flying := false
var size := 1.0
var color := Color.GRAY

var pos := Vector2.ZERO
var path := PackedVector2Array()
var path_index := 1
var traveled := 0.0  ## zurückgelegte Strecke, Tower zielen auf den Vordersten
var dead := false

var slow_factor := 0.0
var slow_time := 0.0
var poison_dps := 0.0
var poison_time := 0.0
var armor_reduction := 0.0
var armor_reduction_time := 0.0
var stun_time := 0.0

var def_model := ""
var def_model_scale := 1.0
var _body_mat: StandardMaterial3D
var _bar_fg: MeshInstance3D
var _body: MeshInstance3D


func setup(g, def: Dictionary, o: Dictionary, p: PackedVector2Array) -> void:
	game = g
	enemy_id = str(def.get("id", ""))
	max_hp = float(o.get("hp", def.get("hp", 10)))
	hp = max_hp
	speed = float(o.get("speed", def.get("speed", 2.0)))
	armor = float(o.get("armor", def.get("armor", 0)))
	bounty = int(o.get("bounty", def.get("bounty", 1)))
	damage = int(o.get("damage", def.get("damage", 1)))
	flying = bool(def.get("flying", false))
	size = float(def.get("size", 1.0))
	color = Color.from_string(str(def.get("color", "#cccccc")), Color.GRAY)
	def_model = str(def.get("model", ""))
	def_model_scale = float(def.get("model_scale", 1.0))
	path = p
	if not path.is_empty():
		pos = path[0]
	_build_visual()
	_sync_position()


func _process(delta: float) -> void:
	if dead:
		return
	if slow_time > 0.0:
		slow_time -= delta
		if slow_time <= 0.0:
			slow_factor = 0.0
	if armor_reduction_time > 0.0:
		armor_reduction_time -= delta
		if armor_reduction_time <= 0.0:
			armor_reduction = 0.0
	if poison_time > 0.0:
		poison_time -= delta
		take_raw_damage(poison_dps * delta)
		if dead:
			return
	var move := speed * (1.0 - slow_factor) * delta
	if stun_time > 0.0:
		stun_time -= delta
		move = 0.0
	while move > 0.0 and path_index < path.size():
		var target := path[path_index]
		var dist := pos.distance_to(target)
		if dist <= move:
			pos = target
			move -= dist
			traveled += dist
			path_index += 1
		else:
			var dir := (target - pos).normalized()
			pos += dir * move
			traveled += move
			move = 0.0
			rotation.y = atan2(-dir.x, -dir.y)
	_sync_position()
	_update_visual()
	if path_index >= path.size():
		dead = true
		game.on_enemy_leaked(self)


func _sync_position() -> void:
	position = Board3D.to_3d(pos, FLY_HEIGHT if flying else 0.0)


func effective_armor() -> float:
	return armor - armor_reduction


## Rüstung wie in Warcraft 3: 6 % weniger Schaden pro Punkt, abnehmend; negative Rüstung erhöht Schaden.
func take_damage(amount: float) -> float:
	var a := effective_armor()
	var factor := 1.0
	if a > 0.0:
		factor = 1.0 - 0.06 * a / (1.0 + 0.06 * a)
	elif a < 0.0:
		factor = 2.0 - pow(0.94, -a)
	return take_raw_damage(amount * factor)


## Schaden ohne Rüstung (Gift, Brand-Auren).
func take_raw_damage(amount: float) -> float:
	if dead:
		return 0.0
	var dealt := minf(amount, hp)
	hp -= amount
	if hp <= 0.0:
		dead = true
		game.on_enemy_killed(self)
	return dealt


func apply_slow(factor: float, duration: float) -> void:
	slow_factor = maxf(slow_factor, clampf(factor, 0.0, 0.9))
	slow_time = maxf(slow_time, duration)


func apply_poison(dps: float, duration: float) -> void:
	poison_dps = maxf(poison_dps, dps) if poison_time > 0.0 else dps
	poison_time = maxf(poison_time, duration)


func apply_armor_reduction(amount: float, duration: float) -> void:
	armor_reduction = maxf(armor_reduction, amount)
	armor_reduction_time = maxf(armor_reduction_time, duration)


func apply_stun(duration: float) -> void:
	stun_time = maxf(stun_time, duration)


# --- Darstellung -------------------------------------------------------------

func _build_visual() -> void:
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = color
	_body_mat.roughness = 0.6
	_body = MeshInstance3D.new()
	var r := 0.26 * size
	var model := ModelLoader.instantiate(str(def_model), def_model_scale * size)
	if model != null:
		add_child(model)
		_body.visible = false
	if flying:
		var prism := PrismMesh.new()
		prism.size = Vector3(r * 2.4, r * 0.5, r * 2.2)
		_body.mesh = prism
		_body.rotation.x = deg_to_rad(-90)
		var shadow := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = r
		disc.bottom_radius = r
		disc.height = 0.01
		shadow.mesh = disc
		shadow.material_override = Board3D.make_material(Color(0, 0, 0, 0.35), true)
		shadow.position.y = -FLY_HEIGHT + 0.03
		add_child(shadow)
	else:
		var capsule := CapsuleMesh.new()
		capsule.radius = r
		capsule.height = r * 3.0
		_body.mesh = capsule
		_body.position.y = r * 1.5
	_body.material_override = _body_mat
	add_child(_body)

	var bar_y := (r * 3.0 if not flying else r) + 0.35
	var bg := _bar(Color(0, 0, 0, 0.8), 0)
	bg.position.y = bar_y
	_bar_fg = _bar(Color("e74c3c"), 1)
	_bar_fg.position.y = bar_y


func _bar(col: Color, priority: int) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.09)
	m.mesh = quad
	var mat := Board3D.make_material(col, true)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.no_depth_test = true
	mat.render_priority = priority
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


func _update_visual() -> void:
	_bar_fg.scale.x = maxf(clampf(hp / max_hp, 0.0, 1.0), 0.001)
	var tint := color
	if poison_time > 0.0:
		tint = tint.lerp(Color("2ecc71"), 0.45)
	if slow_time > 0.0:
		tint = tint.lerp(Color("5dade2"), 0.5)
	if stun_time > 0.0:
		tint = tint.lerp(Color.WHITE, 0.5)
	_body_mat.albedo_color = tint
