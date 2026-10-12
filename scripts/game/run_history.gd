class_name RunHistory
extends RefCounted
## Run-History: jedes beendete Spiel (gewonnen oder verloren) als Eintrag in user://run_history.json,
## neueste zuerst. Das Hauptmenü zeigt sie (RunHistoryPanel).

const MAX_RUNS := 200
static var path := "user://run_history.json"


static func load_runs() -> Array:
	if not FileAccess.file_exists(path):
		return []
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Array else []


static func save_runs(runs: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Run-History nicht speicherbar: %s" % path)
		return
	f.store_string(JSON.stringify(runs.slice(0, MAX_RUNS)))


static func record(entry: Dictionary) -> void:
	var runs := load_runs()
	runs.push_front(entry)
	save_runs(runs)


static func delete(index: int) -> void:
	var runs := load_runs()
	if index >= 0 and index < runs.size():
		runs.remove_at(index)
		save_runs(runs)


## Eintrag aus dem Spiel am Ende eines Laufs.
static func entry_from(game, victory: bool) -> Dictionary:
	var leaks := []
	for i in game.waves.size():
		leaks.append(int(game.leaks_per_wave.get(i, 0)))
	var ts: Array = game.all_towers().filter(func(t): return is_instance_valid(t) and not t.is_new)
	ts.sort_custom(func(a, b): return a.total_damage > b.total_damage)
	var top := []
	for t in ts.slice(0, 5):
		top.append({"label": t.label(), "color": t.color.to_html(false), "damage": roundi(t.total_damage)})
	var specials := []
	for t in ts:
		if str(t.def.get("category", "gem")) == "special" and not specials.has(Database.tower_label(t.tower_id, 0)):
			specials.append(Database.tower_label(t.tower_id, 0))
	return {
		"time": Time.get_datetime_string_from_system(false, true),
		"map": game.map.name if game.map != null else "?",
		"map_path": Session.map_path,
		"difficulty": Session.difficulty,
		"score_mode": game.score_mode,
		"victory": victory,
		"wave": mini(game.wave_index + 1, game.waves.size()),
		"waves": game.waves.size(),
		"lives": game.lives,
		"max_lives": game.map.lives if game.map != null else 50,
		"score": roundi(game.score) if game.score_mode else 0,
		"kills": game.enemies_killed,
		"path": game.path_length,
		"play_time": roundi(game.play_time),
		"towers": ts.size(),
		"leaks": leaks,
		"top": top,
		"specials": specials,
		"summary": game.run_summary(),
	}
