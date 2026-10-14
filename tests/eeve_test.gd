extends Node
## eeveTD: Daten, Wellen und ein kurzes Spiel (Barrikade bauen, Element setzen, aufwerten, Level 1 spielen).
## Start: godot --headless --path . res://tests/eeve_test.tscn (oder tools/run_tests.sh eeve)

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	RunHistory.path = "user://test_run_history.json"
	await get_tree().process_frame
	var rules: Dictionary = Database.eeve
	check(not rules.is_empty(), "data/eeve.json geladen")
	var ids: Array = Database.tower_ids().filter(func(id): return str(Database.towers[id].get("category", "")) == "eeve")
	check(ids.size() >= 80, "eeve-Tower geladen: %d" % ids.size())
	var broken := []
	for id in ids:
		for n in Database.towers[id].eeve.get("next", []):
			if not Database.towers.has(n):
				broken.append("%s → %s" % [id, n])
	check(broken.is_empty(), "alle Aufwertungen zeigen auf vorhandene Tower %s" % [broken])
	check((Database.towers["eeve_barricade"].eeve.next as Array).size() == 6, "Barrikade wird zu sechs Element-Grundtürmen")
	for s in range(1, 11):
		for kind in ["ground", "ground_mass", "air", "air_mass", "boss"]:
			if EeveWaves.enemy_for(s, kind) == "":
				check(false, "Gegner für Stufe %d %s fehlt" % [s, kind])
	check(EeveWaves.stage_of(5) == 1 and EeveWaves.stage_of(6) == 2 and EeveWaves.stage_of(16) == 3 and EeveWaves.stage_of(54) == 10,
		"Gegnerstufe = abgerundet(Level / 5,5) + 1")
	check(EeveWaves.stage_end(1) == 5 and EeveWaves.stage_end(3) == 16 and EeveWaves.stage_end(10) == 54, "letztes Level je Stufe")

	# Wellen: 57 Level, feste Challenges, HP-Formel
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var hard: Dictionary = rules.difficulties[3]
	var waves := EeveWaves.generate(rules, hard, r)
	check(waves.size() == 57, "57 Level")
	check(waves[10].type == "Challenge" and waves[21].type == "Challenge" and waves[56].groups[0].enemy == "eeve_hoellengolem",
		"Challenges in Level 11, 22 … 57")
	check(waves[0].eeve.kind == "ground" and waves[0].groups[0].count == 10, "Level 1 sind 10 Bodengegner")
	# Level 1 Boden auf Schwer: 500 − 4 · 100 = 100 Leben
	check(is_equal_approx(float(waves[0].groups[0].hp), 100.0), "HP Level 1: %s (erwartet 100)" % waves[0].groups[0].hp)
	var types := {}
	for i in 2000:
		var k := EeveWaves.roll_kind(rules, 20, r)
		types[k] = types.get(k, 0) + 1
	# 20 % Boss, 25 % Luft-Zweig, 55 % Boden-Zweig, in den Zweigen 35 % Masse
	check(absi(types.get("boss", 0) - 400) < 80 and absi(types.get("air", 0) + types.get("air_mass", 0) - 500) < 90
		and absi(types.get("ground", 0) - 715) < 100, "Wellentypen gewürfelt: %s" % [types])
	check(is_equal_approx(Database.damage_factor("electric", "eeve_small"), 1.2) and is_equal_approx(Database.damage_factor("spells", "eeve_hero"), 0.5),
		"Schadenstabelle aus der Karte")

	# Spiel: bauen, Element setzen, aufwerten
	Session.map_path = "res://data/maps/eeve.json"
	Session.map_override = null
	Session.skip_setup = true
	var game: Node = load(Session.EEVE_GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	check(game.gold == 200 and game.lives == 50 and game.food_cap == 40, "Start: 200 Gold, 50 Leben, 40 Food")
	check(game.phase == game.Phase.BUILD and game.level_pause > 0.0, "Pause vor Level 1")
	var cell := Vector2i(30, 60)
	check(game.submit({"type": "build", "cell": cell}), "Barrikade bauen")
	var t: Tower = game.towers.get(cell)
	check(t != null and t.tower_id == "eeve_barricade" and game.gold == 198 and game.food_used() == 1, "Barrikade kostet 2 Gold und 1 Food")
	var opts: Array = game.tower_options(t)
	var nature: int = opts.map(func(o): return o.id).find("eeve_nature_base_tower")
	check(nature >= 0 and opts[nature].reason != "", "Grundturm ohne Elementpunkt gesperrt")
	check(game.submit({"type": "element", "element": "nature"}) and game.elements.nature == 1 and game.points == 0, "Elementpunkt in Natur")
	opts = game.tower_options(t)
	check(game.submit({"type": "option", "tower": game.tower_ref(t), "index": nature, "action": "eeve_upgrade", "id": "eeve_nature_base_tower"}),
		"zum Natur-Grundturm aufwerten")
	check(t.tower_id == "eeve_nature_base_tower" and game.gold == 150, "Grundturm kostet 48 Gold (Gold jetzt %d)" % game.gold)
	check(is_equal_approx(t.damage_bonus, 0.1), "Elementbonus +10 %% je Stufe: %s" % t.damage_bonus)
	# Den Weg zubauen geht nicht
	var blocked := 0
	for x in range(1, 84, 2):
		if game.submit({"type": "build", "cell": Vector2i(x, 70)}):
			blocked += 1
	check(not game.pathfinder.compute_path().is_empty(), "Weg bleibt offen (%d Barrikaden in einer Reihe)" % blocked)

	# Level 1 spielen
	var gold_before: int = game.gold
	game.submit({"type": "start_level"})
	await get_tree().process_frame
	check(game.phase == game.Phase.WAVE, "Level 1 läuft")
	check(game.gold == gold_before + floori(gold_before * 0.05) + 14, "Zinsen und Einkommen zu Level 1 (%d → %d)" % [gold_before, game.gold])
	Engine.time_scale = 8.0
	var frames := 0
	while game.phase == game.Phase.WAVE and frames < 20000:
		await get_tree().process_frame
		frames += 1
	Engine.time_scale = 1.0
	check(game.phase == game.Phase.BUILD and game.wave_index == 1, "Level 1 vorbei, Pause vor Level 2")
	check(game.enemies_killed + (50 - game.lives) / 4 >= 10, "alle 10 Gegner getötet oder durch (Kills %d, Leben %d)" % [game.enemies_killed, game.lives])
	check(game.food_cap == 42, "Food nach Level 1: %d (erwartet 42)" % game.food_cap)
	print("eeve: %d Fehler" % failures)
	get_tree().quit(1 if failures > 0 else 0)
