class_name YoutdEnemy
extends Enemy
## Gegner in YouTD: Größe (Masse, Normal, Luft, Champion, Boss, Challenge), Rasse, Rüstungstyp (Hel, Myt, Lua, Sol,
## Sif, Zod) und Eigenschaften der Welle (youtd_waves.gd). Schaden nach der Tabelle Angriffstyp gegen Rüstungstyp
## (rules.json → damage_table), Rüstung wie in WC3. damage_done zählt, wie viel Prozent er schon verloren hat:
## davon hängen Portalschaden und Punkte ab, wenn er durchkommt.

var level := 1               ## Welle, aus der er stammt
var creep_size := "normal"
var race := "orc"
var specials: Array = []     ## Eigenschaften, die für ihn gelten
var evasion := 0.0           ## Anteil der Angriffe, die ins Leere gehen (Zauber treffen immer)
var immune := false          ## Magieimmun: keine Zauber, kein Arkan-Schaden
var regen := 0.0             ## Anteil der Höchstleben pro Sekunde
var exp_factor := 1.0        ## Faktor auf die Erfahrung für den Tower, der ihn tötet
var bounty_factor := 1.0
var item_chance := 1.0
var item_quality := 1.0
var spell_received := 1.0
var last_tower = null       ## Tower, der zuletzt getroffen hat (bekommt Erfahrung, Kopfgeld und Items)


## w: Welle aus YoutdWaves, size: Größe dieses Gegners.
func setup_youtd(g, w: Dictionary, size_id: String, p: PackedVector2Array, hp_factor: float) -> void:
	level = int(w.level)
	creep_size = size_id
	race = str(w.race)
	var rules := YoutdData.rules()
	var sz: Dictionary = rules.get("sizes", {}).get(size_id, {})
	for id in w.get("specials", []):
		if YoutdWaves.special_applies(id, size_id):
			specials.append(id)
	var hp_value := float(w.hp) * float(sz.get("hp", 1.0)) * (1.0 + YoutdWaves.hp_modifier(specials)) * hp_factor
	var base_speed := float(rules.get("units", {}).get("move_speed", 222))
	var speed_mod := 0.0
	var armor_add := 0.0
	var armor_perc := 0.0
	for id in specials:
		var fx := YoutdData.special_effect(id)
		speed_mod += float(fx.get("speed", 0.0))
		armor_add += float(fx.get("armor", 0.0))
		armor_perc += float(fx.get("armor_perc", 0.0))
		evasion = maxf(evasion, float(fx.get("evasion", 0.0)))
		immune = immune or bool(fx.get("immune", false))
		spell_received += float(fx.get("spell", 0.0))
		exp_factor += float(fx.get("exp", 0.0))
		bounty_factor += float(fx.get("bounty", 0.0))
		item_chance += float(fx.get("item_chance", 0.0))
		item_quality += float(fx.get("item_quality", 0.0))
		var r = fx.get("regen", {})
		if r is Dictionary:
			regen = maxf(regen, float(r.get(size_id, 0.0)))
	var u: Dictionary = rules.get("units", {})
	var wc3_speed := clampf(base_speed * (1.0 + speed_mod), float(u.get("move_speed_min", 100)), float(u.get("move_speed_max", 522)))
	var boss_like := size_id == "boss" or size_id == "challenge_boss"
	var def := {
		"id": "youtd_" + size_id,
		"hp": hp_value,
		"speed": YoutdData.units(wc3_speed),
		"armor": float(w.armor) * (1.0 + armor_perc) + armor_add,
		"armor_type": str(w.armor_type),
		"bounty": float(sz.get("gold", 1)) * (int(level / 8) + 1),
		"damage": 0,
		"flying": size_id == "air",
		"boss": boss_like,
		"color": _race_color(race),
		"size": _visual_size(size_id),
	}
	if size_id == "mass" or size_id == "challenge_mass":
		def["shape"] = "pyramid"
	setup(g, def, {}, p)
	bounty *= maxf(bounty_factor, 0.0)
	spell_factor = maxf(spell_received, 0.0) * (0.0 if immune else 1.0)


static func _visual_size(size_id: String) -> float:
	match size_id:
		"mass":
			return 0.8
		"champion":
			return 1.35
		"boss":
			return 1.25
		"challenge_mass":
			return 1.0
		"challenge_boss":
			return 1.6
	return 1.0


static func _race_color(r: String) -> String:
	match r:
		"undead":
			return "#9fb0a8"
		"magic":
			return "#b48cff"
		"nature":
			return "#6fbf5a"
		"orc":
			return "#c9764a"
		"humanoid":
			return "#d9c29a"
		"challenge":
			return "#ffd040"
	return "#cccccc"


## Anteil der Leben, die er schon verloren hat (0..1).
func damage_done() -> float:
	return clampf(1.0 - hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0


## Angriff (attack_type aus rules.damage_table) oder Zauber ("spells"): Ausweichen nur bei Angriffen.
func take_damage(amount: float, damage_type := "") -> float:
	if damage_type == "spells":
		var f := float(YoutdData.rules().get("combat", {}).get("spell_damage_sif" if armor_type == "sif" else "spell_damage", 0.9))
		return take_raw_damage(amount * f * spell_factor)
	if evasion > 0.0 and randf() < evasion:
		return 0.0
	if damage_type == "arcane" and immune:
		return 0.0
	var factor := YoutdData.damage_factor(damage_type, armor_type)
	var a := effective_armor()
	var k := float(YoutdData.rules().get("combat", {}).get("armor_factor", 0.06))
	if a > 0.0:
		factor *= 1.0 - k * a / (1.0 + k * a)
	elif a < 0.0:
		factor *= 2.0 - pow(1.0 - k, -a)
	return take_raw_damage(amount * factor)


func _process(delta: float) -> void:
	if regen > 0.0 and not dead and not remote:
		hp = minf(max_hp, hp + max_hp * regen * delta)
	super._process(delta)


## Lebensbalken: Bosse und Champions immer, Masse nie, die anderen auf dem letzten Stück wie in GemTD.
func bar_visible() -> bool:
	if creep_size == "champion":
		return true
	return super.bar_visible()


## Name fürs Gegner-Fenster: „Champion · Ork“.
func display_name() -> String:
	return "%s · %s" % [YoutdData.size_name(creep_size), YoutdData.race_name(race)]
