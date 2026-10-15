class_name MaulData
extends RefCounted
## Daten von Shopping Maul (data/maul/): Karte, Filialen mit Towern, Level, Regeln.
## map.json, shops.json und waves.json erzeugt tools/wc3/maul_daten.py aus der Kartendatei 5.44f,
## rules.json und pro.json (XP, Hauptgebäude, Profi-Filialen, Items, Korrekturen an Towern) sind von Hand gepflegt.

const DIR := "res://data/maul/"

static var _cache := {}


static func _load(name: String) -> Dictionary:
	if not _cache.has(name):
		var d = Database.load_json(DIR + name + ".json")
		_cache[name] = d if typeof(d) == TYPE_DICTIONARY else {}
	return _cache[name]


static func rules() -> Dictionary:
	return _load("rules")


static func map_dict() -> Dictionary:
	return _load("map")


static func levels() -> Array:
	return _load("waves").get("levels", [])


static func pro() -> Dictionary:
	return _load("pro")


static func shops() -> Array:
	return _load("shops").get("shops", [])


## XP- und Ultimate-Tower, die jede Filiale zusätzlich bauen kann (Filiale "xpert").
static func xpert() -> Dictionary:
	return _load("shops").get("xpert", {})


static func shop(id: String) -> Dictionary:
	if id == "xpert":
		return xpert()
	for s in shops():
		if s.id == id:
			return s
	return {}


## Alle Tower aller Filialen (und des XPert) nach ID, mit den Korrekturen aus pro.json.
static func towers() -> Dictionary:
	if not _cache.has("_towers"):
		var all := {}
		var fix: Dictionary = pro().get("overrides", {})
		for s in shops() + ([xpert()] if not xpert().is_empty() else []):
			for t in s.towers:
				var d: Dictionary = t.duplicate(true)
				d["shop"] = s.id
				d["color"] = s.color
				d.merge(fix.get(t.id, {}), true)
				all[t.id] = d
		_cache["_towers"] = all
	return _cache["_towers"]


static func item(id: String) -> Dictionary:
	return pro().get("items", {}).get(id, {})


static func unit(id: String) -> Dictionary:
	return pro().get("units", {}).get(id, {})


## Name eines Items oder einer Einheit in der eingestellten Sprache (pro.json: name, name_en).
static func name_of(d: Dictionary, fallback := "") -> String:
	if Loc.language == "en" and d.has("name_en"):
		return str(d.name_en)
	return str(d.get("name", fallback))


static func item_name(id: String) -> String:
	return name_of(item(id), id)


## Kosten der Bonus-/Rabatt-Stufe n für m Spieler: n · ⌊√n⌋ · Grundpreis / m.
static func bonus_cost(n: int, rebate: bool, m: int) -> int:
	var b: Dictionary = pro().get("bonus", {})
	var base := int(b.get("rebate_cost" if rebate else "damage_cost", 500))
	return n * floori(sqrt(n)) * base / maxi(m, 1)


static func tower(id: String) -> Dictionary:
	return towers().get(id, {})


## Tower, die man im Laden der Filiale kauft (ohne Upgrades), nach Preis.
static func buyable(shop_id: String) -> Array:
	var s := shop(shop_id)
	var list: Array = s.get("towers", []).filter(func(t): return t.upgrade_from == null)
	list.sort_custom(func(a, b): return int(a.cost) < int(b.cost))
	return list


static func difficulty(i: int) -> Dictionary:
	var list: Array = rules().get("difficulties", [])
	return list[clampi(i, 0, list.size() - 1)] if not list.is_empty() else {}


static func damage_factor(damage_type: String, armor_type: String) -> float:
	var t: Dictionary = rules().get("damage_table", {})
	return float(t.get(damage_type, {}).get(armor_type, 1.0))
