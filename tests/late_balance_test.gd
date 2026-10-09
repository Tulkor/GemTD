extends Node
## Balance-Check späte Wellen: wie viel Prozent der Gesamt-HP einer Welle schafft ein einzelner Tower?
## Start: godot --headless --fixed-fps 60 --path . res://tests/late_balance_test.tscn -- [--tower=gold:1] [--waves=30,35]
## Der Tower steht allein an der ersten Ecke der klassischen Map (Fallen liegen auf dem Weg),
## die übrigen vier Gems der Runde werden abseits zu Steinen. Leben sind unbegrenzt, jede Welle
## läuft also komplett durch. Ausgabe pro Zeile: Tower, dann Prozent der Wellen-HP je Welle.
## Auren für andere Tower (Schaden, Tempo) und Verlangsamung zählen hier nicht mit.

## Spezial-Tower in jeder Stufe, Grund-Gems als Vergleich in den Stufen 4 und 5 (Perfekt, Groß)
const GEM_TIERS := [4, 5]
const WAVES := [30, 31, 32, 33, 34, 35, 39, 42, 43, 48, 50]
const TOWER_AT := Vector2i(10, 32)
const ROCKS_AT := [Vector2i(40, 50), Vector2i(44, 50), Vector2i(48, 50), Vector2i(52, 50)]


func _ready() -> void:
	await get_tree().process_frame
	var configs := []
	var waves := WAVES
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tower="):
			var p := arg.substr(8).split(":")
			configs.append([p[0], int(p[1]) if p.size() > 1 else 0])
		elif arg.begins_with("--waves="):
			waves = Array(arg.substr(8).split(",")).map(func(s): return int(s))
	if configs.is_empty():
		for id in Database.tower_ids():
			if Database.towers[id].get("category", "gem") == "gem":
				for t in GEM_TIERS:
					configs.append([id, t])
			else:
				for t in Database.tier_count(id):
					configs.append([id, t])
	var header := "%-28s" % "Tower"
	for w in waves:
		header += " %6s" % ("W%d%s" % [w, "L" if _is_air(w) else ""])
	print(header)
	for c in configs:
		var line := "%-28s" % ("%s:%d" % c)
		for w in waves:
			line += " %6.1f" % (await _run(c[0], c[1], w))
		print(line)
	Engine.time_scale = 1.0
	get_tree().quit()


func _is_air(wave: int) -> bool:
	var g: Dictionary = Database.wave_sets.get("classic", {}).get("waves", [])[wave - 1].groups[0]
	return Database.enemies.get(str(g.enemy), {}).get("flying", false)


## Prozent der Gesamt-HP der Welle, die der Tower verursacht hat.
func _run(id: String, tier: int, wave: int) -> float:
	Session.map_path = "res://data/maps/classic.json"
	var game: Node = load(Session.GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	game.wave_index = wave - 1
	game.lives = 1000000
	var at := TOWER_AT
	if str(Database.towers[id].get("kind", "tower")) == "trap":
		var path: Array = game.pathfinder.compute_path()
		at = path[path.size() / 8]
	game.debug_tower = "%s:%d" % [id, tier]
	var t: Tower = game.place_gem(at)
	game.debug_tower = "topaz:0"
	for a in ROCKS_AT:
		game.place_gem(a)
	game._select(t)
	game._on_option_chosen(0)
	var total_hp := 0.0
	for g in game.waves[wave - 1].groups:
		total_hp += float(Database.enemies[str(g.enemy)].hp) * int(g.count)
	Engine.time_scale = 4.0
	while game.phase == game.Phase.WAVE:
		await get_tree().process_frame
	var share := 100.0 * t.total_damage / total_hp
	game.queue_free()
	await get_tree().process_frame
	return share
