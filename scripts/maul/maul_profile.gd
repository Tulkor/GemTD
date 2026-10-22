class_name MaulProfile
extends RefCounted
## Profil von Shopping Maul: alles, was über Partien hinweg bleibt (XP, Partien, Siege, Rekorde
## gesamt und je Filiale: bestes Level, schwerste gewonnene Schwierigkeit). Liegt im allgemeinen
## Profil (profile.gd) unter modes.maul.progress; ältere Stände aus user://maul.cfg werden beim
## ersten Zugriff übernommen. Gezählt wird nur ohne Sandbox und ohne Debug-Menü; im Koop schreibt
## jeder Spieler sein eigenes Profil auf seinem Rechner.

static var path := MaulXp.FILE  ## alte Datei, aus der übernommen wird (Tests: eigene Datei)
const TOTAL := ["games", "wins", "levels", "kills", "minutes"]
const PER_SHOP := ["games", "wins", "best_level", "best_win"]


## Maul-Bereich im Profil: {stats: {…}, shops: {id: {…}}, xp: Zehntel}.
static func prog() -> Dictionary:
	var p := Profile.progress("maul")
	if not p.get("migrated", false):
		_migrate(p)
	return p


## Einmalig: XP und Werte aus user://maul.cfg ins Profil holen.
static func _migrate(p: Dictionary) -> void:
	var c := ConfigFile.new()
	var old := c.load(path) == OK
	p.stats = {}
	for k in TOTAL:
		p.stats[k] = int(c.get_value("stats", k, 0)) if old else 0
	p.shops = {}
	if old:
		if c.has_section_key("xp", "tenths"):
			p.xp = int(c.get_value("xp", "tenths"))
		for sec in c.get_sections():
			if sec.begins_with("shop_"):
				var d := {}
				for k in PER_SHOP:
					d[k] = int(c.get_value(sec, k, -1 if k == "best_win" else 0))
				p.shops[sec.substr(5)] = d
	p.migrated = true
	Profile.save()


## Summen über alle Partien: games, wins, levels, kills, minutes.
static func totals() -> Dictionary:
	var st: Dictionary = prog().stats
	var d := {}
	for k in TOTAL:
		d[k] = int(st.get(k, 0))
	return d


## Werte einer Filiale: games, wins, best_level (0 = nie gespielt), best_win (-1 = nie gewonnen, sonst Schwierigkeit).
static func shop(id: String) -> Dictionary:
	var d: Dictionary = prog().shops.get(id, {})
	return {"games": int(d.get("games", 0)), "wins": int(d.get("wins", 0)),
		"best_level": int(d.get("best_level", 0)), "best_win": int(d.get("best_win", -1))}


## Partie eintragen. Gibt zurück, was neu ist: {"best_level": true, "best_win": true}.
static func record(shop_id: String, difficulty: int, levels: int, won: bool, kills: int, seconds: float) -> Dictionary:
	if shop_id == "":
		return {}
	var p := prog()
	var add := {"games": 1, "wins": 1 if won else 0, "levels": levels, "kills": kills, "minutes": roundi(seconds / 60.0)}
	for k in add:
		p.stats[k] = int(p.stats.get(k, 0)) + int(add[k])
	var sh := shop(shop_id)
	var news := {}
	sh.games += 1
	if levels > sh.best_level:
		sh.best_level = levels
		news.best_level = true
	if won:
		sh.wins += 1
		if difficulty > sh.best_win:
			sh.best_win = difficulty
			news.best_win = true
	p.shops[shop_id] = sh
	Profile.save()
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

