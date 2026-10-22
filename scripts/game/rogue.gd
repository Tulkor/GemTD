class_name Rogue
extends Node
## GemTD-Variante Roguelike (Regeln und Boni in data/roguelike.json): nach jeder zehnten Welle bekommt jeder
## Spieler drei zufällige Boni angeboten und wählt einen. Arten (Feld "effect"):
##   stat         mehr Schaden, Tempo oder Reichweite für einen Tower (Grund-Gem in allen Stufen oder Spezialtower)
##   ability      der Tower bekommt eine Fähigkeit aus dem Pool dazu (auch "Abpraller" = chain)
##   anti_air     Bodentower greifen auch Flieger an
##   flask        Treffer eines Grund-Gems hinterlassen Elementflächen am Boden (Feuer, Gift, Frost, Diamant …)
##   global       double_pick, pct_damage, execute, explode, gold, interest, luck (alle eigenen Tower bzw. der Spieler)
## Würfeln, Flächen und Gegner-Zustände rechnet nur der Host (Befehl rogue_pick über game.submit), Mitspieler
## bekommen die Boni über coop_sync. Gegnerwerte im Roguelike: data/roguelike_enemies.json (enemy_def).
## Das Auswahlfenster (rogue_panel.gd) öffnet sich von selbst, solange ein Angebot offen ist.

const STATS := ["damage", "speed", "range"]
const MAX_PATCHES := 60
const FROST_DECAY := 0.5   ## so schnell (s pro s) taut die Frost-Zeit außerhalb der Flächen wieder ab

var game  # game.gd
## Je Spieler die gewählten Boni: [{boon, effect, id, kind ("gem"/"special"/"global"), rarity, params, stat, value, wave}]
var boons: Array = []
## Je Spieler das offene Angebot (leer = nichts zu wählen), Einträge wie in boons
var offers: Array = []
## Je Spieler: wie viele Gems er in dieser Auswahlphase noch zusätzlich behalten darf (Doppelfund)
var extra_keeps: Array = []

## Flächen am Boden: {pos, radius, time, left, kind, params, tower, dps, mesh}
var patches: Array = []
var _states: Dictionary = {}       ## Gegner -> Zustand der Flächen-Wirkungen
var _patch_ready: Dictionary = {}  ## Tower -> Zeit, ab der er wieder eine Fläche legt
var _booms: Array = []             ## Explosionen getöteter Gegner, im nächsten Bild
var _time := 0.0
var _panel: Control = null
var _panel_key := ""


func _init(g = null) -> void:
	game = g
	name = "Rogue"


static func rules() -> Dictionary:
	return Database.roguelike


static func boon_def(id: String) -> Dictionary:
	for b in rules().get("boons", []):
		if str(b.get("id", "")) == id:
			return b
	return {}


func _ensure_players() -> void:
	var n: int = game.players.size()
	for list in [boons, offers]:
		while list.size() < n:
			list.append([])
	while extra_keeps.size() < n:
		extra_keeps.append(0)


## Beginn einer Bauphase: Flächen weg, Zinsen, Doppelfund, nach jeder every-ten Welle ein Angebot würfeln.
func on_build() -> void:
	_ensure_players()
	clear_field()
	for p in game.players.size():
		var rate := global_sum(p, "interest", "rate")
		if rate > 0.0:
			game.players[p].gold += mini(floori(game.players[p].gold * rate), int(global_sum(p, "interest", "max")))
		var every := int(boon_def("double_pick").get("every", 3))
		extra_keeps[p] = count(p, "double_pick") if every > 0 and game.current_wave() % every == 0 else 0
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
	var b: Dictionary = offers[p][index].duplicate(true)
	b.wave = game.wave_index
	boons[p].append(b)
	offers[p] = []
	game._update_auras()
	return true


## Doppelfund: darf Spieler p noch einen Gem zusätzlich behalten? Zählt ihn dann gleich ab.
func take_extra_keep(p: int) -> bool:
	if p < 0 or p >= extra_keeps.size() or extra_keeps[p] <= 0:
		return false
	extra_keeps[p] -= 1
	return true


func extra_keeps_left(p: int) -> int:
	return extra_keeps[p] if p >= 0 and p < extra_keeps.size() else 0


## Wie oft Spieler p einen Bonus dieser Art hat.
func count(p: int, effect: String) -> int:
	if p < 0 or p >= boons.size():
		return 0
	return boons[p].filter(func(b): return str(b.effect) == effect).size()


## Summe eines Werts über alle globalen Boni dieser Art von Spieler p.
func global_sum(p: int, effect: String, key: String) -> float:
	var sum := 0.0
	if p >= 0 and p < boons.size():
		for b in boons[p]:
			if str(b.effect) == effect:
				sum += float(b.params.get(key, 0.0))
	return sum


func gold_factor(p: int) -> float:
	return 1.0 + global_sum(p, "gold", "bonus")


func luck(p: int) -> int:
	return int(global_sum(p, "luck", "levels"))


## Was auf Tower t wirkt: {damage, speed, range, abilities, anti_air, flasks, pct, execute}.
func bonus_for(t) -> Dictionary:
	var out := {"damage": 0.0, "speed": 0.0, "range": 0.0, "abilities": [], "anti_air": false, "flasks": [], "pct": {}, "execute": {}}
	var p: int = t.owner_player
	if p < 0 or p >= boons.size():
		return out
	for b in boons[p]:
		var e := str(b.effect)
		if b.kind == "global":
			if e == "pct_damage":
				out.pct = {"pct": float(out.pct.get("pct", 0.0)) + float(b.params.pct), "boss_factor": float(b.params.get("boss_factor", 0.25))}
			elif e == "execute":
				out.execute = {"chance": float(out.execute.get("chance", 0.0)) + float(b.params.chance),
						"boss_pct": maxf(float(out.execute.get("boss_pct", 0.0)), float(b.params.get("boss_pct", 0.05)))}
			continue
		if t.is_trap() or str(b.id) != t.tower_id:
			continue
		match e:
			"stat":
				out[str(b.stat)] += float(b.value)
			"ability":
				out.abilities.append(b.params)
			"anti_air":
				out.anti_air = true
			"flask":
				out.flasks.append(b.params)
	return out


## Bisheriger Zuschlag von Spieler p auf Tower id und Wert stat.
func total(p: int, id: String, stat: String) -> float:
	var sum := 0.0
	if p >= 0 and p < boons.size():
		for b in boons[p]:
			if str(b.effect) == "stat" and str(b.id) == id and str(b.stat) == stat:
				sum += float(b.value)
	return sum


# --- Würfeln ---------------------------------------------------------------------

## choices verschiedene Boni (nie zweimal derselbe Bonus für denselben Tower).
func roll(p: int) -> Array:
	var r := rules()
	var rng: RandomNumberGenerator = game.rng
	var out := []
	var seen := {}
	var tries := 0
	while out.size() < int(r.get("choices", 3)) and tries < 80:
		tries += 1
		var def = _pick_weighted(r.get("boons", []), func(b): return float(b.get("weight", 1.0)), rng)
		if def == null:
			break
		var o := _make_offer(def, p, rng)
		if o.is_empty():
			continue
		var key := "%s:%s:%s" % [o.boon, o.id, o.params.get("type", "")]
		if seen.has(key):
			continue
		seen[key] = true
		out.append(o)
	return out


func _make_offer(def: Dictionary, p: int, rng: RandomNumberGenerator) -> Dictionary:
	var effect := str(def.get("effect", "stat"))
	var target := str(def.get("target", "tower"))
	var kind := "global"
	var id := ""
	if target != "global":
		kind = "gem"
		if target == "tower":
			var tw: Dictionary = rules().get("target_weights", {"gem": 1.0, "special": 1.0})
			var g := float(tw.get("gem", 1.0))
			kind = "gem" if rng.randf() * (g + float(tw.get("special", 1.0))) < g else "special"
		id = _roll_target(kind, p, rng, func(tid): return _fits(def, tid))
		if id == "":
			return {}
	var rar = rarity(str(def.fixed_rarity)) if def.has("fixed_rarity") else _pick_weighted(rules().get("rarities", []), func(x): return float(x.get("weight", 1.0)), rng)
	if rar == null:
		rar = rarity("common")
	var scale := float(rar.get("scale", 1.0))
	var o := {"boon": str(def.id), "effect": effect, "id": id, "kind": kind, "rarity": str(rar.get("id", "common")), "params": {}}
	match effect:
		"stat":
			o.stat = str(def.stat)
			o.value = snappedf(float(def.get("value", {}).get(kind, 0.1)) * scale, 0.01)
		"ability":
			var pool: Array = (def.get("pool", []) as Array).filter(func(a): return not _has_ability(id, str(a.type)))
			if pool.is_empty():
				return {}
			o.params = _scaled(pool[rng.randi() % pool.size()], scale)
		"flask":
			var el: Dictionary = def.get("elements", {}).get(id, {})
			o.params = _scaled(el, scale)
			for k in ["radius", "duration", "cooldown"]:
				o.params[k] = float(def.get(k, 1.0))
		"anti_air":
			pass
		_:
			var params := def.duplicate()
			for k in ["id", "effect", "target", "weight", "name", "title", "fixed_rarity"]:
				params.erase(k)
			o.params = _scaled(params, scale)
	return o


## Werte aus "scale" mit der Seltenheit malnehmen (Ganzzahlen bleiben ganz), "cap" begrenzt; beide Felder fallen weg.
static func _scaled(src: Dictionary, scale: float) -> Dictionary:
	var out := src.duplicate(true)
	var caps: Dictionary = out.get("cap", {})
	for k in out.get("scale", []):
		if not out.has(k):
			continue
		var v = out[k]
		var nv := float(v) * scale
		if caps.has(k):
			nv = minf(nv, float(caps[k]))
		out[k] = roundi(nv) if v is int else snappedf(nv, 0.001)
	out.erase("scale")
	out.erase("cap")
	return out


## Passt der Bonus def zu Tower id?
func _fits(def: Dictionary, id: String) -> bool:
	match str(def.get("effect", "stat")):
		"stat":
			return _applies(id, str(def.stat))
		"ability":
			return _applies(id, "damage") and (def.get("pool", []) as Array).any(func(a): return not _has_ability(id, str(a.type)))
		"anti_air":
			return _applies(id, "damage") and _ground_only(id)
		"flask":
			return def.get("elements", {}).has(id) and _applies(id, "damage")
	return true


func _roll_target(kind: String, p: int, rng: RandomNumberGenerator, fits: Callable) -> String:
	var owned := {}
	for t in game.all_towers():
		if t.owner_player == p and not t.is_new:
			owned[t.tower_id] = true
	var ids := []
	for id in Database.towers:
		var def: Dictionary = Database.towers[id]
		if str(def.get("kind", "tower")) == "trap" or str(id).begins_with("eeve_"):
			continue
		if str(def.get("category", "gem")) != kind or not fits.call(id):
			continue
		ids.append(id)
	var w := float(rules().get("owned_weight", 3.0))
	var picked = _pick_weighted(ids, func(id): return w if kind == "special" and owned.has(id) else 1.0, rng)
	return str(picked) if picked != null else ""


static func _pick_weighted(list: Array, weight: Callable, rng: RandomNumberGenerator):
	if list.is_empty():
		return null
	var sum := 0.0
	for x in list:
		sum += float(weight.call(x))
	var roll := rng.randf() * sum
	for x in list:
		roll -= float(weight.call(x))
		if roll <= 0.0:
			return x
	return list[-1]


## Wirkt der Wert stat überhaupt bei Tower id (greift er an, hat er Reichweite)?
static func _applies(id: String, stat: String) -> bool:
	for s in Database.towers.get(id, {}).get("tiers", []):
		var dmg: Array = s.get("damage", [0, 0])
		if float(s.get("cooldown", 0)) > 0.0 and dmg.size() > 1 and float(dmg[1]) > 0.0:
			return stat != "range" or float(s.get("range", 0.0)) > 0.0
	return false


## Hat Tower id die Fähigkeit type schon in irgendeiner Stufe (chain zählt auch für bounce)?
static func _has_ability(id: String, type: String) -> bool:
	var same := ["chain", "bounce"] if type in ["chain", "bounce"] else [type]
	for s in Database.towers.get(id, {}).get("tiers", []):
		for ab in s.get("abilities", []):
			if str(ab.get("type", "")) in same:
				return true
	return false


static func _ground_only(id: String) -> bool:
	var def: Dictionary = Database.towers.get(id, {})
	for s in def.get("tiers", []):
		if str(s.get("targets", def.get("targets", "both"))) == "ground":
			return true
	return false


# --- Texte -----------------------------------------------------------------------

static func rarity(id: String) -> Dictionary:
	for r in rules().get("rarities", []):
		if str(r.get("id", "")) == id:
			return r
	return {"id": id, "name": id, "color": "TEXT", "scale": 1.0}


static func stat_name(stat: String) -> String:
	return str(boon_def(stat).get("name", stat))


static func _tr(s: String) -> String:
	return str(TranslationServer.translate(s))


## "+25 %"
static func value_text(v: float) -> String:
	return "+%d %%" % roundi(v * 100.0)


## Prozent ohne Pluszeichen, unter 10 % mit einer Nachkommastelle: "0,4", "12"
static func pct(v: float) -> String:
	var x := v * 100.0
	return str(roundi(x)) if x >= 10.0 or is_equal_approx(x, roundf(x)) else String.num(x, 1)


## Überschrift der Karte: Name der Fähigkeit, des Elements oder des Bonus.
static func headline(b: Dictionary) -> String:
	match str(b.effect):
		"stat":
			return value_text(float(b.value))
		"ability":
			if str(b.boon) == "ability":
				return _tr(str(Abilities.SCHEMA.get(str(b.params.type), {}).get("label", b.params.type)))
		"flask":
			return _tr(str(b.params.get("name", "")))
	return _tr(str(boon_def(str(b.boon)).get("name", b.boon)))


## Was der Bonus genau macht (ein, zwei Sätze).
static func details(b: Dictionary) -> String:
	var p: Dictionary = b.get("params", {})
	match str(b.effect):
		"stat":
			return _tr(stat_name(str(b.stat)))
		"ability":
			if str(p.type) == "poison":
				return _tr("Gift: %s %% des Tower-Schadens pro Sekunde für %.1fs") % [pct(float(p.dps_factor)), float(p.duration)]
			return Abilities.describe(p)
		"anti_air":
			return _tr("Greift auch Flieger an.")
		"flask":
			return _tr("Treffer hinterlassen alle %.1fs eine Fläche am Boden (%.0fs).") % [float(p.cooldown), float(p.duration)] + " " + _flask_text(p)
		"double_pick":
			return _tr("In jeder %d. Auswahlphase behältst du einen Gem mehr.") % int(p.get("every", 3))
		"pct_damage":
			return _tr("Jeder Treffer macht zusätzlich %s %% der maximalen Leben des Ziels (Bosse: %s %%).") % [pct(float(p.pct)), pct(float(p.pct) * float(p.get("boss_factor", 0.25)))]
		"execute":
			return _tr("%s %% Chance pro Treffer, einen Gegner sofort zu töten. Bosse verlieren stattdessen %s %% ihrer Leben.") % [pct(float(p.chance)), pct(float(p.boss_pct))]
		"explode":
			return _tr("Getötete Gegner explodieren: %s %% ihrer maximalen Leben als Schaden an Gegnern im Umkreis %.1f.") % [pct(float(p.pct)), float(p.radius)]
		"gold":
			return _tr("+%s %% Gold für Kills.") % pct(float(p.bonus))
		"interest":
			return _tr("Zu Beginn jeder Bauphase %s %% Zinsen auf dein Gold (höchstens %d).") % [pct(float(p.rate)), int(p.max)]
		"luck":
			return _tr("Deine Gems würfeln mit %d Chance-Stufe mehr.") % int(p.get("levels", 1))
	return ""


static func _flask_text(p: Dictionary) -> String:
	match str(p.get("element", "")):
		"fire":
			return _tr("Brennt mit %s %% des Tower-DPS pro Sekunde, gegen Gegner ohne Rüstung %s-fach.") % [pct(float(p.dps_factor)), String.num(float(p.unarmored), 1)]
		"acid":
			return _tr("Vergiftet %.0fs lang (%s %% des Tower-DPS pro Sekunde), das Gift frisst %.1f Rüstung pro Sekunde (bis %.0f).") % [float(p.linger), pct(float(p.dps_factor)), float(p.shred), float(p.shred_max)]
		"frost":
			return _tr("%s %% langsamer; wer %.1fs darin steht, friert %.1fs ein.") % [pct(float(p.slow)), float(p.freeze_after), float(p.freeze)]
		"weak":
			return _tr("Gegner werden %.0fs lang mit %s %% mehr Chance kritisch getroffen.") % [float(p.linger), pct(float(p.crit))]
		"vulnerable":
			return _tr("Gegner nehmen %.0fs lang %s %% mehr Schaden.") % [float(p.linger), pct(float(p.amount))]
		"paralyze":
			return _tr("Paralysiert %.0fs lang: alle %.1fs ein Ministun von %.1fs.") % [float(p.linger), float(p.interval), float(p.stun)]
		"wet":
			return _tr("%s %% langsamer und %.0f Rüstung weniger, noch %.0fs danach.") % [pct(float(p.slow)), float(p.amount), float(p.linger)]
	return ""


## Kurzer Text eines Bonus für Listen: "Rubin: Feuerfläche", "Alle: Henker".
static func describe(b: Dictionary) -> String:
	var who := _tr("Alle") if str(b.kind) == "global" else _tr(str(Database.towers.get(str(b.id), {}).get("name", b.id)))
	var what := headline(b)
	if str(b.effect) == "stat":
		what += " " + _tr(stat_name(str(b.stat)))
	return "%s: %s" % [who, what]


# --- Kampf (nur Host) ------------------------------------------------------------

## Nach einem Treffer von Tower t auf Gegner e (tower.gd → _hit): Prozentschaden, Henker, Flächen legen.
func on_hit(t, e) -> void:
	var fx: Dictionary = t.rogue_fx
	if not e.dead and not fx.get("pct", {}).is_empty():
		var p: Dictionary = fx.pct
		_deal(t, e, e.max_hp * float(p.pct) * (float(p.boss_factor) if e.boss else 1.0))
	if not e.dead and not fx.get("execute", {}).is_empty() and randf() < float(fx.execute.chance):
		_deal(t, e, e.max_hp * float(fx.execute.boss_pct) if e.boss or e.final_boss else e.hp + 1.0)
	for f in fx.get("flasks", []):
		if _time >= float(_patch_ready.get(t, 0.0)):
			_patch_ready[t] = _time + float(f.cooldown)
			_add_patch(e.pos, f, t)


## Gegner getötet (game.gd → on_enemy_killed): Kettenreaktion vormerken.
func on_kill(e) -> void:
	var p: int = e.last_hit_by
	var share := global_sum(p, "explode", "pct")
	if share <= 0.0:
		return
	var radius := 0.0
	for b in boons[p]:
		if str(b.effect) == "explode":
			radius = maxf(radius, float(b.params.get("radius", 1.5)))
	_booms.append({"pos": e.pos, "dmg": e.max_hp * share, "radius": radius, "player": p})


func _deal(t, e, amount: float) -> void:
	if amount <= 0.0 or e.dead:
		return
	if t != null and is_instance_valid(t):
		e.last_hit_by = t.owner_player
		t.total_damage += e.take_raw_damage(amount)
		if e.dead:
			t.kills += 1
	else:
		e.take_raw_damage(amount)


## Mittlerer Schaden pro Sekunde des Towers mit allen Zuschlägen (Grundlage für Feuer und Gift).
static func tower_dps(t) -> float:
	var dmg: Array = t.stats.get("damage", [0, 0])
	var avg: float = (float(dmg[0]) + float(dmg[1])) / 2.0 * (1.0 + t.damage_bonus + t.kill_bonus() + t.rogue_damage)
	return avg / maxf(t.cooldown(), 0.05)


func _add_patch(at: Vector2, f: Dictionary, t) -> void:
	if patches.size() >= MAX_PATCHES:
		_free_patch(patches.pop_front())
	var col := Color.from_string(str(f.get("color", "#ffffff")), Color.WHITE)
	var patch := {"pos": at, "radius": float(f.radius), "time": float(f.duration), "left": float(f.duration),
			"params": f, "tower": t, "dps": tower_dps(t) * float(f.get("dps_factor", 0.0)), "color": col}
	patch.mesh = _disc(at, float(f.radius), col)
	patches.append(patch)


func _disc(at: Vector2, radius: float, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	cyl.radial_segments = 24
	cyl.rings = 1
	m.mesh = cyl
	m.material_override = Board3D.make_material(Color(col, 0.4), true, true)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Board3D.to_3d(at, 0.04)
	game.board.add_child(m)
	return m


func _free_patch(p: Dictionary) -> void:
	if p.get("mesh") != null and is_instance_valid(p.mesh):
		p.mesh.queue_free()


## Wellenende: alle Flächen und Zustände weg.
func clear_field() -> void:
	for p in patches:
		_free_patch(p)
	patches.clear()
	_states.clear()
	_patch_ready.clear()
	_booms.clear()


func _state(e) -> Dictionary:
	if not _states.has(e):
		_states[e] = {"acid_t": 0.0, "acid_dps": 0.0, "acid_src": null, "shred": 0.0, "shred_rate": 0.0, "shred_max": 0.0,
				"weak": 0.0, "weak_t": 0.0, "vuln": 0.0, "vuln_t": 0.0, "para_t": 0.0, "para_next": 0.0, "para_interval": 1.5,
				"para_stun": 0.3, "frost": 0.0, "on_frost": false, "freeze_cd": 0.0, "wet": 0.0, "wet_t": 0.0}
	return _states[e]


func _process(delta: float) -> void:
	_update_panel()
	if game == null or game.mirror or not game.is_wave_running():
		return
	_time += delta
	for b in _booms:
		for other in game.enemies_in_radius(b.pos, b.radius):
			if not other.dead:
				other.last_hit_by = b.player
				other.take_raw_damage(b.dmg)
		var flash := {"mesh": _disc(b.pos, b.radius, UiTheme.COIN), "left": 0.3, "time": 0.3, "params": {}, "radius": 0.0, "pos": b.pos}
		patches.append(flash)
	_booms.clear()
	for i in range(patches.size() - 1, -1, -1):
		var p: Dictionary = patches[i]
		p.left -= delta
		if p.left <= 0.0:
			_free_patch(p)
			patches.remove_at(i)
			continue
		if is_instance_valid(p.mesh):
			p.mesh.material_override.albedo_color.a = 0.4 * clampf(p.left / minf(float(p.time), 0.8), 0.0, 1.0)
		if float(p.radius) <= 0.0:
			continue
		for e in game.enemies_in_radius(p.pos, p.radius):
			if not e.dead and not e.flying:
				_on_patch(e, p, delta)
	_tick_states(delta)


## Gegner e steht auf Fläche p.
func _on_patch(e, p: Dictionary, delta: float) -> void:
	var f: Dictionary = p.params
	var s := _state(e)
	match str(f.get("element", "")):
		"fire":
			_deal(p.tower, e, float(p.dps) * delta * (float(f.get("unarmored", 2.0)) if e.effective_armor() <= 0.0 else 1.0))
		"acid":
			s.acid_t = float(f.linger)
			s.acid_dps = maxf(float(s.acid_dps), float(p.dps))
			s.acid_src = p.tower
			s.shred_rate = maxf(float(s.shred_rate), float(f.shred))
			s.shred_max = maxf(float(s.shred_max), float(f.shred_max))
		"frost":
			e.apply_slow(float(f.slow), 0.4)
			s.on_frost = true
			s.frost += delta
			if s.frost >= float(f.freeze_after) and s.freeze_cd <= 0.0:
				e.apply_stun(float(f.freeze))
				s.freeze_cd = float(f.freeze) + float(f.immune)
				s.frost = 0.0
		"weak":
			s.weak = maxf(float(s.weak), float(f.crit))
			s.weak_t = float(f.linger)
		"vulnerable":
			s.vuln = maxf(float(s.vuln), float(f.amount))
			s.vuln_t = float(f.linger)
		"paralyze":
			if s.para_t <= 0.0:
				s.para_next = 0.0
			s.para_t = float(f.linger)
			s.para_interval = float(f.interval)
			s.para_stun = maxf(float(s.para_stun) if s.para_t > 0.0 else 0.0, float(f.stun))
		"wet":
			e.apply_slow(float(f.slow), 0.4)
			s.wet = maxf(float(s.wet), float(f.amount))
			s.wet_t = float(f.linger)


## Nachwirkungen der Flächen (Gift, Schwachstelle, Verwundbar, Paralyse, Frost, Nässe) laufen aus.
func _tick_states(delta: float) -> void:
	for e in _states.keys():
		if not is_instance_valid(e) or e.dead:
			_states.erase(e)
			continue
		var s: Dictionary = _states[e]
		if s.acid_t > 0.0:
			s.acid_t -= delta
			s.shred = minf(float(s.shred) + float(s.shred_rate) * delta, float(s.shred_max))
			e.apply_armor_reduction(float(s.shred), 0.2)
			_deal(s.acid_src, e, float(s.acid_dps) * delta)
			if s.acid_t <= 0.0:
				s.shred = 0.0
				s.acid_dps = 0.0
			if e.dead:
				continue
		s.weak_t -= delta
		if s.weak_t <= 0.0:
			s.weak = 0.0
		e.crit_mark = s.weak
		s.vuln_t -= delta
		if s.vuln_t <= 0.0:
			s.vuln = 0.0
		e.damage_taken = 1.0 + float(s.vuln)
		if s.para_t > 0.0:
			s.para_t -= delta
			s.para_next -= delta
			if s.para_next <= 0.0:
				e.apply_stun(float(s.para_stun))
				s.para_next = float(s.para_interval)
		s.freeze_cd -= delta
		if not s.on_frost:
			s.frost = maxf(0.0, float(s.frost) - FROST_DECAY * delta)
		s.on_frost = false
		if s.wet_t > 0.0:
			s.wet_t -= delta
			e.apply_armor_reduction(float(s.wet), 0.2)


# --- Gegnerwerte -----------------------------------------------------------------

## Gegner im Roguelike: Werte aus data/roguelike_enemies.json über die normalen gelegt.
static func enemy_def(id: String) -> Dictionary:
	var def: Dictionary = Database.enemies.get(id, {})
	var over: Dictionary = Database.roguelike_enemies.get("enemies", {}).get(id, {})
	if over.is_empty():
		return def
	var out := def.duplicate()
	out.merge(over, true)
	return out


# --- Speichern und Koop ----------------------------------------------------------

func to_dict() -> Dictionary:
	return {"boons": boons.duplicate(true), "offers": offers.duplicate(true), "extra_keeps": extra_keeps.duplicate()}


func from_dict(d: Dictionary) -> void:
	boons = []
	offers = []
	for list in d.get("boons", []):
		boons.append(_clean(list))
	for list in d.get("offers", []):
		offers.append(_clean(list))
	extra_keeps = (d.get("extra_keeps", []) as Array).map(func(x): return int(x))
	_ensure_players()


static func _clean(list) -> Array:
	var out := []
	if not list is Array:
		return out
	for b in list:
		if not b is Dictionary:
			continue
		# Stände aus der ersten Fassung (nur Werte) kennen boon/effect/params noch nicht
		var effect := str(b.get("effect", "stat"))
		var id := str(b.get("id", ""))
		if effect != "stat" and boon_def(str(b.get("boon", effect))).is_empty():
			continue
		if str(b.get("kind", "gem")) != "global" and not Database.towers.has(id):
			continue
		if effect == "stat" and not str(b.get("stat", "")) in STATS:
			continue
		var c := {"boon": str(b.get("boon", b.get("stat", effect))), "effect": effect, "id": id, "kind": str(b.get("kind", "gem")),
				"rarity": str(b.get("rarity", "common")), "params": (b.get("params", {}) as Dictionary).duplicate(true), "wave": int(b.get("wave", 0))}
		if effect == "stat":
			c.stat = str(b.stat)
			c.value = float(b.get("value", 0.0))
		out.append(c)
	return out


# --- Fenster ---------------------------------------------------------------------

func _update_panel() -> void:
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
