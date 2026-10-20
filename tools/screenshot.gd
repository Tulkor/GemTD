extends Node
## Screenshots aus dem echten Spiel, ohne jedes Mal ein eigenes Aufnahme-Skript zu schreiben.
## Start über tools/screenshot.sh (setzt Xvfb und OpenGL), Optionen nach "--":
##   --szene=spiel|menu|map_editor|tower_editor|maul   Standard spiel
##   --seite=single|history|lobby|einstellungen   im Hauptmenü diese Seite zeigen (Standard Hub)
##   --ui=70                 UI-Größe in Prozent (50–100), wird nicht gespeichert
##   --lobby=Anna,Ben,Max    (mit --seite=lobby) als Host mit diesen Mitspielern, --felder=0,1,1,2 Feld je Spieler
##                           (Host zuerst), --stimme=eevetd Modus vorwählen, --relay=127.0.0.1:24565 über einen Relay
##                           hosten (vorher tools/relay/relay.py starten), Code steht dann oben links
##   Shopping Maul (--szene=maul): --filiale=hm (ohne: Filialwahl), --level=N (so viele Level spielen),
##                           --welle (nächstes Level starten), --auswahl[=Tower-ID], --warten=S; Kamera aufs Zentrum
##                           (oder --punkt=x,y), Abstand --abstand=34;
##                           --sandbox, --gold=N, --reiter=xpert|main (Ladenreiter), --einheit (erste Einheit wählen),
##                           --profi (Filialwahl: Reiter Profi-Filialen), --bauen=h01P,h02O (diese Tower zuerst)
##   --map=<id>              Map aus data/maps (Standard classic)
##   --runden=N              N Runden automatisch spielen (Gems am Weg setzen, ersten behalten, Welle 8× laufen)
##   --tower=ruby:2,opal:0   diese Gems in der nächsten Runde setzen (Reihenfolge = Platzierung)
##   --welle=N               nächste Welle ist Welle N (Debug-Sprung)
##   --phase=bau|wahl|welle  Stand für das Bild (Standard bau); welle startet die Welle
##   --warten=S              Sekunden Spielzeit vor dem Bild (z. B. Gegner unterwegs), Standard 1
##   --faehigkeiten=pierce,fork   allen Towern auf dem Feld diese Fähigkeiten (Standardwerte) dazugeben
##   --auswahl               ersten Tower der Runde (sonst den ersten auf dem Feld) auswählen
##   --treffer               nach --warten weiter warten, bis ein Treffer-Effekt leuchtet (höchstens 10 s), dann Bild
##   --grundtower=water      eeveTD: statt des festen Plans überall den Grundturm dieses Elements
##   --winkel=oben,schraeg,nah,seite   ein Bild pro Winkel (Standard schraeg = Spielansicht)
##   --punkt=x,y             Kamera auf dieses Feld richten (für nah)
##   --gegner                nah: Kamera dicht auf den ersten Gegner (z. B. Boss mit --welle=42 --phase=welle)
##   --zuschnitt=x,y,b,h     Bild zuschneiden (Pixel)
##   --koop=Name1,Name2      als Koop-Partie mit diesen Spielern (ohne Netz), --gast = Bild aus Sicht von Spieler 2
##   --vitrine               eeveTD: viele verschiedene Tower auf den Mauern (Modelle ansehen)
##   --einstellungen         Einstellungsfenster vor Runde 1 offen lassen (z. B. eeveTD)
##   --nacht                 Nachtversion des Spielfeld-Stils (FieldStyle.night, z. B. Shopping Maul im Mondlicht,
##                           eeveTD mit Laternen und Glühwürmchen)
##   --debug                 Debug-Menü offen (GemTD, eeveTD, Shopping Maul)
##   --spielmenue[=einstellungen]  Menü im Spiel offen (wie Esc), mit =einstellungen dazu das Einstellungsfenster
##   --sprache=de|en
##   --aus=<ordner>          Standard /mnt/project-files/screens/auto
##   --name=<präfix>         Dateiname <präfix>_<winkel>.png, Standard bild
## Ausgabe: eine Zeile BILD <pfad> je Bild. Für eigene Zustände (Tooltip, Panel) Skript kopieren
## und nach _prepare() eigene Schritte einfügen.

var opts := {}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	rng.seed = int(opts.get("seed", "1"))
	RunHistory.path = "user://screenshot_run_history.json"
	Session.skip_setup = not opts.has("einstellungen")
	FieldStyle.night = opts.has("nacht")
	if opts.has("koop"):
		var guest := opts.has("gast")
		Session.coop = {"role": "client" if guest else "host", "player": 1 if guest else 0, "names": String(opts.koop).split(",")}
	if opts.has("sprache"):
		Loc.set_language(opts.sprache)
	var out_dir: String = opts.get("aus", "/mnt/project-files/screens/auto")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var scene: String = opts.get("szene", "spiel")
	var node: Node
	match scene:
		"menu": node = load(Session.MAIN_MENU).instantiate()
		"map_editor": node = load(Session.MAP_EDITOR).instantiate()
		"tower_editor": node = load(Session.TOWER_EDITOR).instantiate()
		"maul": node = load(Session.MAUL).instantiate()
		_:
			var path := "res://data/maps/%s.json" % opts.get("map", "classic")
			Session.map_path = path
			Session.map_override = null
			# Maps eines anderen Spiels (z. B. "game": "eevetd") starten dessen Szene
			var md = Database.load_json(path)
			var kind: String = str(md.get("game", "gemtd")) if md is Dictionary else "gemtd"
			Session.game_kind = kind
			node = load(Session.game_scene()).instantiate()
	# Fenster so groß wie der Xvfb-Bildschirm (--groesse), nicht die gespeicherte Auflösung
	Display.resolution = DisplayServer.screen_get_size()
	Display.fullscreen = false
	if opts.has("ui"):
		Display.ui_scale = clampf(float(opts.ui) / 100.0, Display.UI_SCALE_MIN, Display.UI_SCALE_MAX)
	Display._apply()
	add_child(node)
	await _frames(5)
	if scene == "menu" and opts.get("seite", "") == "einstellungen":
		node._open_settings()
	elif scene == "menu" and opts.has("seite"):
		node.show_page(opts.seite)
		await _frames(3)
	if scene == "menu" and opts.has("lobby"):
		await _fake_lobby(node)
	var angles: PackedStringArray = ["bild"]
	if scene == "maul":
		await _prepare_maul(node)
	if scene == "spiel":
		await _prepare(node)
		angles = String(opts.get("winkel", "schraeg")).split(",")
	if opts.has("debug") and (scene == "spiel" or scene == "maul"):
		if scene == "maul":
			node.hud.toggle_debug()
		else:
			node.hud.debug_panel.show()
			node.hud.debug_button.set_pressed_no_signal(true)
	if opts.has("spielmenue") and (scene == "spiel" or scene == "maul"):
		if scene == "maul":
			node.hud.toggle_menu()
		else:
			node.hud.open_leave_confirm()
		if str(opts.spielmenue) == "einstellungen":
			node.hud.settings_panel.open()
	for w in angles:
		if scene == "spiel":
			_camera(node, w)
		await _frames(4)
		if opts.has("treffer") and scene == "spiel":
			await _wait_hit(node)
		var img := get_viewport().get_texture().get_image()
		if opts.has("zuschnitt"):
			var r := String(opts.zuschnitt).split(",")
			img = img.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
		var file := out_dir.path_join("%s_%s.png" % [opts.get("name", "bild"), w])
		img.save_png(file)
		print("BILD ", file)
	get_tree().quit()


## Lobby als Host mit erfundenen Mitspielern (nur fürs Bild, ohne echte Verbindungen).
func _fake_lobby(menu: Node) -> void:
	Net.my_name = "Lukas"
	if opts.has("relay"):   # --relay=127.0.0.1:24565: über einen laufenden Relay hosten (tools/relay/relay.py)
		Net.host_relay(str(opts.relay))
		for i in 300:
			if not Net.is_connecting():
				break
			await get_tree().process_frame
	else:
		Net.host(24690)
	var names := String(opts.lobby).split(",")
	for i in names.size():
		Net.players[100 + i] = {"name": names[i], "status": {}, "uid": "fake-%d" % i}
	if opts.has("stimme"):
		Net.vote(str(opts.stimme))
	var lobby = menu.lobby
	var list := String(opts.get("felder", "")).split(",", false)
	var uids := [Net.uid] + range(names.size()).map(func(i): return "fake-%d" % i)
	for i in mini(list.size(), uids.size()):
		lobby.fields[uids[i]] = int(list[i])
	Net.players_changed.emit()
	await _frames(5)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Spielstand für das Bild herstellen.
func _prepare(game: Node) -> void:
	game.camera_rig.set_process(false)   # kein Mitlaufen am Fensterrand (Maus steht in Xvfb in der Ecke)
	if game.has_method("add_element_point"):
		await _prepare_eeve(game)
		return
	for i in int(opts.get("runden", "0")):
		_place_round(game, [])
		game._select(game.round_towers[0])
		game._on_option_chosen(0)
		Engine.time_scale = 8.0
		var frames := 0
		while game.phase == game.Phase.WAVE and frames < 20000:
			await get_tree().process_frame
			frames += 1
		Engine.time_scale = 1.0
	if opts.has("welle"):
		game.debug_jump_to_wave(int(opts.welle))
	var phase: String = opts.get("phase", "bau")
	if phase != "bau" or opts.has("tower"):
		var wanted: Array = String(opts.get("tower", "")).split(",", false)
		_place_round(game, wanted)
	if phase == "welle":
		game._select(game.round_towers[0])
		game._on_option_chosen(0)
	if opts.has("faehigkeiten"):
		for t in game.towers.values():
			t.stats = t.stats.duplicate(true)
			var list: Array = t.stats.get("abilities", [])
			for type in String(opts.faehigkeiten).split(","):
				list.append(Abilities.default_for(type))
			t.stats["abilities"] = list
	if opts.has("auswahl"):
		if not game.round_towers.is_empty():
			game._select(game.round_towers[0])
		elif not game.towers.is_empty():
			game._select(game.towers.values()[0])
	var t := 0.0
	var wait := float(opts.get("warten", "1"))
	while t < wait:
		await get_tree().process_frame
		t += get_process_delta_time()


## Shopping Maul: Filiale eröffnen, im Zentrum bauen, Level im Zeitraffer spielen.
func _prepare_maul(game: Node) -> void:
	game.camera_rig.set_process(false)
	if not opts.has("filiale"):
		if opts.has("profi"):
			game.hud._setup._kind = "pro"
			game.hud._setup._build_cards()
		return
	var shop: String = opts.filiale
	game.start_game(shop, 1, "group", opts.has("sandbox"))
	if opts.has("gold"):
		game.players[0].gold = int(opts.gold)
	var zone: Rect2i = game.map.zones[0].rect
	var spots := []
	for y in range(zone.position.y + 1, zone.end.y - 2, 4):
		for x in range(zone.position.x + 1, zone.end.x - 2, 4):
			spots.append(Vector2i(x, y))
	var mid := Vector2(zone.get_center())
	spots.sort_custom(func(a, b): return Vector2(a).distance_to(mid) < Vector2(b).distance_to(mid))
	var build := func():
		var list: Array = MaulData.buyable(shop)
		for id in str(opts.get("bauen", "")).split(",", false):
			for a in spots:
				if game.submit({"type": "build", "tower": id, "cell": a}):
					break
		for a in spots:
			var best := ""
			for t in list:
				if int(t.cost) <= game.players[0].gold:
					best = str(t.id)
			if best == "":
				break
			game.submit({"type": "build", "tower": best, "cell": a})
		# Profi-Filialen: Slots mit Items füllen, Drohnen und Zombies holen
		for t in game.towers.values():
			for id in game.items_for(0, "weapon"):
				game.submit({"type": "item", "cell": t.cell, "item": id})
			if t.tower_id == "h02O":
				game.submit({"type": "drone", "cell": t.cell, "kind": "battle"})
	build.call()
	for i in int(opts.get("level", "0")):
		game.submit({"type": "start_now"})
		Engine.time_scale = 8.0
		var frames := 0
		while game.phase != game.Phase.COUNTDOWN or game.level <= i:
			await get_tree().process_frame
			frames += 1
			if frames > 60000 or game.phase >= game.Phase.GAME_OVER:
				break
		Engine.time_scale = 1.0
		build.call()
	if opts.has("welle"):
		game.submit({"type": "start_now"})
	if opts.has("auswahl") and not game.towers.is_empty():
		var pick: Node = game.towers.values()[0]
		for t in game.towers.values():
			if t.slots() > 0 or t.tower_id == str(opts.get("auswahl")):
				pick = t
		game.select(pick)
	if opts.has("einheit") and not game.units.is_empty():
		game.select_unit(game.units[0])
	if opts.has("reiter"):
		game.hud._set_tab(str(opts.reiter))
	var look: Vector2 = game.map.zone_center(0)
	if opts.has("punkt"):
		var pk := String(opts.punkt).split(",")
		look = (Vector2(float(pk[0]), float(pk[1])) + Vector2(0.5, 0.5)) * Board3D.CELL
	game.camera_rig.look_at_point(look, float(opts.get("abstand", "34")))
	var t := 0.0
	var wait := float(opts.get("warten", "1"))
	while t < wait:
		await get_tree().process_frame
		t += get_process_delta_time()


## --vitrine: statt des festen Plans viele verschiedene Tower (Modelle aus den CC0-Paketen) auf den Mauern.
func _eeve_vitrine(game: Node, walls: Array) -> Dictionary:
	for el in game.elements:
		game.element_caps[el] = 6
		game.elements[el] = 6
	game.gold = 200000
	var targets := ["eeve_camp_fire", "eeve_orb_of_life", "eeve_brazier", "eeve_minor_bird_launcher", "eeve_shroom_field",
			"eeve_lesser_rock_launcher", "eeve_enchanted_obelisk", "eeve_thorns_tower", "eeve_heat_stakes",
			"eeve_bird_launcher", "eeve_hazardous_shroom_field", "eeve_rock_launcher", "eeve_arcane_shrine", "eeve_blazing_brazier",
			"eeve_greater_bird_launcher", "eeve_gold_mine", "eeve_altar_of_magic", "eeve_itching_thorns_tower", "eeve_searing_totem",
			"eeve_sacred_orb_of_power", "eeve_ornate_obelisk", "eeve_nonhazardous_shroom_field", "eeve_hell_brazier",
			"eeve_greater_rock_launcher", "eeve_ruinous_obelisk", "eeve_xtreme_bird_launcher"]
	var plan := {}
	var i := 0
	for id in targets:
		var chain := []
		var cur: String = id
		while cur != "" and cur != "eeve_barricade" and chain.size() < 8:
			chain.push_front(cur)
			cur = str(Database.towers.get(cur, {}).get("eeve", {}).get("from", ""))
		if i < walls.size():
			plan[walls[i]] = chain
		i += 1
	return plan


## eeveTD: kleines Labyrinth aus Barrikaden vor dem Eingang, einige davon zu Towern aufgewertet.
## --phase=welle startet Level 1, --auswahl wählt einen Tower aus.
## --fallen: dazu Feuer 4 mit einem Flammenrost auf dem Weg und ein Dual-Tower (Feuerbeerenstrauch, Feld 32,68),
## --auswahl wählt ihn.
func _prepare_eeve(game: Node) -> void:
	game.gold = 3000
	game.lumber = 2
	game.points = 6
	var points := ["nature", "nature", "nature", "fire", "fire", "storm"]
	if opts.has("fallen"):
		game.points = 8
		game.gold = 6000
		points += ["fire", "fire"]
	for el in points:
		game.add_element_point(el)
	# Zwei versetzte Mauern vor dem Eingang (unten Mitte), Gegner laufen im Bogen herum
	var walls := []
	for x in range(30, 58, 2):
		walls.append(Vector2i(x, 76))
	for x in range(32, 60, 2):
		walls.append(Vector2i(x, 68))
	for c in walls:
		game.build_barricade(c)
	var plan := {Vector2i(36, 76): ["eeve_nature_base_tower", "eeve_thorns_tower"], Vector2i(44, 76): ["eeve_fire_base_tower", "eeve_camp_fire", "eeve_brazier"],
			Vector2i(50, 76): ["eeve_storm_base_tower", "eeve_storm_lantern"], Vector2i(40, 68): ["eeve_nature_base_tower", "eeve_orb_of_life"],
			Vector2i(48, 68): ["eeve_fire_base_tower", "eeve_heat_stakes", "eeve_searing_totem"], Vector2i(54, 68): ["eeve_nature_base_tower", "eeve_minor_bird_launcher"]}
	if opts.has("vitrine"):
		plan = _eeve_vitrine(game, walls)
	if opts.has("grundtower"):
		game.points += 1
		game.add_element_point(str(opts.grundtower))
		for c in plan:
			plan[c] = ["eeve_%s_base_tower" % opts.grundtower]
	for c in plan:
		var t: Tower = game.towers.get(c)
		if t == null:
			continue
		for id in plan[c]:
			var opts: Array = game.tower_options(t)
			var i: int = opts.map(func(o): return o.id).find(id)
			if i >= 0:
				game._apply_option(t, opts[i])
	if opts.has("fallen"):
		var d: Tower = game.towers.get(Vector2i(32, 68))
		for id in ["eeve_dual_element_base_tower", "eeve_fire_berry_bush"]:
			var o: Array = game.tower_options(d)
			game._apply_option(d, o[o.map(func(x): return x.id).find(id)])
		game.lumber = 2
		# Falle auf den Weg zwischen den beiden Mauern
		var path := Array(game.pathfinder.compute_path())
		path.sort_custom(func(a, b): return a.distance_to(Vector2(42, 72)) < b.distance_to(Vector2(42, 72)))
		for p in path:
			if game.build_trap("eeve_flame_grate", Vector2i(p) - Vector2i.ONE):
				break
	game.gold = 412
	game.log_lines = []
	if opts.get("phase", "bau") == "welle":
		game.submit({"type": "start_level"})
	if opts.has("auswahl"):
		game._select(game.towers.get(Vector2i(32, 68) if opts.has("fallen") else Vector2i(44, 76)))
	var t := 0.0
	var wait := float(opts.get("warten", "1"))
	while t < wait:
		await get_tree().process_frame
		t += get_process_delta_time()


## --treffer: warten, bis ein Treffer leuchtet. Die Spielzeit läuft dabei langsam (Xvfb rendert nur wenige
## Bilder pro Sekunde, sonst wäre der Treffer schon vorbei); --treffer=0.1 = so viele Sekunden danach.
func _wait_hit(game: Node) -> void:
	var fx: FxPlayer = game.effects.fx
	Engine.time_scale = 0.05
	var t := 0.0
	while fx.lights_active() == 0 and t < 10.0:
		await get_tree().process_frame
		t += get_process_delta_time() / Engine.time_scale
	var after := float(opts.treffer) if str(opts.treffer) != "1" else 0.08
	var waited := 0.0
	while waited < after:
		await get_tree().process_frame
		waited += get_process_delta_time()
	print("TREFFER Lichter=%d nach %.1f s" % [fx.lights_active(), t])


## Setzt Gems nahe am Weg, bis die Runde voll ist (wanted: "id:stufe" je Gem, Rest zufällig).
func _place_round(game: Node, wanted: Array) -> void:
	var tries := 0
	while game.phase == game.Phase.BUILD and tries < 5000:
		tries += 1
		var n: int = game.round_towers.size()
		game.debug_tower = wanted[n] if n < wanted.size() else ""
		var p: Vector2 = game.ground_path[rng.randi_range(0, game.ground_path.size() - 1)]
		var c := Vector2i(p / Board3D.CELL) + Vector2i(rng.randi_range(-3, 1), rng.randi_range(-3, 1))
		if game.can_place(c):
			game.place_gem(c)
	game.debug_tower = ""


func _camera(game: Node, w: String) -> void:
	var rig: CameraRig = game.camera_rig
	rig.frame_map(game.map.width * Board3D.CELL, game.map.height * Board3D.CELL)
	match w:
		"oben":
			rig.pitch = deg_to_rad(-89.0)
			rig.yaw = 0.0
		"seite":
			rig.pitch = deg_to_rad(-25.0)
			rig.yaw = deg_to_rad(35.0)
			rig.distance *= 0.8
		"nah":
			rig.pitch = deg_to_rad(-50.0)
			rig.distance = 14.0
			var focus := Vector2.ZERO
			if opts.has("punkt"):
				var p := String(opts.punkt).split(",")
				focus = Vector2(int(p[0]), int(p[1])) * Board3D.CELL
			elif opts.has("gegner") and not game.enemies.is_empty():
				Engine.time_scale = 0.0  # Bild anhalten, sonst läuft der Gegner bis zur Aufnahme aus dem Bild
				focus = game.enemies[0].pos
				rig.distance = 9.0
			elif not game.towers.is_empty():
				focus = Board3D.footprint_center(game.towers.values()[0].cell)
			rig.target = Board3D.to_3d(focus)
		_:
			pass
	rig._apply()
