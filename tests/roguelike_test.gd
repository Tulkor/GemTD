extends Node
## Lauf: einzeln (Name roguelike)
## GemTD-Variante Roguelike (rogue.gd): Angebot nach jeder zehnten Welle, Setzen gesperrt bis zur Wahl,
## Boni wirken nur auf den gewählten Tower (alle Stufen), Fenster, Spielstand und Einstellungen vor Runde 1.

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _new_game() -> Node:
	Session.map_path = Database.list_maps()[0].path
	Session.map_override = null
	var g: Node = load(Session.GAME).instantiate()
	add_child(g)
	return g


func _free_cell(g: Node, skip := 0) -> Vector2i:
	for y in range(4, g.map.height - 4, 2):
		for x in range(4, g.map.width - 4, 2):
			var c := Vector2i(x, y)
			if g.can_place(c):
				if skip == 0:
					return c
				skip -= 1
	return Vector2i(-1, -1)


func _ready() -> void:
	RunHistory.path = "user://test_run_history.json"
	Session.game_kind = "gemtd"
	check(int(Database.roguelike.get("every", 0)) == 10 and int(Database.roguelike.get("choices", 0)) == 3, "Regeln geladen: alle 10 Wellen 3 Boni")

	# Einstellungen vor Runde 1: Variante Roguelike einschalten
	Session.skip_setup = false
	Session.rogue = false
	var s: Node = _new_game()
	await get_tree().process_frame
	check(s.rogue == null and not s.setup_done, "Klassisch: kein Roguelike vor den Einstellungen")
	check(s.submit({"type": "setup", "difficulty": 1, "score_mode": false, "rogue": true}), "Einstellungen mit Roguelike angenommen")
	check(s.rogue != null and Session.rogue, "Roguelike nach den Einstellungen an")
	s.queue_free()

	Session.skip_setup = true
	Session.rogue = true
	var g: Node = _new_game()
	await get_tree().process_frame
	var r: Rogue = g.rogue
	check(r != null and not r.pending(0), "Roguelike an, vor Welle 1 kein Angebot")

	# Würfeln: nie Fallen, nie doppelt, Werte nach Seltenheit
	var ok := true
	var kinds := {}
	for i in 200:
		var offer := r.roll(0)
		var seen := {}
		ok = ok and offer.size() == 3
		for o in offer:
			var def: Dictionary = Database.towers[o.id]
			ok = ok and str(def.get("kind", "tower")) != "trap" and not seen.has(o.id + o.stat) and float(o.value) > 0.0
			ok = ok and str(def.get("category", "")) == o.kind
			seen[o.id + o.stat] = true
			kinds[o.kind] = true
	check(ok and kinds.has("gem") and kinds.has("special"), "200 Angebote: je 3 verschiedene, Gems und Spezialtower, keine Fallen")

	# nach Welle 10: Angebot, Setzen gesperrt, Fenster offen
	g.wave_index = 10
	g._enter_build()
	check(r.pending(0) and r.offers[0].size() == 3, "Nach Welle 10: drei Boni im Angebot")
	var c := _free_cell(g)
	check(not g.submit({"type": "place", "cell": c}), "Gems setzen ist bis zur Wahl gesperrt")
	await get_tree().process_frame
	var panel: Node = g.hud.find_children("*", "RoguePanel", true, false).front() if not g.hud.find_children("*", "RoguePanel", true, false).is_empty() else null
	check(panel != null, "Auswahlfenster ist offen")
	var o: Dictionary = r.offers[0][1]
	check(not g.submit({"type": "rogue_pick", "index": 1, "id": "falsch", "stat": o.stat}), "Fremdes Angebot wird abgelehnt")
	check(g.submit({"type": "rogue_pick", "index": 1, "id": o.id, "stat": o.stat}), "Bonus gewählt")
	check(not r.pending(0) and r.boons[0].size() == 1 and r.boons[0][0].id == o.id and r.boons[0][0].wave == 10, "Bonus gespeichert, Angebot weg")
	for i in 3:
		await get_tree().process_frame
	check(g.hud.find_children("*", "RoguePanel", true, false).is_empty(), "Fenster nach der Wahl zu")
	g.wave_index = 11
	g._enter_build()
	check(not r.pending(0), "Nach Welle 11 kein neues Angebot")

	# Wirkung: nur auf Rubine (alle Stufen), nicht auf Topas
	r.boons[0] = [
		{"id": "ruby", "kind": "gem", "stat": "damage", "value": 0.5, "rarity": "common", "wave": 10},
		{"id": "ruby", "kind": "gem", "stat": "speed", "value": 0.25, "rarity": "common", "wave": 10},
		{"id": "ruby", "kind": "gem", "stat": "range", "value": 0.2, "rarity": "rare", "wave": 20},
		{"id": "ruby", "kind": "gem", "stat": "damage", "value": 0.1, "rarity": "common", "wave": 30},
	]
	g.debug_tower = "ruby:3"
	g.place_gem(_free_cell(g))
	g.debug_tower = "topaz:0"
	g.place_gem(_free_cell(g))
	var ruby: Tower = g.round_towers[0]
	var topaz: Tower = g.round_towers[1]
	check(is_equal_approx(ruby.rogue_damage, 0.6) and is_equal_approx(ruby.rogue_speed, 0.25) and is_equal_approx(ruby.rogue_range, 0.2),
		"Rubin Stufe 3: +60 % Schaden, +25 % Tempo, +20 % Reichweite (gleiche Boni addieren sich)")
	check(is_equal_approx(ruby.range_cells(), float(ruby.stats.range) * 1.2) and is_equal_approx(ruby.cooldown(), float(ruby.stats.cooldown) / 1.25),
		"Reichweite und Abklingzeit des Rubins mit Bonus")
	check(topaz.rogue_damage == 0.0 and topaz.rogue_range == 0.0, "Topas bekommt nichts")
	var view := TowerStats.view(ruby)
	check(str(view.tiles).contains(tr("Roguelike-Bonus")), "Infofenster zeigt den Roguelike-Bonus")
	ruby.owner_player = 1
	g._update_auras()
	check(ruby.rogue_damage == 0.0, "Boni gelten nur für eigene Tower")
	ruby.owner_player = 0
	g._update_auras()

	# Spielstand: Boni und offenes Angebot bleiben
	g.wave_index = 20
	g._enter_build()
	var a: Dictionary = SaveGame.capture(g)
	check(a.has("rogue") and a.rogue.boons[0].size() == 4 and a.rogue.offers[0].size() == 3, "Spielstand enthält Boni und Angebot")
	Session.rogue = false
	Session.load_state = a.duplicate(true)
	var g2: Node = _new_game()
	await get_tree().process_frame
	check(g2.rogue != null and Session.rogue and g2.rogue.boons[0].size() == 4 and g2.rogue.pending(0), "Geladenes Spiel: Roguelike, Boni und Angebot wieder da")
	var r2: Tower = null
	for t in g2.all_towers():
		if t.tower_id == "ruby":
			r2 = t
	check(r2 != null and is_equal_approx(r2.rogue_damage, 0.6), "Geladener Rubin hat seinen Bonus")
	Session.load_state = {}
	Session.rogue = false
	_finish()


func _finish() -> void:
	print("FERTIG ", "OK" if failures == 0 else "%d Fehler" % failures)
	get_tree().quit(1 if failures > 0 else 0)
