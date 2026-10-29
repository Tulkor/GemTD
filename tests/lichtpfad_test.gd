extends Node
## Lauf: einzeln (Name lichtpfad)
## Lichtpfad (path_lights.gd): Lichter im Abstand von 0,5 s entlang der Gegnerwege, Farben je Modus oder Map,
## Umschalter im HUD (GemTD-Familie und Shopping Maul), gespeichert in Display.path_lights.

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	Profile.dir = "user://test_profile"
	RunHistory.path = "user://test_run_history.json"
	Session.skip_setup = true
	var before: bool = Display.path_lights

	# Einheit: Anzahl, Abstand, Farben
	var board := Board3D.new()
	var pl := PathLights.new(board, "eevetd")
	add_child(pl)
	pl.set_paths([PackedVector2Array([Vector2.ZERO, Vector2(10, 0), Vector2(10, 10)]), PackedVector2Array([Vector2.ZERO])])
	check(pl.lane_count() == 1, "Bahn mit nur einem Punkt wird übersprungen")
	var gap := PathLights.SPEED * PathLights.INTERVAL
	check(pl.light_count() == PathLights.lights_on(pl._lanes[0].len) and pl.light_count() >= int(19.0 / gap), "Lichter auf 20 Einheiten: %d" % pl.light_count())
	check(pl._colors[0] == Color(PathLights.COLORS.eevetd[0]), "eeveTD-Farben aus COLORS")
	var p0 := pl._heads.multimesh.get_instance_transform(1).origin
	pl._process(PathLights.INTERVAL)
	var p1 := pl._heads.multimesh.get_instance_transform(2).origin
	check(p0.distance_to(p1) < 0.2, "Nach 0,5 s steht das nächste Licht dort, wo das vorige war")
	var own := PathLights.new(board, "gemtd", ["123456"])
	check(own._colors == [Color("123456")], "Map-Farben gehen vor")
	own.free()
	pl.free()
	board.free()

	# GemTD: Knopf im HUD, Bahnen, Speichern
	Display.set_path_lights(false)
	Session.map_path = "res://data/maps/canyon.json"
	var game: Node = load(Session.GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	check(game.path_lights != null and not game.path_lights.visible, "GemTD: Lichtpfad aus")
	check(game.path_lights.lane_count() == game.lane_paths.size(), "GemTD: eine Lichterbahn je Bahn (%d)" % game.path_lights.lane_count())
	check(game.path_lights._colors[0] == Color("ffb03a"), "Map Schlucht hat eigene Farben")
	check(game.hud.lights_button != null and not game.hud.lights_button.button_pressed, "GemTD: Knopf Lichtpfad im HUD")
	game.hud.lights_button.button_pressed = true
	check(game.path_lights.visible and Display.path_lights, "GemTD: Knopf schaltet ein")
	var cfg := ConfigFile.new()
	cfg.load(Display.SETTINGS)
	check(bool(cfg.get_value("display", "path_lights", false)), "Einstellung gespeichert")
	game.queue_free()
	await get_tree().process_frame

	# Shopping Maul: startet eingeschaltet (gespeichert), Wege aller Abschnitte
	var maul: MaulGame = load("res://scenes/maul_game.tscn").instantiate()
	add_child(maul)
	await get_tree().process_frame
	check(maul.path_lights.visible and maul.hud.lights_button.button_pressed, "Maul: Lichtpfad bleibt an")
	check(maul.path_lights.lane_count() > 0, "Maul: %d Lichterbahnen" % maul.path_lights.lane_count())
	maul.set_path_lights(false)
	check(not maul.path_lights.visible and not maul.hud.lights_button.button_pressed, "Maul: ausschalten")
	maul.queue_free()
	await get_tree().process_frame

	Display.set_path_lights(before)
	print("FERTIG ", "OK" if failures == 0 else "%d Fehler" % failures)
	get_tree().quit(1 if failures > 0 else 0)
