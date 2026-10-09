class_name Tower
extends Node3D
## Ein Tower (oder eine Falle) auf dem Feld. Alle Werte kommen aus data/towers/<id>.json.
## Logische Position `pos` in Feldern (Vector2), die 3D-Position folgt daraus.

var game  # game.gd
var cell := Vector2i.ZERO
var pos := Vector2.ZERO
var tower_id := ""
var tier := 0
var def: Dictionary = {}
var stats: Dictionary = {}
var color := Color.WHITE

var is_new := false   ## in dieser Runde gesetzt, noch nicht ausgewählt
var selected := false
var speed_bonus := 0.0   ## von Tempo-Auren anderer Tower
var damage_bonus := 0.0  ## von Schadens-Auren anderer Tower
var cooldown_left := 0.0
var kills := 0
var total_damage := 0.0

var _visual: Node3D
var _gem: MeshInstance3D
var _new_ring: MeshInstance3D
var _select_ring: MeshInstance3D
var _range_ring: MeshInstance3D
var _time := 0.0

static var _octahedron: ArrayMesh


func setup(g, c: Vector2i, id: String, t: int) -> void:
	game = g
	cell = c
	pos = Board3D.cell_center(c)
	position = Board3D.to_3d(pos)
	set_tower(id, t)


func set_tower(id: String, t: int) -> void:
	tower_id = id
	tier = t
	def = Database.towers.get(id, {})
	stats = Database.tower_tier(id, t)
	color = Color.from_string(str(def.get("color", "#ffffff")), Color.WHITE)
	_build_visual()


func label() -> String:
	return Database.tower_label(tower_id, tier)


func is_trap() -> bool:
	return str(def.get("kind", "tower")) == "trap"


func range_cells() -> float:
	return float(stats.get("range", 3.0))


func abilities() -> Array:
	return stats.get("abilities", [])


func ability(type: String) -> Dictionary:
	for ab in abilities():
		if ab.get("type", "") == type:
			return ab
	return {}


func target_mode() -> String:
	return str(stats.get("targets", def.get("targets", "both")))


func can_target(e) -> bool:
	match target_mode():
		"air":
			return e.flying
		"ground":
			return not e.flying
	return true


func can_attack() -> bool:
	var dmg: Array = stats.get("damage", [0, 0])
	return float(stats.get("cooldown", 0)) > 0.0 and float(dmg[1]) > 0.0


func cooldown() -> float:
	return float(stats.get("cooldown", 1.0)) / (1.0 + speed_bonus)


# --- Kampf -------------------------------------------------------------------

func _process(delta: float) -> void:
	_animate(delta)
	if game == null or not game.is_wave_running():
		return
	_apply_enemy_auras(delta)
	if not can_attack():
		return
	cooldown_left -= delta
	if cooldown_left > 0.0:
		return
	var count := 1
	var ms := ability("multishot")
	if not ms.is_empty():
		count = int(ms.targets)
	var targets: Array = game.find_targets(self, count)
	if targets.is_empty():
		return
	for e in targets:
		_attack(e)
	cooldown_left = cooldown()


## Auren, die auf Gegner in Reichweite wirken (z. B. Fallen oder Uran).
func _apply_enemy_auras(delta: float) -> void:
	for ab in abilities():
		var type := str(ab.get("type", ""))
		if not type in ["burn_aura", "slow_aura", "armor_aura"]:
			continue
		for e in game.enemies_in_radius(pos, float(ab.radius)):
			if not can_target(e):
				continue
			match type:
				"burn_aura":
					total_damage += e.take_raw_damage(float(ab.dps) * delta)
					if e.dead:
						kills += 1
				"slow_aura":
					e.apply_slow(float(ab.factor), 0.25)
				"armor_aura":
					e.apply_armor_reduction(float(ab.amount), 0.25)


func _roll_damage() -> float:
	var dmg: Array = stats.get("damage", [1, 1])
	return randf_range(float(dmg[0]), float(dmg[1])) * (1.0 + damage_bonus)


func _attack(e) -> void:
	var dmg := _roll_damage()
	var crit := ability("crit")
	if not crit.is_empty() and randf() < float(crit.chance):
		dmg *= float(crit.multiplier)
	game.add_beam(position + Vector3(0, 0.9, 0), e.position, color)
	var target_pos: Vector2 = e.pos
	_hit(e, dmg)
	var splash := ability("splash")
	if not splash.is_empty():
		for other in game.enemies_in_radius(target_pos, float(splash.radius)):
			if other != e and can_target(other):
				_hit(other, dmg * float(splash.factor))
	var bounce := ability("bounce")
	if not bounce.is_empty():
		var hit := [e]
		var current = e
		var bdmg := dmg
		for i in int(bounce.targets):
			bdmg *= float(bounce.get("falloff", 0.8))
			var next = null
			var best := INF
			for other in game.enemies_in_radius(current.pos, float(bounce.get("radius", 2.5))):
				var d: float = other.pos.distance_to(current.pos)
				if not other in hit and can_target(other) and d < best:
					best = d
					next = other
			if next == null:
				break
			game.add_beam(current.position, next.position, color)
			hit.append(next)
			_hit(next, bdmg)
			current = next


func _hit(e, dmg: float) -> void:
	if e.dead:
		return
	if e.flying:
		var ab := ability("air_bonus")
		if not ab.is_empty():
			dmg *= float(ab.multiplier)
	var slow := ability("slow")
	if not slow.is_empty():
		e.apply_slow(float(slow.factor), float(slow.duration))
	var poison := ability("poison")
	if not poison.is_empty():
		e.apply_poison(float(poison.dps), float(poison.duration))
	var armor := ability("armor_reduce")
	if not armor.is_empty():
		e.apply_armor_reduction(float(armor.amount), float(armor.duration))
	var stun := ability("stun")
	if not stun.is_empty() and randf() < float(stun.chance):
		e.apply_stun(float(stun.duration))
	var gold := ability("gold_on_hit")
	if not gold.is_empty() and randf() < float(gold.chance):
		game.add_gold(int(gold.gold))
	total_damage += e.take_damage(dmg)
	if e.dead:
		kills += 1


func info_text() -> String:
	var lines := [label()]
	if is_trap():
		lines.append("Falle – Gegner laufen darüber")
	if can_attack():
		var dmg: Array = stats.get("damage", [0, 0])
		var bonus := "  (+%d%% Aura)" % int(damage_bonus * 100) if damage_bonus > 0 else ""
		lines.append("Schaden: %d–%d%s" % [int(dmg[0]), int(dmg[1]), bonus])
		lines.append("Abklingzeit: %.2fs%s" % [cooldown(), "  (+%d%% Aura)" % int(speed_bonus * 100) if speed_bonus > 0 else ""])
		lines.append("Reichweite: %.1f Felder" % range_cells())
	match target_mode():
		"air":
			lines.append("Wirkt nur gegen Luft")
		"ground":
			lines.append("Wirkt nur gegen Boden")
	for ab in abilities():
		lines.append("• " + Abilities.describe(ab))
	if def.has("description"):
		lines.append(str(def.description))
	if not is_new:
		lines.append("Kills: %d   Schaden gesamt: %d" % [kills, int(total_damage)])
	return "\n".join(lines)


# --- Darstellung -------------------------------------------------------------

func set_selected(value: bool) -> void:
	selected = value
	if _select_ring:
		_select_ring.visible = value
		_range_ring.visible = value and (can_attack() or _aura_radius() > 0.0)


func _aura_radius() -> float:
	var r := 0.0
	for ab in abilities():
		if str(ab.get("type", "")).ends_with("_aura"):
			r = maxf(r, float(ab.radius))
	return r


func _build_visual() -> void:
	if _visual:
		_visual.queue_free()
	_visual = Node3D.new()
	add_child(_visual)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.35
	mat.roughness = 0.2
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.25

	var category := str(def.get("category", "gem"))
	_gem = null
	var model := ModelLoader.instantiate(str(stats.get("model", def.get("model", ""))), float(stats.get("model_scale", def.get("model_scale", 1.0))))
	if model != null:
		_visual.add_child(model)
	elif is_trap():
		var plate := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.42
		cyl.bottom_radius = 0.46
		cyl.height = 0.08
		cyl.radial_segments = 6
		plate.mesh = cyl
		plate.material_override = mat
		plate.position.y = 0.04
		_visual.add_child(plate)
	else:
		var base := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.radial_segments = 6
		if category == "special":
			cyl.top_radius = 0.3
			cyl.bottom_radius = 0.4
			cyl.height = 0.7
			base.material_override = mat
		else:
			cyl.top_radius = 0.25
			cyl.bottom_radius = 0.35
			cyl.height = 0.3
			base.material_override = Board3D.make_material(Color("4a4a52"))
		base.mesh = cyl
		base.position.y = cyl.height / 2.0
		_visual.add_child(base)
		_gem = MeshInstance3D.new()
		_gem.mesh = _gem_mesh()
		_gem.material_override = mat
		var s := 0.3 + 0.04 * tier
		_gem.scale = Vector3(s, s * 1.4, s)
		_gem.position.y = cyl.height + s * 1.4 + 0.05
		_visual.add_child(_gem)

	_new_ring = _ring(0.48, 0.05, Color(1, 1, 1, 0.9))
	_new_ring.visible = is_new
	_select_ring = _ring(0.52, 0.06, Color.YELLOW)
	_range_ring = _ring(maxf(range_cells(), _aura_radius()), 0.05, Color(1, 1, 1, 0.6))
	set_selected(selected)


func _ring(radius: float, thickness: float, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(radius - thickness, 0.01)
	torus.outer_radius = radius
	torus.rings = 48
	torus.ring_segments = 6
	m.mesh = torus
	m.material_override = Board3D.make_material(col, true)
	m.position.y = 0.05
	m.scale = Vector3(1, 0.3, 1)
	_visual.add_child(m)
	return m


func _animate(delta: float) -> void:
	_time += delta
	if _gem:
		_gem.rotation.y += delta * 0.8
	if _new_ring:
		_new_ring.visible = is_new
		if is_new:
			(_new_ring.material_override as StandardMaterial3D).albedo_color.a = 0.5 + 0.5 * sin(_time * 5.0)


static func _gem_mesh() -> ArrayMesh:
	if _octahedron != null:
		return _octahedron
	var top := Vector3(0, 1, 0)
	var bottom := Vector3(0, -1, 0)
	var ring := [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 4]
		for v in [top, b, a, bottom, a, b]:
			st.add_vertex(v)
	st.generate_normals()
	_octahedron = st.commit()
	return _octahedron
