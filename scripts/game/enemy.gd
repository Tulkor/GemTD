class_name Enemy
extends Node3D
## Ein Gegner. Grundwerte aus data/enemies/<id>.json, eine Welle kann sie überschreiben
## (hp, speed, armor, bounty, damage, Massenwellen auch shape und size).
## Logische Position `pos` in Einheiten (1 = eine Towerbreite) als Vector2, die 3D-Position folgt daraus.

const FLY_HEIGHT := 1.4

var game  # game.gd
var enemy_id := ""
var max_hp := 10.0
var hp := 10.0
var speed := 2.0     ## Towerbreiten pro Sekunde
var armor := 0.0
var bounty := 1.0   ## Gold pro Kill, bei Massenwellen auch Bruchteile
var damage := 1      ## Leben, die der Spieler verliert, wenn der Gegner durchkommt
var score_value := 0.0  ## Punkte-Modus: Punkte für den Kill (game.gd → score_for)
var final_boss := false  ## Endboss der letzten Welle: nur Schadenscheck, kostet keine Leben
var flying := false
var armor_type := ""
var spell_factor := 1.0     ## Faktor auf Zauberschaden (eeveTD: Schwierigkeit, 0 = zauberimmun)
var hit_reduction := 0.0    ## weniger Schaden pro Treffer, nicht bei Zaubern (eeveTD: Eigenschaft „Zäh“)
var size := 1.0
var color := Color.GRAY

var pos := Vector2.ZERO
var path := PackedVector2Array()
var path_index := 1
var traveled := 0.0  ## zurückgelegte Strecke, Tower zielen auf den Vordersten
var dead := false

var slow_factor := 0.0
## Tempo-Faktor außerhalb jeder Tower-Reichweite (balance.json → idle_speed_factor), sonst 1
var boost := 1.0
## Wie lange der Gegner im letzten Bild schon in Reichweite war (Sekunden): ein Tower, der auf ihn gewartet
## hat, holt nur so viel Rückstand nach (tower.gd), sonst schösse er bei 4× im Mittel ein halbes Bild zu früh.
var covered_for := 0.0
var slow_time := 0.0
var poison_dps := 0.0
var poison_time := 0.0
var poison_source = null  ## Tower, dem der Giftschaden gutgeschrieben wird
var last_hit_by := -1     ## Spieler, dessen Tower zuletzt Schaden gemacht hat (bekommt das Kopfgeld)
var armor_reduction := 0.0
var armor_reduction_time := 0.0
var stun_time := 0.0
var stacks := 0.0
var stack_time := 0.0

## Mehrspieler: Nummer für den Abgleich, und ob dieser Gegner nur das Feld eines Mitspielers zeigt.
var net_id := 0
var lane := 0   ## Bahn auf Maul-Maps (map_data.gd → lanes)
var remote := false
var remote_field = null   ## remote_field.gd, liefert Punkt auf dem Weg zu einer Strecke
var net_traveled := 0.0   ## zuletzt gemeldete Strecke
var net_speed := 0.0      ## zuletzt gemeldetes Tempo (Towerbreiten pro Sekunde des Mitspielers)
var net_age := 0.0        ## Spielzeit des Mitspielers seit der letzten Meldung
var net_free_from := -1.0 ## Stück, auf dem der Gegner schnell läuft (game.free_stretch), in Strecke
var net_free_to := -1.0
var net_boost := 1.0      ## Schnelllauf-Faktor auf diesem Stück

var group: Dictionary = {}  ## Wellengruppe, aus der der Gegner stammt (für Spielstände)
var shape_name := ""
var boss := false
var def_model := ""
var def_model_scale := 1.0
var _body_mat: StandardMaterial3D
var _bar_fg: MeshInstance3D
var _body: MeshInstance3D


func setup(g, def: Dictionary, o: Dictionary, p: PackedVector2Array) -> void:
	game = g
	group = o
	enemy_id = str(def.get("id", ""))
	max_hp = float(o.get("hp", def.get("hp", 10)))
	hp = max_hp
	speed = float(o.get("speed", def.get("speed", 2.0)))
	armor = float(o.get("armor", def.get("armor", 0)))
	bounty = float(o.get("bounty", def.get("bounty", 1)))
	damage = int(o.get("damage", def.get("damage", 1)))
	flying = bool(def.get("flying", false))
	armor_type = str(o.get("armor_type", def.get("armor_type", "")))
	size = float(o.get("size", def.get("size", 1.0)))
	color = Color.from_string(str(def.get("color", "#cccccc")), Color.GRAY)
	def_model = str(def.get("model", ""))
	def_model_scale = float(def.get("model_scale", 1.0))
	shape_name = str(o.get("shape", def.get("shape", "")))
	boss = bool(def.get("boss", false))
	path = p
	if not path.is_empty():
		pos = path[0]
	_build_visual()
	_sync_position()


func _process(delta: float) -> void:
	if remote:
		_remote_step(delta)
		return
	if dead:
		return
	# Wirkungen laufen zeitgenau aus, auch wenn sie mitten im Bild enden: bei 2× und 4× sind die Bilder
	# länger, sonst würden Betäubung, Verlangsamung und Gift dort länger (oder kürzer) wirken als bei 1×.
	var stunned := clampf(stun_time, 0.0, delta)
	var slowed := clampf(slow_time - stunned, 0.0, delta - stunned)
	var move := slowed_speed() * slowed + speed * (delta - stunned - slowed)
	if stun_time > 0.0:
		stun_time -= delta
	if slow_time > 0.0:
		slow_time -= delta
		if slow_time <= 0.0:
			slow_factor = 0.0
	if armor_reduction_time > 0.0:
		armor_reduction_time -= delta
		if armor_reduction_time <= 0.0:
			armor_reduction = 0.0
	if poison_time > 0.0:
		if is_instance_valid(poison_source):
			last_hit_by = poison_source.owner_player
		var dealt := take_raw_damage(poison_dps * minf(poison_time, delta))
		poison_time -= delta
		if is_instance_valid(poison_source):
			poison_source.total_damage += dealt
			if dead:
				poison_source.kills += 1
		if dead:
			return
	if stack_time > 0.0:
		stack_time -= delta
		if stack_time <= 0.0:
			stacks = 0.0
	# Wo kein Tower hinreicht, gibt es nichts zu sehen: dort laufen Gegner schneller (weniger Wartezeit).
	# In kleinen Schritten, damit sie keine Reichweite (z. B. eine Falle) überspringen; wer hineinläuft,
	# hält genau am Rand an und geht den Rest des Bilds normal schnell. Ohne die genaue Stelle stünde er
	# bis zu einem Schritt tief in der Reichweite und wäre entsprechend kürzer darin.
	boost = 1.0 if game == null or game.is_covered(self) else game.idle_speed_factor()
	covered_for = delta if boost <= 1.0 else 0.0
	if boost > 1.0:
		var left := move * boost
		while left > 0.0 and path_index < path.size():
			var step := minf(left, BOOST_STEP)
			var before := [pos, path_index, traveled, rotation.y]
			_advance(step)
			if game.is_covered(self):
				var lo := 0.0
				var hi := step
				for i in 5:
					var mid := (lo + hi) / 2.0
					_restore(before)
					_advance(mid)
					if game.is_covered(self):
						hi = mid
					else:
						lo = mid
				_restore(before)
				_advance(hi)
				boost = 1.0
				var rest: float = (left - hi) / game.idle_speed_factor()
				covered_for = rest / move * delta
				_advance(rest)
				break
			left -= step
	else:
		_advance(move)
	_sync_position()
	_update_visual()
	if path_index >= path.size():
		dead = true
		game.on_enemy_leaked(self)


const BOOST_STEP := 0.5   ## kleiner als eine Falle breit ist (1,5)


func _restore(state: Array) -> void:
	pos = state[0]
	path_index = state[1]
	traveled = state[2]
	rotation.y = state[3]


func _advance(move: float) -> void:
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


## Tempo gerade jetzt: Verlangsamung drückt nicht unter die Mindestgeschwindigkeit (WC3: 220),
## betäubt steht der Gegner.
func current_speed() -> float:
	return base_speed() * boost


## Tempo ohne Schnelllauf.
func base_speed() -> float:
	if stun_time > 0.0:
		return 0.0
	return slowed_speed() if slow_time > 0.0 else speed


## Tempo unter der aktuellen Verlangsamung (nie unter min_slowed_speed).
func slowed_speed() -> float:
	var min_speed := minf(speed, float(Database.balance.get("min_slowed_speed", 0.0)))
	return maxf(speed * (1.0 - slow_factor), min_speed)


## Zustand für Zuschauer: [net_id, id, Strecke, Tempo ohne Schnelllauf, hp, max_hp, Flags (1 langsam, 2 Gift,
## 4 betäubt), Form, Größe, Bahn, schnelles Stück von, bis, Schnelllauf-Faktor]
func net_state() -> Array:
	var flags := (1 if slow_time > 0.0 else 0) | (2 if poison_time > 0.0 else 0) | (4 if stun_time > 0.0 else 0)
	var free: Array = game.free_stretch(self) if game != null else [-1.0, -1.0]
	var factor: float = game.idle_speed_factor() if game != null else 1.0
	return [net_id, enemy_id, traveled, base_speed(), hp, max_hp, flags, shape_name, size, lane, free[0], free[1], factor]


## Neue Meldung vom Mitspieler übernehmen; die Position läuft in _remote_step weiter.
## age: wie alt die Meldung schon ist (Spielzeit, remote_field.gd → packet_age).
func apply_net_state(s: Array, age := 0.0) -> void:
	net_traveled = float(s[2])
	net_speed = float(s[3])
	net_age = age
	net_free_from = float(s[10]) if s.size() > 12 else -1.0
	net_free_to = float(s[11]) if s.size() > 12 else -1.0
	net_boost = float(s[12]) if s.size() > 12 else 1.0
	hp = float(s[4])
	max_hp = float(s[5])
	var flags := int(s[6])
	slow_time = 1.0 if flags & 1 else 0.0
	poison_time = 1.0 if flags & 2 else 0.0
	stun_time = 1.0 if flags & 4 else 0.0


## Zuschauer: Gegner läuft mit dem gemeldeten Tempo selbst weiter und wird sanft
## auf die vorausberechnete Strecke des Mitspielers gezogen, damit es flüssig aussieht.
func _remote_step(delta: float) -> void:
	var real_dt := delta / maxf(Engine.time_scale, 0.01)
	var dt: float = real_dt * remote_field.time_scale
	net_age += dt
	var predicted := remote_advance(net_traveled, net_age)
	traveled = remote_advance(traveled, dt)
	if absf(predicted - traveled) > 1.5:
		traveled = predicted
	else:
		traveled = lerpf(traveled, predicted, 1.0 - exp(-6.0 * real_dt))
	traveled = clampf(traveled, 0.0, remote_field.path_length(flying, lane))
	var p: Vector2 = remote_field.point_at(flying, traveled, lane)
	var step := p - pos
	if step.length_squared() > 0.000001:
		rotation.y = atan2(-step.x, -step.y)
	pos = p
	_sync_position()
	_update_visual()


## Zuschauer: Strecke nach dt Sekunden ab from, mit Schnelllauf auf dem gemeldeten Stück.
func remote_advance(from: float, dt: float) -> float:
	if net_speed <= 0.0:
		return from
	var left := dt
	if from < net_free_from:
		var reach := from + net_speed * left
		if reach <= net_free_from:
			return reach
		left -= (net_free_from - from) / net_speed
		from = net_free_from
	if from < net_free_to:
		var fast := net_speed * net_boost
		var reach := from + fast * left
		if reach <= net_free_to:
			return reach
		left -= (net_free_to - from) / fast
		from = net_free_to
	return from + net_speed * left


## Spielstand: Gegner an die Stelle setzen, die dist Towerbreiten nach dem Start liegt.
func place_on_path(dist: float) -> void:
	traveled = 0.0
	path_index = 1
	if path.is_empty():
		return
	pos = path[0]
	var left := dist
	while path_index < path.size():
		var seg := pos.distance_to(path[path_index])
		if seg > left:
			var dir := (path[path_index] - pos).normalized()
			pos += dir * left
			traveled += left
			rotation.y = atan2(-dir.x, -dir.y)
			break
		pos = path[path_index]
		left -= seg
		traveled += seg
		path_index += 1
	_sync_position()
	_update_visual()


func _sync_position() -> void:
	position = Board3D.to_3d(pos, FLY_HEIGHT if flying else 0.0)


## Schwierigkeitsstufe: Leben und (positive) Rüstung skalieren.
func apply_difficulty(f: float) -> void:
	max_hp *= f
	hp = max_hp
	if armor > 0.0:
		armor *= f


func effective_armor() -> float:
	return armor - armor_reduction


## Rüstung wie in Warcraft 3: 6 % weniger Schaden pro Punkt, abnehmend; negative Rüstung erhöht Schaden.
## Dazu der Faktor aus Schadensart gegen Rüstungsart (balance.json → damage_table).
func take_damage(amount: float, damage_type := "") -> float:
	if damage_type == "spells":
		amount *= spell_factor
	elif hit_reduction > 0.0:
		amount = maxf(amount - hit_reduction, 0.0)
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


func apply_poison(dps: float, duration: float, source = null) -> void:
	if poison_time <= 0.0 or dps >= poison_dps:
		poison_source = source
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
