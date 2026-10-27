class_name YoutdProgress
extends RefCounted
## Spieler-Erfahrung von YouTD über Partien hinweg (im Profil unter modes.youtd.progress, siehe profile.gd):
## Punkte einer Partie × 0,002 = XP (wie im Original), Level 0–300 nach der Tabelle aus YouTD 2.
## Alle 6 Level gibt es einen Weisheits-Punkt; die gewählten Weisheits-Boni bleiben gespeichert.
## Mit dem Level werden Baumeister frei (ihre Sonderregeln kommen in Etappe 3).
## Partien mit Debug-Menü zählen nicht.


## Bereich im Profil: {xp, wisdom: [ids], games, wins, best_wave, kills}.
static func prog() -> Dictionary:
	var p := Profile.progress("youtd")
	for k in ["xp", "games", "wins", "best_wave", "kills"]:
		if not p.has(k):
			p[k] = 0
	if not p.get("wisdom") is Array:
		p.wisdom = []
	return p


static func xp() -> float:
	return float(prog().xp)


static func level() -> int:
	return YoutdData.player_level(xp())


## XP, die für das nächste Level fehlen (0 = Höchstlevel).
static func xp_to_next() -> float:
	var table := YoutdData.player_exp_table()
	var l := level()
	if l + 1 >= table.size():
		return 0.0
	return float(table[l + 1]) - xp()


## Weisheits-Punkte für ein Level (je 6 Level einer).
static func wisdom_points(lvl := -1) -> int:
	if lvl < 0:
		lvl = level()
	return int(lvl / maxi(1, int(YoutdData.rules().get("player", {}).get("levels_per_wisdom", 6))))


## Gewählte Weisheits-Boni (höchstens so viele wie Punkte; zu viele werden von hinten gekürzt).
static func wisdom() -> Array:
	var list: Array = prog().wisdom
	var n := wisdom_points()
	return list.slice(0, n)


static func set_wisdom(list: Array) -> void:
	prog().wisdom = list.slice(0, wisdom_points())
	Profile.save()


## Partie eintragen. Gibt {xp, level_before, level_after} zurück.
static func record(score: float, wave: int, won: bool, kills: int) -> Dictionary:
	var p := prog()
	var before := level()
	var gained := score * float(YoutdData.rules().get("score", {}).get("to_exp", 0.002))
	p.xp = float(p.xp) + gained
	p.games = int(p.games) + 1
	if won:
		p.wins = int(p.wins) + 1
	p.best_wave = maxi(int(p.best_wave), wave)
	p.kills = int(p.kills) + kills
	Profile.save()
	return {"xp": gained, "level_before": before, "level_after": level()}


## Baumeister mit Freischalt-Level: [{id, name, tier, level, open}].
static func builders() -> Array:
	var l := level()
	return YoutdData.builders().map(func(b): return {"id": b.id, "name": b.name, "tier": b.tier, "level": int(b.level),
			"open": l >= int(b.level)})
