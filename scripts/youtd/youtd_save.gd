class_name YoutdSave
extends RefCounted
## Spielstand für YouTD: was game.gd/save_game.gd nicht kennt, steht unter "mode" (save_extra). Wellen kommen aus
## dem Seed neu, dazu die Zufallszustände; je Spieler Bücher, Food, Elemente, Lager, Baumeister und Weisheit;
## Tower mit Erfahrung, Kills, Mana, Items, Ölen und Abklingzeiten der Zauber; Gegner mit Leben, Bahn und Strecke;
## auf beiden die laufenden Buffs mit Zeitlimit (Stufe, Restzeit, Verursacher, Zähler). Dauerhafte Buffs (Auren,
## Item- und Tower-Auslöser) bauen Tower und Items beim Laden selbst wieder auf. Was Tower-Skripte sonst nur in sich
## tragen (eigene Zähler), geht verloren.

const PLAYER_FIELDS := ["tomes", "food_cap", "can_reroll", "score", "range_bonus", "tower_exp_bonus", "element_max_bonus",
	"tower_max_bonus", "level_at_start", "builder_wisdom_multiplier", "income_rate", "interest_rate"]


static func capture(g) -> Dictionary:
	var ps := []
	for p in g.yt_players:
		var d := {"builder": p.builder_id, "elements": p.elements.duplicate(), "stash": p.stash.duplicate(),
			"wisdom": p.wisdom.duplicate(), "wisdom_mods": p.wisdom_mods.duplicate(), "notes": p.notes.duplicate(),
			"items": p.item_stash.map(func(it): return item_dict(it))}
		for f in PLAYER_FIELDS:
			d[f] = p.get(f)
		ps.append(d)
	var ts := []
	for t in g.all_towers():
		var yt := t as YoutdTower
		if yt == null or yt.core == null:
			continue
		ts.append({"yid": yt.yid, "cell": yt.cell, "owner": yt.owner_player, "spent": yt.spent, "exp": yt.core.get_exp(),
			"kills": yt.core._kill_count, "dmg": yt.core._damage_dealt_total, "best": yt.core._best_hit,
			"mana": yt.core.get_mana(), "items": yt.items.map(func(it): return item_dict(it)),
			"oils": yt.oils.map(func(it): return item_dict(it)), "buffs": buffs_of(yt.core),
			"cds": yt.autocasts().map(func(ac): return ac.get_remaining_cooldown())})
	var es := []
	for e in g.enemies:
		var ye := e as YoutdEnemy
		if ye == null or ye.dead or ye.core == null:
			continue
		es.append({"id": ye.net_id, "size": ye.creep_size, "race": ye.race, "level": ye.level, "lane": ye.lane,
			"base_hp": ye.base_hp, "armor": ye.base_armor, "armor_type": ye.armor_type, "specials": ye.specials.duplicate(),
			"health": ye.core.get_health(), "traveled": ye.traveled, "final": ye.final_boss, "buffs": buffs_of(ye.core)})
	return {
		"mode": g.mode_index, "length": g.length_index, "difficulty": g.difficulty, "seed": g.wave_seed, "foreign_build": g.foreign_build,
		"wave_rng": g.wave_rng.state, "roll_rng": g.roll_rng.state, "synced_rng": YtGlobals.synced_rng.state,
		"portal": g.portal, "score": g.youtd_score, "next_wave": g.next_wave, "next_wave_in": g.next_wave_in,
		"waves_done": g.waves_done, "alive": g.alive.duplicate(),
		"spawners": g.spawners.map(func(s): return {"level": int(s.wave.level), "index": s.index, "timer": s.timer, "lane": s.get("lane", 0)}),
		"players": ps, "towers": ts, "enemies": es,
	}


## Buffs mit Zeitlimit einer Einheit: [Typ, Verursacher, Stufe, Restzeit, Dauer, Stapel, user_int×3, user_real×3].
static func buffs_of(u: YtUnit) -> Array:
	var out := []
	for b in u.get_buff_list():
		if not is_instance_valid(b) or b._time <= 0.0 or b._timer == null or b.get_remaining_duration() <= 0.0:
			continue
		out.append([b._buff_type_name, unit_ref(b._caster), b._level, b.get_remaining_duration(), b._time, b._displayed_stacks,
			b.user_int, b.user_int2, b.user_int3, b.user_real, b.user_real2, b.user_real3])
	return out


## Verweis auf eine Einheit, der ein Laden übersteht: Tower über das Feld, Gegner über ihre Nummer.
static func unit_ref(u) -> Array:
	if u == null or not is_instance_valid(u) or u.body == null:
		return []
	if u is YtTower:
		return ["t", u.body.cell.x, u.body.cell.y]
	return ["e", u.body.net_id]


static func _unit_from_ref(g, r: Array) -> YtUnit:
	if r.is_empty():
		return null
	if str(r[0]) == "t":
		var t := g.towers.get(Vector2i(int(r[1]), int(r[2]))) as YoutdTower
		return t.core if t != null else null
	for e in g.enemies:
		if e.net_id == int(r[1]) and e is YoutdEnemy:
			return e.core
	return null


## Buffs wieder anlegen (nachdem alle Tower und Gegner stehen). Den Buff-Typ liefert das Skript des Verursachers
## (gleicher Name, gehört zum Tower des Verursachers), sonst irgendeiner mit dem Namen auf diesem Feld.
static func _restore_buffs(g, target: YtUnit, list: Array) -> void:
	if target == null:
		return
	for b in list:
		var caster := _unit_from_ref(g, b[1])
		var bt := _buff_type(g, str(b[0]), caster)
		if bt == null:
			continue
		var buff := bt.apply_custom_timed(caster if caster != null else target, target, int(b[2]), float(b[4]))
		if buff == null or not is_instance_valid(buff) or buff._cleanup_done:
			continue
		buff.set_remaining_duration(float(b[3]))
		buff._displayed_stacks = int(b[5])
		buff.user_int = int(b[6])
		buff.user_int2 = int(b[7])
		buff.user_int3 = int(b[8])
		buff.user_real = float(b[9])
		buff.user_real2 = float(b[10])
		buff.user_real3 = float(b[11])


static func _buff_type(g, type_name: String, caster: YtUnit) -> YtBuffType:
	var any: YtBuffType = null
	for bt in g.get_tree().get_nodes_in_group("yt_buff_types"):
		if bt._unique_name != type_name or bt.is_queued_for_deletion() or not g.board.is_ancestor_of(bt):
			continue
		var owner = bt.get_parent()
		if caster != null and owner is YtTowerBehavior and owner.get_tower() == caster:
			return bt
		if any == null:
			any = bt
	return any


static func item_dict(it: YtItem) -> Dictionary:
	return {"id": it.get_id(), "uid": it.get_uid(), "charges": it.get_charges() if it.uses_charges() else -1,
		"lock": it.horadric_lock, "ui": [it.user_int, it.user_int2, it.user_int3], "ur": [it.user_real, it.user_real2, it.user_real3]}


## Item aus einem Eintrag von item_dict neu anlegen (noch an keinem Ort).
static func make_item(d: Dictionary, p: YtPlayer) -> YtItem:
	var it := YtItem.make(int(d.get("id", 0)), p)
	if it == null:
		return null
	var ui: Array = d.get("ui", [0, 0, 0])
	var ur: Array = d.get("ur", [0.0, 0.0, 0.0])
	it.user_int = int(ui[0])
	it.user_int2 = int(ui[1])
	it.user_int3 = int(ui[2])
	it.user_real = float(ur[0])
	it.user_real2 = float(ur[1])
	it.user_real3 = float(ur[2])
	it.horadric_lock = bool(d.get("lock", false))
	if int(d.get("charges", -1)) >= 0:
		it.set_charges(int(d.charges))
	return it


## Stand in ein frisch aufgebautes Spiel übernehmen (YtWorld steht schon, Gold und Phase hat SaveGame.apply gesetzt).
static func restore(g, d: Dictionary) -> void:
	g.mode_index = int(d.get("mode", 0))
	g.length_index = int(d.get("length", 1))
	g.difficulty = int(d.get("difficulty", 2))
	g.foreign_build = bool(d.get("foreign_build", false))
	g.wave_seed = int(d.get("seed", 0))
	g.wave_rng.seed = g.wave_seed
	g.waves = []
	for i in g.wave_count():
		g.waves.append(g._wave(i + 1))
	g.wave_rng.state = int(d.get("wave_rng", g.wave_rng.state))
	g.roll_rng.seed = g.wave_seed * 31 + 7
	g.roll_rng.state = int(d.get("roll_rng", g.roll_rng.state))
	YtGlobals.synced_rng.seed = g.wave_seed * 17 + 3
	YtGlobals.synced_rng.state = int(d.get("synced_rng", YtGlobals.synced_rng.state))
	Session.set_meta("youtd_choice", {"mode": g.mode_index, "length": g.length_index, "difficulty": g.difficulty})
	g._make_players()
	var pls: Array = d.get("players", [])
	for i in mini(pls.size(), g.yt_players.size()):
		var pd: Dictionary = pls[i]
		var p: YtPlayer = g.yt_players[i]
		p.level_at_start = int(pd.get("level_at_start", 0))
		p.set_builder(str(pd.get("builder", "")))
		p.wisdom = (pd.get("wisdom", []) as Array).duplicate()
		for f in PLAYER_FIELDS:
			if pd.has(f):
				p.set(f, pd[f])
		p.wisdom_mods = {}
		var mods: Dictionary = pd.get("wisdom_mods", {})
		for k in mods:
			p.wisdom_mods[str(k)] = float(mods[k])
		p.elements = {}
		var els: Dictionary = pd.get("elements", {})
		for el in els:
			p.elements[str(el)] = int(els[el])
		p.stash = (pd.get("stash", []) as Array).map(func(id): return str(id))
		p.notes = (pd.get("notes", []) as Array).duplicate()
		for idd in pd.get("items", []):
			var it := make_item(idd, p)
			if it != null:
				g.stash_add(it)
	for td in d.get("towers", []):
		_restore_tower(g, td)
	if g.phase == g.Phase.WAVE:
		for ed in d.get("enemies", []):
			_restore_enemy(g, ed)
	# Buffs erst jetzt: Verursacher können Tower oder Gegner sein, die später im Stand stehen
	for td in d.get("towers", []):
		var t := g.towers.get(td.get("cell", Vector2i.ZERO)) as YoutdTower
		if t != null and t.core != null:
			_restore_buffs(g, t.core, td.get("buffs", []))
	if g.phase == g.Phase.WAVE:
		for ed in d.get("enemies", []):
			for e in g.enemies:
				if e.net_id == int(ed.get("id", -1)) and e is YoutdEnemy:
					_restore_buffs(g, e.core, ed.get("buffs", []))
	g.spawners = []
	for s in d.get("spawners", []):
		var lvl := int(s.get("level", 1))
		if lvl >= 1 and lvl <= g.waves.size():
			g.spawners.append({"wave": g.waves[lvl - 1], "index": int(s.index), "timer": float(s.timer), "lane": int(s.get("lane", 0))})
	g.alive = {}
	var al: Dictionary = d.get("alive", {})
	for k in al:
		g.alive[str(k)] = int(al[k])
	g.portal = float(d.get("portal", 100.0))
	g.youtd_score = float(d.get("score", 0.0))
	g.next_wave = int(d.get("next_wave", 1))
	g.next_wave_in = float(d.get("next_wave_in", 15.0))
	g.waves_done = int(d.get("waves_done", 0))
	g.setup_done = true
	g.hud.setup_debug(0, g.waves.size())


static func _restore_tower(g, d: Dictionary) -> void:
	var yid := str(d.get("yid", ""))
	var cell: Vector2i = d.get("cell", Vector2i.ZERO)
	if YoutdData.tower(yid).is_empty():
		return
	var before: int = g.acting
	g.acting = clampi(int(d.get("owner", 0)), 0, g.yt_players.size() - 1)
	var t := YoutdTower.new()
	t.game = g
	t.cell = cell
	t.owner_player = g.acting
	g.board.add_child(t)
	t.set_youtd(yid)
	g._register(t)
	g.acting = before
	t.spent = int(d.get("spent", 0))
	var core: YtTower = t.core
	core.add_exp_flat(float(d.get("exp", 0.0)))
	core._kill_count = int(d.get("kills", 0))
	core._damage_dealt_total = float(d.get("dmg", 0.0))
	core._best_hit = float(d.get("best", 0.0))
	var p: YtPlayer = YtPlayer.of(t.owner_player)
	for idd in d.get("oils", []) + d.get("items", []):
		var it := make_item(idd, p)
		if it != null:
			it.add_to_tower(core)
	core.set_mana(float(d.get("mana", 0.0)))
	# Abklingzeiten der Zauber (Tower und Items, gleiche Reihenfolge wie beim Speichern)
	var cds: Array = d.get("cds", [])
	var acs: Array = t.autocasts()
	if cds.size() == acs.size():
		for i in acs.size():
			var timer: YtManualTimer = acs[i]._cooldown_timer
			if float(cds[i]) > 0.0 and timer != null:
				var full := timer.wait_time
				timer.start(float(cds[i]))
				timer.wait_time = full


static func _restore_enemy(g, d: Dictionary) -> void:
	var size := str(d.get("size", "normal"))
	var lane := int(d.get("lane", 0))
	var w := {"level": int(d.get("level", 1)), "race": str(d.get("race", "orc")), "armor": float(d.get("armor", 0.0)),
		"armor_type": str(d.get("armor_type", "")), "hp": float(d.get("base_hp", 1.0)), "specials": d.get("specials", [])}
	var e := YoutdEnemy.new()
	e.net_id = int(d.get("id", 0))
	g.board.add_child(e)
	var lp: Dictionary = g.lane_paths[g.lane_index(lane)]
	e.setup_youtd(g, w, size, lp.air if size == "air" else lp.ground, 1.0, float(d.get("base_hp", 1.0)), lane)
	e.final_boss = bool(d.get("final", false))
	e.core.set_health(float(d.get("health", e.core.get_health())))
	e.place_on_path(float(d.get("traveled", 0.0)))
	g.enemies.append(e)
