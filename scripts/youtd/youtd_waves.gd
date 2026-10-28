class_name YoutdWaves
extends RefCounted
## Wellen von YouTD, gewürfelt wie in YouTD 2 (src/creeps/wave.gd, wave_special.gd): Größe, Rasse, Rüstungstyp,
## Champions, Leben und Rüstung nach den Formeln je Schwierigkeit, dazu bis zu zwei Eigenschaften (Specials).
## Eine Welle ist ein Dictionary:
##   {level, size, race, armor_type, hp (Grundleben ohne Größenfaktor), armor, specials: [id], creeps: [Größe …]}
## Die Reihenfolge in creeps ist die Spawn-Reihenfolge (Champions gleichmäßig verteilt).


## Welle level (1-basiert) würfeln. diff: Eintrag aus rules.difficulties, count: Wellen im Spiel (80/120/240).
static func generate(level: int, diff: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var w: Dictionary = YoutdData.rules().get("waves", {})
	var size := _size(level, w, rng)
	var challenge := size.begins_with("challenge")
	var race := "challenge" if challenge else str(_pick(w.get("races", ["orc"]), rng))
	var armor_type := _armor_type(level, challenge, w, rng)
	var creeps := _combination(level, size, w, rng)
	var specials := _specials(level, size, creeps.has("champion"), w, rng)
	if specials.has(_special_id("Flock")):
		creeps += creeps.duplicate()
	return {"level": level, "size": size, "race": race, "armor_type": armor_type, "creeps": creeps, "specials": specials,
			"hp": base_hp(level, diff, armor_type), "armor": base_armor(level, diff)}


## Grundleben einer Welle (Wave._calculate_base_hp): Polynom 6. Grades in j = level − 1, mal (0,9 − 0,002·level),
## in Bonuswellen (über 240) mit steil wachsendem Zuschlag, Sif-Rüstung × 0,48.
static func base_hp(level: int, diff: Dictionary, armor_type: String) -> float:
	var c: Array = diff.get("hp", [42, 33, 1.8, 0.021, 0.0005, 0.000011, 0.000000013])
	var j := float(level - 1)
	var hp: float = float(c[0]) + j * (float(c[1]) + j * (float(c[2]) + j * (float(c[3]) + j * (float(c[4]) + j * (float(c[5]) + j * float(c[6]))))))
	var extra := 0.9 - level * 0.002
	if level > 240:
		extra += pow(1.0001, pow((level - 240) / 2.0, 2.4)) - 1.0
	hp *= extra
	if armor_type == "sif":
		hp *= float(YoutdData.rules().get("waves", {}).get("sif_hp", 0.48))
	return hp


## Grundrüstung (Wave._calculate_base_armor), abgerundet wie im Original.
static func base_armor(level: int, diff: Dictionary) -> float:
	var c: Array = diff.get("armor", [4, 0.3, 0])
	var j := float(level - 1)
	return floorf(float(c[0]) + j * (float(c[1]) + j * float(c[2])))


static func _size(level: int, w: Dictionary, rng: RandomNumberGenerator) -> String:
	var every := int(w.get("challenge_every", 8))
	if level % every == 0:
		var m := level % 120
		if m % int(w.get("challenge_mass_every", 16)) == 0 and m != 0:
			return "challenge_mass"
		return "challenge_boss"
	return str(weighted(w.get("size_chances", {"normal": 1}), rng))


static func _armor_type(level: int, challenge: bool, w: Dictionary, rng: RandomNumberGenerator) -> String:
	if challenge:
		return "zod"
	if level >= int(w.get("sif_from_wave", 32)) and rng.randf() < float(w.get("sif_chance", 0.15)):
		return "sif"
	return str(_pick(w.get("armor_types", ["hel"]), rng))


## Gegner der Welle (Wave._generate_creep_combination): Kapazität 20 + Welle/40, verteilt nach Gewicht;
## Champions stehen in gleichen Abständen dazwischen.
static func _combination(level: int, size: String, w: Dictionary, rng: RandomNumberGenerator) -> Array:
	var sizes: Dictionary = YoutdData.rules().get("sizes", {})
	var capacity := int(w.get("capacity", 20)) + int(level / 40) * int(w.get("capacity_per_40", 1))
	var champions := _champion_count(level, size, w, rng)
	var champ_weight := int(sizes.get("champion", {}).get("weight", 4))
	var unit_weight := maxi(1, int(sizes.get(size, {}).get("weight", 2)))
	var total := 0
	var champ_ratio := -1.0
	var regular_ratio := -1.0
	if size == "challenge_boss":
		total = 1
	elif champions > 0:
		total = int((capacity - champions * champ_weight) / unit_weight) + champions
		champ_ratio = float(total) / champions
		regular_ratio = float(total) / champions / 2.0
	else:
		total = int(capacity / unit_weight)
	var out := []
	var so_far := 0
	for k in total:
		if int(regular_ratio + champ_ratio * so_far - 0.5) == k:
			out.append("champion")
			so_far += 1
		else:
			out.append(size)
	return out


static func _champion_count(level: int, size: String, w: Dictionary, rng: RandomNumberGenerator) -> int:
	if size.begins_with("challenge"):
		return 0
	var chances: Dictionary = w.get("champion_chances", {}).get(size, {})
	if chances.is_empty():
		return 0
	var n := int(str(weighted(chances, rng)))
	if n > 0:
		n += int(level / 120)
	return n


## Bis zu zwei Eigenschaften (WaveSpecial.get_random): die zweite nie aus einer Gruppe der ersten.
static func _specials(level: int, size: String, has_champions: bool, w: Dictionary, rng: RandomNumberGenerator) -> Array:
	if size.begins_with("challenge"):
		return []
	var all: Dictionary = YoutdData.specials()
	var first_list := []
	for id in all:
		var s: Dictionary = all[id]
		if not s.get("enabled", true) or level < int(s.get("level", 0)):
			continue
		var sizes: Array = s.get("sizes", [])
		if sizes.has("all"):
			sizes = w.get("special_sizes_all", ["mass", "normal", "air", "boss"])
		if not sizes.has(size):
			continue
		if s.get("champions_bosses_only", false) and not (has_champions or size == "boss"):
			continue
		first_list.append(id)
	var first := _special_pick(first_list, all, rng)
	var second_list := []
	if first != "":
		var blocked: Array = all[first].get("groups", [])
		for id in first_list:
			if id == first:
				continue
			var groups: Array = all[id].get("groups", [])
			if groups.any(func(g): return blocked.has(g)):
				continue
			second_list.append(id)
	var second := _special_pick(second_list, all, rng)
	var count := 0
	if level > int(w.get("specials_from_wave", 8)):
		var table: Dictionary = w.get("special_count_chances_bonus" if level > 240 else "special_count_chances", {"1": 1})
		count = int(str(weighted(table, rng)))
	var out := []
	for s in [first, second].slice(0, count):
		if s != "":
			out.append(s)
	return out


static func _special_pick(list: Array, all: Dictionary, rng: RandomNumberGenerator) -> String:
	if list.is_empty():
		return ""
	var weights := {}
	for id in list:
		weights[id] = float(all[id].get("frequency", 100))
	return str(weighted(weights, rng))


static func _special_id(name: String) -> String:
	var all: Dictionary = YoutdData.specials()
	for id in all:
		if str(all[id].get("name", "")) == name:
			return id
	return ""


## HP-Faktor der Eigenschaften (WaveSpecial._get_hp_modifier): eine allein zählt, bei zwei die kleinste plus
## die größte, wenn sie verschiedene Vorzeichen haben, sonst die extremere.
static func hp_modifier(specials: Array) -> float:
	if specials.is_empty():
		return 0.0
	var mods: Array = specials.map(func(id): return float(YoutdData.specials().get(id, {}).get("hp", 0.0)))
	mods.sort()
	if mods.size() == 1:
		return mods[0]
	var lo: float = mods.front()
	var hi: float = mods.back()
	if lo <= 0.0 and hi >= 0.0:
		return lo + hi
	if lo < 0.0 and hi < 0.0:
		return lo
	return hi


## Gilt eine Eigenschaft für diese Gegnergröße? Manche wirken nur auf Champions und Bosse der Welle.
static func special_applies(id: String, size: String) -> bool:
	if YoutdData.specials().get(id, {}).get("champions_bosses_only", false):
		return size == "boss" or size == "champion"
	return true


## Abstand bis zum nächsten Gegner (CreepSpawner.get_creep_delay): nach der Hauptgröße der Welle.
static func creep_delay(size: String, rng: RandomNumberGenerator) -> float:
	var d: Array = YoutdData.rules().get("sizes", {}).get(size, {}).get("delay", [1.0, 1.0])
	return rng.randf_range(float(d[0]), float(d[1]))


static func _pick(list: Array, rng: RandomNumberGenerator):
	return list[rng.randi() % list.size()]


## Zufall nach Gewichten {Schlüssel: Gewicht}.
static func weighted(weights: Dictionary, rng: RandomNumberGenerator):
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r < 0.0:
			return k
	return weights.keys().back()
