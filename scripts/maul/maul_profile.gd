class_name MaulProfile
extends RefCounted
## Profil von Shopping Maul: alles, was über Partien hinweg bleibt, in derselben Datei wie die XP
## (user://maul.cfg, maul_xp.gd). Dazu Partien, Siege und Rekorde gesamt und je Filiale (bestes Level,
## schwerste gewonnene Schwierigkeit). Gezählt wird nur ohne Sandbox und ohne Debug-Menü; im Koop
## schreibt jeder Spieler sein eigenes Profil auf seinem Rechner.

static var path := MaulXp.FILE  ## Tests schreiben in eine eigene Datei
const TOTAL := ["games", "wins", "levels", "kills", "minutes"]
const PER_SHOP := ["games", "wins", "best_level", "best_win"]


static func _file() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(path)
	return c


## Summen über alle Partien: games, wins, levels, kills, minutes.
static func totals() -> Dictionary:
	var c := _file()
	var d := {}
	for k in TOTAL:
		d[k] = int(c.get_value("stats", k, 0))
	return d


## Werte einer Filiale: games, wins, best_level (0 = nie gespielt), best_win (-1 = nie gewonnen, sonst Schwierigkeit).
static func shop(id: String) -> Dictionary:
	var c := _file()
	return {"games": int(c.get_value("shop_" + id, "games", 0)), "wins": int(c.get_value("shop_" + id, "wins", 0)),
		"best_level": int(c.get_value("shop_" + id, "best_level", 0)), "best_win": int(c.get_value("shop_" + id, "best_win", -1))}


## Partie eintragen. Gibt zurück, was neu ist: {"best_level": true, "best_win": true}.
static func record(shop_id: String, difficulty: int, levels: int, won: bool, kills: int, seconds: float) -> Dictionary:
	if shop_id == "":
		return {}
	var c := _file()
	var add := {"games": 1, "wins": 1 if won else 0, "levels": levels, "kills": kills, "minutes": roundi(seconds / 60.0)}
	for k in add:
		c.set_value("stats", k, int(c.get_value("stats", k, 0)) + int(add[k]))
	var sec := "shop_" + shop_id
	var news := {}
	c.set_value(sec, "games", int(c.get_value(sec, "games", 0)) + 1)
	if levels > int(c.get_value(sec, "best_level", 0)):
		c.set_value(sec, "best_level", levels)
		news.best_level = true
	if won:
		c.set_value(sec, "wins", int(c.get_value(sec, "wins", 0)) + 1)
		if difficulty > int(c.get_value(sec, "best_win", -1)):
			c.set_value(sec, "best_win", difficulty)
			news.best_win = true
	c.save(path)
	return news


## Alles, was XP freischalten: [{xp (Zehntel), name, open}], nach XP sortiert (Profi-Filialen und XPert-Tower).
static func unlocks(xp: int) -> Array:
	var out: Array = []
	var pro := int(MaulXp.cfg().get("pro_shops", 25)) * 10
	out.append({"xp": pro, "name": "Profi-Filialen", "open": xp >= pro})
	for t in MaulData.xpert().get("towers", []):
		var need := 0
		for req in t.get("requires", []):
			need = maxi(need, MaulXp.needed(str(req)))
		if need > 0:
			out.append({"xp": need, "name": str(t.name), "open": xp >= need})
	out.sort_custom(func(a, b): return int(a.xp) < int(b.xp))
	return out


## Nächste Freischaltung über xp ({} = alles offen).
static func next_unlock(xp: int) -> Dictionary:
	for u in unlocks(xp):
		if not u.open:
			return u
	return {}

