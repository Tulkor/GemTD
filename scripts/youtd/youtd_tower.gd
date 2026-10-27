class_name YoutdTower
extends Tower
## Tower in YouTD. Werte aus data/youtd/towers.json (WC3-Einheiten, umgerechnet über YoutdData.units).
## Dazu kommen Modifikatoren ("MOD_…") aus dem Tower selbst (wachsen je Level), aus eingelegten Items und Ölen
## und aus den Weisheits-Boni des Spielers. Tower sammeln Erfahrung für Kills und steigen bis Level 25 (30) auf:
## je Level +4 % Grundschaden, +1 % Angriffstempo, +0,15 % kritische Chance, +2 % kritischer Schaden.
## Fähigkeiten aus eigenen Skripten (Feld "script") kommen in Etappe 2, bis dahin schießen diese Tower nur normal.

const PREFIX := "youtd_"
## Modelle je Element (Stylized Nature MegaKit und Kristalle, CC0). solid = eigene Farben, sonst in Elementfarbe.
const N := "res://assets/models/nature/%s.glb"
const C := "res://assets/models/crystals/%s.glb"
const LOOKS := {
	"nature": [["bush_common_flowers", true], ["pine_5", true], ["mushroom_red_group", true], ["plant_1_big", true],
		["common_tree_3", true], ["fern_1", true], ["mushroom_tan_group", true], ["pine_2", true], ["lily_large", true]],
	"ice": [["crystal_08", false], ["crystal_11", false], ["crystal_13", false], ["crystal_19", false], ["crystal_23", false]],
	"fire": [["campfire_pit", true, 0.5, 0.3], ["pot_large", true, 0.5, 0.7], ["campfire_stones", true, 0.45, 0.2],
		["campfire_bricks", true, 0.35, 0.2], ["rock_tall_e", true, 0.45, 0.95]],
	"astral": [["statue_obelisk", false], ["statue_ring", false], ["crystal_20", false], ["statue_column", false]],
	"darkness": [["statue_column_damaged", false], ["statue_head", false], ["mushroom_laetiporus", false], ["stone_tall_g", false]],
	"iron": [["rock_tall_a", true], ["statue_block", false], ["rock_medium_3", true], ["stone_tall_a", false]],
	"storm": [["stone_tall_a", false], ["crystal_24", false], ["statue_obelisk", false], ["crystal_18", false]],
}

var yid := ""              ## Tower-ID aus YouTD 2
var yt: Dictionary = {}    ## Werte aus towers.json
var xp := 0.0
var level := 0
var items: Array = []      ## eingelegte Item-IDs (höchstens slots())
var oils: Array = []       ## verbrauchte Öle (wirken dauerhaft)
var mods := {}             ## alle Modifikatoren zusammengezählt (_update_mods)
var spent := 0             ## Gold, das in diesen Tower geflossen ist (Verkaufswert)


## Tower aus YouTD setzen (Bauen und Aufwerten). Erfahrung, Items und Öle bleiben beim Aufwerten erhalten.
func set_youtd(id: String) -> void:
	yid = id
	yt = YoutdData.tower(id)
	set_tower(PREFIX + id, maxi(int(yt.get("tier", 1)) - 1, 0))


func set_tower(id: String, t: int) -> void:
	tower_id = id
	tier = t
	var el := str(yt.get("element", ""))
	color = YoutdData.element_color(el)
	def = _look()
	def["name"] = str(yt.get("name", id))
	def["color"] = "#" + color.to_html(false)
	def["category"] = "special"
	_update_mods()
	place_at(cell)
	_build_visual()


func _look() -> Dictionary:
	var list: Array = LOOKS.get(str(yt.get("element", "")), [])
	if list.is_empty():
		return {}
	var l: Array = list[int(yt.get("family", 0)) % list.size()]
	var path: String = (C if str(l[0]).begins_with("crystal") else N) % l[0]
	var d := {"model": path, "model_tint": not bool(l[1]), "model_solid": bool(l[1])}
	if l.size() > 2:
		d["flame"] = l[2]
		d["flame_height"] = l[3]
	return d


## Werte für FxData und Sfx (Schuss- und Treffereffekte nach Elementfarbe).
static func fx_def(id: String) -> Dictionary:
	var t := YoutdData.tower(id.trim_prefix(PREFIX))
	if t.is_empty():
		return {}
	return {"color": "#" + YoutdData.element_color(str(t.get("element", ""))).to_html(false)}


func label() -> String:
	return str(yt.get("name", tower_id))


# --- Werte ---------------------------------------------------------------------

## Alle Modifikatoren neu zusammenzählen: Tower (Wert + Zuwachs × Level), Items und Öle (ebenso), Weisheit.
func _update_mods() -> void:
	mods = {}
	for m in yt.get("mods", []):
		_add_mod(str(m[0]), float(m[1]) + float(m[2]) * level)
	for id in items + oils:
		for m in YoutdData.item(str(id)).get("mods", []):
			_add_mod(str(m[0]), float(m[1]) + float(m[2]) * level)
	if game != null and "wisdom_mods" in game:
		var wm: Dictionary = game.wisdom_mods
		for k in wm:
			_add_mod(k, float(wm[k]))
	stats = {
		"range": range_cells(),
		"cooldown": float(yt.get("cooldown", 1.0)),
		"damage": yt.get("damage", [0, 0]),
		"targets": str(yt.get("targets", "both")),
		"damage_type": str(yt.get("attack_type", "")),
		"abilities": [],
	}
	if int(yt.get("multishot", 0)) > 1:
		stats.abilities.append({"type": "multishot", "targets": int(yt.multishot)})
	if not bool(yt.get("attack", true)):
		stats.cooldown = 0.0


func _add_mod(k: String, v: float) -> void:
	mods[k] = float(mods.get(k, 0.0)) + v


func mod(k: String) -> float:
	return float(mods.get(k, 0.0))


func range_cells() -> float:
	var u: Dictionary = YoutdData.rules().get("units", {})
	var bonus := float(game.range_bonus) if game != null and "range_bonus" in game else 0.0
	return YoutdData.units(float(yt.get("range", 800)) + float(u.get("range_bonus", 72)) + bonus)


func can_attack() -> bool:
	return bool(yt.get("attack", true)) and float(yt.get("cooldown", 0)) > 0.0


func damage_type() -> String:
	return str(yt.get("attack_type", ""))


func target_mode() -> String:
	return str(yt.get("targets", "both"))


func kill_bonus() -> float:
	return 0.0


## Abklingzeit mit Angriffstempo (Mods + 1 % je Level), begrenzt wie im Original.
func cooldown() -> float:
	var c: Dictionary = YoutdData.rules().get("combat", {})
	var speed := clampf(1.0 + mod("MOD_ATTACKSPEED") + float(c.get("level_attackspeed", 0.01)) * level,
			float(c.get("attackspeed_min", 0.2)), float(c.get("attackspeed_max", 5.0)))
	return maxf(float(yt.get("cooldown", 1.0)) / speed, float(c.get("cooldown_min", 0.2)))


## Schaden eines Angriffs vor Krit und Rüstung: (Grund × (1 + Grund-% + 4 % je Level) + Grund-Plus) × (1 + Plus-%)
## + Schaden pro Sekunde × Abklingzeit.
func base_damage_range() -> Array:
	var c: Dictionary = YoutdData.rules().get("combat", {})
	var dmg: Array = yt.get("damage", [0, 0])
	var base_perc := 1.0 + mod("MOD_DAMAGE_BASE_PERC") + float(c.get("level_damage", 0.04)) * level
	var add_perc := 1.0 + mod("MOD_DAMAGE_ADD_PERC")
	var out := []
	for d in dmg:
		out.append(maxf(0.0, ((float(d) * base_perc + mod("MOD_DAMAGE_BASE")) * add_perc + mod("MOD_DAMAGE_ADD") + mod("MOD_DPS_ADD") * cooldown())))
	return out


func crit_chance() -> float:
	var c: Dictionary = YoutdData.rules().get("combat", {})
	return minf(float(c.get("crit_chance", 0.0125)) + float(c.get("level_crit_chance", 0.0015)) * level + mod("MOD_ATK_CRIT_CHANCE"),
			float(c.get("crit_cap", 0.8)))


func crit_damage() -> float:
	var c: Dictionary = YoutdData.rules().get("combat", {})
	return float(c.get("crit_damage", 1.25)) + float(c.get("level_crit_damage", 0.02)) * level + mod("MOD_ATK_CRIT_DAMAGE")


## Faktor gegen diesen Gegner aus MOD_DMG_TO_<Größe/Rasse> (und Challenges, Gesamtschaden).
func target_factor(e) -> float:
	var f := 1.0 + mod("MOD_DMG_TOTAL_MULTIPLIER")
	if not "creep_size" in e:
		return f
	var size: String = e.creep_size
	if size.begins_with("challenge"):
		f *= 1.0 + mod("MOD_DMG_TO_CHALLENGE")
		size = "mass" if size == "challenge_mass" else "boss"
	f *= 1.0 + mod("MOD_DMG_TO_" + size.to_upper())
	if e.race != "challenge":
		f *= 1.0 + mod("MOD_DMG_TO_" + str(e.race).to_upper())
	return f


func _roll_damage() -> float:
	var r := base_damage_range()
	return randf_range(float(r[0]), float(r[1]))


# --- Angriff -----------------------------------------------------------------

func _attack(e) -> void:
	var dmg := _roll_damage()
	# Krit, dazu Mehrfach-Krits (jeder weitere mit 80 % der vorigen Chance), jeder addiert (Krit-Schaden − 1)
	var chance := crit_chance()
	var extra := 0.0
	var crits := 1 + int(mod("MOD_MULTICRIT_COUNT"))
	var falloff := float(YoutdData.rules().get("combat", {}).get("multicrit_falloff", 0.8))
	for i in crits:
		if randf() >= chance:
			break
		extra += crit_damage() - 1.0
		chance *= falloff
	dmg *= 1.0 + extra
	game.add_beam(position + Vector3(0, 0.9, 0), _hit_point(e), color, fx_key())
	var at: Vector2 = e.pos
	_hit(e, dmg)
	# Flächenschaden: Ringe [Radius, Anteil], der innerste passende gilt
	var splash: Array = yt.get("splash", [])
	if not splash.is_empty():
		for other in game.enemies_in_radius(at, YoutdData.units(float(splash[-1][0]))):
			if other == e or not can_target(other):
				continue
			var d: float = other.pos.distance_to(at)
			for ring in splash:
				if d <= YoutdData.units(float(ring[0])):
					_hit(other, dmg * float(ring[1]))
					break
	# Abpraller: [Anzahl Ziele, Abnahme je Sprung], Sprungweite 340
	var bounce: Array = yt.get("bounce", [])
	if bounce.size() >= 1 and int(bounce[0]) > 1:
		var hit := [e]
		var current = e
		var bdmg := dmg
		for i in int(bounce[0]) - 1:
			bdmg *= 1.0 - (float(bounce[1]) if bounce.size() > 1 else 0.0)
			var next = null
			var best := INF
			for other in game.enemies_in_radius(current.pos, YoutdData.units(340.0)):
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


func _hit(e, dmg: float) -> void:
	if e.dead:
		return
	e.last_hit_by = owner_player
	if "last_tower" in e:
		e.last_tower = self
	total_damage += e.take_damage(dmg * target_factor(e), damage_type())
	if e.dead:
		kills += 1


# --- Erfahrung -------------------------------------------------------------------

## Erfahrung dazu; Level nach der Tabelle, begrenzt auf das höchste Tower-Level des Spielers.
func add_exp(amount: float) -> void:
	if amount <= 0.0:
		return
	xp += amount * maxf(0.0, 1.0 + mod("MOD_EXP_RECEIVED"))
	var cap := int(game.max_tower_level()) if game != null and game.has_method("max_tower_level") else 25
	var l := YoutdData.level_at(YoutdData.tower_exp_table(), xp, cap)
	if l != level:
		level = l
		_update_mods()


## Item-Plätze dieses Towers.
func slots() -> int:
	return YoutdData.item_slots(yid)


# --- Darstellung -------------------------------------------------------------

## Kein Drehen: Bäume und Statuen stehen, jeder Tower leicht anders ausgerichtet.
func _animate(delta: float) -> void:
	_time += delta
	if _gem and _gem.rotation.y == 0.0:
		_gem.rotation.y = float(hash(cell)) / float(1 << 31) * TAU
	if _new_ring:
		_new_ring.visible = false


## Werte fürs Infofenster (Aufbau wie TowerStats.view).
func view() -> Dictionary:
	var tiles := []
	var r := range_cells()
	tiles.append({"key": "range", "caption": tr("Reichweite"), "value": TowerStats.num(r), "mod": false,
			"rows": [[tr("Grundwert"), str(int(yt.get("range", 0))), ""]], "total": []})
	if can_attack():
		var srows := [[tr("Grundwert"), TowerStats.num(float(yt.get("cooldown", 1.0)), 2) + " s", ""]]
		if mod("MOD_ATTACKSPEED") != 0.0:
			srows.append([tr("Items und Boni"), TowerStats.pct(mod("MOD_ATTACKSPEED")), "up"])
		if level > 0:
			srows.append([tr("Level %d") % level, TowerStats.pct(0.01 * level), "up"])
		tiles.append({"key": "speed", "caption": tr("Tempo"), "value": TowerStats.num(cooldown(), 2) + " s",
				"mod": srows.size() > 1, "rows": srows, "total": [tr("Gesamt"), TowerStats.num(cooldown(), 2) + " s"]})
		var dmg: Array = yt.get("damage", [0, 0])
		var now := base_damage_range()
		var drows := [[tr("Grundwert"), TowerStats.dmg_text(float(dmg[0]), float(dmg[1])), ""]]
		if level > 0:
			drows.append([tr("Level %d") % level, TowerStats.pct(0.04 * level), "up"])
		var extra := mod("MOD_DAMAGE_BASE_PERC") + mod("MOD_DAMAGE_ADD_PERC")
		if extra != 0.0:
			drows.append([tr("Items und Boni"), TowerStats.pct(extra), "up"])
		var total := TowerStats.dmg_text(float(now[0]), float(now[1]))
		tiles.append({"key": "damage", "caption": tr("Schaden"), "value": total, "mod": drows.size() > 1, "rows": drows,
				"total": [tr("Gesamt"), total]})
		tiles.append({"key": "type", "caption": tr("Angriff"), "value": YoutdData.attack_name(damage_type()), "mod": false,
				"rows": [], "total": []})
	var abilities := []
	abilities.append(tr("Kritisch: %s %% Chance, ×%s Schaden") % [TowerStats.num(crit_chance() * 100.0), TowerStats.num(crit_damage(), 2)])
	if int(yt.get("multishot", 0)) > 1:
		abilities.append(tr("Mehrfachschuss: %d Ziele") % int(yt.multishot))
	for ring in yt.get("splash", []):
		abilities.append(tr("Flächenschaden: %d %% im Umkreis %d") % [roundi(float(ring[1]) * 100), int(ring[0])])
	var bounce: Array = yt.get("bounce", [])
	if not bounce.is_empty():
		abilities.append(tr("Abpraller: %d Ziele, −%d %% je Sprung") % [int(bounce[0]), roundi(float(bounce[1]) * 100 if bounce.size() > 1 else 0.0)])
	for k in mods:
		if k.begins_with("MOD_DMG_TO_") and absf(float(mods[k])) > 0.0001:
			abilities.append(tr("%s Schaden gegen %s") % [TowerStats.pct(float(mods[k])), YoutdData.target_name(k.trim_prefix("MOD_DMG_TO_"))])
	if yt.has("script"):
		abilities.append(tr("Eigene Fähigkeit kommt in Etappe 2"))
	var kills_info := {"kills": kills, "rank": level, "bonus": 0.0, "per_rank": 1, "step": 0.0, "max": 0.0, "maxed": true,
			"next_at": 0, "missing": 0, "next_bonus": 0.0, "progress": 0, "total_damage": total_damage}
	return {"subtitle": "%s · %s · %s" % [YoutdData.element_name(str(yt.get("element", ""))), YoutdData.rarity_name(str(yt.get("rarity", ""))),
			TowerStats.targets_text(target_mode())], "tiles": tiles, "kills": kills_info, "abilities": abilities, "description": ""}
