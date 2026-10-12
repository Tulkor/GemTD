extends Node
## Screenshots aus dem echten Spiel, ohne jedes Mal ein eigenes Aufnahme-Skript zu schreiben.
## Start über tools/screenshot.sh (setzt Xvfb und OpenGL), Optionen nach "--":
##   --szene=spiel|menu|map_editor|tower_editor   Standard spiel
##   --map=<id>              Map aus data/maps (Standard classic)
##   --runden=N              N Runden automatisch spielen (Gems am Weg setzen, ersten behalten, Welle 8× laufen)
##   --tower=ruby:2,opal:0   diese Gems in der nächsten Runde setzen (Reihenfolge = Platzierung)
##   --welle=N               nächste Welle ist Welle N (Debug-Sprung)
##   --phase=bau|wahl|welle  Stand für das Bild (Standard bau); welle startet die Welle
##   --warten=S              Sekunden Spielzeit vor dem Bild (z. B. Gegner unterwegs), Standard 1
##   --auswahl               ersten Tower der Runde (sonst den ersten auf dem Feld) auswählen
##   --winkel=oben,schraeg,nah,seite   ein Bild pro Winkel (Standard schraeg = Spielansicht)
##   --punkt=x,y             Kamera auf dieses Feld richten (für nah)
##   --zuschnitt=x,y,b,h     Bild zuschneiden (Pixel)
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
	Session.skip_setup = true
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
		_:
			var path := "res://data/maps/%s.json" % opts.get("map", "classic")
			Session.map_path = path
			Session.map_override = null
			# Maps eines anderen Spiels (z. B. "game": "eevetd") starten dessen Szene
			var md = Database.load_json(path)
			var kind: String = str(md.get("game", "gemtd")) if md is Dictionary else "gemtd"
			Session.game_kind = kind
			node = load(Session.game_scene()).instantiate()
	add_child(node)
	await _frames(5)
	var angles: PackedStringArray = ["bild"]
	if scene == "spiel":
		await _prepare(node)
		angles = String(opts.get("winkel", "schraeg")).split(",")
	for w in angles:
		if scene == "spiel":
			_camera(node, w)
		await _frames(4)
		var img := get_viewport().get_texture().get_image()
		if opts.has("zuschnitt"):
			var r := String(opts.zuschnitt).split(",")
			img = img.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
		var file := out_dir.path_join("%s_%s.png" % [opts.get("name", "bild"), w])
		img.save_png(file)
		print("BILD ", file)
	get_tree().quit()


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


## eeveTD: kleines Labyrinth aus Barrikaden vor dem Eingang, einige davon zu Towern aufgewertet.
## --phase=welle startet Level 1, --auswahl wählt einen Tower aus.
func _prepare_eeve(game: Node) -> void:
	game.gold = 3000
	game.lumber = 2
	game.points = 6
	for el in ["nature", "nature", "nature", "fire", "fire", "storm"]:
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
	for c in plan:
		var t: Tower = game.towers.get(c)
		if t == null:
			continue
		for id in plan[c]:
			var opts: Array = game.tower_options(t)
			var i: int = opts.map(func(o): return o.id).find(id)
			if i >= 0:
				game._apply_option(t, opts[i])
	game.gold = 412
	game.log_lines = []
	if opts.get("phase", "bau") == "welle":
		game.submit({"type": "start_level"})
	if opts.has("auswahl"):
		game._select(game.towers.get(Vector2i(44, 76)))
	var t := 0.0
	var wait := float(opts.get("warten", "1"))
	while t < wait:
		await get_tree().process_frame
		t += get_process_delta_time()


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
			elif not game.towers.is_empty():
				focus = Board3D.footprint_center(game.towers.values()[0].cell)
			rig.target = Board3D.to_3d(focus)
		_:
			pass
	rig._apply()
