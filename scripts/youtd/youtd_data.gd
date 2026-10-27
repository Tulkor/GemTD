class_name YoutdData
extends RefCounted
## Daten von YouTD (data/youtd/): Regeln von Hand (rules.json), Tower, Items, Wellen-Eigenschaften und
## Erfahrungstabellen erzeugt tools/youtd/youtd_daten.py aus YouTD 2 (MIT). Einmal geladen, dann gemerkt.
## Tower-IDs und Item-IDs sind die Nummern aus YouTD 2 als String.

const DIR := "res://data/youtd/"

static var _cache := {}


static func _file(name: String) -> Variant:
	if not _cache.has(name):
		var d = Database.load_json(DIR + name + ".json")
		_cache[name] = d if d != null else {}
	return _cache[name]


static func rules() -> Dictionary:
	return _file("rules")


static func towers() -> Dictionary:
	return _file("towers")


static func items() -> Dictionary:
	return _file("items")


static func specials() -> Dictionary:
	return _file("specials")


static func builders() -> Array:
	var b = _file("builders")
	return b if typeof(b) == TYPE_ARRAY else []


## Rezepte des Horadrischen Würfels (youtd_cube.gd).
static func recipes() -> Array:
	var r = _file("recipes")
	return r if r is Array else []


static func tower(id: String) -> Dictionary:
	return towers().get(id, {})


static func item(id: String) -> Dictionary:
	return items().get(id, {})


# --- Umrechnung ------------------------------------------------------------------

## WC3-Einheiten → Towerbreiten (128 = 1).
static func units(wc3: float) -> float:
	return wc3 / float(rules().get("units", {}).get("wc3_per_tower", 128))


# --- Elemente und Seltenheit -------------------------------------------------------

static func elements() -> Array:
	return rules().get("elements", {}).get("order", [])


static func element_name(el: String) -> String:
	return str(TranslationServer.translate(str(rules().get("elements", {}).get("names", {}).get(el, el))))


static func element_color(el: String) -> Color:
	return Color.from_string(str(rules().get("elements", {}).get("colors", {}).get(el, "#cccccc")), Color.GRAY)


static func rarity_name(r: String) -> String:
	return str(TranslationServer.translate(str(rules().get("rarities", {}).get("names", {}).get(r, r))))


static func rarity_color(r: String) -> Color:
	return Color.from_string(str(rules().get("rarities", {}).get("colors", {}).get(r, "#cccccc")), Color.GRAY)


static func rarity_index(r: String) -> int:
	return maxi(0, (rules().get("rarities", {}).get("order", []) as Array).find(r))


static func attack_name(a: String) -> String:
	return str(TranslationServer.translate(str(rules().get("attack_names", {}).get(a, a))))


static func armor_name(a: String) -> String:
	return str(TranslationServer.translate(str(rules().get("armor_names", {}).get(a, a))))


static func size_name(s: String) -> String:
	return str(TranslationServer.translate(str(rules().get("size_names", {}).get(s, s))))


static func race_name(r: String) -> String:
	return str(TranslationServer.translate(str(rules().get("race_names", {}).get(r, r))))


## "MASS", "UNDEAD" … aus MOD_DMG_TO_<X> als Name.
static func target_name(key: String) -> String:
	var k := key.to_lower()
	if rules().get("size_names", {}).has(k):
		return size_name(k)
	if rules().get("race_names", {}).has(k):
		return race_name(k)
	return k


static func special_name(id: String) -> String:
	var en := str(specials().get(id, {}).get("name", id))
	return str(TranslationServer.translate(str(rules().get("special_names", {}).get(en, en))))


## Was eine Wellen-Eigenschaft im Spiel bewirkt ({} = noch ohne Wirkung, nur ihr HP-Faktor gilt).
static func special_effect(id: String) -> Dictionary:
	var en := str(specials().get(id, {}).get("name", ""))
	return rules().get("special_effects", {}).get(en, {})


static func damage_factor(attack: String, armor: String) -> float:
	return float(rules().get("damage_table", {}).get(attack, {}).get(armor, 1.0))


# --- Tower ---------------------------------------------------------------------

## Tower der nächsten Stufe derselben Familie ("" = keine).
static func upgrade_of(id: String) -> String:
	var t := tower(id)
	if t.is_empty():
		return ""
	for other in towers():
		var o: Dictionary = towers()[other]
		if int(o.family) == int(t.family) and int(o.tier) == int(t.tier) + 1:
			return other
	return ""


## Elementstufe, die ein Tower verlangt (nach Kosten, wie TowerProperties.get_required_element_level).
static func required_element_level(id: String) -> int:
	var cost := int(tower(id).get("cost", 0))
	var table: Dictionary = rules().get("elements", {}).get("cost_for_level", {})
	var level := 1
	for l in range(1, 16):
		if cost >= int(table.get(str(l), 1 << 30)):
			level = l
	return level


## Mindestwelle eines Towers (nur im Baumodus mit Untergrenze je Seltenheit).
static func required_wave(id: String, build_mode: bool) -> int:
	var t := tower(id)
	var cost := float(t.get("cost", 0))
	var wave := ceili((sqrt(maxf(0.01, 60.0 * cost - 3575.0)) - 25.0) / 6.0)
	var low := 0
	if build_mode:
		low = int(rules().get("rarities", {}).get("min_wave_build_mode", {}).get(str(t.get("rarity", "common")), 0))
	return clampi(wave, low, int(rules().get("required_wave_max", 80)))


static func food_cost(id: String) -> int:
	return int(rules().get("rarities", {}).get("food", {}).get(str(tower(id).get("rarity", "common")), 2))


static func tome_cost(id: String, build_mode: bool) -> int:
	if not build_mode:
		return 0
	return int(rules().get("rarities", {}).get("tomes_build_mode", {}).get(str(tower(id).get("rarity", "common")), 0))


## Item-Plätze nach Kosten und Seltenheit (TowerProperties.get_inventory_capacity).
static func item_slots(id: String) -> int:
	var t := tower(id)
	var r: Dictionary = rules().get("rarities", {})
	var rarity := str(t.get("rarity", "common"))
	var lo := int(r.get("item_slots_min", {}).get(rarity, 1))
	var hi := int(r.get("item_slots_max", {}).get(rarity, 4))
	var cost := int(t.get("cost", 0))
	for step in rules().get("item_slots_cost", []):
		if int(step[0]) <= hi and cost >= int(step[1]):
			return clampi(int(step[0]), lo, hi)
	return lo


# --- Erfahrung -------------------------------------------------------------------

static func tower_exp_table() -> Array:
	return _file("xp").get("tower", [0])


static func player_exp_table() -> Array:
	return _file("xp").get("player", [0])


## Level zu einer Erfahrung in einer Tabelle (höchstes Level, dessen Schwelle erreicht ist).
static func level_at(table: Array, value: float, cap := 1 << 30) -> int:
	var level := 0
	for i in table.size():
		if value >= float(table[i]):
			level = i
		else:
			break
	return mini(level, cap)


## Spielerlevel aus Spieler-XP.
static func player_level(value: float) -> int:
	return level_at(player_exp_table(), value, int(rules().get("player", {}).get("max_level", 300)))
