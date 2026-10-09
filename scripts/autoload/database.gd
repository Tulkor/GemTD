extends Node
## Lädt alle Spieldaten aus JSON-Dateien.
##
## res://data/<typ>/*.json  -> mitgelieferte Daten
## user://data/<typ>/*.json -> eigene Daten (überschreiben gleiche IDs)
##
## Typen: towers, enemies, waves, maps. Dazu res://data/balance.json.

const RES_DATA := "res://data/"
const USER_DATA := "user://data/"
const TIER_NAMES := ["Splitter", "Fehlerhafter", "Normaler", "Makelloser", "Perfekter", "Großer"]

var towers: Dictionary = {}
var enemies: Dictionary = {}
var wave_sets: Dictionary = {}
var balance: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	towers = _load_dir("towers")
	enemies = _load_dir("enemies")
	wave_sets = _load_dir("waves")
	var b = load_json(RES_DATA + "balance.json")
	balance = b if typeof(b) == TYPE_DICTIONARY else {}


# --- Dateien -----------------------------------------------------------------

func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	var err := json.parse(FileAccess.get_file_as_string(path))
	if err != OK:
		push_error("JSON-Fehler in %s (Zeile %d): %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


func save_json(path: String, data: Variant) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Kann %s nicht schreiben (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data, "\t", false) + "\n")
	return true


## Wohin Editoren speichern: im Godot-Editor direkt ins Projekt, sonst ins Benutzerverzeichnis.
func writable_path(kind: String, id: String) -> String:
	var base := RES_DATA if OS.has_feature("editor") else USER_DATA
	return base + kind + "/" + id + ".json"


func json_files(kind: String) -> PackedStringArray:
	var result := PackedStringArray()
	for base in [RES_DATA, USER_DATA]:
		var dir: String = base + kind
		if not DirAccess.dir_exists_absolute(dir):
			continue
		var files := DirAccess.get_files_at(dir)
		files.sort()
		for f in files:
			if f.ends_with(".json"):
				result.append(dir + "/" + f)
	return result


func _load_dir(kind: String) -> Dictionary:
	var out := {}
	for path in json_files(kind):
		var d = load_json(path)
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var id := str(d.get("id", path.get_file().get_basename()))
		d["id"] = id
		d["_path"] = path
		out[id] = d
	return out


## Liste aller Maps: [{id, name, path}], user:// überschreibt res:// bei gleicher ID.
func list_maps() -> Array:
	var by_id := {}
	for path in json_files("maps"):
		var d = load_json(path)
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var id := str(d.get("id", path.get_file().get_basename()))
		by_id[id] = {"id": id, "name": str(d.get("name", id)), "path": path}
	var list := by_id.values()
	list.sort_custom(func(a, b): return a.name < b.name)
	return list


# --- Tower -------------------------------------------------------------------

func tower_ids() -> Array:
	var ids := towers.keys()
	ids.sort()
	return ids


func gem_ids() -> Array:
	return tower_ids().filter(func(id): return towers[id].get("category", "gem") == "gem")


func special_ids() -> Array:
	return tower_ids().filter(func(id): return towers[id].get("category", "gem") == "special")


func tier_count(id: String) -> int:
	return (towers.get(id, {}).get("tiers", []) as Array).size()


func tower_tier(id: String, tier: int) -> Dictionary:
	var tiers: Array = towers.get(id, {}).get("tiers", [])
	if tiers.is_empty():
		return {}
	return tiers[clampi(tier, 0, tiers.size() - 1)]


func tower_label(id: String, tier: int) -> String:
	var def: Dictionary = towers.get(id, {})
	var stats := tower_tier(id, tier)
	if stats.has("name"):
		return str(stats.name)
	var name := str(def.get("name", id))
	if def.get("category", "gem") == "gem":
		return "%s %s" % [TIER_NAMES[clampi(tier, 0, TIER_NAMES.size() - 1)], name]
	if tier_count(id) > 1:
		return "%s (Stufe %d)" % [name, tier + 1]
	return name


## Würfelt einen zufälligen Gem. Rückgabe: [id, tier]
func roll_gem(chance_level: int, rng: RandomNumberGenerator) -> Array:
	var ids := gem_ids()
	if ids.is_empty():
		return ["", 0]
	var id: String = ids[rng.randi() % ids.size()]
	var levels: Array = balance.get("chance_levels", [{"weights": [1]}])
	var weights: Array = levels[clampi(chance_level, 0, levels.size() - 1)].get("weights", [1])
	var total := 0.0
	for wgt in weights:
		total += float(wgt)
	var roll := rng.randf() * total
	var tier := 0
	for i in weights.size():
		roll -= float(weights[i])
		if roll < 0.0:
			tier = i
			break
	return [id, mini(tier, tier_count(id) - 1)]
