class_name YtItemDropCalc
extends RefCounted
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Welches Item fällt (item_drop_calc.gd): Seltenheit nach Qualität, 40 % Öl oder Verbrauchsgegenstand (Seltenheit nach
## Gegnerwelle begrenzt), sonst ein normales Item bis zur Gegnerwelle. Werte unter "items" in data/youtd/rules.json.
## Ergebnis 0 = kein Item.

const RARITIES := ["common", "uncommon", "rare", "unique"]


static func _rules() -> Dictionary:
	return YoutdData.rules().get("items", {})


static func calculate_item_drop(creep_level: int, quality_multiplier: float, rng: RandomNumberGenerator = null) -> int:
	if rng == null:
		rng = YtGlobals.synced_rng
	var probs: Array = _rules().get("rarity_weights", [1000.0, 0.25, 0.06, 0.02])
	var rarity: int = 3
	var rarity_chance: float = rng.randf_range(0.0, 1.0)
	while true:
		rarity_chance = rarity_chance - float(probs[rarity]) * quality_multiplier
		if rarity_chance < 0.0 || rarity == 0:
			break
		rarity = rarity - 1

	if YtUtils.rand_chance(rng, float(_rules().get("oil_chance", 0.4))):
		var threshold: Array = _rules().get("oil_quality_wave", [0, 6, 18, 36])
		while rarity > 0 and creep_level < int(threshold[rarity]):
			rarity = rarity - 1
		return get_random_oil_or_consumable(rarity, rng)
	return get_random_item_at_or_below_rarity_bounded(rarity, 0, creep_level, rng)


static func get_random_oil_or_consumable(rarity: int, rng: RandomNumberGenerator = null) -> int:
	var list: Array = get_oil_and_consumables_list(rarity)
	if list.is_empty():
		return 0
	return YtUtils.pick_random(rng if rng != null else YtGlobals.synced_rng, list)


static func get_random_item_at_or_below_rarity_bounded(rarity: int, lvl_min: int, lvl_max: int, rng: RandomNumberGenerator = null) -> int:
	var random_item: int = get_random_item_at_rarity_bounded(rarity, lvl_min, lvl_max, rng)
	if random_item != 0:
		return random_item
	if rarity > 0:
		return get_random_item_at_rarity_bounded(rarity - 1, lvl_min, lvl_max, rng)
	return 0


# RandomItemSet.permanent.getRandomItemAtRarityBounded() in JASS
static func get_random_item_at_rarity_bounded(rarity: int, lvl_min: int, lvl_max: int, rng: RandomNumberGenerator = null) -> int:
	var list: Array[int] = get_item_list_bounded(rarity, lvl_min, lvl_max)
	if list.is_empty():
		return 0
	return YtUtils.pick_random(rng if rng != null else YtGlobals.synced_rng, list)


static func get_item_list_bounded(rarity: int, lvl_min: int, lvl_max: int) -> Array[int]:
	var out: Array[int] = []
	if rarity < 0 or rarity >= RARITIES.size():
		return out
	var all := YoutdData.items()
	for id in all:
		var it: Dictionary = all[id]
		var level := int(it.get("level", 0))
		if str(it.type) == "regular" and str(it.rarity) == RARITIES[rarity] and lvl_min <= level and level <= lvl_max:
			out.append(int(id))
	return out


static func get_oil_and_consumables_list(rarity: int) -> Array:
	var out: Array = []
	if rarity < 0 or rarity >= RARITIES.size():
		return out
	var all := YoutdData.items()
	for t in ["oil", "consumable"]:
		for id in all:
			if str(all[id].type) == t and str(all[id].rarity) == RARITIES[rarity]:
				out.append(int(id))
	return out
