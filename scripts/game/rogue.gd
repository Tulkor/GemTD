class_name Rogue
extends Node
## GemTD-Variante Roguelike (Regeln in data/roguelike.json): nach jeder zehnten Welle bekommt jeder Spieler
## drei zufällige Boni angeboten und wählt einen. Ein Bonus erhöht Schaden, Tempo oder Reichweite aller Stufen
## eines Grund-Gems oder eines Spezialtowers samt Upgrades, und zwar nur für die Tower dieses Spielers.
## Würfeln und Wählen rechnet nur der Host (Befehl rogue_pick über game.submit), Mitspieler bekommen den Stand
## über coop_sync. Das Auswahlfenster (rogue_panel.gd) öffnet sich von selbst, solange ein Angebot offen ist.

const STATS := ["damage", "speed", "range"]

var game  # game.gd
## Je Spieler die gewählten Boni: [{id, kind ("gem"/"special"), stat, value, rarity, wave}]
var boons: Array = []
## Je Spieler das offene Angebot (leer = nichts zu wählen), Einträge wie in boons
var offers: Array = []
var _panel: Control = null
var _panel_key := ""


func _init(g = null) -> void:
	game = g
	name = "Rogue"


static func rules() -> Dictionary:
	return Database.roguelike


func _ensure_players() -> void:
	var n: int = game.players.size()
	while boons.size() < n:
		boons.append([])
	while offers.size() < n:
		offers.append([])


## Beginn einer Bauphase: nach jeder every-ten Welle ein Angebot für jeden Spieler würfeln.
func on_build() -> void:
	_ensure_players()
	var every := int(rules().get("every", 10))
	if game.wave_index <= 0 or every <= 0 or game.wave_index % every != 0:
		return
	for p in game.players.size():
		if offers[p].is_empty():
			offers[p] = roll(p)


func pending(p: int) -> bool:
	return p >= 0 and p < offers.size() and not offers[p].is_empty()


## Spieler p nimmt Angebot index.
func pick(p: int, index: int) -> bool:
	if not pending(p) or index < 0 or index >= offers[p].size():
		return false
	var b: Dictionary = offers[p][index].duplicate()
	b.wave = game.wave_index
	boons[p].append(b)
	offers[p] = []
	game._update_auras()
	return true


## Summe der Boni, die auf Tower t wirken: {damage, speed, range}.
func bonus_for(t) -> Dictionary:
	var out := {"damage": 0.0, "speed": 0.0, "range": 0.0}
	if t.is_trap() or t.owner_player < 0 or t.owner_player >= boons.size():
		return out
	for b in boons[t.owner_player]:
		if str(b.id) == t.tower_id:
			out[str(b.stat)] += float(b.value)
	return out


## Bisheriger Zuschlag von Spieler p auf Tower id und Wert stat.
func total(p: int, id: String, stat: String) -> float:
	var sum := 0.0
	if p >= 0 and p < boons.size():
		for b in boons[p]:
			if str(b.id) == id and str(b.stat) == stat:
				sum += float(b.value)
	return sum


# --- Würfeln ---------------------------------------------------------------------

## choices verschiedene Boni (nie zweimal derselbe Tower mit demselben Wert).
func roll(p: int) -> Array:
	var r := rules()
	var rng: RandomNumberGenerator = game.rng
	var out := []
	var seen := {}
	var tries := 0
	while out.size() < int(r.get("choices", 3)) and tries < 50:
		tries += 1
		var tw: Dictionary = r.get("target_weights", {"gem": 1.0, "special": 1.0})
		var kind := "gem" if rng.randf() * (float(tw.get("gem", 1.0)) + float(tw.get("special", 1.0))) < float(tw.get("gem", 1.0)) else "special"
		var id := _roll_target(kind, p, rng)
		if id == "":
			continue
		var stats := STATS.filter(func(s): return _applies(id, s))
		if stats.is_empty():
			continue
		var stat: String = stats[rng.randi() % stats.size()]
		if seen.has(id + ":" + stat):
			continue
		seen[id + ":" + stat] = true
		var rar := _roll_rarity(rng)
		var base := float(r.get("stats", {}).get(stat, {}).get(kind, 0.1))
		out.append({"id": id, "kind": kind, "stat": stat, "rarity": str(rar.get("id", "common")),
				"value": snappedf(base * float(rar.get("scale", 1.0)), 0.01)})
	return out


func _roll_target(kind: String, p: int, rng: RandomNumberGenerator) -> String:
	var ids := []
	var weights := []
	var owned := {}
	for t in game.all_towers():
		if t.owner_player == p and not t.is_new:
			owned[t.tower_id] = true
	for id in Database.towers:
		var def: Dictionary = Database.towers[id]
		if str(def.get("kind", "tower")) == "trap" or str(id).begins_with("eeve_"):
			continue
		if str(def.get("category", "gem")) != kind:
			continue
		ids.append(id)
		weights.append(float(rules().get("owned_weight", 3.0)) if kind == "special" and owned.has(id) else 1.0)
	if ids.is_empty():
		return ""
	var sum := 0.0
	for w in weights:
		sum += w
	var x := rng.randf() * sum
	for i in ids.size():
		x -= weights[i]
		if x <= 0.0:
			return ids[i]
	return ids[-1]


func _roll_rarity(rng: RandomNumberGenerator) -> Dictionary:
	var list: Array = rules().get("rarities", [])
	if list.is_empty():
		return {"id": "common", "scale": 1.0}
	var sum := 0.0
	for r in list:
		sum += float(r.get("weight", 1.0))
	var x := rng.randf() * sum
	for r in list:
		x -= float(r.get("weight", 1.0))
		if x <= 0.0:
			return r
	return list[-1]


## Wirkt der Wert stat überhaupt bei Tower id (greift er an, hat er Reichweite)?
static func _applies(id: String, stat: String) -> bool:
	for s in Database.towers.get(id, {}).get("tiers", []):
		var dmg: Array = s.get("damage", [0, 0])
		if float(s.get("cooldown", 0)) > 0.0 and dmg.size() > 1 and float(dmg[1]) > 0.0:
			return stat != "range" or float(s.get("range", 0.0)) > 0.0
	return false


static func rarity(id: String) -> Dictionary:
	for r in rules().get("rarities", []):
		if str(r.get("id", "")) == id:
			return r
	return {"id": id, "name": id, "color": "TEXT"}


static func stat_name(stat: String) -> String:
	return str(rules().get("stats", {}).get(stat, {}).get("name", stat))


## "+25 %"
static func value_text(v: float) -> String:
	return "+%d %%" % roundi(v * 100.0)


## Kurzer Text eines Bonus fürs Infofenster und die Liste: "Rubin: +20 % Schaden".
static func describe(b: Dictionary) -> String:
	return "%s: %s %s" % [TranslationServer.translate(str(Database.towers.get(str(b.id), {}).get("name", b.id))),
			value_text(float(b.value)), TranslationServer.translate(stat_name(str(b.stat)))]


# --- Speichern und Koop ----------------------------------------------------------

func to_dict() -> Dictionary:
	return {"boons": boons.duplicate(true), "offers": offers.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	boons = []
	offers = []
	for list in d.get("boons", []):
		boons.append(_clean(list))
	for list in d.get("offers", []):
		offers.append(_clean(list))
	_ensure_players()


static func _clean(list) -> Array:
	var out := []
	if not list is Array:
		return out
	for b in list:
		if b is Dictionary and Database.towers.has(str(b.get("id", ""))) and str(b.get("stat", "")) in STATS:
			out.append({"id": str(b.id), "kind": str(b.get("kind", "gem")), "stat": str(b.stat),
					"value": float(b.get("value", 0.0)), "rarity": str(b.get("rarity", "common")), "wave": int(b.get("wave", 0))})
	return out


# --- Fenster ---------------------------------------------------------------------

func _process(_delta: float) -> void:
	if game == null or game.hud == null:
		return
	var p: int = game.local_player
	var want: bool = game.setup_done and pending(p) and game.phase < game.Phase.GAME_OVER
	var key := str(offers[p]) if want else ""
	if key == _panel_key and (want == (_panel != null and is_instance_valid(_panel))):
		return
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	_panel_key = key
	if want:
		_panel = RoguePanel.new()
		_panel.game = game
		_panel.offers = offers[p]
		_panel.boons = boons[p] if p < boons.size() else []
		game.hud.add_child(_panel)
