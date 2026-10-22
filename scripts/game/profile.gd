class_name Profile
extends RefCounted
## Spielerprofil für alle Modi, lokal in user://profile/: profile.json (versioniert) mit Summen,
## Rekorden und Tower-Statistik je Modus, dazu jeder Run komplett in runs/<id>.json (alle Tower,
## jede Welle, siehe run_stats.gd), damit man später an jedes Detail kommt. Angezeigt wird nur
## das Wichtigste (profile_panel.gd). Shopping Maul legt XP und Rekorde je Filiale unter
## modes.maul.progress ab (maul_profile.gd, maul_xp.gd). Runs mit Debug-Hilfen stehen in der
## Liste, zählen aber nicht für Summen und Rekorde.
##
## profile.json: {version, created, updated, name,
##   modes: {<modus>: {runs, wins, losses, play_time, kills, damage, waves, leaks, built, actions,
##     by_map: {map: {runs, wins, best_wave, best_score}}, by_difficulty: {…}, best_run: {Index-Eintrag},
##     records: {name: {value, run, id?, label?, wave?, time}}, progress?: {…}}},
##   towers: {<modus>: {tower_id: {built, tiers, runs, wins, wins_alive, kills, damage, best_run_kills,
##     best_run_damage, best_tower_kills, best_tower_damage, best_wave_damage, (je *_run)}}},
##   runs: [Index-Einträge, neueste zuerst]}
## runs/<id>.json: Index-Eintrag + alles aus info + RunStats.result() (towers, types, wave_log, actions).

const VERSION := 1
const MAX_INDEX := 2000
const MODES := ["gemtd", "eeve", "maul", "roguelike"]
## Rekorde, bei denen der kleinere Wert besser ist
const LOWER_IS_BETTER := ["fastest_win"]

static var dir := "user://profile"  ## Tests schreiben in einen eigenen Ordner
static var _data := {}
static var _loaded_from := ""


static func file() -> String:
	return dir.path_join("profile.json")


static func data() -> Dictionary:
	if _loaded_from != dir:
		_load()
	return _data


static func _load() -> void:
	_loaded_from = dir
	_data = {}
	if FileAccess.file_exists(file()):
		var d = JSON.parse_string(FileAccess.get_file_as_string(file()))
		if d is Dictionary:
			_data = d
		else:
			push_warning("Profil beschädigt, nehme Sicherung: %s" % file())
			d = JSON.parse_string(FileAccess.get_file_as_string(file() + ".bak")) if FileAccess.file_exists(file() + ".bak") else null
			if d is Dictionary:
				_data = d
	if _data.is_empty():
		_data = {"version": VERSION, "created": _now(), "updated": _now(), "name": "", "modes": {}, "towers": {}, "runs": []}
		_import_old()
		save()
	_upgrade()


## Ältere Fassungen der Datei auf VERSION bringen (hier kommen später Umbauten hin).
static func _upgrade() -> void:
	for k in ["modes", "towers"]:
		if not _data.get(k) is Dictionary:
			_data[k] = {}
	if not _data.get("runs") is Array:
		_data.runs = []
	_data.version = VERSION


static func save() -> void:
	DirAccess.make_dir_recursive_absolute(dir.path_join("runs"))
	_data.updated = _now()
	if FileAccess.file_exists(file()):
		DirAccess.copy_absolute(file(), file() + ".bak")
	var f := FileAccess.open(file(), FileAccess.WRITE)
	if f == null:
		push_warning("Profil nicht speicherbar: %s" % file())
		return
	f.store_string(JSON.stringify(_data, "\t"))


## Nur für Tests: alles vergessen (nächster Zugriff lädt neu).
static func reset_cache() -> void:
	_loaded_from = ""
	_data = {}


static func _now() -> String:
	return Time.get_datetime_string_from_system(false, true)


## Werte eines Modus (legt sie an).
static func mode(m: String) -> Dictionary:
	var modes: Dictionary = data().modes
	if not modes.has(m):
		modes[m] = {"runs": 0, "wins": 0, "losses": 0, "play_time": 0, "kills": 0, "damage": 0, "waves": 0,
			"leaks": 0, "built": 0, "actions": {}, "by_map": {}, "by_difficulty": {}, "best_run": {}, "records": {}}
	return modes[m]


## Eigener Bereich eines Modus für Fortschritt (Maul: XP, Rekorde je Filiale). Danach save().
static func progress(m: String) -> Dictionary:
	var md := mode(m)
	if not md.get("progress") is Dictionary:
		md.progress = {}
	return md.progress


static func towers(m: String) -> Dictionary:
	var t: Dictionary = data().towers
	if not t.has(m):
		t[m] = {}
	return t[m]


## Index aller Runs (neueste zuerst), optional nur ein Modus.
static func runs(m := "") -> Array:
	var all: Array = data().runs
	return all if m == "" else all.filter(func(r): return r.get("mode", "") == m)


## Ganzer Run mit allen Details ({} wenn die Datei fehlt, z. B. bei übernommenen alten Runs).
static func load_run(rid: String) -> Dictionary:
	var p := dir.path_join("runs/%s.json" % rid)
	if not FileAccess.file_exists(p):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d if d is Dictionary else {}


## Summen über alle Modi.
static func totals() -> Dictionary:
	var s := {"runs": 0, "wins": 0, "play_time": 0, "kills": 0, "damage": 0, "waves": 0, "built": 0, "best_wave": 0}
	for m in data().modes:
		var md: Dictionary = data().modes[m]
		for k in ["runs", "wins", "play_time", "kills", "damage", "waves", "built"]:
			s[k] += int(md.get(k, 0))
		s.best_wave = maxi(s.best_wave, int(md.get("records", {}).get("best_wave", {}).get("value", 0)))
	return s


## Bester Run über alle Modi (oder nur m).
static func best_run(m := "") -> Dictionary:
	var best := {}
	for k in data().modes:
		if m != "" and k != m:
			continue
		var r: Dictionary = data().modes[k].get("best_run", {})
		if not r.is_empty() and (best.is_empty() or _better(r, best)):
			best = r
	return best


## Ist Run a besser als b? Sieg vor Niederlage, dann Welle, Punkte, Leben, kürzere Zeit.
static func _better(a: Dictionary, b: Dictionary) -> bool:
	for k in ["victory", "wave", "score", "lives"]:
		var x := float(a.get(k, 0))
		var y := float(b.get(k, 0))
		if x != y:
			return x > y
	return float(a.get("play_time", 0)) < float(b.get("play_time", 0))


## Einen beendeten Run eintragen. info: map, map_path, difficulty, victory, wave, waves, lives,
## max_lives, score, score_mode, kills, play_time, path, coop, players, debug und was der Modus
## sonst mitgibt; stats: RunStats.result(). Gibt die neuen Rekorde zurück ({name: true}).
static func record_run(m: String, info: Dictionary, stats: Dictionary) -> Dictionary:
	data()
	var rid := "%s_%s_%04d" % [m, Time.get_datetime_string_from_system(false, false).replace(":", "").replace("-", ""), randi() % 10000]
	var damage := 0.0
	for id in stats.get("types", {}):
		damage += float(stats.types[id].damage)
	var waves_done := int(info.get("wave", 0)) - (0 if info.get("victory", false) else 1)
	var entry := {"id": rid, "mode": m, "time": _now(), "map": info.get("map", ""), "difficulty": info.get("difficulty", 0),
		"victory": bool(info.get("victory", false)), "wave": int(info.get("wave", 0)), "waves": int(info.get("waves", 0)),
		"lives": int(info.get("lives", 0)), "score": int(info.get("score", 0)), "kills": int(info.get("kills", 0)),
		"damage": roundi(damage), "play_time": int(info.get("play_time", 0)), "debug": bool(info.get("debug", false))}
	var top: Array = stats.get("towers", [])
	if not top.is_empty():
		entry.top = {"id": top[0].id, "label": top[0].label, "damage": top[0].damage}
	var full := info.duplicate(true)
	full.merge(stats, true)
	full.merge(entry, true)
	full.version = VERSION
	DirAccess.make_dir_recursive_absolute(dir.path_join("runs"))
	var f := FileAccess.open(dir.path_join("runs/%s.json" % rid), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(full))
		f.close()
	_data.runs.push_front(entry)
	if _data.runs.size() > MAX_INDEX:
		_data.runs.resize(MAX_INDEX)
	var news := {}
	if not entry.debug:
		news = _count(m, entry, info, stats, maxi(waves_done, 0))
	save()
	return news


static func _count(m: String, entry: Dictionary, info: Dictionary, stats: Dictionary, waves_done: int) -> Dictionary:
	var md := mode(m)
	var won: bool = entry.victory
	md.runs += 1
	md.wins += 1 if won else 0
	md.losses += 0 if won else 1
	md.play_time += entry.play_time
	md.kills += entry.kills
	md.damage += entry.damage
	md.waves += waves_done
	var leaks := 0
	for x in info.get("leaks", []):
		leaks += int(x)
	md.leaks += leaks
	for a in stats.get("actions", {}):
		md.actions[a] = int(md.actions.get(a, 0)) + int(stats.actions[a])
	for group in [["by_map", str(entry.map)], ["by_difficulty", str(entry.difficulty)]]:
		var g: Dictionary = md[group[0]]
		if not g.has(group[1]):
			g[group[1]] = {"runs": 0, "wins": 0, "best_wave": 0, "best_score": 0}
		var s: Dictionary = g[group[1]]
		s.runs += 1
		s.wins += 1 if won else 0
		s.best_wave = maxi(int(s.best_wave), entry.wave)
		s.best_score = maxi(int(s.best_score), entry.score)
	if md.best_run.is_empty() or _better(entry, md.best_run):
		md.best_run = entry.duplicate()

	var news := {}
	var before: Dictionary = md.records.duplicate()
	var rec := func(name: String, value: float, extra := {}):
		if value <= 0.0:
			return
		var old: Dictionary = md.records.get(name, {})
		var lower := LOWER_IS_BETTER.has(name)
		if old.is_empty() or (value < float(old.value) if lower else value > float(old.value)):
			var r := {"value": value, "run": entry.id, "time": entry.time}
			r.merge(extra)
			md.records[name] = r
			if before.has(name):
				news[name] = true
	rec.call("most_kills", entry.kills)
	rec.call("best_wave", entry.wave)
	rec.call("best_score", entry.score)
	rec.call("most_damage", entry.damage)
	rec.call("longest_path", float(info.get("path", 0)))
	if won:
		rec.call("fastest_win", entry.play_time)

	var built := 0
	var ts := towers(m)
	for id in stats.get("types", {}):
		var ty: Dictionary = stats.types[id]
		built += int(ty.built)
		if not ts.has(id):
			ts[id] = {"built": 0, "tiers": {}, "runs": 0, "wins": 0, "wins_alive": 0, "kills": 0, "damage": 0,
				"best_run_kills": 0, "best_run_damage": 0, "best_tower_kills": 0, "best_tower_damage": 0, "best_wave_damage": 0}
		var a: Dictionary = ts[id]
		a.built += int(ty.built)
		for k in ty.get("tiers", {}):
			a.tiers[k] = int(a.tiers.get(k, 0)) + int(ty.tiers[k])
		a.runs += 1
		a.wins += 1 if won else 0
		a.wins_alive += 1 if won and int(ty.get("alive", 0)) > 0 else 0
		a.kills += int(ty.kills)
		a.damage += roundi(float(ty.damage))
		_best(a, "best_run_kills", int(ty.kills), entry.id)
		_best(a, "best_run_damage", roundi(float(ty.damage)), entry.id)
		_best(a, "best_wave_damage", roundi(float(ty.best_wave_damage)), entry.id)
		rec.call("type_damage_wave", float(ty.best_wave_damage), {"id": id, "wave": int(ty.best_wave)})
	md.built += built
	for tw in stats.get("towers", []):
		var a: Dictionary = ts.get(tw.id, {})
		if not a.is_empty():
			_best(a, "best_tower_kills", int(tw.kills), entry.id)
			_best(a, "best_tower_damage", roundi(float(tw.damage)), entry.id)
		rec.call("tower_kills_run", float(tw.kills), {"id": tw.id, "label": tw.label})
		rec.call("tower_damage_run", float(tw.damage), {"id": tw.id, "label": tw.label})
		rec.call("tower_damage_wave", float(tw.best_wave_damage), {"id": tw.id, "label": tw.label, "wave": int(tw.best_wave)})
	for w in stats.get("wave_log", []):
		rec.call("wave_damage", float(w.damage), {"wave": int(w.wave)})
		rec.call("wave_kills", float(w.kills), {"wave": int(w.wave)})
	return news


static func _best(a: Dictionary, key: String, value: int, rid: String) -> void:
	if value > int(a.get(key, 0)):
		a[key] = value
		a[key + "_run"] = rid


## Beim ersten Start: alte Run-History (GemTD) in die Liste und die Summen übernehmen.
static func _import_old() -> void:
	var old := RunHistory.load_runs()
	for i in range(old.size() - 1, -1, -1):
		var r: Dictionary = old[i]
		var top: Array = r.get("top", [])
		var entry := {"id": "alt_%d" % i, "mode": "gemtd", "time": r.get("time", ""), "map": r.get("map", ""),
			"difficulty": r.get("difficulty", 0), "victory": bool(r.get("victory", false)), "wave": int(r.get("wave", 0)),
			"waves": int(r.get("waves", 0)), "lives": int(r.get("lives", 0)), "score": int(r.get("score", 0)),
			"kills": int(r.get("kills", 0)), "damage": 0, "play_time": int(r.get("play_time", 0)), "debug": false, "imported": true}
		if not top.is_empty():
			entry.top = {"id": "", "label": top[0].get("label", ""), "damage": int(top[0].get("damage", 0))}
		_data.runs.push_front(entry)
		var waves_done: int = entry.wave - (0 if entry.victory else 1)
		_count("gemtd", entry, r, {}, maxi(waves_done, 0))
