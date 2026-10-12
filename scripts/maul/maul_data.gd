class_name MaulData
extends RefCounted
## Daten von Shopping Maul (data/maul/): Karte, Filialen mit Towern, Level, Regeln.
## map.json, shops.json und waves.json erzeugt tools/wc3/maul_daten.py aus der Kartendatei 5.44f,
## rules.json ist von Hand gepflegt.

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


static func shops() -> Array:
	return _load("shops").get("shops", [])


static func shop(id: String) -> Dictionary:
	for s in shops():
		if s.id == id:
			return s
	return {}


## Alle Tower aller Filialen nach ID.
static func towers() -> Dictionary:
	if not _cache.has("_towers"):
		var all := {}
		for s in shops():
			for t in s.towers:
				var d: Dictionary = t.duplicate()
				d["shop"] = s.id
				d["color"] = s.color
				all[t.id] = d
		_cache["_towers"] = all
	return _cache["_towers"]


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
