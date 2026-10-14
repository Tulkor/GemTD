class_name MaulTower
extends Tower
## Tower einer Filiale in Shopping Maul. Werte aus data/maul/shops.json (eine Stufe pro Tower,
## Upgrades sind eigene Tower mit "upgrade_from"). Schießt wie ein GemTD-Tower und wirkt dazu
## Zauber mit eigener Abklingzeit: Donnerschlag (nova_spell), Kettenblitz (chain_spell),
## Schockwelle (wave_spell). Vorerst als Neon-Säule in der Filialfarbe, höher je teurer.

const SPELLS := ["nova_spell", "chain_spell", "wave_spell"]

var value := 0             ## Gold, das im Tower steckt (Kauf und Upgrades); Verkauf bringt 75 %
var _spell_cd := {}        ## Index der Fähigkeit -> Restzeit


func set_tower(id: String, _t: int) -> void:
	tower_id = id
	tier = 0
	def = MaulData.tower(id)
	stats = def
	color = Color.from_string(str(def.get("color", "#ffffff")), Color.WHITE)
	place_at(cell)
	_spell_cd.clear()
	_build_visual()


func label() -> String:
	return str(def.get("name", tower_id))


func kill_bonus() -> float:
	return 0.0


func can_attack() -> bool:
	var dmg: Array = stats.get("damage", [0, 0])
	return float(stats.get("cooldown", 0)) > 0.0 and float(dmg[1]) > 0.0


func can_target(e) -> bool:
	return super.can_target(e) and (game == null or game.is_detected(e))


func cooldown() -> float:
	var f: float = game.frost_factor(self) if game != null else 1.0
	return float(stats.get("cooldown", 1.0)) / (1.0 + speed_bonus) * f


func _roll_damage() -> float:
	var dmg: Array = stats.get("damage", [1, 1])
	return randf_range(float(dmg[0]), float(dmg[1])) * (1.0 + damage_bonus)


func _process(delta: float) -> void:
	super._process(delta)
	if game == null or game.mirror or not game.is_wave_running():
		return
	var list := abilities()
	for i in list.size():
		var ab: Dictionary = list[i]
		var type := str(ab.get("type", ""))
		if not type in SPELLS:
			continue
		var left: float = _spell_cd.get(i, 0.0) - delta
		if left <= 0.0 and _cast(ab):
			left += float(ab.get("cooldown", 2.0)) * (game.frost_factor(self) if game != null else 1.0)
		_spell_cd[i] = maxf(left, -delta)


## Zauber wirken, wenn ein Ziel in Reichweite ist. true = gewirkt.
func _cast(ab: Dictionary) -> bool:
	var bonus := 1.0 + damage_bonus
	match str(ab.type):
		"nova_spell":
			var near: Array = game.enemies_in_radius(pos, float(ab.radius)).filter(func(e): return can_target(e))
			if near.is_empty():
				return false
			for e in near:
				if float(ab.get("slow", 0.0)) > 0.0:
					e.apply_slow(float(ab.slow), float(ab.get("slow_duration", 3.0)))
				_spell_hit(e, float(ab.damage) * bonus)
			game.add_ring(pos, float(ab.radius), color)
			return true
		"chain_spell":
			var r := float(ab.get("range", range_cells()))
			var first = null
			for e in game.find_targets_in(self, r, 1):
				first = e
			if first == null:
				return false
			var hit := [first]
			var current = first
			var dmg := float(ab.damage) * bonus
			game.add_beam(position + Vector3(0, 1.0, 0), first.position, Color.WHITE)
			_spell_hit(first, dmg)
			for i in int(ab.get("targets", 3)) - 1:
				dmg *= float(ab.get("falloff", 0.85))
				var next = null
				var best := INF
				for other in game.enemies_in_radius(current.pos, 4.0):
					var d: float = other.pos.distance_to(current.pos)
					if not other in hit and can_target(other) and d < best:
						best = d
						next = other
				if next == null:
					break
				game.add_beam(current.position, next.position, Color.WHITE)
				hit.append(next)
				_spell_hit(next, dmg)
				current = next
			return true
		"wave_spell":
			var r := float(ab.get("range", range_cells()))
			var first = null
			for e in game.find_targets_in(self, r, 1):
				first = e
			if first == null:
				return false
			var dir: Vector2 = (first.pos - pos).normalized()
			var width := float(ab.get("width", 1.5))
			var end := pos + dir * r
			for e in game.enemies_in_radius(pos, r + width):
				if not can_target(e):
					continue
				var rel: Vector2 = e.pos - pos
				var along := rel.dot(dir)
				if along >= 0.0 and along <= r and absf(rel.cross(dir)) <= width:
					_spell_hit(e, float(ab.damage) * bonus)
			game.add_beam(Board3D.to_3d(pos, 0.3), Board3D.to_3d(end, 0.3), color.lerp(Color.WHITE, 0.5))
			return true
	return false


func _spell_hit(e, dmg: float) -> void:
	if e.dead:
		return
	e.last_hit_by = owner_player
	total_damage += e.take_spell_damage(dmg)
	if e.dead:
		kills += 1


func info_text() -> String:
	return label()


# --- Darstellung ---------------------------------------------------------------

func _build_visual() -> void:
	if _visual:
		_visual.queue_free()
	_preview_ring = null
	_gem = null
	_visual = Node3D.new()
	add_child(_visual)
	var base := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(0.92, 0.12, 0.92)
	base.mesh = slab
	base.position.y = 0.06
	base.material_override = Board3D.make_material(Color("160b28"))
	_visual.add_child(base)
	# Höhe wächst mit dem Wert: 9 Gold ≈ 0,35, 6.000 Gold ≈ 1,5 Towerbreiten
	var cost := maxf(float(def.get("value", def.get("cost", 10))), 5.0)
	var h := clampf(0.15 + log(cost) / log(10.0) * 0.36, 0.3, 1.6)
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	var w := 0.5 if str(def.get("targets", "both")) != "air" else 0.36
	box.size = Vector3(w, h, w)
	body.mesh = box
	body.position.y = 0.12 + h / 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.35)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.6
	mat.roughness = 0.4
	body.material_override = mat
	_visual.add_child(body)
	# Kappe in Weiß: Lufttower spitz, Bodentower flach, beide als Neonkante
	var cap := MeshInstance3D.new()
	if str(def.get("targets", "both")) == "air":
		var prism := PrismMesh.new()
		prism.size = Vector3(w * 1.2, 0.3, w * 1.2)
		cap.mesh = prism
		cap.position.y = 0.12 + h + 0.15
	else:
		var top := BoxMesh.new()
		top.size = Vector3(w + 0.1, 0.06, w + 0.1)
		cap.mesh = top
		cap.position.y = 0.12 + h + 0.03
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = color.lerp(Color.WHITE, 0.6)
	cap_mat.emission_enabled = true
	cap_mat.emission = color.lerp(Color.WHITE, 0.4)
	cap_mat.emission_energy_multiplier = 1.4
	cap.material_override = cap_mat
	_visual.add_child(cap)
	_finish_visual()
