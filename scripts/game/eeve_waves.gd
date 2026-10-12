class_name EeveWaves
extends RefCounted
## Würfelt die Level eines eeveTD-Spiels aus (Regeln in data/eeve.json, Abschnitt Gegner und Wellen im
## Design-Dokument). Fest sind nur die Challenges, alles andere wird pro Spiel neu gewürfelt:
##   Level 1 Boden; Level 2–3 zu 25 % Luft; ab Level 4 zu 20 % Boss, 25 % Luft-Zweig, sonst Boden-Zweig,
##   in beiden Zweigen zu 35 % die Masse-Variante. Dazu ab Level 4 null bis zwei Eigenschaften.
## Leben je Gegner: HP(L) = (HP_Basis − (L_Ende − L) · k · f_Typ) · f_Schwierigkeit · f_Eigenschaften,
## k = 100 · Stufe² (Boden, Boss) bzw. (75 + 25 · Stufe) · Stufe (Luft), Stufe = abgerundet(L / 5,5) + 1.

const TYPE_LABELS := {"ground": "Boden", "ground_mass": "Masse", "air": "Flieger", "air_mass": "Masse", "boss": "Boss",
		"challenge": "Challenge"}


static func stage_of(level: int) -> int:
	return mini(floori(level / 5.5) + 1, 10)


## Letztes Level einer Gegnerstufe (5, 10, 16, 21 …).
static func stage_end(stage: int) -> int:
	return ceili(5.5 * stage) - 1


static func prop(rules: Dictionary, id: String) -> Dictionary:
	for p in rules.get("properties", []):
		if p.id == id:
			return p
	return {}


## Gegner-ID für Stufe und Wellentyp (data/enemies/eeve_*.json).
static func enemy_for(stage: int, kind: String) -> String:
	for id in Database.enemies:
		var e: Dictionary = Database.enemies[id].get("eeve", {})
		if int(e.get("stage", -1)) == stage and str(e.get("kind", "")) == kind:
			return id
	return ""


static func roll_kind(rules: Dictionary, level: int, r: RandomNumberGenerator) -> String:
	var wr: Dictionary = rules.get("wave_rules", {})
	if level <= 1:
		return "ground"
	if level <= 3:
		return "air" if r.randf() < float(wr.get("early_air", 0.25)) else "ground"
	var x := r.randf()
	var mass := r.randf() < float(wr.get("mass", 0.35))
	if x < float(wr.get("boss", 0.2)):
		return "boss"
	if x < float(wr.get("boss", 0.2)) + float(wr.get("air", 0.25)):
		return "air_mass" if mass else "air"
	return "ground_mass" if mass else "ground"


static func roll_props(rules: Dictionary, level: int, kind: String, r: RandomNumberGenerator) -> Array:
	if level < 4:
		return []
	var odds: Dictionary = rules.get("properties_odds", {})
	var x := r.randf()
	var n := 2 if x < float(odds.get("two", 0.18)) else (1 if x < float(odds.get("two", 0.18)) + float(odds.get("one", 0.47)) else 0)
	var pool := []
	for p in rules.get("properties", []):
		if not p.get("enabled", true) or level < int(p.get("from_level", 0)):
			continue
		if (p.get("not", []) as Array).has(kind):
			continue
		if p.has("only") and not (p.only as Array).has(kind):
			continue
		pool.append(p.id)
	var out := []
	for i in n:
		if pool.is_empty():
			break
		var pick: String = pool[r.randi() % pool.size()]
		pool.erase(pick)
		out.append(pick)
	return out


## Alle Level: [{type, groups: [{enemy, count, interval, hp, armor, speed, damage, props}], eeve: {kind, stage, props}}]
static func generate(rules: Dictionary, diff: Dictionary, r: RandomNumberGenerator) -> Array:
	var waves := []
	var challenges: Dictionary = rules.get("challenges", {})
	var armor_steps: Array = diff.get("armor", [0])
	for level in range(1, int(rules.get("levels", 57)) + 1):
		var stage := stage_of(level)
		var armor_bonus := float(armor_steps[clampi(stage - 1, 0, armor_steps.size() - 1)])
		var interval: Dictionary = rules.get("spawn_interval", {})
		if challenges.has(str(level)):
			var c: Dictionary = challenges[str(level)]
			var cd: Dictionary = Database.enemies.get(str(c.enemy), {})
			waves.append({"type": "Challenge", "eeve": {"kind": "challenge", "stage": stage, "props": []}, "groups": [{
				"enemy": str(c.enemy), "count": int(c.count), "hp": float(cd.get("hp", 1000)),
				"armor": float(cd.get("armor", 0)) + armor_bonus, "damage": 0,
				"interval": float(interval.get("mass" if int(c.count) > 1 else "boss", 1.0)), "props": []}]})
			continue
		var kind := roll_kind(rules, level, r)
		var props := roll_props(rules, level, kind, r)
		var id := enemy_for(stage, kind)
		var d: Dictionary = Database.enemies.get(id, {})
		var wt: Dictionary = rules.get("wave_types", {}).get(kind, {})
		var k := 100.0 * stage * stage if str(wt.get("k", "ground")) == "ground" else (75.0 + 25.0 * stage) * stage
		var hp := float(d.get("hp", 100)) - (stage_end(stage) - level) * k * float(wt.get("hp_factor", 1.0))
		hp *= float(diff.get("hp", 1.0))
		var armor := float(d.get("armor", 0)) + armor_bonus
		var speed := float(d.get("speed", 2.3))
		for pid in props:
			var p := prop(rules, pid)
			hp *= float(p.get("hp", 1.0))
			armor += float(p.get("armor", 0))
			speed += float(p.get("speed", 0))
		speed = minf(speed, float(rules.get("max_speed", 4.078)))
		var mass := kind.ends_with("_mass")
		waves.append({"type": TYPE_LABELS.get(kind, "Boden"), "eeve": {"kind": kind, "stage": stage, "props": props}, "groups": [{
			"enemy": id, "count": int(wt.get("count", 10)), "hp": maxf(roundf(hp), 1.0), "armor": armor, "speed": speed,
			"interval": float(interval.get("mass" if mass else ("boss" if kind == "boss" else "normal"), 1.0)),
			"props": props}]})
	return waves
