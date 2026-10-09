class_name Tower
extends Node2D
## Ein Tower auf dem Feld. Alle Werte kommen aus data/towers/<id>.json.

const CELL := MapView.CELL

var game  # game.gd
var cell := Vector2i.ZERO
var tower_id := ""
var tier := 0
var def: Dictionary = {}
var stats: Dictionary = {}
var color := Color.WHITE

var is_new := false   ## in dieser Runde gesetzt, noch nicht ausgewählt
var selected := false
var speed_bonus := 0.0
var cooldown_left := 0.0
var kills := 0
var total_damage := 0.0
var _pulse := 0.0


func setup(g, c: Vector2i, id: String, t: int) -> void:
	game = g
	cell = c
	position = MapView.cell_center(c)
	set_tower(id, t)


func set_tower(id: String, t: int) -> void:
	tower_id = id
	tier = t
	def = Database.towers.get(id, {})
	stats = Database.tower_tier(id, t)
	color = Color.from_string(str(def.get("color", "#ffffff")), Color.WHITE)
	queue_redraw()


func label() -> String:
	return Database.tower_label(tower_id, tier)


func range_px() -> float:
	return float(stats.get("range", 3.0)) * CELL


func abilities() -> Array:
	return stats.get("abilities", [])


func ability(type: String) -> Dictionary:
	for ab in abilities():
		if ab.get("type", "") == type:
			return ab
	return {}


func target_mode() -> String:
	return str(stats.get("targets", def.get("targets", "both")))


func can_target(e) -> bool:
	match target_mode():
		"air":
			return e.flying
		"ground":
			return not e.flying
	return true


func cooldown() -> float:
	return float(stats.get("cooldown", 1.0)) / (1.0 + speed_bonus)


func _process(delta: float) -> void:
	if is_new:
		_pulse += delta
		queue_redraw()
	if game == null or not game.is_wave_running():
		return
	cooldown_left -= delta
	if cooldown_left > 0.0:
		return
	var count := 1
	var ms := ability("multishot")
	if not ms.is_empty():
		count = int(ms.targets)
	var targets: Array = game.find_targets(self, count)
	if targets.is_empty():
		return
	for e in targets:
		_attack(e)
	cooldown_left = cooldown()


func _roll_damage() -> float:
	var dmg: Array = stats.get("damage", [1, 1])
	return randf_range(float(dmg[0]), float(dmg[1]))


func _attack(e) -> void:
	var dmg := _roll_damage()
	var crit := ability("crit")
	if not crit.is_empty() and randf() < float(crit.chance):
		dmg *= float(crit.multiplier)
	game.add_beam(position, e.position, color)
	var target_pos: Vector2 = e.position
	_hit(e, dmg)
	var splash := ability("splash")
	if not splash.is_empty():
		for other in game.enemies_in_radius(target_pos, float(splash.radius) * CELL):
			if other != e and can_target(other):
				_hit(other, dmg * float(splash.factor))


func _hit(e, dmg: float) -> void:
	if e.dead:
		return
	var slow := ability("slow")
	if not slow.is_empty():
		e.apply_slow(float(slow.factor), float(slow.duration))
	var poison := ability("poison")
	if not poison.is_empty():
		e.apply_poison(float(poison.dps), float(poison.duration))
	total_damage += e.take_damage(dmg)
	if e.dead:
		kills += 1


func info_text() -> String:
	var dmg: Array = stats.get("damage", [0, 0])
	var lines := [
		label(),
		"Schaden: %d–%d" % [int(dmg[0]), int(dmg[1])],
		"Abklingzeit: %.2fs%s" % [cooldown(), "  (+%d%% Aura)" % int(speed_bonus * 100) if speed_bonus > 0 else ""],
		"Reichweite: %.1f Felder" % float(stats.get("range", 0)),
	]
	match target_mode():
		"air":
			lines.append("Greift nur Luft an")
		"ground":
			lines.append("Greift nur Boden an")
	for ab in abilities():
		lines.append("• " + Abilities.describe(ab))
	if not is_new:
		lines.append("Kills: %d   Schaden gesamt: %d" % [kills, int(total_damage)])
	return "\n".join(lines)


func _draw() -> void:
	var r := CELL * 0.42
	if selected:
		draw_circle(Vector2.ZERO, range_px(), Color(1, 1, 1, 0.07))
		draw_arc(Vector2.ZERO, range_px(), 0, TAU, 64, Color(1, 1, 1, 0.5), 1.5)
	if def.get("category", "gem") == "special":
		var pts := PackedVector2Array()
		for i in 6:
			pts.append(Vector2.from_angle(i * TAU / 6.0) * r)
		draw_colored_polygon(pts, color)
		pts.append(pts[0])
		draw_polyline(pts, color.darkened(0.5), 2.0)
	else:
		var s := r * (0.7 + 0.075 * tier)
		var pts := PackedVector2Array([Vector2(0, -s), Vector2(s, 0), Vector2(0, s), Vector2(-s, 0)])
		draw_colored_polygon(pts, color)
		pts.append(pts[0])
		draw_polyline(pts, color.darkened(0.5), 1.5)
		# Stufe als Punkte
		for i in tier + 1:
			draw_circle(Vector2(-CELL * 0.36 + i * 5.0, CELL * 0.38), 1.8, Color.WHITE)
	if is_new:
		var a := 0.5 + 0.5 * sin(_pulse * 5.0)
		draw_rect(Rect2(-Vector2(CELL, CELL) / 2.0 + Vector2.ONE, Vector2(CELL, CELL) - Vector2.ONE * 2), Color(1, 1, 1, a), false, 1.5)
	if selected:
		draw_rect(Rect2(-Vector2(CELL, CELL) / 2.0, Vector2(CELL, CELL)), Color.YELLOW, false, 2.0)
