class_name Enemy
extends Node2D
## Ein Gegner. Grundwerte aus data/enemies/<id>.json, eine Welle kann sie überschreiben
## (hp, speed, armor, bounty, damage).

const CELL := MapView.CELL

var game  # game.gd
var enemy_id := ""
var max_hp := 10.0
var hp := 10.0
var speed := 2.0     ## Felder pro Sekunde
var armor := 0.0
var bounty := 1
var damage := 1      ## Leben, die der Spieler verliert, wenn der Gegner durchkommt
var flying := false
var size := 1.0
var color := Color.GRAY

var path := PackedVector2Array()
var path_index := 1
var traveled := 0.0  ## zurückgelegte Strecke, Tower zielen auf den Vordersten
var dead := false

var slow_factor := 0.0
var slow_time := 0.0
var poison_dps := 0.0
var poison_time := 0.0


func setup(g, def: Dictionary, o: Dictionary, p: PackedVector2Array) -> void:
	game = g
	enemy_id = str(def.get("id", ""))
	max_hp = float(o.get("hp", def.get("hp", 10)))
	hp = max_hp
	speed = float(o.get("speed", def.get("speed", 2.0)))
	armor = float(o.get("armor", def.get("armor", 0)))
	bounty = int(o.get("bounty", def.get("bounty", 1)))
	damage = int(o.get("damage", def.get("damage", 1)))
	flying = bool(def.get("flying", false))
	size = float(def.get("size", 1.0))
	color = Color.from_string(str(def.get("color", "#cccccc")), Color.GRAY)
	path = p
	if not path.is_empty():
		position = path[0]


func _process(delta: float) -> void:
	if dead:
		return
	if slow_time > 0.0:
		slow_time -= delta
		if slow_time <= 0.0:
			slow_factor = 0.0
	if poison_time > 0.0:
		poison_time -= delta
		_apply_raw(poison_dps * delta)
		if dead:
			return
	var move := speed * CELL * (1.0 - slow_factor) * delta
	while move > 0.0 and path_index < path.size():
		var target := path[path_index]
		var dist := position.distance_to(target)
		if dist <= move:
			position = target
			move -= dist
			traveled += dist
			path_index += 1
		else:
			position += (target - position).normalized() * move
			traveled += move
			move = 0.0
	queue_redraw()
	if path_index >= path.size():
		dead = true
		game.on_enemy_leaked(self)


## Rüstung wie in Warcraft 3: 6 % weniger Schaden pro Punkt, abnehmend.
func take_damage(amount: float) -> float:
	var reduction := 0.06 * armor / (1.0 + 0.06 * armor) if armor > 0 else 0.0
	return _apply_raw(amount * (1.0 - reduction))


func _apply_raw(amount: float) -> float:
	if dead:
		return 0.0
	var dealt := minf(amount, hp)
	hp -= amount
	if hp <= 0.0:
		dead = true
		game.on_enemy_killed(self)
	return dealt


func apply_slow(factor: float, duration: float) -> void:
	slow_factor = maxf(slow_factor, clampf(factor, 0.0, 0.9))
	slow_time = maxf(slow_time, duration)


func apply_poison(dps: float, duration: float) -> void:
	poison_dps = maxf(poison_dps, dps) if poison_time > 0.0 else dps
	poison_time = maxf(poison_time, duration)


func _draw() -> void:
	var r := CELL * 0.28 * size
	if flying:
		draw_circle(Vector2(3, 6), r * 0.8, Color(0, 0, 0, 0.3))
		var pts := PackedVector2Array([Vector2(0, -r), Vector2(r, r * 0.8), Vector2(-r, r * 0.8)])
		draw_colored_polygon(pts, color)
	else:
		draw_circle(Vector2.ZERO, r, color)
	if slow_time > 0.0:
		draw_arc(Vector2.ZERO, r + 2, 0, TAU, 20, Color("5dade2"), 2.0)
	if poison_time > 0.0:
		draw_arc(Vector2.ZERO, r + 4, 0, TAU, 20, Color("2ecc71"), 1.5)
	var w := CELL * 0.7
	var bar := Rect2(Vector2(-w / 2, -r - 7), Vector2(w, 3))
	draw_rect(bar, Color(0, 0, 0, 0.7))
	draw_rect(Rect2(bar.position, Vector2(w * clampf(hp / max_hp, 0, 1), 3)), Color("e74c3c"))
