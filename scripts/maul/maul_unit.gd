class_name MaulUnit
extends Node3D
## Bewegliche Einheit in Shopping Maul: Zombies des Bestattungsinstituts und Drohnen des Waffenladens.
## Beide fliegen über das Gelände (kein Maze) und greifen den nächsten Gegner im Umkreis ihres
## Postens an; ohne Ziel kehren sie zum Posten zurück. Den Posten setzt der Besitzer (Klick ins
## eigene Gebiet, solange die Einheit gewählt ist).
##   Zombie: verliert jede Sekunde Leben (decay), Kultstätten in der Nähe heilen ihn. Bei 0 zerfällt er.
##   Drohne: verbraucht im Level Energie, lädt am Drone Charger auf; leer springt sie zum Charger.
##           Module (pro.json → items, kind "module") geben Schaden, Tempo, Energie, Scanner, Kanonen.
## Gerechnet wird nur beim Host (game.mirror = false), Mitspieler bekommen Position und Werte gemeldet.

var game: MaulGame
var net_id := 0
var unit_id := ""          ## u000 … u007, battle, support
var owner_player := 0
var drone := false
var def: Dictionary = {}
var pos := Vector2.ZERO
var post := Vector2.ZERO
var home := Vector2i(-1, -1)  ## Anker des Turms, der ihn erzeugt hat (Charger, Friedhof)
var hp := 1.0
var max_hp := 1.0
var energy := 0.0
var modules := {}          ## Modulart → Item-ID (Drohnen)
var kills := 0
var total_damage := 0.0
var color := Color.WHITE
var selected := false

var _cd := 0.0
var _weapon_cd := {}
var _target = null
var _body: MeshInstance3D
var _bar: MeshInstance3D
var _ring: MeshInstance3D
var _net_pos := Vector2.ZERO


func setup(g: MaulGame, id: String, p: int, at: Vector2) -> void:
	game = g
	unit_id = id
	owner_player = p
	drone = id == "battle" or id == "support"
	def = MaulData.unit(id)
	pos = at
	post = at
	_net_pos = at
	max_hp = float(def.get("hp", 100))
	hp = max_hp * (1.0 if drone else 0.5)
	energy = max_energy()
	color = Color("#d05a5a") if drone else Color("#8a8aa0")
	if id == "support":
		color = Color("#5fe08a")
	_build_visual()
	_sync()


func label() -> String:
	return MaulData.name_of(def, unit_id)


func max_energy() -> float:
	var e := float(MaulData.pro().get("drones", {}).get("energy", 15))
	for id in modules.values():
		e += float(MaulData.item(id).get("energy", 0))
	return e


func _mod(key: String) -> float:
	var v := 0.0
	for id in modules.values():
		v += float(MaulData.item(id).get(key, 0))
	return v


func speed() -> float:
	return (float(def.get("speed", 200)) + _mod("speed")) / 128.0


func damage() -> float:
	return (float(def.get("damage", 10)) + _mod("bonus_damage")) * game.damage_factor_for(owner_player)


func cooldown() -> float:
	return float(def.get("cooldown", 1.0)) / (1.0 + _mod("attack_speed"))


func range_cells() -> float:
	return float(def.get("range", 3.0))


func detect_radius() -> float:
	return _mod("detect")


func can_target(e) -> bool:
	match str(def.get("targets", "both")):
		"air":
			if not e.flying:
				return false
		"ground":
			if e.flying:
				return false
	return game.is_detected(e)


func _process(delta: float) -> void:
	if game == null:
		return
	if game.mirror:
		# Mitspieler: zur gemeldeten Stelle gleiten
		pos = pos.lerp(_net_pos, clampf(delta * 10.0, 0.0, 1.0))
		_sync()
		return
	if game.phase == MaulGame.Phase.SETUP or game.phase >= MaulGame.Phase.GAME_OVER:
		return
	if drone:
		_step_energy(delta)
	else:
		hp -= float(def.get("decay", 0)) * delta
		hp = minf(hp + game.cult_heal_at(pos, owner_player) * delta, max_hp)
		if hp <= 0.0:
			game.remove_unit(self)
			return
	_step_fight(delta)
	_sync()


func _step_energy(delta: float) -> void:
	var dr: Dictionary = MaulData.pro().get("drones", {})
	var charger = game.charger_of(owner_player)
	if charger != null and pos.distance_to(charger.pos) <= float(dr.get("recharge_radius", 5.47)):
		energy = minf(energy + float(dr.get("recharge", 15)) * delta, max_energy())
	if game.is_wave_running():
		energy -= float(def.get("drain", 10)) * delta
	if energy <= 0.0:
		energy = 0.0
		if charger != null:
			game.add_beam(Board3D.to_3d(pos, 0.6), charger.position + Vector3(0, 0.6, 0), Color("b38cff"))
			pos = charger.pos + Vector2(0.6, 0.6)


func _step_fight(delta: float) -> void:
	var leash := float(MaulData.pro().get("drones" if drone else "undertaker", {}).get("leash", 7.0))
	if _target != null and (not is_instance_valid(_target) or _target.dead or _target.pos.distance_to(post) > leash + range_cells() or not can_target(_target)):
		_target = null
	if _target == null and game.is_wave_running():
		var best := INF
		for e in game.enemies_in_radius(post, leash + range_cells()):
			if not can_target(e):
				continue
			var d: float = e.pos.distance_to(pos)
			if d < best:
				best = d
				_target = e
	var goal := post
	if _target != null:
		var d: float = _target.pos.distance_to(pos)
		goal = pos if d <= range_cells() * 0.9 else _target.pos
	var off := goal - pos
	var step := speed() * delta
	if drone and energy <= 0.0:
		step = 0.0
	if off.length() > 0.05:
		pos += off.normalized() * minf(step, off.length())
	_cd = maxf(_cd - delta, -delta)
	if _target != null and _cd <= 0.0 and _target.pos.distance_to(pos) <= range_cells():
		_attack(_target)
		_cd += cooldown()
	# Kanonen der Drohne (AG/AA) feuern selbst auf Ziele in ihrer Reichweite
	for slot in modules:
		var it := MaulData.item(str(modules[slot]))
		if not it.has("cooldown"):
			continue
		var left: float = _weapon_cd.get(slot, 0.0) - delta
		if left <= 0.0 and game.is_wave_running():
			var t = _nearest(float(it.range), str(it.get("targets", "both")))
			if t != null:
				_hit(t, float(it.damage) * game.damage_factor_for(owner_player))
				game.add_beam(Board3D.to_3d(pos, 0.8), t.position, color.lerp(Color.WHITE, 0.5))
				left += float(it.cooldown)
		_weapon_cd[slot] = maxf(left, -delta)
	# Statik: Flächenschaden pro Sekunde um die Drohne (nur Boden)
	var st := _mod("static")
	if st > 0.0 and game.is_wave_running():
		for e in game.enemies_in_radius(pos, _mod("radius")):
			if not e.flying:
				_hit(e, st * delta, true)


func _nearest(r: float, targets: String):
	var best := INF
	var out = null
	for e in game.enemies_in_radius(pos, r):
		if (targets == "air" and not e.flying) or (targets == "ground" and e.flying) or not game.is_detected(e):
			continue
		var d: float = e.pos.distance_to(pos)
		if d < best:
			best = d
			out = e
	return out


func _attack(e) -> void:
	var dmg := damage()
	game.add_beam(Board3D.to_3d(pos, 0.7), e.position, color)
	var center: Vector2 = e.pos
	_hit(e, dmg)
	if def.has("splash"):
		for o in game.enemies_in_radius(center, float(def.splash)):
			if o != e and can_target(o):
				_hit(o, dmg * 0.5)
	if def.has("nova"):
		for o in game.enemies_in_radius(center, float(def.nova)):
			if o != e and can_target(o):
				_hit(o, dmg * 0.5)
		game.add_ring(center, float(def.nova), color)
	if def.has("chain"):
		var hit := [e]
		var cur = e
		var cdmg := dmg
		for i in int(def.chain) - 1:
			cdmg *= 0.85
			var next = null
			var best := INF
			for o in game.enemies_in_radius(cur.pos, 4.0):
				var d: float = o.pos.distance_to(cur.pos)
				if not o in hit and can_target(o) and d < best:
					best = d
					next = o
			if next == null:
				break
			game.add_beam(cur.position, next.position, Color.WHITE)
			hit.append(next)
			_hit(next, cdmg)
			cur = next
	var frost := float(def.get("frost", 0.0)) + _mod("frost")
	if frost > 0.0 and not e.dead:
		e.apply_slow(frost, 1.0)


func _hit(e, dmg: float, raw := false) -> void:
	if e.dead:
		return
	e.last_hit_by = owner_player
	total_damage += e.take_raw_damage(dmg) if raw else e.take_damage(dmg, "normal" if drone else "chaos")
	if e.dead:
		kills += 1
		if def.has("life_chance") and randf() < float(def.life_chance):
			game.gain_lives(1)


## Mitspieler: Stand vom Host übernehmen.
func apply_net(d: Array) -> void:
	_net_pos = Vector2(float(d[2]), float(d[3]))
	post = Vector2(float(d[4]), float(d[5]))
	hp = float(d[6])
	energy = float(d[7])
	modules = d[8] if d.size() > 8 else {}
	kills = int(d[9]) if d.size() > 9 else kills


func net_state() -> Array:
	return [net_id, unit_id, snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(post.x, 0.01), snappedf(post.y, 0.01),
		roundf(hp), snappedf(energy, 0.1), modules, kills, owner_player, home.x, home.y]


# --- Darstellung -------------------------------------------------------------

func _build_visual() -> void:
	_body = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.3)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.7
	if drone:
		var disk := CylinderMesh.new()
		disk.top_radius = 0.22
		disk.bottom_radius = 0.16
		disk.height = 0.1
		_body.mesh = disk
		_body.position.y = 0.9
	else:
		var cap := CapsuleMesh.new()
		cap.radius = 0.13
		cap.height = 0.5
		_body.mesh = cap
		_body.position.y = 0.3
	_body.material_override = mat
	add_child(_body)
	_bar = MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.5, 0.04, 0.06)
	_bar.mesh = bar
	_bar.material_override = Board3D.make_material(UiTheme.CYAN if drone else UiTheme.HAVE, true)
	_bar.position.y = 1.15 if drone else 0.7
	add_child(_bar)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.28
	torus.outer_radius = 0.34
	_ring.mesh = torus
	_ring.material_override = Board3D.make_material(UiTheme.CYAN, true)
	_ring.position.y = 0.05
	_ring.visible = false
	add_child(_ring)


func set_selected(on: bool) -> void:
	selected = on
	if _ring != null:
		_ring.visible = on


func _sync() -> void:
	position = Board3D.to_3d(pos)
	if _bar != null:
		var f := clampf(energy / maxf(max_energy(), 1.0), 0.0, 1.0) if drone else clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
		_bar.scale.x = maxf(f, 0.02)
