class_name YoutdCube
extends RefCounted
## Horadrischer Würfel (nach horadric_cube.gd aus YouTD 2, MIT): aus Items im Lager neue machen. Rezepte in
## data/youtd/recipes.json: wie viele normale (permanent) und Öle/Verbrauchsgegenstände (usable) gleicher Seltenheit
## hineinkommen, was herauskommt (Art, Anzahl, Seltenheit ±) und in welchem Levelbereich (Mittel der Zutaten + Bonus,
## dazu Glück −9/0/+7/+18). Drei Rezepte gibt es nur mit dem Baumeister Backpacker.

const RARITIES := ["common", "uncommon", "rare", "unique"]
const LUCK := {-9: 20, 0: 50, 7: 20, 18: 10}


static func recipes() -> Array:
	return YoutdData.recipes()


static func recipe(id: String) -> Dictionary:
	for r in recipes():
		if str(r.id) == id:
			return r
	return {}


static func unlocked(r: Dictionary, player: YtPlayer) -> bool:
	return not bool(r.get("backpacker", false)) or player.get_builder().get_adds_extra_recipes()


static func _rarity(it: YtItem) -> int:
	return RARITIES.find(str(YoutdData.item(str(it.get_id())).get("rarity", "common")))


## Zutaten für Rezept r aus list (niedrigste Seltenheit und Stufe zuerst, gesperrte nicht). [] = reicht nicht.
static func autofill(r: Dictionary, list: Array) -> Array:
	for rarity in RARITIES.size():
		var out := autofill_rarity(r, list, rarity)
		if not out.is_empty():
			return out
	return []


## Freie Zutaten einer Seltenheit im Lager: [normale Items, Öle/Verbrauch] (gesperrte zählen nicht).
static func count(list: Array, rarity: int) -> Array:
	var pool := list.filter(func(it): return _rarity(it) == rarity and not it.get_horadric_lock_is_enabled())
	return [pool.filter(func(it): return it.get_type_name() == "regular").size(),
			pool.filter(func(it): return ["oil", "consumable"].has(it.get_type_name())).size()]


static func autofill_rarity(r: Dictionary, list: Array, rarity: int) -> Array:
	var result_rarity: int = rarity + int(r.get("rarity_change", 0))
	if result_rarity < 0 or result_rarity >= RARITIES.size():
		return []
	var pool := list.filter(func(it): return _rarity(it) == rarity and not it.get_horadric_lock_is_enabled())
	pool.sort_custom(func(a, b): return a.get_required_wave_level() < b.get_required_wave_level())
	var out := []
	for part in [[["regular"], int(r.get("permanent", 0))], [["oil", "consumable"], int(r.get("usable", 0))]]:
		var sub := pool.filter(func(it): return (part[0] as Array).has(it.get_type_name()))
		if sub.size() < int(part[1]):
			return []
		out.append_array(sub.slice(0, int(part[1])))
	return out


## Rezept, zu dem genau diese Items passen ({} = keins).
static func current_recipe(player: YtPlayer, list: Array) -> Dictionary:
	if list.is_empty():
		return {}
	var ids := list.map(func(it): return it.get_id())
	for r in recipes():
		if not unlocked(r, player):
			continue
		var auto := autofill(r, list)
		if auto.map(func(it): return it.get_id()) == ids:
			return r
	return {}


## Ergebnis-IDs für Rezept r aus den Zutaten list. luck: Level-Bonus durch Glück (zurückgegeben unter "luck").
static func results(r: Dictionary, list: Array, rng: RandomNumberGenerator) -> Dictionary:
	var rarity: int = clampi((_rarity(list[0]) if not list.is_empty() else 0) + int(r.get("rarity_change", 0)), 0, 3)
	var luck: int = YtUtils.random_weighted_pick(rng, LUCK)
	var avg := _average_level(list)
	var lvl_min: int = avg + int(r.get("level_min", 0)) + luck
	var lvl_max: int = avg + int(r.get("level_max", 0)) + luck
	var ingredients := list.map(func(it): return it.get_id())
	if str(r.id) == "precipitate":
		lvl_min = 0
		lvl_max = 100000
	var out := []
	for i in int(r.get("count", 1)):
		if str(r.get("result", "")) == "usable":
			var pool := YtItemDropCalc.get_oil_and_consumables_list(rarity).filter(func(id): return not ingredients.has(id))
			if not pool.is_empty():
				out.append(YtUtils.pick_random(rng, pool))
		else:
			out.append(_transmuted_item(ingredients, rarity, lvl_min, lvl_max, rng))
	var lucky: bool = str(r.get("result", "")) == "permanent" and str(r.id) != "precipitate"
	return {"items": out.filter(func(id): return int(id) != 0), "luck": luck if lucky else 0}


static func _transmuted_item(ingredients: Array, rarity: int, lvl_min: int, lvl_max: int, rng: RandomNumberGenerator) -> int:
	var lo := lvl_min
	for _i in 11:
		var pool := YtItemDropCalc.get_item_list_bounded(rarity, lo, lvl_max).filter(func(id): return not ingredients.has(id))
		if not pool.is_empty():
			return YtUtils.pick_random(rng, pool)
		lo -= 10
	return 0


## Mittleres Level der normalen Items unter den Zutaten (Öle zählen nicht).
static func _average_level(list: Array) -> int:
	var perm := list.filter(func(it): return it.get_type_name() == "regular")
	if perm.is_empty():
		return 0
	var sum := 0.0
	for it in perm:
		sum += it.get_required_wave_level()
	return floori(sum / perm.size())
