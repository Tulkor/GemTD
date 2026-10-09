class_name Enemy
extends Node3D
## Ein Gegner. Grundwerte aus data/enemies/<id>.json, eine Welle kann sie überschreiben
## (hp, speed, armor, bounty, damage).
## Logische Position `pos` in Einheiten (1 = eine Towerbreite) als Vector2, die 3D-Position folgt daraus.

const FLY_HEIGHT := 1.4

var game  # game.gd
var enemy_id := ""
var max_hp := 10.0
var hp := 10.0
var speed := 2.0     ## Towerbreiten pro Sekunde
var armor := 0.0
var bounty := 1
var damage := 1      ## Leben, die der Spieler verliert, wenn der Gegner durchkommt
var flying := false
var armor_type := ""
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
var stacks := 0.0
var stack_time := 0.0

var shape_name := ""
var boss := false
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
	armor_type = str(o.get("armor_type", def.get("armor_type", "")))
	size = float(def.get("size", 1.0))
	color = Color.from_string(str(def.get("color", "#cccccc")), Color.GRAY)
	def_model = str(def.get("model", ""))
	def_model_scale = float(def.get("model_scale", 1.0))
	shape_name = str(def.get("shape", ""))
	boss = bool(def.get("boss", false))
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
	if stack_time > 0.0:
		stack_time -= delta
		if stack_time <= 0.0:
			stacks = 0.0
	# Verlangsamung drückt nicht unter die Mindestgeschwindigkeit (WC3: 220)
	var min_speed := minf(speed, float(Database.balance.get("min_slowed_speed", 0.0)))
	var move := maxf(speed * (1.0 - slow_factor), min_speed) * delta
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
## Dazu der Faktor aus Schadensart gegen Rüstungsart (balance.json → damage_table).
func take_damage(amount: float, damage_type := "") -> float:
	var a := effective_armor()
	var factor := Database.damage_factor(damage_type, armor_type)
	if a > 0.0:
		factor *= 1.0 - 0.06 * a / (1.0 + 0.06 * a)
	elif a < 0.0:
		factor *= 2.0 - pow(0.94, -a)
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


## Steigender Zusatzschaden pro Treffer (Geisterplatte). Gibt den Bonus dieses Treffers zurück.
func add_stack(per_hit: float, duration: float) -> float:
	stacks += per_hit
	stack_time = duration
	return stacks


# --- Darstellung -------------------------------------------------------------

func shape() -> String:
	if shape_name != "":
		return shape_name
	if flying:
		return "sphere"
	if boss:
		return "boss"
	return "cube"


func _build_visual() -> void:
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = color
	_body_mat.roughness = 0.6
	_body = MeshInstance3D.new()
	# schmal genug für Lücken von einer halben Towerbreite
	var r := 0.2 * size
	var model := ModelLoader.instantiate(str(def_model), def_model_scale * size)
	if model != null:
		add_child(model)
		_body.visible = false
	# Platzhalterformen: Würfel = Boden, Pyramide = Massenwelle, großer Quader = Boss, Kugel = Flieger.
	# In der Gegner-Datei mit "shape" wählbar, sonst aus flying/boss abgeleitet.
	var height := 0.0
	match shape():
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = r
			sphere.height = r * 2.0
			_body.mesh = sphere
			height = r * 2.0
		"pyramid":
			var prism := PrismMesh.new()
			prism.size = Vector3(r * 2.0, r * 2.2, r * 2.0)
			_body.mesh = prism
			height = r * 2.2
		"boss":
			var big := BoxMesh.new()
			big.size = Vector3(r * 2.2, r * 3.2, r * 2.2)
			_body.mesh = big
			height = r * 3.2
		_:
			var cube := BoxMesh.new()
			cube.size = Vector3.ONE * r * 2.0
			_body.mesh = cube
			height = r * 2.0
	_body.position.y = height / 2.0 - (r if flying else 0.0)
	if flying:
		var shadow := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = r
		disc.bottom_radius = r
		disc.height = 0.01
		shadow.mesh = disc
		shadow.material_override = Board3D.make_material(Color(0, 0, 0, 0.35), true)
		shadow.position.y = -FLY_HEIGHT + 0.03
		add_child(shadow)
	_body.material_override = _body_mat
	add_child(_body)

	var bar_y := _body.position.y + height / 2.0 + 0.25
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
