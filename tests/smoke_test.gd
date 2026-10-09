extends Node
## Automatischer Rauchtest: startet .../godot --headless --path . res://tests/smoke_test.tscn
## Lädt alle Szenen, spielt ein paar Runden automatisch und beendet sich mit Exit-Code 0/1.

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	await get_tree().process_frame
	check(Database.towers.size() >= 8, "Tower geladen: %d" % Database.towers.size())
	check(Database.enemies.size() >= 1, "Gegner geladen: %d" % Database.enemies.size())
	check(not Database.list_maps().is_empty(), "Maps gefunden")

	for m in Database.list_maps():
		var md := MapData.load_file(m.path)
		var pf := Pathfinder.new(md)
		check(not pf.compute_path().is_empty(), "Weg vorhanden auf Map %s" % m.id)
		# Rundreise JSON
		check(MapData.from_dict(md.to_dict()).to_dict() == md.to_dict(), "Map %s speichern/laden verlustfrei" % m.id)

	# Blockieren wird verhindert: Spawn einmauern
	var small := MapData.create_empty(9, 9)
	small.spawn = Vector2i(0, 0)
	small.goal = Vector2i(8, 8)
	small.marker_radius = 0
	var pf2 := Pathfinder.new(small)
	pf2.set_solid(Vector2i(1, 0), true)
	pf2.set_solid(Vector2i(1, 1), true)
	check(pf2.would_block(Vector2i(0, 1)), "letzter Ausgang wird als blockierend erkannt")
	check(not pf2.would_block(Vector2i(4, 4)), "normales Feld blockiert nicht")

	# Halbes Raster: eine Mauer aus 2×2-Towern mit einer Lücke von einem Feld bleibt passierbar
	var gap := MapData.create_empty(12, 11)
	gap.spawn = Vector2i(0, 0)
	gap.goal = Vector2i(11, 0)
	gap.marker_radius = 0
	var pf3 := Pathfinder.new(gap)
	for y in [0, 2, 4, 7, 9]:
		pf3.set_solid_cells(Board3D.footprint(Vector2i(5, y)), true)
	var gap_path := pf3.compute_path()
	check(not gap_path.is_empty() and Vector2i(5, 6) in gap_path, "Gegner passen durch eine Lücke von einer halben Towerbreite")
	check(pf3.would_block_cells(Board3D.footprint(Vector2i(4, 5))), "Tower in der Lücke würde blockieren")

	# Editoren laden
	for scene in [Session.MAP_EDITOR, Session.TOWER_EDITOR, Session.MAIN_MENU]:
		var inst: Node = load(scene).instantiate()
		add_child(inst)
		await get_tree().process_frame
		check(is_instance_valid(inst), "Szene lädt: " + scene)
		inst.queue_free()
		await get_tree().process_frame

	# Spiel automatisch spielen
	Session.map_path = Database.list_maps()[0].path
	var game: Node = load(Session.GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for round_i in 3:
		var placed := 0
		var tries := 0
		while game.phase == game.Phase.BUILD and tries < 5000:
			tries += 1
			# nahe am aktuellen Weg bauen, wie ein Spieler
			var p: Vector2 = game.ground_path[rng.randi_range(0, game.ground_path.size() - 1)]
			var c := Vector2i(p / Board3D.CELL) + Vector2i(rng.randi_range(-3, 1), rng.randi_range(-3, 1))
			if game.can_place(c):
				game.place_gem(c)
				placed += 1
		check(game.phase == game.Phase.CHOOSE, "Runde %d: %d Gems gesetzt, Auswahlphase" % [round_i + 1, placed])
		var t = game.round_towers[0]
		game._select(t)
		check(not game.choice_options(t).is_empty(), "Auswahloptionen vorhanden")
		check(game.hud._options[0].style == "primary" and game.hud._main_button != null, "Behalten ist die große Hauptaktion")
		game._on_option_chosen(0)
		check(game.phase == game.Phase.WAVE, "Welle %d gestartet" % (round_i + 1))
		check(game.towers.size() == round_i + 1, "nur ein Tower behalten, Rest sind Steine (%d Steine)" % game.rocks.size())
		check(game.occupied.size() == 4 * (game.towers.size() + game.rocks.size()), "jeder Tower und Stein belegt 2×2 Felder")
		check(not game.ground_path.is_empty(), "Weg ist noch offen")
		Engine.time_scale = 8.0
		var frames := 0
		while game.phase == game.Phase.WAVE and frames < 20000:
			await get_tree().process_frame
			frames += 1
		print("  Tower-Schaden: ", game.towers.values().map(func(t): return [t.tower_id, t.cell, int(t.total_damage)]))
		check(game.phase == game.Phase.BUILD, "Welle %d beendet (Leben %d, Gold %d)" % [round_i + 1, game.lives, game.gold])

	# Stein entfernen (Bauphase)
	var rock: Vector2i = game.rocks.keys()[0]
	var gold_before: int = game.gold
	check(game.remove_rock(rock), "Stein entfernt")
	check(not game.rocks.has(rock) and game.can_place(rock), "Feld ist wieder bebaubar")
	check(game.gold == gold_before - game.rock_remove_cost(), "Kosten abgezogen")

	# Kombinieren: zwei gleiche Gems -> nächste Stufe, Rezept -> Silber
	game.debug_tower = "ruby:0"
	var cells := []
	var tries2 := 0
	while game.phase == game.Phase.BUILD and tries2 < 5000:
		tries2 += 1
		var c := Vector2i(rng.randi_range(0, game.map.width - 1), rng.randi_range(0, game.map.height - 1))
		if game.can_place(c):
			if game.round_towers.size() == 2: game.debug_tower = "topaz:0"
			if game.round_towers.size() == 3: game.debug_tower = "diamond:0"
			if game.round_towers.size() == 4: game.debug_tower = "sapphire:0"
			game.place_gem(c)
			if game.round_towers.size() == 1:
				check(not game.can_place(c + Vector2i(1, 0)) and not game.can_place(c + Vector2i(1, 1)), "Tower überlappen sich nicht")
	var labels: Array = game.choice_options(game.round_towers[0]).map(func(o): return o.label)
	check(labels.size() == 2, "Rubin: Behalten + 2er-Kombination: %s" % [labels])
	labels = game.choice_options(game.round_towers[2]).map(func(o): return o.label)
	check(labels.any(func(l): return "Silber" in l), "Topas: Rezept Silber angeboten: %s" % [labels])

	# Falle aus derselben Runde: normaler Amethyst + fehlerhafter Smaragd -> Luftplatte (begehbar)
	game.round_towers.clear()
	for t in game.towers.values().filter(func(o): return o.is_new):
		game._turn_into_rock(t)
	game.phase = game.Phase.BUILD
	var plan := ["amethyst:2", "emerald:1", "ruby:4", "ruby:4", "ruby:4"]
	var placed_cells := []
	tries2 = 0
	while game.phase == game.Phase.BUILD and tries2 < 5000:
		tries2 += 1
		var p: Vector2 = game.ground_path[rng.randi_range(0, game.ground_path.size() - 1)]
		var c := Vector2i(p / Board3D.CELL) + Vector2i(rng.randi_range(-3, 1), rng.randi_range(-3, 1))
		if game.can_place(c):
			game.debug_tower = plan[game.round_towers.size()]
			game.place_gem(c)
	var amethyst = game.round_towers[0]
	labels = game.choice_options(amethyst).map(func(o): return o.label)
	check(labels.any(func(l): return "Luftplatte" in l), "Amethyst: Luftplatte angeboten: %s" % [labels])
	labels = game.choice_options(game.round_towers[2]).map(func(o): return o.label)
	check(labels.any(func(l): return "Großartiger Rubin" in l), "2 perfekte Rubine → Großartig: %s" % [labels])
	game._select(amethyst)
	var opts: Array = game.choice_options(amethyst)
	var slate_index := opts.map(func(o): return o.label).find(opts.filter(func(o): return "Luftplatte" in o.label)[0].label)
	game._on_option_chosen(slate_index)
	check(amethyst.tower_id == "air_slate" and amethyst.is_trap(), "Luftplatte gesetzt")
	check(not game.pathfinder.astar.is_point_solid(amethyst.cell), "Falle blockiert den Weg nicht")
	var dmg_before: float = amethyst.total_damage
	var frames2 := 0
	while game.phase == game.Phase.WAVE and frames2 < 20000:
		await get_tree().process_frame
		frames2 += 1
	print("  Luftplatte Schaden: ", int(amethyst.total_damage - dmg_before))

	# Stein von Bryvx: 4 gleiche perfekte Gems
	tries2 = 0
	while game.phase == game.Phase.BUILD and tries2 < 5000:
		tries2 += 1
		var p: Vector2 = game.ground_path[rng.randi_range(0, game.ground_path.size() - 1)]
		var c := Vector2i(p / Board3D.CELL) + Vector2i(rng.randi_range(-3, 1), rng.randi_range(-3, 1))
		if game.can_place(c):
			game.debug_tower = "topaz:4"
			game.place_gem(c)
	labels = game.choice_options(game.round_towers[0]).map(func(o): return o.label)
	check(labels.any(func(l): return "Bryvx" in l), "4 perfekte → Stein von Bryvx: %s" % [labels])

	# One-Shot: Silber schon in der Bauphase, sobald Topas, Diamant und Saphir stehen
	for t in game.towers.values().filter(func(o): return o.is_new):
		game._turn_into_rock(t)
	game.round_towers.clear()
	game.phase = game.Phase.BUILD
	# Ein fertiger Saphir auf dem Feld zählt für One-Shots nicht mit
	var field_sapphire = null
	tries2 = 0
	while field_sapphire == null and tries2 < 5000:
		tries2 += 1
		var p: Vector2 = game.ground_path[rng.randi_range(0, game.ground_path.size() - 1)]
		var c := Vector2i(p / Board3D.CELL) + Vector2i(rng.randi_range(-3, 1), rng.randi_range(-3, 1))
		if game.can_place(c):
			game.debug_tower = "sapphire:0"
			field_sapphire = game.place_gem(c)
	field_sapphire.is_new = false
	game.round_towers.erase(field_sapphire)
	var shot_plan := ["topaz:0", "diamond:0", "sapphire:0"]
	tries2 = 0
	while game.round_towers.size() < shot_plan.size() and tries2 < 5000:
		tries2 += 1
		var p: Vector2 = game.ground_path[rng.randi_range(0, game.ground_path.size() - 1)]
		var c := Vector2i(p / Board3D.CELL) + Vector2i(rng.randi_range(-3, 1), rng.randi_range(-3, 1))
		if game.can_place(c):
			if game.round_towers.size() == 2:
				check(game.one_shot_hints().is_empty(), "One-Shot ignoriert Tower auf dem Feld: %s" % [game.one_shot_hints()])
			game.debug_tower = shot_plan[game.round_towers.size()]
			game.place_gem(c)
	check(game.phase == game.Phase.BUILD, "nach 3 Gems noch Bauphase")
	check(game.one_shot_hints().any(func(h): return "Silber" in h), "One-Shot-Hinweis: %s" % [game.one_shot_hints()])
	var topaz = game.round_towers[0]
	game._select(topaz)
	opts = game.choice_options(topaz)
	labels = opts.map(func(o): return o.label)
	check(labels == ["One-Shot → Silber"], "Bauphase bietet nur das Rezept an: %s" % [labels])
	game._refresh_hud()
	check(game.hud._options.size() == 1 and game.hud._options[0].style == "oneshot", "One-Shot-Button ist lila: %s" % [game.hud._options])
	check(game.hud.oneshot_pill.visible and "Silber" in game.hud.oneshot_label.text, "Banner zeigt One-Shot: " + game.hud.oneshot_label.text)
	check(game.hud._gems.all(func(g): return g.oneshot), "alle drei Zutaten lila markiert")
	game.hud.toggle_recipe_book()
	await get_tree().process_frame
	check(game.hud.recipe_book.visible and game.hud.recipe_book.grid.get_child_count() > 10, "Rezeptbuch zeigt %d Rezepte" % game.hud.recipe_book.grid.get_child_count())
	game.hud.toggle_recipe_book()
	var st := Recipes.status("silver", [["diamond", 0], ["sapphire", 0]])
	check(st.missing == 1 and st.lines[2].have == false, "Rezeptstatus Silber: Topas fehlt")
	st = Recipes.status("poison_slate", [["emerald", 2], ["opal", 1]])
	check(st.missing == 0, "Rezeptstatus Giftplatte mit 'einer von' erfüllt")
	check(Recipes.used_in("emerald", 2).has("jade") and Recipes.used_in("emerald", 2).has("poison_slate"), "Normaler Smaragd wird für Jade und Giftplatte gebraucht")
	Session.pinned_recipes = ["jade"]
	game._refresh_hud()
	game.hud._refresh_pinned()
	check(game.hud.pinned_panel.visible, "angepinntes Rezept wird angezeigt")
	Session.pinned_recipes = []
	var rocks_before: int = game.rocks.size()
	game._on_option_chosen(0)
	check(topaz.tower_id == "silver" and game.phase == game.Phase.WAVE, "One-Shot gebaut, Welle startet")
	check(game.rocks.size() == rocks_before + 2, "die anderen beiden Gems sind Steine")

	# Wellenvorschau links
	var preview: Array = game._upcoming_waves(4)
	check(preview.size() == 4 and preview[0].number == game.wave_index + 1, "Vorschau zeigt die nächsten 4 Wellen ab Welle %d" % (game.wave_index + 1))
	check(game.wave_type(game.waves[3]) == "Flieger" and game.wave_type(game.waves[0]) == "Boden" and game.wave_type(game.waves[49]) == "Boss", "Wellentypen: Boden, Flieger, Boss")
	check(game.hud.waves_panel.visible, "Wellenvorschau sichtbar")

	# Weglänge in der Leiste und Menü am Spielende
	check(game.path_length > 0 and str(game.path_length) in game.hud.path_value.text, "Weglänge angezeigt: " + game.hud.path_value.text)
	game._finish(game.Phase.GAME_OVER)
	check(game.hud.game_over.visible and game.hud.game_over_title.text == "Verloren", "Menü am Spielende erscheint")

	# Alle Tower-Dateien gültig
	for id in Database.tower_ids():
		var def: Dictionary = Database.towers[id]
		check(not (def.get("tiers", []) as Array).is_empty(), "Tower %s hat Stufen" % id)
		for ing in def.get("recipe", []):
			var alts: Array = ing.get("any_of", [ing])
			for a in alts:
				check(Database.towers.has(str(a.get("tower", ""))), "Rezept von %s: Zutat %s existiert" % [id, a.get("tower", "")])
	for w in Database.wave_sets.get("classic", {}).get("waves", []):
		for g in w.groups:
			check(Database.enemies.has(g.enemy), "Gegner %s existiert" % g.enemy)

	Engine.time_scale = 1.0
	print("FERTIG, Fehler: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
