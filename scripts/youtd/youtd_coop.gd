class_name YoutdCoop
extends RefCounted
## Koop in YouTD (wie YouTD 2): jeder Spieler hat seinen eigenen Weg mit eigenen Wellen, sein Gebiet, Gold, Bücher,
## Elemente, Lager und Tower; Portal-Leben und Wellen-Timer teilen sich alle. Der Host rechnet alles (coop_sync.gd).
## Die Karte ist die Solo-Karte einmal je Spieler (koop_map), Bahn i und Gebiet i gehören Spieler i.
##
## Mitspieler bekommen über coop_snapshot den YouTD-Teil des Stands: Einstellungen, Portal, Timer, je Spieler
## Bücher, Food, Elemente, Lager und Items, je Tower YouTD-ID und Items. Erfahrung, Kills, Schaden und Mana der Tower
## ändern sich laufend und kommen einmal pro Sekunde (coop_stats). Ihre Tower haben einen Kern für Werte und
## Infofenster, aber YtWorld steht still: gerechnet wird nur beim Host. Gegner zeigt coop_sync.gd wie beim Zuschauen,
## Schüsse als Linien (YoutdTower.yt_attacked).

## Solo-Karte base n-mal nebeneinander (zwei Spalten), jede Kopie mit eigener Bahn, eigenem Ziel und Gebiet.
static func koop_map(base: MapData, n: int) -> MapData:
	if n <= 1 or not base.lanes.is_empty():
		return base
	var cols := 2
	var rows := ceili(n / 2.0)
	var m := base.duplicate_map()
	m.id = base.id + "_koop"
	m.width = base.width * cols
	m.height = base.height * rows
	m.rows = PackedStringArray()
	for r in rows:
		for y in base.height:
			var line := ""
			for c in cols:
				line += base.rows[y] if r * cols + c < n else "#".repeat(base.width)
			m.rows.append(line)
	m.spawn_player = 0
	m.lanes = []
	m.zones = [{"rect": Rect2i(0, 0, base.width, base.height), "player": 0}]
	for i in range(1, n):
		var off := Vector2i((i % cols) * base.width, (i / cols) * base.height)
		var cps: Array[Vector2i] = []
		for c in base.checkpoints:
			cps.append(c + off)
		m.lanes.append({"spawn": base.spawn + off, "checkpoints": cps, "player": i, "goal": base.goal + off})
		m.zones.append({"rect": Rect2i(off, Vector2i(base.width, base.height)), "player": i})
	return m


# --- Host → Mitspieler -------------------------------------------------------------------

static func snapshot(g) -> Dictionary:
	var ps := []
	for p in g.yt_players:
		var d := {"builder": p.builder_id, "elements": p.elements.duplicate(), "stash": p.stash.duplicate(),
			"wisdom": p.wisdom.duplicate(), "wisdom_mods": p.wisdom_mods.duplicate(), "notes": p.notes.duplicate(),
			"items": p.item_stash.map(func(it): return _item(it))}
		for f in YoutdSave.PLAYER_FIELDS:
			if f != "score":
				d[f] = p.get(f)
		ps.append(d)
	var ts := {}
	for t in g.all_towers():
		var yt := t as YoutdTower
		if yt != null and yt.core != null:
			ts["%d,%d" % [yt.cell.x, yt.cell.y]] = {"yid": yt.yid, "owner": yt.owner_player, "spent": yt.spent,
				"items": yt.items.map(func(it): return _item(it)), "oils": yt.oils.map(func(it): return _item(it))}
	return {"setup": [g.mode_index, g.length_index, g.difficulty, g.wave_seed], "portal": snappedf(g.portal, 0.01), "foreign_build": g.foreign_build,
		"next_wave": g.next_wave, "timer": ceili(maxf(g.next_wave_in, 0.0)), "waves_done": g.waves_done,
		"alive": g.alive.duplicate(), "players": ps, "towers": ts}


## Was sich laufend ändert (zählt nicht als neuer Stand, kommt mit den Kills und dem Schaden der Tower).
static func stats(g) -> Dictionary:
	var ts := {}
	for t in g.all_towers():
		var yt := t as YoutdTower
		if yt != null and yt.core != null:
			ts["%d,%d" % [yt.cell.x, yt.cell.y]] = [yt.core.get_exp(), yt.core._kill_count, yt.core._damage_dealt_total,
				yt.core.get_mana()]
	return {"towers": ts, "score": g.yt_players.map(func(p): return p.score), "total": g.youtd_score}


static func _item(it: YtItem) -> Array:
	return [it.get_uid(), it.get_id(), it.get_charges() if it.uses_charges() else -1, it.horadric_lock]


# --- Mitspieler -----------------------------------------------------------------------------

static func apply(g, d: Dictionary) -> void:
	var st: Array = d.get("setup", [])
	if st.size() == 4 and (int(st[3]) != g.wave_seed or g.waves.is_empty()):
		g.mode_index = int(st[0])
		g.length_index = int(st[1])
		g.difficulty = int(st[2])
		g.wave_seed = int(st[3])
		g.wave_rng.seed = g.wave_seed
		g.waves = []
		for i in g.wave_count():
			g.waves.append(g._wave(i + 1))
		g.hud.setup_debug(0, g.waves.size())
	g._make_players()
	g.foreign_build = bool(d.get("foreign_build", g.foreign_build))
	g.portal = float(d.get("portal", g.portal))
	g.next_wave = int(d.get("next_wave", g.next_wave))
	g.next_wave_in = float(d.get("timer", g.next_wave_in))
	g.waves_done = int(d.get("waves_done", g.waves_done))
	g.alive = {}
	var al: Dictionary = d.get("alive", {})
	for k in al:
		g.alive[str(k)] = int(al[k])
	var ps: Array = d.get("players", [])
	for i in mini(ps.size(), g.yt_players.size()):
		var pd: Dictionary = ps[i]
		var p: YtPlayer = g.yt_players[i]
		if p.builder_id != str(pd.get("builder", "")) or p.builder == null:
			p.set_builder(str(pd.get("builder", "")))
		for f in YoutdSave.PLAYER_FIELDS:
			if pd.has(f):
				p.set(f, pd[f])
		p.wisdom = (pd.get("wisdom", []) as Array).duplicate()
		p.wisdom_mods = (pd.get("wisdom_mods", {}) as Dictionary).duplicate()
		p.elements = (pd.get("elements", {}) as Dictionary).duplicate()
		p.stash = (pd.get("stash", []) as Array).duplicate()
		p.notes = (pd.get("notes", []) as Array).duplicate()
	# Tower anlegen oder aufwerten (entfernt hat coop_sync.gd sie schon)
	var tds: Dictionary = d.get("towers", {})
	for key in tds:
		var td: Dictionary = tds[key]
		var xy: PackedStringArray = str(key).split(",")
		var cell := Vector2i(int(xy[0]), int(xy[1]))
		var t := g.towers.get(cell) as YoutdTower
		var yid := str(td.get("yid", ""))
		if YoutdData.tower(yid).is_empty():
			continue
		var before: int = g.acting
		g.acting = clampi(int(td.get("owner", 0)), 0, g.yt_players.size() - 1)
		if t == null:
			t = YoutdTower.new()
			t.game = g
			t.cell = cell
			t.owner_player = g.acting
			g.board.add_child(t)
			t.set_youtd(yid)
			g._register(t)
		elif t.yid != yid:
			g._unregister(t)
			t.set_youtd(yid)
			g._register(t)
			if t == g.selected:
				t.set_selected(true)
		g.acting = before
		t.spent = int(td.get("spent", 0))
	_sync_items(g, d)


## Items wie beim Host: dieselben uids, gleiche Orte (Lager je Spieler, Tower, Öle).
static func _sync_items(g, d: Dictionary) -> void:
	var known := {}
	for it in g.world.item_holder().get_children():
		if it is YtItem and not it.is_queued_for_deletion():
			known[it.get_uid()] = it
	var wanted := {}
	var ps: Array = d.get("players", [])
	for i in mini(ps.size(), g.yt_players.size()):
		for e in ps[i].get("items", []):
			wanted[int(e[0])] = true
	var tds: Dictionary = d.get("towers", {})
	for key in tds:
		for e in tds[key].get("items", []) + tds[key].get("oils", []):
			wanted[int(e[0])] = true
	var changed := false
	for uid in known:
		if not wanted.has(uid):
			_detach(known[uid])
			known[uid].queue_free()
			changed = true
	for key in tds:
		var xy: PackedStringArray = str(key).split(",")
		var t := g.towers.get(Vector2i(int(xy[0]), int(xy[1]))) as YoutdTower
		if t == null or t.core == null:
			continue
		var list: Array = tds[key].get("oils", []) + tds[key].get("items", [])
		var want_uids: Array = list.map(func(e): return int(e[0]))
		var have_uids: Array = (t.oils + t.items).map(func(it): return it.get_uid())
		if want_uids == have_uids:
			for e in list:
				_update(known[int(e[0])], e)
			continue
		changed = true
		for it in (t.oils + t.items).duplicate():
			_detach(it)
		for e in list:
			var it := _get_or_make(known, e, YtPlayer.of(t.owner_player))
			if it != null:
				_detach(it)
				it.add_to_tower(t.core)
	for i in mini(ps.size(), g.yt_players.size()):
		var p: YtPlayer = g.yt_players[i]
		var list: Array = ps[i].get("items", [])
		var want_uids: Array = list.map(func(e): return int(e[0]))
		if want_uids != p.item_stash.map(func(it): return it.get_uid()):
			changed = true
			for it in p.item_stash.duplicate():
				_detach(it)
			for e in list:
				var it := _get_or_make(known, e, p)
				if it != null:
					_detach(it)
					p.item_stash.append(it)
					it.place = YtItem.Place.STASH
		for e in list:
			if known.has(int(e[0])):
				_update(known[int(e[0])], e)
	if changed and g.youtd_panel != null:
		g.youtd_panel.items_dirty()


static func _get_or_make(known: Dictionary, e: Array, p: YtPlayer) -> YtItem:
	var uid := int(e[0])
	if known.has(uid):
		return known[uid]
	var it := YtItem.make(int(e[1]), p)
	if it == null:
		return null
	it._uid = uid
	it.name = "item_%d" % uid
	known[uid] = it
	_update(it, e)
	return it


static func _update(it: YtItem, e: Array) -> void:
	if int(e[2]) >= 0 and it.get_charges() != int(e[2]):
		it.set_charges(int(e[2]))
	it.horadric_lock = bool(e[3])


## Item von seinem Ort lösen (Lager oder Tower), danach liegt es nirgends.
static func _detach(it: YtItem) -> void:
	if it.place == YtItem.Place.TOWER:
		var c: YtTower = it._carrier
		if c != null and is_instance_valid(c) and c.body != null and is_instance_valid(c.body):
			c.body.items.erase(it)
			c.body.oils.erase(it)
			it._remove_from_tower()
		else:
			it._carrier = null
	elif it.place == YtItem.Place.STASH:
		it.get_player().item_stash.erase(it)
	it.place = YtItem.Place.NONE


static func apply_stats(g, d: Dictionary) -> void:
	var ts: Dictionary = d.get("towers", {})
	for key in ts:
		var xy: PackedStringArray = str(key).split(",")
		var t := g.towers.get(Vector2i(int(xy[0]), int(xy[1]))) as YoutdTower
		if t == null or t.core == null:
			continue
		var v: Array = ts[key]
		var diff := float(v[0]) - t.core.get_exp()
		if diff > 0.001:
			t.core.add_exp_flat(diff)
		elif diff < -0.001:
			t.core.remove_exp_flat(-diff)
		t.core._kill_count = int(v[1])
		t.core._damage_dealt_total = float(v[2])
		t.core.set_mana(float(v[3]))
	var sc: Array = d.get("score", [])
	for i in mini(sc.size(), g.yt_players.size()):
		g.yt_players[i].score = float(sc[i])
	g.youtd_score = float(d.get("total", g.youtd_score))
