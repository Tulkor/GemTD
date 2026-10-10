class_name Tower
extends Node3D
## Ein Tower (oder eine Falle) auf dem Feld. Alle Werte kommen aus data/towers/<id>.json.
## cell ist das Feld oben links der 2×2 belegten Felder. Logische Position `pos` in Einheiten
## (1 = eine Towerbreite) als Vector2, die 3D-Position folgt daraus.

const GEM_SHADER := preload("res://assets/shaders/gem.gdshader")
## Deckkraft für Modelle mit eigener Textur ("model_tint": false)
const GEM_OPACITY_TEXTURED := 0.7

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
var moves_left := 0  ## wie oft eine Falle noch verschoben werden darf
var total_damage := 0.0

var _visual: Node3D
var _gem: Node3D
var _new_ring: MeshInstance3D
var _select_ring: MeshInstance3D
var _range_ring: MeshInstance3D
var _time := 0.0

static var _octahedron: ArrayMesh


func setup(g, c: Vector2i, id: String, t: int) -> void:
	game = g
	cell = c
	set_tower(id, t)


func set_tower(id: String, t: int) -> void:
	tower_id = id
	tier = t
	def = Database.towers.get(id, {})
	stats = Database.tower_tier(id, t)
	color = Color.from_string(str(def.get("color", "#ffffff")), Color.WHITE)
	place_at(cell)
	_build_visual()


## Felder pro Kante: Tower 2×2, Fallen 3×3 (ab dem Anker cell).
func footprint_size() -> int:
	return Board3D.TRAP_CELLS if is_trap() else Board3D.TOWER_CELLS


func place_at(c: Vector2i) -> void:
	cell = c
	pos = Board3D.footprint_center(c, footprint_size())
	position = Board3D.to_3d(pos)


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
	return float(stats.get("cooldown", 0)) > 0.0 and (float(dmg[1]) > 0.0 or not ability("wave_damage").is_empty())


## Reichweite gegen ein bestimmtes Ziel (manche Fallen haben gegen Flieger mehr Reichweite).
func range_for(e) -> float:
	if e.flying and stats.has("range_air"):
		return float(stats.range_air)
	return range_cells()


## Fallen mit kurzer Reichweite treffen alles auf ihrer 3×3-Fläche, alle anderen im Kreis.
func in_range(e) -> bool:
	var r := range_for(e)
	if is_trap() and r <= Board3D.TRAP_CELLS * Board3D.CELL:
		var half := Board3D.TRAP_CELLS * Board3D.CELL / 2.0
		return absf(e.pos.x - pos.x) <= half and absf(e.pos.y - pos.y) <= half
	return e.pos.distance_to(pos) <= r


func damage_type() -> String:
	return str(stats.get("damage_type", def.get("damage_type", "")))


## Kill-Ränge wie in WC3: +10 % Schaden pro 10 Kills (Werte in balance.json).
func kill_bonus() -> float:
	var kr: Dictionary = Database.balance.get("kill_rank", {})
	if kr.is_empty():
		return 0.0
	var ranks := floori(kills / float(kr.get("kills_per_rank", 10)))
	return minf(ranks * float(kr.get("bonus_per_rank", 0.1)), float(kr.get("max_bonus", 1.2)))


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
	# höchstens ein Frame Rückstand, sonst feuert ein Tower nach langer Pause mehrfach hintereinander
	cooldown_left = maxf(cooldown_left - delta, -delta)
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
	# Überhang behalten, damit hohe Spielgeschwindigkeit (große Frames) die Feuerrate nicht senkt
	cooldown_left += cooldown()


## Auren, die auf Gegner in Reichweite wirken (z. B. Fallen oder Uran).
func _apply_enemy_auras(delta: float) -> void:
	for ab in abilities():
		var type := str(ab.get("type", ""))
		if not type in ["burn_aura", "slow_aura", "armor_aura"]:
			continue
		var mode := str(ab.get("targets", target_mode()))
		for e in game.enemies_in_radius(pos, float(ab.radius)):
			if (mode == "air" and not e.flying) or (mode == "ground" and e.flying):
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
	var base := randf_range(float(dmg[0]), float(dmg[1]))
	var wd := ability("wave_damage")
	if not wd.is_empty():
		base += float(wd.per_wave) * game.current_wave()
	return base * (1.0 + damage_bonus + kill_bonus())


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


## Treffer-Effekte. Jede Fähigkeit mit "chance" löst nur mit dieser Wahrscheinlichkeit aus.
func _hit(e, dmg: float) -> void:
	if e.dead:
		return
	if e.flying:
		var ab := ability("air_bonus")
		if not ab.is_empty():
			dmg *= float(ab.multiplier)
	for ab in abilities():
		var type := str(ab.get("type", ""))
		if not type in ON_HIT:
			continue
		if ab.has("chance") and randf() >= float(ab.chance):
			continue
		match type:
			"slow":
				e.apply_slow(float(ab.factor), float(ab.duration))
			"poison":
				e.apply_poison(float(ab.dps), float(ab.duration), self)
			"armor_reduce":
				e.apply_armor_reduction(float(ab.amount), float(ab.duration))
			"stun":
				e.apply_stun(float(ab.duration))
			"gold_on_hit":
				game.add_gold(int(ab.get("gold", 0)) + floori(float(ab.get("gold_per_wave", 0)) * game.current_wave()))
			"stacking_damage":
				dmg += e.add_stack(float(ab.per_hit), float(ab.duration))
			"nova":
				_nova(e, ab)
	total_damage += e.take_damage(dmg, damage_type())
	if e.dead:
		kills += 1


const ON_HIT := ["slow", "poison", "armor_reduce", "stun", "gold_on_hit", "stacking_damage", "nova"]


## Zauber um das Ziel herum (Frostnova, Blitz, Messerfächer …).
func _nova(target, ab: Dictionary) -> void:
	var center: Vector2 = target.pos
	for other in game.enemies_in_radius(center, float(ab.get("radius", 2.0))):
		if not can_target(other):
			continue
		if ab.has("slow"):
			other.apply_slow(float(ab.slow), 3.0)
		total_damage += other.take_damage(float(ab.damage) * (1.0 + kill_bonus()), "spells")
		if other.dead:
			kills += 1
	game.add_beam(Board3D.to_3d(center, 0.1), Board3D.to_3d(center, 1.5), Color.WHITE)


func info_text() -> String:
	var lines := [label()]
	if is_trap():
		lines.append(tr("Falle – Gegner laufen darüber") + (tr(", noch %d× verschiebbar") % moves_left if moves_left > 0 else ""))
	if can_attack():
		var dmg: Array = stats.get("damage", [0, 0])
		var bonus := tr("  (+%d%% Aura/Rang)") % int((damage_bonus + kill_bonus()) * 100) if damage_bonus + kill_bonus() > 0 else ""
		lines.append(tr("Schaden: %d–%d%s") % [int(dmg[0]), int(dmg[1]), bonus])
		lines.append(tr("Abklingzeit: %.2fs%s") % [cooldown(), tr("  (+%d%% Aura)") % int(speed_bonus * 100) if speed_bonus > 0 else ""])
		var reach := tr("Fläche %d×%d Felder") % [Board3D.TRAP_CELLS, Board3D.TRAP_CELLS] if _square_hitbox() else tr("%.1f Towerbreiten") % range_cells()
		lines.append(tr("Reichweite: %s%s") % [reach, tr(" (Luft %.1f)") % float(stats.range_air) if stats.has("range_air") else ""])
		if damage_type() != "":
			lines.append(tr("Schadensart: ") + tr(Database.DAMAGE_TYPE_NAMES.get(damage_type(), damage_type())))
	match target_mode():
		"air":
			lines.append(tr("Wirkt nur gegen Luft"))
		"ground":
			lines.append(tr("Wirkt nur gegen Boden"))
	for ab in abilities():
		lines.append("• " + Abilities.describe(ab))
	if def.has("description"):
		lines.append(tr(str(def.description)))
	if not is_new:
		lines.append(tr("Kills: %d   Schaden gesamt: %d") % [kills, int(total_damage)])
	return "\n".join(lines)


# --- Darstellung -------------------------------------------------------------

func set_selected(value: bool) -> void:
	selected = value
	if _select_ring:
		_select_ring.visible = value
		_range_ring.visible = value and (can_attack() or _aura_radius() > 0.0)


func _square_hitbox() -> bool:
	return is_trap() and range_cells() <= Board3D.TRAP_CELLS * Board3D.CELL


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
	var mat := ShaderMaterial.new()
	mat.shader = GEM_SHADER
	mat.set_shader_parameter("color", color)
	# "model_tint": false behält die Farben/Texturen des Modells (nur leicht durchsichtig gemacht)
	var tint: Material = mat if bool(def.get("model_tint", true)) else null

	var category := str(def.get("category", "gem"))
	_gem = null
	var model_path := str(stats.get("model", def.get("model", "")))
	if is_trap():
		var plate := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		# Platte deckt die 3×3-Fläche der Falle ab
		var plate_r := Board3D.TRAP_CELLS * Board3D.CELL / 2.0
		cyl.top_radius = plate_r * 0.98
		cyl.bottom_radius = plate_r * 1.05
		cyl.height = 0.08
		cyl.radial_segments = 6
		plate.mesh = cyl
		plate.material_override = mat
		plate.position.y = 0.04
		_visual.add_child(plate)
		if model_path != "":
			_gem = ModelLoader.instantiate(model_path, float(stats.get("model_scale", def.get("model_scale", 0.35))), mat)
			if _gem:
				_gem.position.y = 0.08
				_visual.add_child(_gem)
		_finish_visual()
		return
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.radial_segments = 6
	if category == "special":
		cyl.top_radius = 0.34
		cyl.bottom_radius = 0.42
		cyl.height = 0.35
	else:
		cyl.top_radius = 0.28
		cyl.bottom_radius = 0.36
		cyl.height = 0.2
	base.material_override = Board3D.make_material(Color("4a4a52"))
	base.mesh = cyl
	base.position.y = cyl.height / 2.0
	_visual.add_child(base)
	var default_size := (0.75 + 0.05 * tier) if category == "special" else (0.5 + 0.06 * tier)
	var size := float(stats.get("model_scale", def.get("model_scale", default_size)))
	if model_path != "":
		_gem = ModelLoader.instantiate(model_path, size, tint)
		if _gem:
			if tint == null:
				ModelLoader.make_translucent(_gem, GEM_OPACITY_TEXTURED)
			_gem.position.y = cyl.height
			_visual.add_child(_gem)
	if _gem == null:
		var oct := MeshInstance3D.new()
		oct.mesh = _gem_mesh()
		oct.material_override = mat
		var s := size * 0.45
		oct.scale = Vector3(s, s * 1.4, s)
		oct.position.y = cyl.height + s * 1.4 + 0.05
		_gem = Node3D.new()
		_gem.add_child(oct)
		_visual.add_child(_gem)
	_finish_visual()


func _finish_visual() -> void:
	_new_ring = _ring(0.48, 0.05, Color(1, 1, 1, 0.9))
	_new_ring.visible = is_new
	_select_ring = _ring(0.52, 0.06, Color.YELLOW)
	# Fallen zeigen ihre Fläche über die Platte, der Ring nur Luft- oder Aurareichweite
	var ring := maxf(float(stats.get("range_air", 0.0)), _aura_radius()) if _square_hitbox() else maxf(range_cells(), _aura_radius())
	_range_ring = _ring(ring, 0.05, Color(1, 1, 1, 0.6))
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
		_gem.rotation.y += delta * 0.5
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
