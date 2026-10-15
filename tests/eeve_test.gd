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
	check(ids.size() == 108, "108 eeve-Tower wie im Original: %d" % ids.size())
	check((Database.towers["eeve_barricade"].eeve.next as Array).size() == 7, "Barrikade wird zu sechs Element-Grundtürmen oder zum Dual-Grundturm")
	check((Database.towers["eeve_dual_element_base_tower"].eeve.next as Array).size() == 15, "Dual-Grundturm hat 15 Dual-Tower")
	var trap_count := ids.filter(func(id): return Database.towers[id].get("kind", "") == "trap").size()
	check(trap_count == 6, "sechs Fallen, eine je Element: %d" % trap_count)
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
	check(game.scene_file_path == Session.EEVE_GAME, "Nochmal spielen startet wieder eeveTD (gleiche Szene)")
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

	# Fallen: ab Elementstufe 4, 900 Gold + 1 Holz, liegen auf dem Weg und versperren ihn nicht
	game.gold = 20000
	game.lumber = 5
	game.food_cap = 60
	check(game.trap_reason("eeve_earthbind_trap") != "", "Falle ohne Erde 4 gesperrt")
	game.elements.earth = 4
	check(game.trap_reason("eeve_earthbind_trap") == "", "Falle mit Erde 4 baubar")
	var path: PackedVector2Array = game.pathfinder.compute_path()
	var length_before: float = game.path_length
	var spot: Vector2i = game.NO_CELL
	# gleich hinter dem Start, damit die Gegner darüber laufen, bevor die Tower sie töten
	for i in range(2, path.size()):
		var a := Vector2i(path[i]) - Vector2i.ONE  # Wegpunkte sind Felder
		if game.can_build_trap("eeve_earthbind_trap", a):
			spot = a
			break
	check(spot != game.NO_CELL, "Platz für eine Falle auf dem Weg gefunden")
	var gold_trap: int = game.gold
	check(game.submit({"type": "trap", "id": "eeve_earthbind_trap", "cell": spot}), "Erdfessel-Falle bauen")
	var trap: Tower = game.traps.get(spot)
	check(trap != null and trap is EeveTower and game.gold == gold_trap - 900 and game.lumber == 4, "Falle kostet 900 Gold und 1 Holz")
	game._update_paths()
	check(is_equal_approx(game.path_length, length_before), "Falle versperrt den Weg nicht")
	check(not game.can_build(spot) and not game.can_build_trap("eeve_earthbind_trap", spot), "auf der Falle kann nichts anderes stehen")

	# Dual-Tower: Barrikade → Dual-Grundturm (ab 3 + 3) → kostenlos zum Dual-Tower der beiden Elemente
	var dcell := Vector2i(10, 60)
	check(game.submit({"type": "build", "cell": dcell}), "Barrikade für den Dual-Tower")
	var d: Tower = game.towers.get(dcell)
	var dopts: Array = game.tower_options(d)
	var di: int = dopts.map(func(o): return o.id).find("eeve_dual_element_base_tower")
	check(di >= 0 and dopts[di].reason != "", "Dual-Grundturm ohne zwei Elemente auf 3 gesperrt")
	game.elements.water = 3
	game.elements.nature = 3
	dopts = game.tower_options(d)
	check(dopts[di].reason == "" and int(dopts[di].cost) == 1998 and int(dopts[di].lumber) == 1, "Dual-Grundturm: 1998 Gold + 1 Holz")
	check(game.submit({"type": "option", "tower": game.tower_ref(d), "index": di, "action": "eeve_upgrade", "id": "eeve_dual_element_base_tower"}),
		"zum Dual-Grundturm aufwerten")
	dopts = game.tower_options(d)
	var dual_ids: Array = dopts.filter(func(o): return o.action == "eeve_upgrade").map(func(o): return o.id)
	# Erde ist von der Falle auf 4: Wasser + Natur, Wasser + Erde, Erde + Natur
	dual_ids.sort()
	check(dual_ids == ["eeve_acid_fountain", "eeve_gaea_spring", "eeve_thornweed_field"],
		"nur Dual-Tower, deren beide Elemente auf 3 sind: %s" % [dual_ids])
	var gold_dual: int = game.gold
	check(game.submit({"type": "option", "tower": game.tower_ref(d), "index": 0, "action": "eeve_upgrade", "id": "eeve_acid_fountain"}),
		"zum Säurebrunnen aufwerten")
	check(d.tower_id == "eeve_acid_fountain" and game.gold == gold_dual, "Dual-Tower kostenlos")
	check(is_equal_approx(d.damage_bonus, 0.3), "Elementbonus Dual-Tower aus beiden Elementen: %s" % d.damage_bonus)

	# Zeitkristall betäubt alle Gegner, Wolke nimmt einmalig Leben: Level 2 spielen
	game.elements.magic = 3
	var ccell := Vector2i(14, 60)
	while not game.can_build(ccell) and ccell.x < 80:
		ccell.x += 2
	check(game.submit({"type": "build", "cell": ccell}), "Barrikade für den Zeitkristall")
	var c: Tower = game.towers.get(ccell)
	c.set_tower("eeve_icy_time_crystal", 0)
	game.submit({"type": "start_level"})
	await get_tree().process_frame
	Engine.time_scale = 8.0
	var stunned := false
	frames = 0
	while game.phase == game.Phase.WAVE and frames < 20000:
		await get_tree().process_frame
		frames += 1
		if not stunned:
			stunned = game.enemies.any(func(e): return e.stun_time > 0.0)
	Engine.time_scale = 1.0
	check(game.phase == game.Phase.BUILD and game.wave_index == 2, "Level 2 vorbei")
	check(stunned, "Zeitsperre des Eisigen Zeitkristalls betäubt Gegner")
	var ground: bool = not Database.enemies[str(game.waves[1].groups[0].enemy)].get("flying", false)
	check(not ground or trap.total_damage > 0.0, "Falle trifft Bodengegner, die darüber laufen (Schaden %d)" % trap.total_damage)

	# Kegelangriff (Feuerspeiender Schneemann): trifft im Kegel vor dem Tower, nicht daneben oder dahinter
	c.set_tower("eeve_fire_breathing_snowman", 0)
	var probes := {}
	for k in ["ziel", "im_kegel", "daneben", "dahinter"]:
		var en := Enemy.new()
		en.game = game
		en.max_hp = 1e7
		en.hp = 1e7
		probes[k] = en
	probes.ziel.pos = c.pos + Vector2(2.0, 0.0)
	probes.im_kegel.pos = c.pos + Vector2(4.0, 1.0)
	probes.daneben.pos = c.pos + Vector2(2.0, 2.0)
	probes.dahinter.pos = c.pos + Vector2(-1.0, 0.0)
	var keep: Array = game.enemies
	game.enemies = probes.values()
	c._attack(probes.ziel)
	game.enemies = keep
	check(probes.ziel.hp < 1e7 and probes.im_kegel.hp < 1e7, "Kegel trifft Ziel und Gegner im Kegel")
	check(probes.daneben.hp == 1e7 and probes.dahinter.hp == 1e7, "Kegel trifft nichts daneben oder hinter dem Tower")
	for en in probes.values():
		en.free()
	print("eeve: %d Fehler" % failures)
	get_tree().quit(1 if failures > 0 else 0)
