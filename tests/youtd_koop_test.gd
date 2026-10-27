extends Node
## Lauf: einzeln (Name ytkoop)
## YouTD: Spielstand (Speichern mitten in der Welle, Laden in ein neues Spiel) und Koop ohne Netz (Host und Mitspieler
## als zwei Spiele, Befehle und Stand laufen direkt wie über ENet): eigener Weg und eigenes Gebiet je Spieler,
## gemeinsames Portal und gemeinsamer Wellen-Timer. Start: godot --headless --path . res://tests/youtd_koop_test.tscn

const SCENE := "res://scenes/youtd_game.tscn"

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	RunHistory.path = "user://test_run_history.json"
	Profile.dir = "user://test_profile_youtd_koop"
	Profile.reset_cache()
	Session.map_path = "res://data/maps/youtd.json"
	Session.map_override = null
	Session.skip_setup = false
	Session.game_kind = "youtd"
	await _save_tests()
	await _coop_tests()
	print("YTKOOP TEST ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _wire(v):
	return bytes_to_var(var_to_bytes(v))


## Erster freier Bauplatz von Spieler pid (Anker eines 2×2-Towers) am nächsten zu seinem Weg.
func _anchor(g, pid: int, skip := 0, far := false) -> Vector2i:
	var path: PackedVector2Array = g.lane_paths[g.lane_index(pid)].ground
	var best := []
	for y in g.map.height:
		for x in g.map.width:
			var c := Vector2i(x, y)
			if not g.can_place_for(c, pid):
				continue
			var p := Board3D.footprint_center(c, 2)
			var d := INF
			for q in path:
				d = minf(d, p.distance_to(q))
			best.append([d, c])
	best.sort_custom(func(a, b): return a[0] > b[0] if far else a[0] < b[0])
	var out: Array = []
	for b in best:
		if out.all(func(o): return (o - b[1]).abs().x >= 2 or (o - b[1]).abs().y >= 2):
			out.append(b[1])
		if out.size() > skip:
			break
	return out[skip]


func _wait_for(cond: Callable, frames := 600) -> void:
	var n := 0
	while not cond.call() and n < frames:
		await get_tree().process_frame
		n += 1


# --- Spielstand ---------------------------------------------------------------------

func _save_tests() -> void:
	var game: Node = load(SCENE).instantiate()
	add_child(game)
	await get_tree().process_frame
	check(game.save_mode() == "none", "vor dem Startfenster gibt es nichts zu speichern")
	game.submit({"type": "setup", "mode": 1, "length": 0, "difficulty": 1, "seed": 11, "wisdom": [], "builder": "backpacker", "level": 300})
	check(game.save_mode() == "single", "nach dem Start: selbst speichern")
	game.gold = 5000
	game.tomes = 200
	game.submit({"type": "research", "element": "nature"})
	var p: YtPlayer = game.yp()
	var a: Vector2i = _anchor(game, 0, 0, true)   # weit weg vom Weg, damit die Welle noch läuft
	check(game.debug_place("1", a), "Tower gesetzt")
	var t: YoutdTower = game.towers.get(a)
	var claws := YtItem.make(2, p)
	var oil := YtItem.make(1001, p)
	var spare := YtItem.make(3, p)
	for it in [claws, oil, spare]:
		game.stash_add(it)
	game.submit({"type": "item_put", "tower": game.tower_ref(t), "uid": claws.get_uid()})
	game.submit({"type": "item_put", "tower": game.tower_ref(t), "uid": oil.get_uid()})
	spare.toggle_horadric_lock()
	t.core.add_exp_flat(300.0)
	game.stash.append("2")
	game.submit({"type": "next_wave"})
	await _wait_for(func(): return game.enemies.size() >= 3)
	game.portal = 77.0
	var st: Dictionary = SaveGame.capture(game)
	var want := {"gold": game.gold, "tomes": game.tomes, "nature": int(game.elements.get("nature", 0)), "level": t.level,
		"enemies": game.enemies.size(), "next_wave": game.next_wave, "hp5": float(game.waves[5].hp), "stash": game.stash.duplicate(),
		"dmg": t.mod("MOD_DAMAGE_ADD_PERC"), "alive": game.alive.duplicate(), "food": game.food_cap,
		"items": game.item_stash.size()}
	check(not st.is_empty() and st.has("mode") and (st.mode.towers as Array).size() == 1, "Stand mit YouTD-Teil erfasst")
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	Session.load_state = _wire(st)
	Session.map_override = MapData.from_dict(st.map)
	var g2: Node = load(SCENE).instantiate()
	add_child(g2)
	await get_tree().process_frame
	check(g2.setup_done and g2.phase == g2.Phase.WAVE, "geladen: Einstellungen fertig, Welle läuft")
	check(g2.gold == want.gold and g2.tomes == want.tomes and int(g2.elements.get("nature", 0)) == want.nature and g2.food_cap == want.food,
		"Gold, Bücher, Elemente und Food wie vorher (%d Gold, %d Bücher)" % [g2.gold, g2.tomes])
	check(is_equal_approx(g2.portal, 77.0) and g2.next_wave == want.next_wave and is_equal_approx(float(g2.waves[5].hp), want.hp5),
		"Portal, nächste Welle und Wellen aus dem Seed")
	check(g2.yp().builder_id == "backpacker" and g2.stash == want.stash, "Baumeister und Tower-Lager")
	var t2: YoutdTower = g2.towers.get(a)
	check(t2 != null and t2.yid == "1" and t2.level == want.level, "Tower mit Level %d" % (t2.level if t2 != null else -1))
	check(t2 != null and t2.items.size() == 1 and t2.oils.size() == 1 and is_equal_approx(t2.mod("MOD_DAMAGE_ADD_PERC"), want.dmg),
		"Item und Öl im Tower wirken wieder")
	check(g2.item_stash.size() == want.items and g2.item_stash.any(func(it): return it.get_id() == 3 and it.horadric_lock),
		"Item-Lager mit Sperre (%d Items)" % g2.item_stash.size())
	check(g2.enemies.size() == want.enemies and g2.enemies.all(func(e): return e is YoutdEnemy and e.core != null),
		"Gegner mit Kern zurück: %d" % g2.enemies.size())
	check(g2.alive == want.alive, "Wellenstand je Bahn")
	await _wait_for(func(): return g2.enemies.size() > want.enemies, 300)
	check(g2.enemies.size() > want.enemies or g2.spawners.is_empty(), "Welle läuft nach dem Laden weiter")
	g2.queue_free()
	Session.map_override = null
	await get_tree().process_frame


# --- Koop ------------------------------------------------------------------------------

func _coop_tests() -> void:
	Session.coop = {"role": "host", "player": 0, "names": ["Host", "Gast"]}
	var host: Node = load(SCENE).instantiate()
	add_child(host)
	Session.coop = {"role": "client", "player": 1, "names": ["Host", "Gast"]}
	var client: Node = load(SCENE).instantiate()
	add_child(client)
	await get_tree().process_frame
	check(host.coop != null and client.mirror and client.local_player == 1, "Koop: Host und Mitspieler angelegt")
	YtWorld.use(host)   # die Laufzeit gehört dem Host, der Mitspieler setzt sie nur beim Übernehmen kurz um
	check(host.map.lane_count() == 2 and host.map.width == 148 and client.map.width == 148 and host.map.lane_goal(1) != host.map.goal,
		"Karte: eigener Weg mit eigenem Ziel je Spieler")
	client.coop.command_sink = func(cmd): host.coop.receive(1, _wire(cmd))
	var pump := func():
		client.coop.apply_state(_wire(host.coop.snapshot()))
		client.coop.apply_enemies(_wire(host.coop.enemy_packet()))
	var beginner := ""
	for b in YoutdProgress.builders():
		if b.open and int(b.level) == 0:
			beginner = str(b.id)
			break
	client.submit({"type": "player_setup", "builder": beginner, "wisdom": [], "level": 0})
	client.submit({"type": "setup", "mode": 0, "length": 0, "difficulty": 0, "seed": 1})
	check(not host.setup_done, "nur der Host startet die Partie")
	host.submit({"type": "setup", "mode": 1, "length": 0, "difficulty": 1, "seed": 5, "wisdom": [], "builder": "", "level": 0})
	pump.call()
	check(client.setup_done and client.wave_seed == 5 and is_equal_approx(float(client.waves[7].hp), float(host.waves[7].hp)),
		"Mitspieler übernimmt Einstellungen und Wellen")
	check(beginner != "" and host.yt_players[1].builder_id == beginner and client.yp().builder_id == beginner and host.yt_players[0].builder_id == "",
		"Baumeister je Spieler (%s)" % beginner)
	# Mitspieler erforscht und baut in seinem Gebiet
	var el: String = YoutdData.elements()[0]
	client.submit({"type": "research", "element": el})
	pump.call()
	check(int(host.yt_players[1].elements.get(el, 0)) == 1 and int(host.yt_players[0].elements.get(el, 0)) == 0 and int(client.elements.get(el, 0)) == 1,
		"Elemente je Spieler")
	var id: String = client.buildable()[0] if not client.buildable().is_empty() else ""
	var a1: Vector2i = _anchor(client, 1)
	var a0: Vector2i = _anchor(host, 0)
	check(not host.can_place_for(a0, 1) and not host.can_place_for(a1, 0), "jeder baut nur in seinem Gebiet")
	var gold0: int = host.players[0].gold
	client.submit({"type": "build", "id": id, "cell": a1})
	pump.call()
	var t: YoutdTower = host.towers.get(a1)
	var ct: YoutdTower = client.towers.get(a1)
	check(t != null and t.owner_player == 1 and ct != null and ct.yid == id and ct.core != null, "Host baut den Tower des Mitspielers, er sieht ihn (%s)" % id)
	check(host.players[0].gold == gold0 and host.players[1].gold < gold0 and client.gold == host.players[1].gold, "Gold je Spieler")
	# Items: Fund beim Host, Lager und Einlegen beim Mitspieler
	var claws := YtItem.make(2, host.yt_players[1])
	host.stash_add(claws)
	pump.call()
	check(client.item_stash.size() == 1 and client.item_stash[0].get_uid() == claws.get_uid() and host.yt_players[0].item_stash.is_empty(),
		"Item im Lager des Mitspielers")
	client.submit({"type": "item_put", "tower": client.tower_ref(ct), "uid": claws.get_uid()})
	pump.call()
	check(t.items == [claws] and ct.items.size() == 1 and ct.items[0].get_uid() == claws.get_uid() and client.item_stash.is_empty(),
		"Item im Tower bei beiden (Host %d, Gast %d, Lager %d)" % [t.items.size(), ct.items.size(), client.item_stash.size()])
	check(is_equal_approx(ct.mod("MOD_DAMAGE_ADD_PERC"), t.mod("MOD_DAMAGE_ADD_PERC")), "Item wirkt auch im Infofenster des Mitspielers")
	t.core.add_exp_flat(500.0)
	pump.call()
	check(ct.level == t.level and t.level > 0, "Tower-Level kommt an (%d)" % ct.level)
	# Welle: auf beiden Wegen, gemeinsamer Timer
	client.submit({"type": "next_wave"})
	await _wait_for(func(): return host.enemies.any(func(e): return e.lane == 0) and host.enemies.any(func(e): return e.lane == 1))
	check(host.enemies.any(func(e): return e.lane == 1) and host.enemies.any(func(e): return e.lane == 0), "Welle 1 läuft auf beiden Wegen")
	var lane1: Array = host.enemies.filter(func(e): return e.lane == 1)
	check(lane1[0].path[0].x > 74 * 0.5 * 0.9 if not lane1.is_empty() else false, "Gegner des Gasts laufen auf seiner Kartenhälfte")
	pump.call()
	check(client.phase == client.Phase.WAVE and client.enemies.size() == host.enemies.size() and client.enemies.size() > 0,
		"Gegner gespiegelt: %d" % client.enemies.size())
	host.modify_portal(-10.0)
	host._note("Testmeldung", 1)
	pump.call()
	check(is_equal_approx(client.portal, host.portal) and client.log_lines.has("Testmeldung") and not host.log_lines.has("Testmeldung"),
		"Portal gemeinsam, Meldungen je Spieler")
	var st: Dictionary = SaveGame.capture(host)
	check(host.save_mode() == "single" and (st.mode.players as Array).size() == 2 and st.map.has("lanes"), "Koop-Stand mit beiden Spielern und Karte")
	# Verkaufen: Item zurück ins Lager, Tower weg bei beiden
	var opts: Array = client.tower_options(ct)
	var k: int = opts.map(func(o): return o.action).find("sell")
	client.submit({"type": "option", "tower": client.tower_ref(ct), "index": k, "action": "sell", "id": opts[k].id})
	pump.call()
	check(not host.towers.has(a1) and not client.towers.has(a1) and client.item_stash.size() == 1, "Verkauft: Tower weg, Item zurück im Lager")
	host.queue_free()
	client.queue_free()
	Session.coop = {}
	await get_tree().process_frame
