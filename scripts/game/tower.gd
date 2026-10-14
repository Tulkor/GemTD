class_name Tower
extends Node3D
## Ein Tower (oder eine Falle) auf dem Feld. Alle Werte kommen aus data/towers/<id>.json.
## cell ist das Feld oben links der 2×2 belegten Felder. Logische Position `pos` in Einheiten
## (1 = eine Towerbreite) als Vector2, die 3D-Position folgt daraus.

const GEM_SHADER := preload("res://assets/shaders/gem.gdshader")
## Deckkraft für Modelle mit eigener Textur ("model_tint": false)
const GEM_OPACITY_TEXTURED := 0.85
## Helligkeit der Lichtscheibe im Sockel (über 1 = leuchtet im Glow)
const BASE_LIGHT_ENERGY := 1.3
## Drehgeschwindigkeit der Gems (rad/s): zur Auswahl in dieser Runde, und fixiert
const SPIN_NEW := 0.425
const SPIN_FIXED := 0.325
const BASE_HEIGHT := 0.12
const BASE_HEIGHT_SPECIAL := 0.18
## Höchstens so hoch (Towerbreiten) wird ein Special, auch wenn das Modell schmal und lang ist
const GEM_MAX_HEIGHT := 1.3
## Gems je Qualität (Splitter … Großartig): Anzahl Kristalle auf dem Sockel und die Kiste
## (Breite, Höhe in Sockelbreiten), in die jeder Kristall passt. Splitter sind viele kleine,
## mit jeder Stufe werden es weniger, dafür größere.
const GEM_CLUSTERS := [
	[5, 0.26, 0.34],
	[4, 0.34, 0.46],
	[3, 0.44, 0.6],
	[2, 0.56, 0.78],
	[1, 0.78, 1.0],
	[1, 0.92, 1.25],
]
## Platz der Kristalle auf dem Sockel (in Sockelbreiten) je Anzahl
const CLUSTER_SPOTS := {
	1: [Vector2.ZERO],
	2: [Vector2(-0.17, 0.15), Vector2(0.17, -0.15)],
	3: [Vector2(0.0, -0.22), Vector2(-0.19, 0.11), Vector2(0.19, 0.11)],
	4: [Vector2(-0.18, -0.18), Vector2(0.18, -0.18), Vector2(0.18, 0.18), Vector2(-0.18, 0.18)],
	5: [Vector2.ZERO, Vector2(-0.21, -0.21), Vector2(0.21, -0.21), Vector2(0.21, 0.21), Vector2(-0.21, 0.21)],
}
## Größenunterschiede innerhalb eines Clusters, damit es natürlicher aussieht
const CLUSTER_VARY := [1.0, 0.86, 0.94, 0.8, 0.9]
static var _slab_cache := {}

var game  # game.gd
var cell := Vector2i.ZERO
var pos := Vector2.ZERO
var tower_id := ""
var tier := 0
var def: Dictionary = {}
var stats: Dictionary = {}
var color := Color.WHITE

var is_new := false   ## in dieser Runde gesetzt, noch nicht ausgewählt
var owner_player := 0  ## Spielernummer (Koop): nur er wählt, kombiniert und wertet auf, bekommt das Kopfgeld
var selected := false
var speed_bonus := 0.0   ## von Tempo-Auren anderer Tower
var damage_bonus := 0.0  ## von Schadens-Auren anderer Tower
var speed_source := ""   ## Name des Towers, dessen Tempo-Aura gerade wirkt (fürs Infofenster)
var damage_source := ""  ## Name des Towers, dessen Schadens-Aura gerade wirkt
var cooldown_left := 0.0
var kills := 0
var moves_left := 0  ## wie oft eine Falle noch verschoben werden darf
var total_damage := 0.0

var _visual: Node3D
var _gem: Node3D
var _new_ring: MeshInstance3D
var _select_ring: MeshInstance3D
var _range_ring: MeshInstance3D
var _preview_ring: MeshInstance3D  ## Reichweite nach einem Upgrade (Hover über den Knopf)
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
	# Koop-Mitspieler: geschossen wird nur beim Host
	if game == null or game.mirror or not game.is_wave_running():
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
					e.last_hit_by = owner_player
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
	game.add_beam(position + Vector3(0, 0.9, 0), _hit_point(e), color, fx_key())
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
			game.add_beam(_hit_point(current), _hit_point(next), color, fx_key())
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
				dmg += float(ab.get("damage", 0.0))
			"gold_on_hit":
				game.add_gold(int(ab.get("gold", 0)) + floori(float(ab.get("gold_per_wave", 0)) * game.current_wave()), owner_player)
			"stacking_damage":
				dmg += e.add_stack(float(ab.per_hit), float(ab.duration))
			"nova":
				_nova(e, ab)
	e.last_hit_by = owner_player
	total_damage += e.take_damage(dmg, damage_type())
	if e.dead:
		kills += 1


const ON_HIT := ["slow", "poison", "armor_reduce", "stun", "gold_on_hit", "stacking_damage", "nova"]


## Schuss- und Treffer-Effekt dieses Towers (effects.gd, fx_data.gd)
func fx_key() -> String:
	return "t:%s:%d" % [tower_id, tier]


## Mitte des Gegnerkörpers, dort sitzt der Treffer-Effekt
func _hit_point(e) -> Vector3:
	return e.position + Vector3(0, 0.0 if e.flying else 0.2 * e.size, 0)


## Zauber um das Ziel herum (Frostnova, Blitz, Messerfächer …).
func _nova(target, ab: Dictionary) -> void:
	var center: Vector2 = target.pos
	for other in game.enemies_in_radius(center, float(ab.get("radius", 2.0))):
		if not can_target(other):
			continue
		if ab.has("slow"):
			other.apply_slow(float(ab.slow), 3.0)
		other.last_hit_by = owner_player
		total_damage += other.take_damage(float(ab.damage) * (1.0 + kill_bonus()), "spells")
		if other.dead:
			kills += 1
	game.add_beam(Board3D.to_3d(center, 0.1), Board3D.to_3d(center, 1.5), Color.WHITE, "n:%s:%d:%s" % [tower_id, tier, float(ab.get("radius", 2.0))])


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
	if not value:
		show_preview_range(0.0)


## Türkiser Ring mit der Reichweite nach einem Upgrade; 0 blendet ihn aus.
func show_preview_range(radius: float) -> void:
	if _preview_ring != null and is_instance_valid(_preview_ring):
		_preview_ring.queue_free()
	_preview_ring = null
	if radius > 0.0 and _visual != null:
		_preview_ring = _ring(radius, 0.07, UiTheme.CYAN)


## Radius des Reichweitenrings für bestimmte Werte: Fallen mit Fläche zeigen nur Luft- oder Aurareichweite.
static func ring_radius(s: Dictionary, trap: bool) -> float:
	var aura := 0.0
	for ab in s.get("abilities", []):
		if str(ab.get("type", "")).ends_with("_aura"):
			aura = maxf(aura, float(ab.radius))
	var r := float(s.get("range", 3.0))
	if trap and r <= Board3D.TRAP_CELLS * Board3D.CELL:
		return maxf(float(s.get("range_air", 0.0)), aura)
	return maxf(r, aura)


func _square_hitbox() -> bool:
	return is_trap() and range_cells() <= Board3D.TRAP_CELLS * Board3D.CELL


## Größter Radius einer Aura, die auf diesen Gegner wirkt (Brand, Verlangsamung, Rüstung), 0 = keine.
func enemy_aura_radius(e) -> float:
	var r := 0.0
	for ab in abilities():
		if not str(ab.get("type", "")) in ["burn_aura", "slow_aura", "armor_aura"]:
			continue
		var mode := str(ab.get("targets", target_mode()))
		if (mode == "air" and not e.flying) or (mode == "ground" and e.flying):
			continue
		r = maxf(r, float(ab.radius))
	return r


func _aura_radius() -> float:
	var r := 0.0
	for ab in abilities():
		if str(ab.get("type", "")).ends_with("_aura"):
			r = maxf(r, float(ab.radius))
	return r


func _build_visual() -> void:
	if _visual:
		_visual.queue_free()
	_preview_ring = null
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
	# Sockel: eckige Glasplatte mit runden Ecken über die ganzen 2×2 Felder, von innen beleuchtet
	var foot := footprint_size() * Board3D.CELL
	var base_h := BASE_HEIGHT_SPECIAL if category == "special" else BASE_HEIGHT
	var base := MeshInstance3D.new()
	base.mesh = rounded_slab(foot * 0.96, base_h, 0.1)
	base.material_override = _glass_material()
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(base)
	ModelLoader.add_outline(base)
	var light := MeshInstance3D.new()
	light.mesh = rounded_slab(foot * 0.5, 0.012, 0.07)
	var light_mat := Board3D.make_material(color.lerp(Color.WHITE, 0.4) * BASE_LIGHT_ENERGY, true)
	light_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	light.material_override = light_mat
	light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light.position.y = base_h - 0.025
	_visual.add_child(light)
	if mat is ShaderMaterial:
		mat.set_shader_parameter("base_top", base_h)
	# Special füllt die Sockelfläche: Breite (nicht Höhe) wird angepasst, höhere Stufen etwas breiter
	var width := minf(0.86 + 0.02 * tier, 0.92) * foot
	if category == "gem" and model_path != "":
		_gem = _gem_cluster(model_path, tint, foot, base_h)
		width = float(GEM_CLUSTERS[clampi(tier, 0, GEM_CLUSTERS.size() - 1)][1]) * foot
		if _gem:
			if tint == null:
				ModelLoader.make_translucent(_gem, GEM_OPACITY_TEXTURED, color)
			_visual.add_child(_gem)
	elif model_path != "":
		if stats.has("model_scale") or def.has("model_scale"):
			_gem = ModelLoader.instantiate(model_path, float(stats.get("model_scale", def.get("model_scale"))), tint)
		else:
			_gem = ModelLoader.instantiate_fit(model_path, width, GEM_MAX_HEIGHT, tint)
		if _gem:
			if tint == null:
				ModelLoader.make_translucent(_gem, GEM_OPACITY_TEXTURED, color)
			_gem.position.y = base_h
			_visual.add_child(_gem)
	var size := width
	if _gem == null:
		var oct := MeshInstance3D.new()
		oct.mesh = _gem_mesh()
		oct.material_override = mat
		var s := size * 0.45
		oct.scale = Vector3(s, s * 1.4, s)
		oct.position.y = base_h + s * 1.4 + 0.05
		_gem = Node3D.new()
		_gem.add_child(oct)
		_visual.add_child(_gem)
	ModelLoader.add_outline(_gem)
	_finish_visual()


## Mehrere Kristalle auf dem Sockel, Anzahl und Größe nach Qualität (GEM_CLUSTERS).
## Jeder Kristall passt in seine Kiste, schmale Modelle werden so nicht übermäßig hoch.
func _gem_cluster(model_path: String, tint: Material, foot: float, base_h: float) -> Node3D:
	var cfg: Array = GEM_CLUSTERS[clampi(tier, 0, GEM_CLUSTERS.size() - 1)]
	var n := int(cfg[0])
	var layout := _splinter_layout(tower_id, n) if tier <= 1 else []
	if layout.is_empty():
		# äußere Kristalle leicht nach außen geneigt wie bei einer Druse
		for i in n:
			var spot: Vector2 = CLUSTER_SPOTS[n][i]
			layout.append([spot, CLUSTER_VARY[i % CLUSTER_VARY.size()], 0.0 if spot == Vector2.ZERO else 12.0, -1.0])
	var cluster := Node3D.new()
	for i in layout.size():
		var entry: Array = layout[i]
		var k := float(entry[1])
		var crystal := ModelLoader.instantiate_fit(model_path, float(cfg[1]) * foot * k, float(cfg[2]) * foot * k, tint)
		if crystal == null:
			break
		var spot: Vector2 = entry[0] * foot
		var tilt := deg_to_rad(float(entry[2]))
		var basis := Basis(Vector3.UP, i * 2.4)
		var lift := 0.0
		if tilt > 0.0:
			var dir := Vector3(spot.x, 0.0, spot.y)
			if float(entry[3]) >= 0.0 or dir.is_zero_approx():
				var a := deg_to_rad(maxf(float(entry[3]), 0.0))
				dir = Vector3(cos(a), 0.0, sin(a))
			basis = Basis(Vector3.UP.cross(dir.normalized()).normalized(), tilt) * basis
			# geneigte Kristalle anheben, damit die Unterkante nicht im Sockel verschwindet
			var box := ModelLoader.aabb(crystal, Transform3D())
			lift = maxf(box.size.x, box.size.z) * 0.5 * sin(tilt) * 0.8
		crystal.position = Vector3(spot.x, base_h + lift, spot.y)
		crystal.basis = basis
		cluster.add_child(crystal)
	if cluster.get_child_count() == 0:
		cluster.free()
		return null
	return cluster


## Anordnung der Splitter (Stufe 0 und 1, n Kristalle), je Grundgem eine eigene.
## Je Kristall: [Platz in Sockelbreiten, Größe, Neigung in Grad, Neigungsrichtung in Grad
## (0 = +X, 90 = +Z, nach vorne zur Kamera) oder -1 = vom Sockelmittelpunkt weg].
## Leer = Standardanordnung aus CLUSTER_SPOTS.
static func _splinter_layout(id: String, n: int) -> Array:
	var out := []
	match id:
		"ruby":  # Krone: Ring mit freier Mitte, alle nach außen geneigt
			for i in n:
				var a := deg_to_rad(-90.0 + 360.0 * i / n)
				out.append([Vector2(cos(a), sin(a)) * 0.21, 1.0 - 0.1 * (i % 2), 22.0, -1.0])
		"sapphire":  # Reihe quer über den Sockel, nach hinten größer
			for i in n:
				var t := float(i) / (n - 1)
				out.append([Vector2(-0.28, 0.28).lerp(Vector2(0.28, -0.28), t), 0.75 + 0.4 * t, 6.0, 270.0])
		"emerald":  # Druse: ein großer in der Mitte, kleine rundherum stark geneigt
			out.append([Vector2.ZERO, 1.4, 0.0, -1.0])
			for i in n - 1:
				var a := deg_to_rad(45.0 + 360.0 * i / (n - 1))
				out.append([Vector2(cos(a), sin(a)) * 0.24, 0.7, 34.0, -1.0])
		"diamond":  # zwei Grüppchen in gegenüberliegenden Ecken
			var back := n - floori(n / 2.0)
			for i in n:
				var group := Vector2(-0.16, -0.15) if i < back else Vector2(0.19, 0.17)
				var j := i if i < back else i - back
				var a := deg_to_rad(200.0 + 120.0 * j)
				out.append([group + Vector2(cos(a), sin(a)) * 0.1, (0.95 if i < back else 0.78) - 0.06 * j, 10.0, -1.0])
		"topaz":  # Bogen hinten, nach vorne offen, die Mitte am größten
			for i in n:
				var t := float(i) / (n - 1)
				var a := deg_to_rad(lerpf(195.0, 345.0, t))
				out.append([Vector2(cos(a), sin(a)) * 0.25 + Vector2(0.0, 0.06), 0.8 + 0.35 * sin(t * PI), 14.0, -1.0])
		"amethyst":  # wie aus einer Wand gewachsen: hinten aufgereiht, alle nach vorne geneigt
			var spots := [Vector2(-0.26, -0.2), Vector2(0.24, -0.24), Vector2(-0.04, -0.27), Vector2(0.06, 0.02), Vector2(-0.2, 0.12)]
			var sizes := [1.0, 0.95, 1.1, 0.8, 0.72]
			for i in n:
				out.append([spots[i], sizes[i], 30.0, 70.0])
		"aquamarine":  # Strauß: alle aus der Mitte, nach außen gefächert
			out.append([Vector2.ZERO, 1.15, 0.0, -1.0])
			for i in n - 1:
				var a := deg_to_rad(20.0 + 360.0 * i / (n - 1))
				out.append([Vector2(cos(a), sin(a)) * 0.07, 0.95, 38.0, -1.0])
		"opal":  # verstreut liegend, einer steht
			var spots := [Vector2(0.02, -0.02), Vector2(-0.22, -0.19), Vector2(0.21, -0.2), Vector2(0.22, 0.19), Vector2(-0.2, 0.2)]
			var dirs := [0.0, 20.0, 150.0, 250.0, 300.0]
			for i in n:
				out.append([spots[i], 1.1 if i == 0 else 0.9, 0.0 if i == 0 else 62.0, dirs[i]])
	return out


## Quader mit abgerundeten senkrechten Kanten, Unterseite auf Y = 0, Mitte auf X/Z = 0.
static func rounded_slab(size: float, height: float, radius: float, segments := 6) -> ArrayMesh:
	var key := "%.3f/%.3f/%.3f" % [size, height, radius]
	if _slab_cache.has(key):
		return _slab_cache[key]
	var h := size / 2.0 - radius
	var outline: Array[Vector2] = []  # Umriss gegen den Uhrzeigersinn (von oben gesehen)
	var normals: Array[Vector2] = []
	var corners := [Vector2(h, h), Vector2(-h, h), Vector2(-h, -h), Vector2(h, -h)]
	for i in 4:
		for k in segments + 1:
			var a := (i + float(k) / segments) * PI / 2.0
			var n := Vector2(cos(a), sin(a))
			outline.append(corners[i] + n * radius)
			normals.append(n)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := outline.size()
	for i in count:
		var j := (i + 1) % count
		var p0 := outline[i]
		var p1 := outline[j]
		var n0 := Vector3(normals[i].x, 0, normals[i].y)
		var n1 := Vector3(normals[j].x, 0, normals[j].y)
		# Seite
		for v in [[p0, n0, 0.0], [p1, n1, height], [p1, n1, 0.0], [p0, n0, 0.0], [p0, n0, height], [p1, n1, height]]:
			st.set_normal(v[1])
			st.add_vertex(Vector3(v[0].x, v[2], v[0].y))
		# Deckel und Boden als Fächer um die Mitte
		for v in [[Vector2.ZERO, height], [p0, height], [p1, height]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(v[0].x, v[1], v[0].y))
		for v in [[Vector2.ZERO, 0.0], [p1, 0.0], [p0, 0.0]]:
			st.set_normal(Vector3.DOWN)
			st.add_vertex(Vector3(v[0].x, v[1], v[0].y))
	var mesh := st.commit()
	_slab_cache[key] = mesh
	return mesh


func _glass_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.8, 1.0, 0.16)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS  # damit die Kontur innen verdeckt wird
	m.roughness = 0.05
	m.metallic_specular = 0.9
	m.rim_enabled = true
	m.rim = 0.7
	m.rim_tint = 0.2
	m.emission_enabled = true
	m.emission = color.lerp(Color.WHITE, 0.5)
	m.emission_energy_multiplier = 0.35
	return m


func _finish_visual() -> void:
	_new_ring = _ring(0.48, 0.05, Color(1, 1, 1, 0.9))
	_new_ring.visible = is_new
	_select_ring = _ring(0.52, 0.06, Color.YELLOW)
	# Fallen zeigen ihre Fläche über die Platte, der Ring nur Luft- oder Aurareichweite
	_range_ring = _ring(ring_radius(stats, is_trap()), 0.05, Color(1, 1, 1, 0.6))
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
		_gem.rotation.y += delta * (SPIN_NEW if is_new else SPIN_FIXED)
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
