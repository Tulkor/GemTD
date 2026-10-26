extends Node
## Lauf: einzeln
## Randgruppen TD: Daten, Karte und ein kurzes Spiel (Rasse, bauen, Weg offen, Endtower gesperrt, Level 1, verkaufen).
## Start: godot --headless --path . res://tests/randgruppen_test.tscn (oder tools/run_tests.sh randgruppen)

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	RunHistory.path = "user://test_run_history.json"
	Profile.dir = "user://test_profile"
	await get_tree().process_frame
	var rules: Dictionary = Database.randgruppen
	check(not rules.is_empty(), "data/randgruppen.json geladen")
	var races: Array = rules.get("races", [])
	check(races.size() == 11, "11 Rassen: %d" % races.size())
	var broken := []
	for r in races:
		var list: Array = r.towers
		if list.size() != 7:
			broken.append("%s hat %d Tower" % [r.id, list.size()])
		for id in list:
			if not Database.towers.has(id):
				broken.append(id)
		var ult: Dictionary = Database.towers.get(list[-1], {}).get("rg", {})
		if not ult.get("ultimate", false) or int(ult.get("lumber", 0)) != 1 or (ult.get("requires", []) as Array).size() != 6:
			broken.append("Endtower von %s" % r.id)
	check(broken.is_empty(), "jede Rasse hat 7 vorhandene Tower, der letzte ist der Endtower (1 Holz, braucht 6) %s" % [broken])
	var levels: Array = rules.get("levels", [])
	check(levels.size() == 35, "35 Level")
	check(levels.all(func(lv): return Database.enemies.has(str(lv.enemy))), "alle Gegner der Level vorhanden")
	check(Database.enemies[str(levels[4].enemy)].flying and Database.enemies[str(levels[34].enemy)].boss, "Level 5 fliegt, Level 35 ist der Boss")
	check(is_equal_approx(Database.damage_factor("pierce", "rg_small"), 2.0) and is_equal_approx(Database.damage_factor("magic", "rg_large"), 2.0),
		"WC3-Schadenstabelle: Durchbohrend gegen Leicht ×2, Magie gegen Schwer ×2")
	var map := MapData.load_file("res://data/maps/randgruppen.json")
	check(map != null and map.width == 168 and map.zones.size() == 9 and map.lane_count() == 12, "Karte 168 × 168, 9 Zonen, 12 Bahnen")
	var pf := Pathfinder.new(map)
	var bad := range(map.lane_count()).filter(func(i): return pf.compute_path(i).is_empty())
	check(bad.is_empty(), "alle 12 Bahnen haben einen Weg zur Hochburg %s" % [bad])

	# Kurzes Spiel: Kleingartenverein auf Normal
	Session.game_kind = "randgruppen"
	Session.map_path = "res://data/maps/randgruppen.json"
	Session.map_override = null
	Session.skip_setup = false
	Session.rg_choice = {}
	var game: Node = load("res://scenes/rg_game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	check(not game.setup_done and game.gold == 50, "Startfenster offen, 50 Gold (550 − 500 Baumeister)")
	check(game.submit({"type": "setup", "race": "kleingarten", "difficulty": 0}), "Rasse und Schwierigkeit wählen")
	check(game.setup_done and game.lives == 50 and str(game.rp().race) == "kleingarten", "Gemütlich: 50 Leben, Rasse Kleingartenverein")
	check(game.active_lanes().size() == 2 and game.lanes_for("main").size() == 2 and game.lanes_for("two").is_empty(),
		"allein: nur die zwei roten Bahnen")
	var first: String = game.race_towers()[0]
	var zone: Rect2i = map.zones[0].rect
	var built := 0
	for y in range(zone.position.y + 4, zone.end.y - 4, 2):
		for x in range(zone.position.x + 2, zone.end.x - 2, 2):
			if game.gold >= 12 and game.submit({"type": "build", "id": first, "cell": Vector2i(x, y)}):
				built += 1
		if built >= 4:
			break
	check(built == 4 and game.gold == 50 - 4 * 12, "4 Gartenzwerge für je 12 Gold (gebaut %d, Gold %d)" % [built, game.gold])
	check(not game.submit({"type": "build", "id": first, "cell": Vector2i(140, 20)}), "nicht in einer fremden Zone")
	check(not game.submit({"type": "build", "id": "rg_wuehltisch_kunde", "cell": Vector2i(zone.position.x + 20, zone.position.y + 30)}),
		"keine Tower einer anderen Rasse")
	game.gold = 5000
	check(game.build_reason("rg_der_obmann").begins_with("zu wenig Holz"), "Endtower ohne Holz gesperrt: %s" % game.build_reason("rg_der_obmann"))
	game.lumber = 1
	check(game.build_reason("rg_der_obmann") != "", "Endtower braucht die anderen 6 Tower")
	var t: Tower = game.own_towers()[0]
	var gold_before: int = game.gold
	check(game.submit({"type": "option", "tower": game.tower_ref(t), "index": 0, "action": "rg_sell", "id": t.tower_id, "tier": 0})
		and game.gold == gold_before + 9, "verkaufen gibt 75 % zurück (12 → 9)")
	game.gold = 50

	check(game.submit({"type": "start_level"}), "Level 1 sofort starten")
	for i in 3:
		await get_tree().process_frame
	check(game.phase == game.Phase.WAVE, "Level 1 läuft")
	check(game.spawn_queue.size() + game.enemies.size() >= 23, "Level 1: 2 × 12 Gegner an den roten Bahnen")
	Engine.time_scale = 8.0
	var frames := 0
	while game.phase == game.Phase.WAVE and frames < 30000:
		await get_tree().process_frame
		frames += 1
	Engine.time_scale = 1.0
	check(game.phase == game.Phase.BUILD and game.wave_index == 1, "Level 1 vorbei, Pause vor Level 2")
	check(game.enemies_killed + (50 - game.lives) == 24, "alle 24 Gegner getötet oder durch (Kills %d, Leben %d)" % [game.enemies_killed, game.lives])
	check(game.level_pause > 25.0, "30 s Pause nach dem Level")
	game.queue_free()
	await get_tree().process_frame
	print("FERTIG: %d Fehler" % failures)
	get_tree().quit(1 if failures > 0 else 0)

