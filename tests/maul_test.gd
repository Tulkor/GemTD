extends Node
## Test für Shopping Maul: godot --headless --path . res://tests/maul_test.tscn
## Lädt die Daten, prüft alle Wege, baut im Zentrum und spielt die ersten Level im Zeitraffer.

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	await get_tree().process_frame
	check(MaulData.shops().size() == 20, "20 Filialen geladen")
	check(MaulData.towers().size() >= 200, "Tower geladen: %d" % MaulData.towers().size())
	check(MaulData.levels().size() == 50, "50 Level geladen")
	for s in MaulData.shops():
		for t in s.towers:
			if t.upgrade_from != null:
				check(MaulData.tower(str(t.upgrade_from)).get("upgrades_to", []).has(t.id), "Upgrade %s hängt an %s" % [t.id, t.upgrade_from])
	for s in MaulData.shops().filter(func(x): return x.kind == "standard"):
		check(not MaulData.buyable(str(s.id)).is_empty(), "Filiale %s hat kaufbare Tower" % s.id)

	var game: MaulGame = load("res://scenes/maul_game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	for leg in game.all_legs():
		var r := game._compute_route(leg[0], leg[1], "ground", game.pathfinder)
		check(not r.path.is_empty(), "Weg von %s über %d Punkte" % [leg[0], leg[1].size()])

	game.start_game("hm", 1, "group")
	check(game.phase == MaulGame.Phase.COUNTDOWN, "Countdown läuft nach der Filialwahl")
	check(game.players[0].gold == 545, "Startgold 500 + 45 für P1: %d" % game.players[0].gold)
	check(game.lives == 150, "Normal: 150 Leben")

	# Bauen: eigene Zone, nicht außerhalb, nicht blockierend
	var zone: Rect2i = game.map.zones[0].rect
	var cheap := str(MaulData.buyable("hm")[0].id)
	check(game.build_problem(cheap, Vector2i(5, 5), 0) != "", "außerhalb des Gebiets wird nicht gebaut")
	var built := 0
	var spots := _spots(game, zone)
	for a in spots:
		if game.players[0].gold < 100:
			break
		var id := str(MaulData.buyable("hm")[2].id) if game.players[0].gold >= 200 else cheap
		if game.submit({"type": "build", "tower": id, "cell": a}):
			built += 1
	check(built >= 4, "%d Tower im Zentrum gebaut" % built)
	for leg in game.all_legs():
		check(not game._route(leg[0], leg[1], "ground").path.is_empty(), "Weg nach dem Bauen offen")
		break
	# Verkaufen bringt 75 %
	var t: MaulTower = game.towers.values()[0]
	var gold_before: int = game.players[0].gold
	var refund := game.sell_value(t)
	check(game.submit({"type": "sell", "cell": t.cell}), "Verkaufen klappt")
	check(game.players[0].gold == gold_before + refund, "Verkauf bringt %d Gold" % refund)

	# Level 1 im Zeitraffer
	game.submit({"type": "start_now"})
	Engine.time_scale = 8.0
	var waited := 0.0
	while game.level < 3 and waited < 240.0 and game.phase < MaulGame.Phase.GAME_OVER:
		await get_tree().create_timer(0.5, true, false, true).timeout
		waited += 0.5
		if game.phase == MaulGame.Phase.COUNTDOWN:
			game.submit({"type": "start_now"})
			# Gold sofort verbauen
			for a in spots:
				if game.players[0].gold < 30:
					break
				game.submit({"type": "build", "tower": str(MaulData.buyable("hm")[1].id), "cell": a})
	Engine.time_scale = 1.0
	check(game.level >= 3, "Level 1 und 2 gespielt (jetzt Level %d)" % game.level)
	check(game.enemies_killed > 0, "Gegner besiegt: %d" % game.enemies_killed)
	check(game.income_pot > 185, "Einkommen gewachsen: %d" % game.income_pot)
	print("Leben %d, durchgelassen %d, JE %.2f, Gold %d, Tower %d" % [game.lives, game.enemies_leaked, game.je, game.players[0].gold, game.towers.size()])
	game.queue_free()
	await get_tree().process_frame
	print("FERTIG mit %d Fehlern" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Bauplätze im Gebiet mit Abstand, damit der Weg frei bleibt.
func _spots(game: MaulGame, zone: Rect2i) -> Array:
	var list := []
	for y in range(zone.position.y + 1, zone.end.y - 2, 4):
		for x in range(zone.position.x + 1, zone.end.x - 2, 4):
			list.append(Vector2i(x, y))
	# nahe an der Mittelbahn zuerst (dort laufen die Gegner)
	var mid := Vector2(zone.get_center())
	list.sort_custom(func(a, b): return Vector2(a).distance_to(mid) < Vector2(b).distance_to(mid))
	return list
