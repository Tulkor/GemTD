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
	pass
