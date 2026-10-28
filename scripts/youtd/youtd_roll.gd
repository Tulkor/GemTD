class_name YoutdRoll
extends RefCounted
## Würfeln wie in YouTD 2 (tower_distribution.gd, item_drop_calc.gd; Werte unter "roll" und "items" in rules.json):
## Tower nach Wellen und beim Startwurf aus den erforschten Elementen, Items beim Kill.
## Alle Zufallszahlen kommen aus game.roll_rng, damit ein Seed dieselben Würfe ergibt.

const RARITIES := ["common", "uncommon", "rare", "unique"]

static var _groups := {}   ## "all"/"first" -> Element -> Seltenheit -> [IDs nach Kosten]


static func _group(first_tier_only: bool, el: String, rarity: String) -> Array:
	var key := "first" if first_tier_only else "all"
	if not _groups.has(key):
		var g := {}
		var all := YoutdData.towers()
		var ids := all.keys()
		ids.sort_custom(func(a, b): return int(all[a].cost) < int(all[b].cost))
		for id in ids:
			var t: Dictionary = all[id]
			if first_tier_only and int(t.tier) > 1:
				continue
			var e := str(t.element)
			if not g.has(e):
				g[e] = {}
			if not g[e].has(str(t.rarity)):
				g[e][str(t.rarity)] = []
			g[e][str(t.rarity)].append(id)
		_groups[key] = g
	return _groups[key].get(el, {}).get(rarity, [])


static func _mode(game) -> Dictionary:
	return (game.rules.get("modes", []) as Array)[game.mode_index]


## Chance je Element und Welle: 7,5 % (Zufall mit Aufwertungen) bzw. 10 % (komplett zufällig) je Elementstufe.
static func element_chance(game, el: String) -> float:
	return float(_mode(game).get("element_chance", 0.0)) * int(game.elements.get(el, 0))


static func _possible(game) -> Array:
	var list := []
	for el in YoutdData.elements():
		if element_chance(game, el) > 0.0:
			list.append(el)
	return list


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp


## Nach jeder Welle: jedes Element einmal mit seiner Chance; kam nichts, wird ein Tower erzwungen.
static func per_wave(game) -> Array:
	var rng: RandomNumberGenerator = game.roll_rng
	var list := _possible(game)
	if list.is_empty():
		return []
	_shuffle(list, rng)
	var out := []
	for el in list:
		var chance := clampf(element_chance(game, el), 0.0, 1.0)
		var id := _tower_for_element(game, el, chance)
		if id != "":
			out.append(id)
	if out.is_empty():
		out = with_count(game, 1)
	return out


## Genau n Tower (Startwurf): reihum über die Elemente würfeln, bis genug da sind.
static func with_count(game, n: int) -> Array:
	var rng: RandomNumberGenerator = game.roll_rng
	var list := _possible(game)
	if list.is_empty() or n <= 0:
		return []
	_shuffle(list, rng)
	var out := []
	for tries in 1000:
		var el: String = list.pop_front()
		list.push_back(el)
		var id := _tower_for_element(game, el, element_chance(game, el))
		if id != "":
			out.append(id)
			if out.size() >= n:
				break
	return out


static func _tower_for_element(game, el: String, chance: float) -> String:
	var rng: RandomNumberGenerator = game.roll_rng
	if rng.randf() >= chance:
		return ""
	var r: Dictionary = game.rules.get("roll", {})
	var lvl := int(game.elements.get(el, 0))
	var wave := int(game.current_wave())
	var max_cost := floorf(70.0 + wave * (5.0 + wave * 0.6))
	max_cost *= float(r.get("element_cost_base", 0.75)) + float(r.get("element_cost_add", 0.03)) * lvl
	max_cost = floorf(max_cost * rng.randf_range(1.0, 1.1))
	# Seltenheit nach Elementstufe; zu teure Seltenheiten fallen weg
	var weights := {}
	for rarity in RARITIES:
		if float(r.get("rarity_cost_threshold", {}).get(rarity, 0)) > max_cost:
			continue
		weights[rarity] = clampf(float(r.get("rarity_base", {}).get(rarity, 0.0)) + float(r.get("rarity_add", {}).get(rarity, 0.0)) * lvl, 0.0, 1.0)
	var rarity := str(YoutdWaves.weighted(weights, rng))
	if rarity == "" or rarity == "<null>":
		rarity = "common"
	max_cost *= float(r.get("rarity_cost_factor", {}).get(rarity, 1.0))
	var m := _mode(game)
	var first := bool(m.get("first_tier_only", true))
	var power := float(m.get("weight_power", 0.25))
	var ri := RARITIES.find(rarity)
	var group := []
	while true:
		group = _group(first, el, RARITIES[ri]).filter(func(id): return float(YoutdData.tower(id).cost) < max_cost)
		if not group.is_empty() or ri == 0:
			break
		ri -= 1
	if group.is_empty():
		return ""
	# teurere Tower etwas öfter (Gewicht = Kosten ^ Potenz)
	var gw := {}
	for id in group:
		gw[id] = pow(float(YoutdData.tower(id).cost), power)
	return str(YoutdWaves.weighted(gw, rng))


## Item beim Kill (YtItemDropCalc): Seltenheit nach Gewichten × Qualität, 40 % Öl oder Verbrauchsgegenstand, sonst
## reguläres Item bis zur Welle. "" = nichts passendes.
static func item(game, level: int, quality: float) -> String:
	var id := YtItemDropCalc.calculate_item_drop(level, quality, game.roll_rng)
	return str(id) if id != 0 else ""
