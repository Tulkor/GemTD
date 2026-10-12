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
	# Wellentypen: jede vierte Welle Flieger, versetzt dazu Massenwellen, dazu Bosse
	var kinds := {}
	for w in Database.wave_sets.get("classic", {}).get("waves", []):
		var k: String = load("res://scripts/game/game.gd").wave_type(w)
		kinds[k] = kinds.get(k, 0) + 1
	check(kinds.get("Masse", 0) >= 8 and kinds.get("Flieger", 0) >= 10 and kinds.get("Boss", 0) >= 1 and kinds.get("Boden", 0) >= 10,
		"alle vier Wellentypen kommen vor: %s" % [kinds])

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
	var down: Array = game.choice_options(game.round_towers[2]).filter(func(o): return o.label.begins_with("Abstufen"))
	check(down.size() == 1 and down[0].id == "ruby" and down[0].tier == 3, "Perfekten Rubin abstufen → %s" % [down.map(func(o): return o.label)])
	var views: Array = game.choice_options(game.round_towers[2]).map(func(o): return game._option_view(game.round_towers[2], o))
	var down_view: Array = views.filter(func(v): return v.get("icon", "") == "down")
	var up_view: Array = views.filter(func(v): return v.get("icon", "") == "up")
	check(down_view.size() == 1 and down_view[0].label == "Makelloser Rubin" and up_view.size() == 1 and up_view[0].label == "Großartiger Rubin",
		"Knöpfe: roter Pfeil + Makelloser Rubin, grüner Pfeil + Großartiger Rubin: %s" % [views])
	var amethyst_views: Array = game.choice_options(amethyst).map(func(o): return game._option_view(amethyst, o))
	check(amethyst_views.any(func(v): return v.get("icon", "") == "combine" and v.label == "Luftplatte"), "Kombinieren-Symbol + Luftplatte: %s" % [amethyst_views])
	check(UiTheme.icon("up") != null and UiTheme.icon("down") != null and UiTheme.icon("combine") != null, "Symbole für Pfeile und Kombinieren laden")
	game._select(amethyst)
	var opts: Array = game.choice_options(amethyst)
	var slate_index := opts.map(func(o): return o.label).find(opts.filter(func(o): return "Luftplatte" in o.label)[0].label)
	game._on_option_chosen(slate_index)
	check(amethyst.tower_id == "air_slate" and amethyst.is_trap(), "Luftplatte gesetzt")
	check(not game.pathfinder.astar.is_point_solid(amethyst.cell), "Falle blockiert den Weg nicht")
	var slate_cell: Vector2i = amethyst.cell
	check(game.traps.get(slate_cell) == amethyst and not game.towers.has(slate_cell) and not game.occupied.has(slate_cell), "Falle liegt auf eigener Ebene")
	# Trefferfläche 3×3 Felder (1,5 Towerbreiten) um die Mitte der Falle
	check(amethyst.in_range({"pos": amethyst.pos + Vector2(0.7, -0.7), "flying": false}) and not amethyst.in_range({"pos": amethyst.pos + Vector2(0.8, 0), "flying": false}), "Falle trifft auf 3×3 Feldern")
	# Zweimal verschieben, auch auf einen Checkpoint
	check(amethyst.moves_left == 2 and game.tower_options(amethyst).any(func(o): return o.action == "move"), "Falle hat 2 Verschiebungen")
	var on_cp: Vector2i = game.map.checkpoints[0] - Vector2i(1, 1)
	check(game.can_move_trap(amethyst, on_cp) and game.move_trap(amethyst, on_cp), "Falle auf Checkpoint verschoben")
	check(amethyst.cell == on_cp and amethyst.moves_left == 1 and game.traps.has(on_cp) and not game.traps.has(slate_cell), "Falle liegt jetzt am Checkpoint")
	check(game.move_trap(amethyst, slate_cell) and amethyst.moves_left == 0, "zweites Verschieben")
	check(not game.can_move_trap(amethyst, on_cp) and not game.tower_options(amethyst).any(func(o): return o.action == "move"), "kein drittes Verschieben")
	# Steine auch während der Welle entfernen
	var wave_rock: Vector2i = game.rocks.keys()[0]
	check(game.remove_rock(wave_rock) and not game.ground_path.is_empty(), "Stein während der Welle entfernt")
	var dmg_before: float = amethyst.total_damage
	var frames2 := 0
	while game.phase == game.Phase.WAVE and frames2 < 20000:
		await get_tree().process_frame
		frames2 += 1
	print("  Luftplatte Schaden: ", int(amethyst.total_damage - dmg_before))

	# Tower auf eine Falle bauen; zweiter Klick wählt die Falle darunter
	check(game.can_place(slate_cell), "Tower auf Falle baubar")
	game.debug_tower = "topaz:4"
	var on_trap = game.place_gem(slate_cell)
	check(game.towers.get(slate_cell) == on_trap and game.traps.get(slate_cell) == amethyst, "Tower steht auf der Falle")
	game._select(on_trap)
	game._on_click(slate_cell, slate_cell)
	check(game.selected == amethyst, "zweiter Klick wählt die Falle unter dem Tower")

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
	# Fertiger Saphir, Topas und Diamant auf dem Feld: zählen für One-Shots nicht mit,
	# und kombinieren lassen sie sich erst außerhalb der Bauphase
	var field_plan := ["sapphire:0", "topaz:0", "diamond:0"]
	var field_gems := []
	tries2 = 0
	while field_gems.size() < field_plan.size() and tries2 < 5000:
		tries2 += 1
		var p: Vector2 = game.ground_path[rng.randi_range(0, game.ground_path.size() - 1)]
		var c := Vector2i(p / Board3D.CELL) + Vector2i(rng.randi_range(-3, 1), rng.randi_range(-3, 1))
		if game.can_place(c):
			game.debug_tower = field_plan[field_gems.size()]
			var g = game.place_gem(c)
			g.is_new = false
			game.round_towers.erase(g)
			field_gems.append(g)
	var field_sapphire = field_gems[0]
	var field_labels: Array = game.tower_options(field_sapphire).map(func(o): return o.label)
	check(not field_labels.any(func(l): return "Kombinieren" in l), "kein Kombinieren in der Bauphase: %s" % [field_labels])
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
	check(game.hud._options.size() == 2 and game.hud._options[0].style == "oneshot" and game.hud._options[1].label == "Zurücknehmen",
		"One-Shot-Button ist lila, daneben Zurücknehmen: %s" % [game.hud._options.map(func(o): return o.label)])
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
	game.hud.set_selection({"title": "Smaragd", "color": Color.GREEN, "body": "", "used_in": Recipes.used_in("emerald", 2)})
	var used_n := Recipes.used_in("emerald", 2).size()
	check(game.hud.used_row.get_child_count() == 1 and game.hud.used_page_label.text == "1 / %d" % used_n, "Wird gebraucht für: ein Rezept pro Seite, Seite 1 / %d" % used_n)
	game.hud._turn_used_page(1)
	check(game.hud.used_page_label.text == "2 / %d" % used_n, "Pfeil blättert weiter")
	game.hud._turn_used_page(-2)
	check(game.hud.used_page_label.text == "%d / %d" % [used_n, used_n], "Pfeil zurück springt ans Ende")
	game.hud.set_selection({})
	check(not game.hud.used_col.visible, "nach dem Abwählen kein \"Wird gebraucht für\" mehr")
	# Reihenfolge: meiste vorhandene Zutaten zuerst, bei Gleichstand Tower vor Fallen
	var sorted_ids: Array = Hud.sort_used_in(["air_slate", "silver"], [])
	check(sorted_ids == ["silver", "air_slate"], "Gleichstand: Tower vor Falle: %s" % [sorted_ids])
	sorted_ids = Hud.sort_used_in(["silver", "air_slate"], [["amethyst", 2, false]])
	check(sorted_ids[0] == "air_slate", "Rezept mit mehr vorhandenen Zutaten zuerst: %s" % [sorted_ids])
	st = Recipes.status("silver", [["diamond", 0, true], ["sapphire", 0], ["topaz", 0]])
	check(st.lines[0].new and not st.lines[1].new and st.missing == 0, "Neuer Gem der Runde violett, fixierter Tower grün")
	var jade_set := [["emerald", 2], ["opal", 2], ["sapphire", 1]]
	check(not Recipes.ready_now("jade", jade_set, {"pool": [], "wave": false}), "Jade mit Feld-Towern beim Setzen nicht baubar")
	check(Recipes.ready_now("jade", jade_set, {"pool": jade_set, "wave": true}), "Jade mit Feld-Towern in der Welle baubar")
	check(not Recipes.ready_now("poison_slate", [["emerald", 2], ["opal", 1]], {"pool": [["emerald", 2], ["opal", 1]], "wave": true}), "Giftplatte nur aus einer Runde, nicht in der Welle")
	Session.pinned_recipes = ["jade"]
	game._refresh_hud()
	game.hud._refresh_pinned()
	check(game.hud.pinned_panel.visible, "angepinntes Rezept wird angezeigt")
	Session.pinned_recipes = []
	var rocks_before: int = game.rocks.size()
	game._on_option_chosen(0)
	check(topaz.tower_id == "silver" and game.phase == game.Phase.WAVE, "One-Shot gebaut, Welle startet")
	check(game.rocks.size() == rocks_before + 2, "die anderen beiden Gems sind Steine")
	field_labels = game.tower_options(field_sapphire).map(func(o): return o.label)
	check(field_labels.has("Kombinieren → Silber"), "Kombinieren während der Welle: %s" % [field_labels])
	game._select(field_sapphire)
	game._on_option_chosen(field_labels.find("Kombinieren → Silber"))
	check(field_sapphire.tower_id == "silver" and game.phase == game.Phase.WAVE and not game.ground_path.is_empty(), "während der Welle kombiniert, Welle läuft weiter")
	labels = game.tower_options(topaz).map(func(o): return o.label)
	check(labels.any(func(l): return l.begins_with("Aufwerten → Sterlingsilber")), "Upgrade während der Welle: %s" % [labels])
	var up_views: Array = game.tower_options(topaz).filter(func(o): return o.action == "upgrade").map(func(o): return game._option_view(topaz, o))
	check(not up_views.is_empty() and up_views[0].label == "Sterlingsilber" and str(up_views[0].get("sub", "")).ends_with("Gold"), "Upgrade-Knopf: nur Name, darunter Goldkosten: %s" % [up_views])
	check(not (up_views[0].diff as Array).is_empty() and float(up_views[0].preview_range) > 0.0, "Upgrade-Knopf mit Werte-Vergleich und neuer Reichweite: %s" % [up_views[0].get("diff")])
	# Infofenster: Kacheln, Kills mit Rang, Herkunft der Boni, Upgrade-Vorschau
	var ki := TowerStats.kill_info(23)
	check(ki.rank == 2 and ki.missing == 7 and is_equal_approx(ki.next_bonus, 0.3) and not ki.maxed, "Kill-Rang bei 23 Kills: %s" % [ki])
	check(TowerStats.kill_info(500).maxed, "Kill-Rang gedeckelt")
	var old_kills: int = topaz.kills
	topaz.kills = 23
	topaz.damage_bonus = 0.1
	topaz.damage_source = "Kraftplatte"
	var tv := TowerStats.view(topaz)
	var tkeys: Array = tv.tiles.map(func(x): return x.key)
	check(tkeys == ["range", "speed", "damage", "type"], "Kacheln: %s" % [tkeys])
	var dtile: Dictionary = tv.tiles[2]
	check(dtile.mod and dtile.rows.any(func(r): return "Kraftplatte" in r[0]) and dtile.rows.any(func(r): return "Rang 2" in r[0]), "Schaden grün, Tooltip nennt Kraftplatte und Kill-Rang: %s" % [dtile.rows])
	game._select(topaz)
	game._refresh_hud()
	var hud = game.hud
	check(hud.info_kills.visible and "23" in hud.info_kills_label.text, "Kills neben dem Namen: " + hud.info_kills_label.text)
	check(hud._tiles[2].value.get_theme_color("font_color") == UiTheme.HAVE, "veränderter Schaden ist grün")
	var tips := [hud._kills_tooltip(), hud._stat_tooltip(2), hud._diff_tooltip(up_views[0])]
	check(tips.all(func(x): return x != null), "Tooltips für Kills, Schaden und Upgrade")
	var tip_text := func(n: Node) -> String:
		return " ".join(n.find_children("*", "Label", true, false).map(func(l): return l.text))
	check("noch 7" in tip_text.call(tips[0]), "Kill-Tooltip: noch 7 Kills bis Rang 3: " + tip_text.call(tips[0]))
	for x in tips:
		x.free()
	check(hud.abil_panel.visible == not topaz.abilities().is_empty(), "Fähigkeiten-Fenster nur mit Fähigkeiten")
	hud.preview_range_requested.emit(float(up_views[0].preview_range))
	check(topaz._preview_ring != null, "Hover auf Upgrade zeigt die neue Reichweite")
	hud.preview_range_requested.emit(0.0)
	check(topaz._preview_ring == null, "Reichweiten-Vorschau wieder aus")
	topaz.kills = old_kills
	topaz.damage_bonus = 0.0
	topaz.damage_source = ""

	# Sternrubin aus Fehlerhaftem Rubin (frühere Runde) + Splitter Amethyst + Splitter Rubin (neu):
	# alte Tower zählen weder als One-Shot noch in der Auswahlphase, nur während der Welle
	game.round_towers.clear()
	game.phase = game.Phase.BUILD
	var star_plan := ["ruby:1", "amethyst:0", "ruby:0", "topaz:0", "topaz:0", "topaz:0"]
	var star := []
	var star_name := Database.tower_label("star_ruby", 0)
	tries2 = 0
	while game.phase == game.Phase.BUILD and tries2 < 5000:
		tries2 += 1
		var p: Vector2 = game.ground_path[rng.randi_range(0, game.ground_path.size() - 1)]
		var c := Vector2i(p / Board3D.CELL) + Vector2i(rng.randi_range(-3, 1), rng.randi_range(-3, 1))
		if game.can_place(c):
			game.debug_tower = star_plan[star.size()]
			var g = game.place_gem(c)
			if star.is_empty():
				g.is_new = false
				game.round_towers.erase(g)
			star.append(g)
			if star.size() == 3:
				check(not game.one_shot_hints().any(func(h): return star_name in h), "kein One-Shot %s mit altem Rubin: %s" % [star_name, game.one_shot_hints()])
	labels = game.choice_options(star[1]).map(func(o): return o.label)
	check(game.phase == game.Phase.CHOOSE and not labels.any(func(l): return star_name in l), "Auswahlphase: kein %s mit altem Rubin: %s" % [star_name, labels])
	labels = game.tower_options(star[0]).map(func(o): return o.label)
	check(not labels.any(func(l): return "Kombinieren" in l), "alter Rubin kombiniert in der Auswahlphase nicht: %s" % [labels])
	labels = game.tower_options(topaz).map(func(o): return o.label)
	check(labels.is_empty(), "kein Upgrade außerhalb der Welle: %s" % [labels])

	# Wellenvorschau links
	var preview: Array = game._upcoming_waves(4)
	check(preview.size() == 4 and preview[0].number == game.wave_index + 1, "Vorschau zeigt die nächsten 4 Wellen ab Welle %d" % (game.wave_index + 1))
	check(game.wave_type(game.waves[3]) == "Flieger" and game.wave_type(game.waves[0]) == "Boden" and game.wave_type(game.waves[49]) == "Boss", "Wellentypen: Boden, Flieger, Boss")
	check(game.hud.waves_panel.visible, "Wellenvorschau sichtbar")

	# Debug-Menü
	var g0: int = game.gold
	game.hud.debug_gold_requested.emit(100)
	check(game.gold == g0 + 100, "Debug: Gold +100")
	var l0: int = game.lives
	game.hud.debug_lives_requested.emit(10)
	check(game.lives == l0 + 10, "Debug: Leben +10")
	game.hud.debug_gems.value = 3
	check(game.gems_per_round() == 3, "Debug: Gems pro Runde einstellbar")
	game.hud.debug_gems.value = 5
	Session.debug_gems_per_round = 0
	var sep_ok := false
	for i in game.hud.debug_option.item_count:
		if game.hud.debug_option.is_item_separator(i) and game.hud.debug_option.get_item_text(i) == "Spezial-Tower":
			sep_ok = game.hud.debug_keys[i] == "" and game.hud.debug_keys[i + 1].begins_with(Database.special_ids()[0])
	check(sep_ok, "Debug: Gem-Liste mit Trennern Basis-Gems / Spezial-Tower")
	game.lives = l0
	game.gold = g0
	var w0: int = game.wave_index
	if game.phase != game.Phase.WAVE:
		game.debug_jump_to_wave(3)
		check(game.wave_index == 2 and game._upcoming_waves(1)[0].number == 3, "Debug: Welle 3 kommt als nächste")
		game.wave_index = w0
		game._refresh_hud()

	# Chance-Tooltip und Qualitätskästchen
	var chance_tip: String = Hud.chance_lines(1)
	check("Splitter" in chance_tip and "70 %" in chance_tip and "30 %" in chance_tip, "Chance-Tooltip zeigt Prozente pro Qualität: %s" % chance_tip)
	check("Splitter" in game.hud.chance_value.get_parent().get_parent().tooltip_text, "Tooltip hängt am Chance-Feld")
	var chance_host: TooltipHost = game.hud.chance_value.get_parent().get_parent()
	var chance_tt = chance_host._make_custom_tooltip("")
	check(chance_tt is Control and chance_tt.get_child_count() >= 5, "Chance-Tooltip mit Titel, Balken und nächster Stufe")
	if chance_tt != null:
		chance_tt.free()
	var badge := QualityBadge.new(Color.RED, 2, 6)
	check(badge.tier == 2 and badge.tiers == 5 and not badge.is_perfect() and badge.custom_minimum_size.y > badge.custom_minimum_size.x,
		"Facetten-Gem: 5 Stufen (Splitter bis Perfekt), Normal füllt 3 Facetten")
	badge.free()
	badge = QualityBadge.new(Color.RED, 4, 6)
	check(badge.is_perfect(), "Facetten-Gem: Perfekt füllt die Mitte")
	badge.free()
	badge = QualityBadge.new(Color.RED, 5, 6)
	check(badge.tier == 4 and badge.is_perfect(), "Facetten-Gem: Großartig zählt wie Perfekt")
	badge.free()
	badge = QualityBadge.new(Color("f1c40f"), 1, 6, 36.0, "topaz")
	check(badge.color == Color("ffe600"), "Facetten-Gem: Topas in grellerem Gelb")
	badge.free()

	# DPS-Meter rechts: Top 5 je Welle, letzte Welle je Typ, Gesamt
	var meter: DpsMeter = game.hud.dps_meter
	var dps_towers: Array = game.all_towers()
	check(meter != null and meter.select.item_count == 6, "DPS-Meter mit 6 Ansichten im Dropdown")
	check(meter._total_time > 0.0 and not meter._total.is_empty(), "DPS-Meter hat die bisherigen Wellen mitgezählt")
	if not dps_towers.is_empty():
		meter._last.clear()
		meter._total.clear()
		meter._total_time = 0.0
		meter._begin_wave()
		meter._running = true
		meter._wave_time = 10.0
		dps_towers[0].total_damage += 500.0
		meter.view = "now"
		var dps_top: Array = meter.top()
		check(dps_top.size() == 1 and is_equal_approx(dps_top[0][2], 50.0), "DPS-Meter: 500 Schaden in 10 s ergibt 50 DPS")
		var dps_type: String = meter._wave_type
		meter._end_wave()
		meter.view = dps_type
		check(meter._last.has(dps_type) and is_equal_approx(meter.top()[0][2], 50.0), "DPS-Meter merkt sich die letzte %s-Welle" % dps_type)
		meter.view = "total"
		meter.refresh()
		check(is_equal_approx(meter.top()[0][2], 50.0) and meter.rows[0].box.visible and not meter.rows[1].box.visible, "DPS-Meter: Gesamt zeigt den Tower")
		meter.view = "Boss" if dps_type != "Boss" else "Masse"
		check(meter.top().is_empty(), "DPS-Meter: Welle ohne Daten ist leer")
		dps_towers[0].total_damage -= 500.0
		meter._last.clear()
		meter._total.clear()
		meter._total_time = 0.0
		meter.view = "now"
		meter.refresh()

	# Menü-Knopf fragt erst nach und pausiert solange
	game.hud.open_leave_confirm()
	check(game.hud.leave_confirm.visible and get_tree().paused, "Menü-Knopf zeigt Rückfrage und pausiert")
	game.hud.close_leave_confirm()
	check(not game.hud.leave_confirm.visible and not get_tree().paused, "Weiterspielen schließt Rückfrage")

	# Chance-Stufe steigt automatisch mit der Welle, Gold wird um gold_income_factor gekürzt
	check(game.chance_level_for(1) == 0 and game.chance_level_for(3) == 1 and game.chance_level_for(27) == 8 and game.chance_level_for(50) == 8,
		"Chance automatisch: Welle 1 → 0, Welle 3 → 1, ab Welle 27 → 8")
	var old_gold: int = game.gold
	game.gold = 0
	game._gold_frac = 0.0
	for k in 4:
		game.earn_gold(1)
	var g_start := float(Database.balance.gold_income_factor)
	check(game.gold == floori(4 * g_start), "Goldeinkommen ×%s: 4 × 1 Gold ergibt %d Gold" % [g_start, game.gold])
	var ramp: Dictionary = Database.balance.gold_income_ramp
	var g_from := int(ramp.from_wave)
	var g_to := int(ramp.to_wave)
	var g_top := float(ramp.to_factor)
	var g_mid: float = game.gold_income_factor((g_from + g_to) / 2)
	check(is_equal_approx(game.gold_income_factor(g_from), g_start) and is_equal_approx(game.gold_income_factor(g_to), g_top)
		and is_equal_approx(game.gold_income_factor(g_to + 10), g_top) and g_mid > g_start and g_mid < g_top,
		"Goldeinkommen steigt von Welle %d bis %d linear von %s auf %s" % [g_from, g_to, g_start, g_top])
	game.gold = old_gold
	game._refresh_hud()

	# Weglänge in der Leiste und Menü am Spielende
	check(game.path_length > 0 and str(game.path_length) in game.hud.path_value.text, "Weglänge angezeigt: " + game.hud.path_value.text)
	# Debug „Unsterblich“: Leben gehen ins Minus, kein Spielende
	Session.debug_immortal = true
	game.lives = 1
	var leaker := Enemy.new()
	leaker.damage = 3
	game.on_enemy_leaked(leaker)
	check(game.lives == -2 and game.phase < game.Phase.GAME_OVER, "Unsterblich: Leben %d, Spiel läuft weiter" % game.lives)
	Session.debug_immortal = false
	var tough := Enemy.new()
	tough.max_hp = 100.0
	tough.armor = 4.0
	var expect := [80.0, 90.0, 115.0]
	for d in 3:
		tough.max_hp = 100.0
		tough.armor = 4.0
		Session.difficulty = d
		tough.apply_difficulty(Session.difficulty_factor())
		check(is_equal_approx(tough.max_hp, expect[d]) and is_equal_approx(tough.armor, 4.0 * expect[d] / 100.0) and tough.hp == tough.max_hp,
			"%s: Leben %.0f, Rüstung %.2f" % [Session.difficulty_name(), tough.max_hp, tough.armor])
	tough.free()
	Session.difficulty = 1
	game._finish(game.Phase.GAME_OVER)
	check(game.hud.game_over.visible and game.hud.game_over_title.text == "Verloren", "Menü am Spielende erscheint")

	await _save_test()
	await _score_test()
	await _rock_select_test()
	await _take_back_test()
	await _final_boss_test()

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


## Spielstände: Zustand mitten in einer Welle sichern, in ein neues Spiel laden, gleich weiter;
## Datei ist verschlüsselt und eine geänderte Datei lädt nicht mehr.
func _save_test() -> void:
	Session.map_path = Database.list_maps()[0].path
	Session.map_override = null
	var g: Node = load(Session.GAME).instantiate()
	add_child(g)
	await get_tree().process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var tries := 0
	while g.phase == g.Phase.BUILD and tries < 5000:
		tries += 1
		var p: Vector2 = g.ground_path[rng.randi_range(0, g.ground_path.size() - 1)]
		var c := Vector2i(p / Board3D.CELL) + Vector2i(rng.randi_range(-3, 1), rng.randi_range(-3, 1))
		if g.can_place(c):
			g.place_gem(c)
	# Gegner dieser Welle unsterblich machen, damit der Stand nicht davon abhängt, wie schnell der Tower tötet
	g.waves = g.waves.duplicate(true)
	for grp in g.waves[g.wave_index].groups:
		grp.hp = 1.0e7
	g._select(g.round_towers[0])
	g._on_option_chosen(0)
	Engine.time_scale = 1.0
	var frames := 0
	# mitten in der Welle: Gegner unterwegs und noch welche in der Warteschlange
	# (ohne Mindestzahl an Bildern: bei niedriger Bildrate wäre die Warteschlange sonst schon leer)
	while g.phase == g.Phase.WAVE and (g.enemies.size() < 2 or g.spawn_queue.is_empty()) and frames < 5000:
		await get_tree().process_frame
		frames += 1
	Engine.time_scale = 1.0
	var a: Dictionary = SaveGame.capture(g)
	check(a.phase == g.Phase.WAVE and not a.enemies.is_empty(), "Spielstand mitten in der Welle: %d Gegner, %d Tower, %d Steine" % [a.enemies.size(), a.towers.size(), a.rocks.size()])

	Session.load_state = a.duplicate(true)
	var g2: Node = load(Session.GAME).instantiate()
	add_child(g2)
	var b: Dictionary = SaveGame.capture(g2)
	var same := true
	for k in ["phase", "wave_index", "lives", "gold", "rocks", "towers", "round", "killed", "spawn_queue", "next_enemy_id", "rng_state", "difficulty"]:
		if str(a[k]) != str(b[k]):
			same = false
			print("  Unterschied bei ", k, ": ", a[k], " / ", b[k])
	check(same and is_equal_approx(a.spawn_timer, b.spawn_timer), "Geladenes Spiel hat denselben Stand")
	var close: bool = a.enemies.size() == b.enemies.size()
	for i in mini(a.enemies.size(), b.enemies.size()):
		var ea: Dictionary = a.enemies[i]
		var eb: Dictionary = b.enemies[i]
		close = close and absf(ea.traveled - eb.traveled) < 0.01 and is_equal_approx(ea.hp, eb.hp) \
			and ea.id == eb.id and is_equal_approx(ea.slow_time, eb.slow_time)
	check(close, "Gegner stehen nach dem Laden an derselben Stelle mit denselben Leben")
	check(g2.ground_path == g.ground_path and g2.map.name == g.map.name, "Weg und Map nach dem Laden gleich")

	# Datei: verschlüsselt, Änderung wird erkannt
	var data := {"id": "smoke_test_save", "kind": "single", "meta": SaveGame.meta_for(g), "state": a}
	check(SaveGame.write(data), "Spielstand geschrieben")
	var path := SaveGame.path_for("smoke_test_save")
	var raw := FileAccess.get_file_as_bytes(path)
	var text := raw.get_string_from_ascii()
	check(raw.size() > 100 and not ("towers" in text) and not (g.map.name in text) and not ("gold" in text), "Datei ist nicht im Klartext lesbar (%d Bytes)" % raw.size())
	var back := SaveGame.read(path)
	check(str(back.get("state", {})) == str(a), "Datei lädt verlustfrei")
	check(SaveGame.list().any(func(e): return e.id == "smoke_test_save" and e.meta.map == g.map.name), "Spielstand erscheint in der Liste")
	raw[raw.size() / 2] = raw[raw.size() / 2] ^ 0x55
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(raw)
	f.close()
	check(SaveGame.read(path).is_empty(), "Veränderte Datei wird abgelehnt")
	SaveGame.remove("smoke_test_save")
	check(not FileAccess.file_exists(path), "Spielstand gelöscht")

	# Rückfrage beim Verlassen bietet im Einzelspiel Speichern an
	g2.hud.open_leave_confirm()
	check(g2.save_mode() == "single" and g2.hud._save_leave.visible and not g2.hud._save_leave.disabled, "Verlassen fragt nach Speichern")
	g2.hud.close_leave_confirm()
	Session.save_id = ""
	g.queue_free()
	g2.queue_free()
	await get_tree().process_frame


## Punkte-Modus: späte Wellen zählen mehr, ein Durchbruch kostet die Hälfte, kein Leben geht verloren.
func _score_test() -> void:
	Session.map_path = Database.list_maps()[0].path
	Session.map_override = null
	Session.score_mode = true
	var g: Node = load(Session.GAME).instantiate()
	add_child(g)
	await get_tree().process_frame
	check(g.score_mode and g.hud.lives_value.get_parent().get_child(0).text == "Punkte", "Punkte-Modus: Leiste zeigt Punkte")
	var w1: Dictionary = g.waves[0]
	var sum := 0.0
	for grp in w1.groups:
		sum += g.score_for(grp) * int(grp.get("count", 1))
	check(is_equal_approx(sum, g.wave_points(1)), "Welle 1 ist insgesamt %.0f Punkte wert" % sum)
	var v1: float = g.score_for(w1.groups[0])
	g.wave_index = 39
	var v40: float = g.score_for(g.waves[39].groups[0])
	var full_leak_1 := 0.0
	for grp in w1.groups:
		full_leak_1 += g.leak_penalty(v1) * int(grp.get("count", 1))
	check(v40 > v1 * 3.0, "Gegner aus Welle 40 zählt mehr als aus Welle 1 (%.1f gegen %.1f)" % [v40, v1])
	check(g.leak_penalty(v40) < full_leak_1, "Durchbruch eines Gegners aus Welle 40 (−%.1f) kostet weniger als eine ganze frühe Welle (−%.1f)" % [g.leak_penalty(v40), full_leak_1])
	var e := Enemy.new()
	e.score_value = v40
	g.enemies.append(e)
	var lives_before: int = g.lives
	g.on_enemy_killed(e)
	check(is_equal_approx(g.score, v40), "Kill gibt %.1f Punkte" % v40)
	var e2 := Enemy.new()
	e2.score_value = v40
	e2.damage = 5
	g.enemies.append(e2)
	g.on_enemy_leaked(e2)
	check(is_equal_approx(g.score, v40 * 0.5) and g.lives == lives_before and g.phase < g.Phase.GAME_OVER, "Durchbruch kostet die Hälfte, keine Leben")
	var st := SaveGame.capture(g)
	check(st.score_mode and is_equal_approx(st.score, g.score), "Spielstand enthält Punkte")
	g._finish(g.Phase.VICTORY)
	check("Punkte: %d" % roundi(g.score) in g.hud.game_over_stats.text, "Endbildschirm zeigt die Punkte")
	Session.score_mode = false
	g.queue_free()
	await get_tree().process_frame


## Steine: per Rahmen bis zu 5 auswählen, direkt durch Gems ersetzen (nur so viele, wie die Runde noch hat), Rest entfernen.
func _rock_select_test() -> void:
	Session.map_path = Database.list_maps()[0].path
	Session.map_override = null
	var g: Node = load(Session.GAME).instantiate()
	add_child(g)
	await get_tree().process_frame
	g.gold = 10000
	var gem_cells := [Vector2i(14, 40), Vector2i(18, 40), Vector2i(22, 40)]
	for c in gem_cells:
		g.place_gem(c)
	var rock_cells := []
	for i in 3:
		for j in 2:
			var c := Vector2i(14 + 4 * i, 32 + 4 * j)
			if g.can_place(c):
				g.rocks[c] = true
				g._occupy(c, true, true)
				rock_cells.append(c)
	g._update_paths()
	g.board.refresh_rocks()
	check(rock_cells.size() == 6 and g.gems_left() == 2, "6 Steine liegen, noch %d Gems in der Runde" % g.gems_left())
	var cam: Camera3D = g.camera_rig.camera
	var r := Rect2()
	for i in rock_cells.size():
		var p := cam.unproject_position(Board3D.to_3d(Board3D.footprint_center(rock_cells[i])))
		r = Rect2(p, Vector2.ZERO) if i == 0 else r.expand(p)
	g._press_pos = cam.unproject_position(Board3D.to_3d(Board3D.footprint_center(rock_cells[0])))
	g._box_select(r.grow(4.0))
	check(g.selected_rocks.size() == 5 and g.selected_rocks[0] == rock_cells[0] and g.board.selected_rocks.size() == 5,
		"Auswahlrahmen markiert höchstens 5 Steine (%d)" % g.selected_rocks.size())
	var picked: Array = g.selected_rocks.duplicate()
	g._on_option_chosen(0)
	var replaced := picked.slice(0, 2)
	check(g.round_towers.size() == 5 and g.phase == g.Phase.CHOOSE and replaced.all(func(c): return g.towers.has(c) and not g.rocks.has(c)),
		"Ersetzen setzt nur die 2 übrigen Gems, dann Auswahlphase")
	check(g.rocks.size() == 4, "die anderen Steine bleiben liegen (%d)" % g.rocks.size())
	var gold_before: int = g.gold
	g._select_rocks(g.rocks.keys())
	g._on_option_chosen(0)
	check(g.rocks.is_empty() and g.gold == gold_before - 4 * g.rock_remove_cost(), "ohne freie Gems entfernt die Auswahl alle 4 Steine")
	g.queue_free()
	await get_tree().process_frame


## Strg+Klick: Steine einzeln zur Auswahl hinzufügen/abwählen. Gesetzte Gems zurücknehmen, ohne neu zu würfeln.
func _take_back_test() -> void:
	Session.map_path = Database.list_maps()[0].path
	Session.map_override = null
	var g: Node = load(Session.GAME).instantiate()
	add_child(g)
	await get_tree().process_frame
	g.gold = 10000
	var rock_cells := []
	for i in 7:
		var c := Vector2i(14 + 4 * (i % 4), 32 + 4 * (i / 4))
		if g.can_place(c):
			g.rocks[c] = true
			g._occupy(c, true, true)
			rock_cells.append(c)
	g._update_paths()
	g.board.refresh_rocks()
	for i in 6:
		g.toggle_rock(rock_cells[i])
	check(g.selected_rocks.size() == 5 and not g.selected_rocks.has(rock_cells[5]), "Strg+Klick wählt Steine dazu, höchstens 5")
	g.toggle_rock(rock_cells[1])
	check(g.selected_rocks.size() == 4 and not g.selected_rocks.has(rock_cells[1]), "Strg+Klick auf markierten Stein wählt ihn ab")
	g._select(null)

	# Ersetzen und wieder zurücknehmen: Stein kommt zurück, Kosten werden erstattet
	var cost_before = Database.balance.get("rock_remove_cost", 0)
	Database.balance["rock_remove_cost"] = 7
	var gold0: int = g.gold
	g.replace_rocks([rock_cells[0]])
	var on_rock: Tower = g.towers.get(rock_cells[0])
	check(on_rock != null and g.gold == gold0 - 7, "Stein durch Gem ersetzt")
	var rock_gem := "%s:%d" % [on_rock.tower_id, on_rock.tier]
	check(g.take_back(on_rock) and g.rocks.has(rock_cells[0]) and g.gold == gold0 and g.round_towers.is_empty(),
		"Zurücknehmen legt den Stein wieder hin und erstattet die Kosten")
	Database.balance["rock_remove_cost"] = cost_before

	# 5 Gems setzen, Auswahlphase, einen zurücknehmen → Bauphase, nächster Gem ist derselbe
	var cells := [Vector2i(14, 40), Vector2i(18, 40), Vector2i(22, 40), Vector2i(26, 40), Vector2i(30, 40)]
	var first: Tower = g.place_gem(Vector2i(34, 40))   # der zurückgenommene Gem von oben kommt wieder
	check(first != null and _gem_key(first) == rock_gem, "zurückgenommener Gem wird beim nächsten Setzen wiederverwendet")
	for c in cells.slice(0, 4):
		g.place_gem(c)
	check(g.phase == g.Phase.CHOOSE, "5 Gems gesetzt, Auswahlphase")
	var gems: Array = g.round_towers.map(_gem_key)
	var rng_state: int = g.rng.state
	var mid: Tower = g.round_towers[2]
	var mid_gem := _gem_key(mid)
	var mid_cell := mid.cell
	var opts: Array = g.tower_options(mid)
	check(opts.any(func(o): return o.action == "take_back"), "Auswahlphase bietet Zurücknehmen")
	g._select(mid)
	g._on_option_chosen(opts.find(opts.filter(func(o): return o.action == "take_back")[0]))
	check(g.phase == g.Phase.BUILD and g.round_towers.size() == 4 and not g.towers.has(mid_cell), "Zurücknehmen in der Auswahlphase führt zurück in die Bauphase")
	# Spielstand mitten drin: auch nach dem Laden kommt derselbe Gem wieder
	var st := SaveGame.capture(g)
	var h: Node = load(Session.GAME).instantiate()
	add_child(h)
	await get_tree().process_frame
	SaveGame.apply(h, st)
	var again: Tower = h.place_gem(cells[4])
	check(again != null and _gem_key(again) == mid_gem and h.phase == h.Phase.CHOOSE, "nach Laden: derselbe Gem, nicht neu gewürfelt")
	h.queue_free()
	var re: Tower = g.place_gem(cells[4])
	check(_gem_key(re) == mid_gem and g.rng.state == rng_state, "Neusetzen würfelt nicht neu (gleicher Gem, Zufall unverändert)")
	# Alle zurücknehmen und neu setzen: genau dieselben Gems
	while not g.round_towers.is_empty():
		g.take_back(g.round_towers[-1])
	for c in cells:
		g.place_gem(c)
	var a1 := gems.duplicate()
	a1.sort()
	var a2: Array = g.round_towers.map(_gem_key)
	a2.sort()
	check(a1 == a2 and g.rng.state == rng_state, "alle zurücknehmen und neu setzen ergibt dieselben 5 Gems")
	# Nach dem Behalten (Welle) lässt sich nichts mehr zurücknehmen
	var kept: Tower = g.round_towers[0]
	g._select(kept)
	g._on_option_chosen(0)
	check(g.phase == g.Phase.WAVE and not g.can_take_back(kept) and g.round_towers.is_empty(), "nach Behalten kein Zurücknehmen mehr")
	check(not g.tower_options(kept).any(func(o): return o.action == "take_back"), "fertige Tower bieten kein Zurücknehmen")
	g.queue_free()
	await get_tree().process_frame


func _gem_key(t: Tower) -> String:
	return "%s:%d" % [t.tower_id, t.tier]


## Endboss der letzten Welle: Schadenscheck ohne Lebensverlust, im Punkte-Modus Punkte nach Schaden; Aufschlüsselung.
func _final_boss_test() -> void:
	for mode in [false, true]:
		Session.map_path = Database.list_maps()[0].path
		Session.map_override = null
		Session.score_mode = mode
		var g: Node = load(Session.GAME).instantiate()
		add_child(g)
		await get_tree().process_frame
		# ein normaler Kill in Welle 1 zählt beim Wellentyp
		g.phase = g.Phase.WAVE
		g._spawn_enemy(g.waves[0].groups[0])
		var first: Enemy = g.enemies[-1]
		g.on_enemy_killed(first)
		var t1: String = g.wave_type(g.waves[0])
		check(int(g.score_stats.get(t1, {}).get("kills", 0)) == 1, "Kill zählt beim Wellentyp %s" % t1)
		g.wave_index = g.waves.size() - 1
		check(g.is_final_boss_wave(), "letzte Welle ist der Endboss")
		g._spawn_enemy(g.waves[-1].groups[0])
		var boss: Enemy = g.enemies[-1]
		check(boss.final_boss, "Endboss markiert")
		boss.hp = boss.max_hp * 0.4
		g.lives = 1
		var score_before: float = g.score
		var st := SaveGame.capture(g)
		g.on_enemy_leaked(boss)
		check(g.lives == 1 and g.phase == g.Phase.WAVE, "%s: Endboss läuft durch, kostet keine Leben" % ("Punkte" if mode else "Leben"))
		check(is_equal_approx(g.final_boss.damage, boss.max_hp * 0.6), "Schaden am Endboss gezählt (60 %)")
		if mode:
			var expect: float = g.wave_points(g.waves.size()) * float(Database.balance.score.get("final_boss_factor", 3.0)) * 0.6
			check(is_equal_approx(g.score - score_before, expect), "Endboss bringt Punkte nach Schaden (%.0f)" % (g.score - score_before))
		else:
			check(g.score == score_before, "Leben-Modus: keine Punkte")
		g._process_wave(0.0)
		check(g.phase == g.Phase.VICTORY, "nach dem Endboss ist das Spiel gewonnen")
		check(g.hud.game_over_boss.visible and "60.0" in g.hud.game_over_boss.text, "Endbildschirm zeigt den Schaden am Endboss: %s" % g.hud.game_over_boss.text)
		check(g.hud.game_over_table.visible == mode, "Aufschlüsselung nur im Punkte-Modus (%d Felder)" % g.hud.game_over_table.get_child_count())
		# Laden mitten im Endboss: Markierung und Wertung bleiben
		var h: Node = load(Session.GAME).instantiate()
		add_child(h)
		await get_tree().process_frame
		SaveGame.apply(h, st)
		check(h.enemies.size() >= 1 and h.enemies.any(func(e): return e.final_boss) and int(h.score_stats.get(t1, {}).get("kills", 0)) == 1,
			"Spielstand: Endboss und Wertung bleiben erhalten")
		h.queue_free()
		g.queue_free()
		await get_tree().process_frame
	Session.score_mode = false
