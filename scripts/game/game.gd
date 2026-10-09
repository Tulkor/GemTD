extends Node3D
## Hauptspiel.
## Ablauf pro Runde wie in GemTD:
##   1. Bauphase: der Spieler setzt gems_per_round zufällige Gems ins Labyrinth.
##      Steine kann er jederzeit (gegen Gold laut balance.json) entfernen.
##   2. Auswahl: einen davon behalten (oder kombinieren), der Rest wird zu Steinen.
##   3. Welle: Gegner laufen Spawn -> Checkpoints -> Ziel durch das Labyrinth.

enum Phase { BUILD, CHOOSE, WAVE, GAME_OVER, VICTORY }

const NO_CELL := Vector2i(-1, -1)

var map: MapData
var pathfinder: Pathfinder
var waves: Array = []
var ground_path := PackedVector2Array()
var air_path := PackedVector2Array()

var board: Board3D
var camera_rig: CameraRig
var effects: Effects
var hud: Hud

## Tower und Steine belegen 2×2 Felder und sind über ihr Feld oben links (Anker) gespeichert.
## Fallen liegen auf einer eigenen Ebene darunter (3×3 Felder): Gegner laufen darüber,
## und man kann Tower darauf bauen.
var towers: Dictionary = {}      ## Anker -> Tower (ohne Fallen)
var rocks: Dictionary = {}       ## Anker -> true
var occupied: Dictionary = {}    ## jedes von Tower/Stein belegte Feld -> Anker
var traps: Dictionary = {}       ## Anker -> Falle
var trap_cells: Dictionary = {}  ## jedes Feld unter einer Falle -> Anker
var moving: Tower = null         ## Falle, für die gerade ein neuer Platz gewählt wird
var enemies: Array = []
var round_towers: Array = []
var selected: Tower = null
var selected_rock := NO_CELL

var phase := Phase.BUILD
var wave_index := 0
var lives := 50
var gold := 0
var chance_level := 0
var spawn_queue: Array = []
## Länge des Bodenwegs in Feldern, und wie lang er zu Beginn der Bauphase war.
var path_length := 0
var round_path_start := 0
var enemies_killed := 0
var spawn_timer := 0.0
var debug_tower := ""
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	map = _load_map()
	if map == null:
		push_error("Keine Map gefunden")
		Session.goto(Session.MAIN_MENU)
		return
	waves = Database.wave_sets.get(map.wave_set, {}).get("waves", [])
	lives = map.lives
	gold = map.start_gold
	pathfinder = Pathfinder.new(map)

	CameraRig.add_environment(self)
	board = Board3D.new()
	board.map = map
	board.rocks = rocks
	add_child(board)
	effects = Effects.new()
	board.add_child(effects)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.frame_map(map.width * Board3D.CELL, map.height * Board3D.CELL)

	hud = Hud.new()
	add_child(hud)
	hud.option_chosen.connect(_on_option_chosen)
	hud.round_gem_selected.connect(func(i): if i < round_towers.size(): _select(round_towers[i]))
	hud.chance_upgrade_requested.connect(_upgrade_chance)
	hud.speed_selected.connect(func(f): Engine.time_scale = f)
	hud.menu_requested.connect(func(): Session.goto(Session.return_scene))
	hud.main_menu_requested.connect(func(): Session.goto(Session.MAIN_MENU))
	hud.restart_requested.connect(func(): Session.goto(Session.GAME))
	hud.debug_tower_changed.connect(func(k): debug_tower = k)
	hud.debug_immortal_changed.connect(func(on): Session.debug_immortal = on)
	hud.immortal_button.set_pressed_no_signal(Session.debug_immortal)
	debug_tower = Session.test_tower
	hud.setup_debug_towers(debug_tower)

	_apply_variance()
	_update_paths()
	board.refresh_rocks()
	_enter_build()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _load_map() -> MapData:
	if Session.map_override != null:
		return Session.map_override.duplicate_map()
	var path := Session.map_path
	if path == "":
		var maps := Database.list_maps()
		if maps.is_empty():
			return null
		path = maps[0].path
	return MapData.load_file(path)


## Zufällige Steine laut map.variance.
func _apply_variance() -> void:
	var count := int(map.variance.get("random_rocks", 0))
	if count <= 0:
		return
	var vr := RandomNumberGenerator.new()
	var seed_value := int(map.variance.get("seed", -1))
	if seed_value >= 0:
		vr.seed = seed_value
	else:
		vr.randomize()
	var placed := 0
	for attempt in count * 30:
		if placed >= count:
			break
		var c := Vector2i(vr.randi_range(0, map.width - 2), vr.randi_range(0, map.height - 2))
		if can_place(c):
			rocks[c] = true
			_occupy(c, true, true)
			placed += 1


func _update_paths() -> void:
	ground_path = PackedVector2Array()
	var cells := pathfinder.compute_path()
	path_length = cells.size()
	for c in cells:
		ground_path.append(Board3D.cell_center(c))
	air_path = PackedVector2Array()
	for c in map.waypoints():
		air_path.append(Board3D.cell_center(c))
	board.path_points = ground_path
	board.refresh_path()


# --- Eingabe -----------------------------------------------------------------

func _process(delta: float) -> void:
	_update_hover()
	if phase == Phase.WAVE:
		_process_wave(delta)


func _update_hover() -> void:
	var c := NO_CELL
	var size := Board3D.TOWER_CELLS
	if moving != null:
		size = Board3D.TRAP_CELLS
		c = board.mouse_anchor(camera_rig.camera, size)
	elif phase == Phase.BUILD and not occupied.has(board.mouse_cell(camera_rig.camera)):
		c = board.mouse_anchor(camera_rig.camera)
	if c != board.hover_cell or size != board.hover_size:
		board.hover_cell = c
		board.hover_size = size
		board.hover_ok = can_move_trap(moving, c) if moving != null else can_place(c)
		board.refresh_hover()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_click(board.mouse_cell(camera_rig.camera), board.mouse_anchor(camera_rig.camera))
		elif event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed and not camera_rig.right_dragged:
			# Rechtsklick hebt die Auswahl auf, rechts ziehen verschiebt nur die Kamera
			_select(null)
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				_select(null)
			KEY_1:
				Engine.time_scale = 1.0
			KEY_2:
				Engine.time_scale = 2.0
			KEY_3:
				Engine.time_scale = 4.0


## c: Feld unter der Maus, anchor: wo ein neuer Tower hinkäme.
func _on_click(c: Vector2i, anchor: Vector2i) -> void:
	if moving != null:
		var target := board.mouse_anchor(camera_rig.camera, Board3D.TRAP_CELLS)
		if can_move_trap(moving, target):
			move_trap(moving, target)
		return
	var a: Vector2i = occupied.get(c, NO_CELL)
	var trap: Tower = traps.get(trap_cells.get(c, NO_CELL), null)
	# Liegt eine Falle unter einem Tower/Stein, wählt ein zweiter Klick die Falle
	var on_top_selected: bool = (towers.has(a) and selected == towers[a]) or (rocks.has(a) and selected_rock == a)
	if trap != null and on_top_selected:
		_select(trap)
	elif towers.has(a):
		_select(towers[a])
	elif rocks.has(a):
		_select(null, a)
	elif phase == Phase.BUILD and can_place(anchor):
		place_gem(anchor)
	elif trap != null:
		_select(trap)
	else:
		_select(null)


## Alle Tower und Fallen.
func all_towers() -> Array:
	return towers.values() + traps.values()


## Tower/Falle eintragen: Tower belegen ihre Felder und blockieren Gegner, Fallen liegen darunter.
func _register(t: Tower) -> void:
	if t.is_trap():
		traps[t.cell] = t
		for c in Board3D.footprint(t.cell, Board3D.TRAP_CELLS):
			trap_cells[c] = t.cell
	else:
		towers[t.cell] = t
		_occupy(t.cell, true, true)


func _unregister(t: Tower) -> void:
	if traps.get(t.cell) == t:
		traps.erase(t.cell)
		for c in Board3D.footprint(t.cell, Board3D.TRAP_CELLS):
			if trap_cells.get(c) == t.cell:
				trap_cells.erase(c)
	if towers.get(t.cell) == t:
		towers.erase(t.cell)
		_occupy(t.cell, false, false)


## Würde t als Falle auf seinem Platz eine andere Falle überdecken (außer den verbrauchten)?
func _trap_overlaps(t: Tower, at: Vector2i, ignore: Array = []) -> bool:
	for c in Board3D.footprint(at, Board3D.TRAP_CELLS):
		var other: Tower = traps.get(trap_cells.get(c, NO_CELL), null)
		if other != null and other != t and not ignore.has(other):
			return true
	return false


func trap_moves() -> int:
	return int(Database.balance.get("trap_moves", 2))


## Falle verschieben: auf jedes begehbare Feld (auch Checkpoints und unter Tower), nicht auf andere Fallen.
func can_move_trap(t: Tower, a: Vector2i) -> bool:
	if t == null or not is_instance_valid(t) or not t.is_trap() or t.moves_left <= 0 or a == t.cell:
		return false
	for c in Board3D.footprint(a, Board3D.TRAP_CELLS):
		if not map.is_walkable(c):
			return false
	return not _trap_overlaps(t, a)


func move_trap(t: Tower, a: Vector2i) -> bool:
	if not can_move_trap(t, a):
		return false
	_unregister(t)
	t.place_at(a)
	_register(t)
	t.moves_left -= 1
	moving = null
	board.hover_cell = NO_CELL
	_update_auras()
	_refresh_hud()
	return true


## Passt ein Tower mit Anker a hin, ohne den Weg zu versperren? Fallen darunter stören nicht.
func can_place(a: Vector2i) -> bool:
	var cells := Board3D.footprint(a)
	for c in cells:
		if not map.is_buildable(c) or occupied.has(c):
			return false
	return not pathfinder.would_block_cells(cells)


## Belegt oder räumt die Felder eines Towers/Steins. solid: blockiert er Gegner?
func _occupy(a: Vector2i, on: bool, solid: bool) -> void:
	var cells := Board3D.footprint(a)
	for c in cells:
		if on:
			occupied[c] = a
		else:
			occupied.erase(c)
	pathfinder.set_solid_cells(cells, on and solid)


func _select(t: Tower, rock := NO_CELL) -> void:
	moving = null
	if selected != null and is_instance_valid(selected):
		selected.set_selected(false)
	selected = t
	selected_rock = rock
	if t != null:
		t.set_selected(true)
	_refresh_hud()


# --- Bauphase ----------------------------------------------------------------

func gems_per_round() -> int:
	return int(Database.balance.get("gems_per_round", 5))


func rock_remove_cost() -> int:
	return int(Database.balance.get("rock_remove_cost", 0))


func _enter_build() -> void:
	phase = Phase.BUILD
	round_towers.clear()
	round_path_start = path_length
	_refresh_hud()


func place_gem(c: Vector2i) -> Tower:
	var id := ""
	var tier := 0
	if debug_tower != "":
		var parts := debug_tower.split(":")
		id = parts[0]
		tier = int(parts[1]) if parts.size() > 1 else 0
	else:
		var roll := Database.roll_gem(chance_level, rng)
		id = roll[0]
		tier = roll[1]
	if not Database.towers.has(id):
		push_error("Unbekannter Tower: " + id)
		return null
	var t := Tower.new()
	t.is_new = true
	board.add_child(t)
	t.setup(self, c, id, tier)
	_register(t)
	round_towers.append(t)
	_update_paths()
	_update_auras()
	board.hover_ok = false
	board.refresh_hover()
	if round_towers.size() >= gems_per_round():
		phase = Phase.CHOOSE
		_select(t)
	_refresh_hud()
	return t


## Stein entfernen (in jeder Phase, kostet rock_remove_cost Gold).
func can_remove_rock(c: Vector2i) -> bool:
	return phase < Phase.GAME_OVER and rocks.has(c) and gold >= rock_remove_cost()


func remove_rock(c: Vector2i) -> bool:
	if not can_remove_rock(c):
		return false
	gold -= rock_remove_cost()
	rocks.erase(c)
	_occupy(c, false, false)
	_update_paths()
	board.refresh_rocks()
	_select(null)
	return true


## Was man mit dem ausgewählten Tower machen kann.
## Rückgabe: [{label, action, id, tier, consume: [Tower], cost}]
##   action "keep":    Runde abschließen, ausgewählter Gem wird zu id/tier, Rest der Runde wird zu Steinen
##   action "combine": Kombination aus fertigen Towern auf dem Feld, ohne die Runde zu beenden
##   action "upgrade": Spezial-Tower gegen Gold aufwerten
func tower_options(t: Tower) -> Array:
	if t == null or not is_instance_valid(t) or phase >= Phase.GAME_OVER:
		return []
	if t.is_new:
		return choice_options(t)
	var opts := []
	var field := all_towers().filter(func(o): return o != t and not o.is_new)
	# Fertige Tower auf dem Feld kombinieren geht nur während der Welle, nicht beim Setzen und Auswählen
	# der neuen Gems (deren Rezepte siehe choice_options)
	if phase == Phase.WAVE:
		for sid in Database.special_ids():
			var def: Dictionary = Database.towers[sid]
			if def.get("recipe_same_round", false):
				continue
			var consume = _match_recipe(def.get("recipe", []), t, field)
			if consume != null:
				opts.append({"label": "Kombinieren → " + Database.tower_label(sid, 0), "action": "combine",
						"id": sid, "tier": 0, "consume": consume, "cost": 0})
	opts.append_array(upgrade_options(t))
	if t.is_trap() and t.moves_left > 0:
		opts.append({"label": "Verschieben (noch %d×)" % t.moves_left, "action": "move", "id": t.tower_id,
				"tier": t.tier, "consume": [], "cost": 0})
	return opts.filter(func(o): return not _makes_blocked_trap(t, o))


## Option, die aus t eine Falle macht, obwohl dort schon eine andere Falle liegt?
func _makes_blocked_trap(t: Tower, o: Dictionary) -> bool:
	if o.action == "move" or str(Database.towers.get(o.id, {}).get("kind", "tower")) != "trap":
		return false
	return _trap_overlaps(t, t.cell, o.consume)


## In der Auswahlphase: behalten, 2/4 gleiche, Rezepte.
## Schon in der Bauphase (One-Shot): nur Rezepte, wer das nimmt, beendet die Runde sofort.
## Rezepte gelten in beiden Fällen nur mit den in dieser Runde gesetzten Gems, fertige Tower auf dem
## Feld zählen nicht (die lassen sich während der Welle kombinieren, siehe tower_options).
func choice_options(t: Tower) -> Array:
	var one_shot := phase == Phase.BUILD
	if (phase != Phase.CHOOSE and not one_shot) or t == null or not round_towers.has(t):
		return []
	var opts := [] if one_shot else [_keep_option("Behalten: " + t.label(), t.tower_id, t.tier)]
	if t.def.get("category", "gem") == "gem" and not one_shot:
		# Abstufen wie in WC3: den Gem eine Qualität niedriger behalten, z. B. für ein Rezept
		if t.tier > 0:
			opts.append(_keep_option("Abstufen → " + Database.tower_label(t.tower_id, t.tier - 1), t.tower_id, t.tier - 1))
		var same := round_towers.filter(func(o): return o.tower_id == t.tower_id and o.tier == t.tier).size()
		var max_tier := Database.tier_count(t.tower_id) - 1
		for n in [2, 4]:
			if same < n:
				continue
			var steps := 1 if n == 2 else 2
			if t.tier + steps <= max_tier:
				opts.append(_keep_option("%d gleiche → %s" % [n, Database.tower_label(t.tower_id, t.tier + steps)], t.tower_id, t.tier + steps))
			else:
				var overflow := str(Database.balance.get("overflow_tower", ""))
				if Database.towers.has(overflow):
					opts.append(_keep_option("%d gleiche → %s" % [n, Database.tower_label(overflow, 0)], overflow, 0))
				break
	var others := round_towers.filter(func(o): return o != t)
	for sid in Database.special_ids():
		var def: Dictionary = Database.towers[sid]
		# Zutaten sind alle aus dieser Runde und werden ohnehin mit dem Rest zu Steinen
		if _match_recipe(def.get("recipe", []), t, others) != null:
			opts.append(_keep_option(("One-Shot → " if one_shot else "Kombinieren → ") + Database.tower_label(sid, 0), sid, 0))
	return opts.filter(func(o): return not _makes_blocked_trap(t, o))


## Spezial-Tower, die man in der Bauphase schon jetzt bauen könnte, z. B. "Silber (aus Splitter Topas)".
func one_shot_hints() -> Array:
	var hints := []
	for t in round_towers:
		for o in choice_options(t):
			hints.append("%s (aus %s)" % [Database.tower_label(o.id, o.tier), t.label()])
	return hints


func _keep_option(label: String, id: String, tier: int) -> Dictionary:
	return {"label": label, "action": "keep", "id": id, "tier": tier, "consume": [], "cost": 0}


func _ingredient_matches(ing: Dictionary, o: Tower) -> bool:
	if ing.has("any_of"):
		for alt in ing.any_of:
			if _ingredient_matches(alt, o):
				return true
		return false
	return o.tower_id == str(ing.get("tower", "")) and o.tier == int(ing.get("tier", 0))


## Prüft ein Rezept. Der ausgewählte Tower t muss eine Zutat sein, die übrigen kommen aus pool.
## Rückgabe: die verbrauchten Tower aus pool, oder null wenn das Rezept nicht erfüllt ist.
func _match_recipe(recipe: Array, t: Tower, pool: Array):
	if recipe.is_empty():
		return null
	for i in recipe.size():
		if not _ingredient_matches(recipe[i], t):
			continue
		var rest := pool.duplicate()
		var used := []
		var ok := true
		for j in recipe.size():
			if j == i:
				continue
			var found = null
			for o in rest:
				if _ingredient_matches(recipe[j], o):
					found = o
					break
			if found == null:
				ok = false
				break
			rest.erase(found)
			used.append(found)
		if ok:
			return used
	return null


## Upgrades fertiger Spezial-Tower (Feld "upgrades" in der Tower-Datei): Gold, optional weitere Zutaten.
## Nur während der Welle möglich.
func upgrade_options(t: Tower) -> Array:
	if t == null or t.is_new or phase != Phase.WAVE:
		return []
	var ups: Array = t.def.get("upgrades", [])
	if t.tier >= ups.size() or t.tier + 1 >= Database.tier_count(t.tower_id):
		return []
	var up: Dictionary = ups[t.tier]
	var consume := []
	var pool := all_towers().filter(func(o): return o != t and not o.is_new)
	for ing in up.get("recipe", []):
		var found = null
		for o in pool:
			if _ingredient_matches(ing, o):
				found = o
				break
		if found == null:
			return []
		pool.erase(found)
		consume.append(found)
	var cost := int(up.get("cost", 0))
	return [{"label": "Aufwerten → %s%s" % [Database.tower_label(t.tower_id, t.tier + 1), " (%d Gold)" % cost if cost > 0 else ""],
			"action": "upgrade", "id": t.tower_id, "tier": t.tier + 1, "consume": consume, "cost": cost}]


func _on_option_chosen(index: int) -> void:
	if selected_rock != NO_CELL:
		remove_rock(selected_rock)
		return
	if moving != null:
		# einzige Option im Verschiebe-Modus: abbrechen
		moving = null
		board.hover_cell = NO_CELL
		_refresh_hud()
		return
	var opts := tower_options(selected)
	if index < 0 or index >= opts.size():
		return
	var o: Dictionary = opts[index]
	if o.action == "move":
		moving = selected
		board.hover_cell = NO_CELL
		_refresh_hud()
		return
	if gold < int(o.cost):
		return
	gold -= int(o.cost)
	for c in o.consume:
		_consume(c)
	var t := selected
	if o.action == "keep":
		for r in round_towers:
			if r != t and is_instance_valid(r):
				_turn_into_rock(r)
		round_towers.clear()
		t.is_new = false
	t.kills += o.consume.reduce(func(acc, c): return acc + c.kills, 0)
	var old_id := t.tower_id
	_unregister(t)
	t.set_tower(o.id, o.tier)
	_register(t)
	if t.is_trap() and (o.id != old_id or o.action == "keep"):
		t.moves_left = trap_moves()
	t.set_selected(true)
	_update_paths()
	board.refresh_rocks()
	_update_auras()
	if o.action == "keep":
		_start_wave()
	else:
		_refresh_hud()


## Verbrauchte Zutat: Tower werden zu Steinen, Fallen verschwinden.
func _consume(t: Tower) -> void:
	if t.is_trap():
		_unregister(t)
		t.queue_free()
	else:
		_turn_into_rock(t)


func _turn_into_rock(t: Tower) -> void:
	_unregister(t)
	rocks[t.cell] = true
	_occupy(t.cell, true, true)
	t.queue_free()


func _upgrade_chance() -> void:
	var levels: Array = Database.balance.get("chance_levels", [])
	if chance_level + 1 >= levels.size():
		return
	var cost := int(levels[chance_level + 1].get("cost", 0))
	if gold < cost:
		return
	gold -= cost
	chance_level += 1
	_refresh_hud()


func current_wave() -> int:
	return wave_index + 1


func add_gold(amount: int) -> void:
	gold += amount
	_refresh_hud()


## Auren, die andere Tower verstärken.
func _update_auras() -> void:
	for t in all_towers():
		t.speed_bonus = 0.0
		t.damage_bonus = 0.0
	for src in all_towers():
		for ab in src.abilities():
			var type := str(ab.get("type", ""))
			if type != "speed_aura" and type != "damage_aura":
				continue
			for t in all_towers():
				if t == src or t.pos.distance_to(src.pos) > float(ab.radius):
					continue
				if type == "speed_aura":
					t.speed_bonus = maxf(t.speed_bonus, float(ab.bonus))
				else:
					t.damage_bonus = maxf(t.damage_bonus, float(ab.bonus))


# --- Welle -------------------------------------------------------------------

func is_wave_running() -> bool:
	return phase == Phase.WAVE


func _start_wave() -> void:
	if wave_index >= waves.size():
		_finish(Phase.VICTORY)
		return
	phase = Phase.WAVE
	spawn_queue.clear()
	var w: Dictionary = waves[wave_index]
	for g in w.get("groups", []):
		for i in int(g.get("count", 1)):
			spawn_queue.append(g)
	spawn_timer = 0.5
	_refresh_hud()


func _process_wave(delta: float) -> void:
	spawn_timer -= delta
	while spawn_timer <= 0.0 and not spawn_queue.is_empty():
		var g: Dictionary = spawn_queue.pop_front()
		_spawn_enemy(g)
		spawn_timer += float(g.get("interval", 1.0))
	if spawn_queue.is_empty() and enemies.is_empty() and phase == Phase.WAVE:
		wave_index += 1
		effects.clear()
		if wave_index >= waves.size():
			_finish(Phase.VICTORY)
		else:
			_enter_build()


func _spawn_enemy(g: Dictionary) -> void:
	var def: Dictionary = Database.enemies.get(str(g.get("enemy", "")), {})
	if def.is_empty():
		push_warning("Unbekannter Gegner: %s" % g.get("enemy", ""))
		return
	var e := Enemy.new()
	board.add_child(e)
	e.setup(self, def, g, air_path if def.get("flying", false) else ground_path)
	enemies.append(e)


func find_targets(t: Tower, count: int) -> Array:
	var list := enemies.filter(func(e): return not e.dead and t.can_target(e) and t.in_range(e))
	list.sort_custom(func(a, b): return a.traveled > b.traveled)
	return list.slice(0, count)


func enemies_in_radius(p: Vector2, radius: float) -> Array:
	return enemies.filter(func(e): return not e.dead and e.pos.distance_to(p) <= radius)


func add_beam(from: Vector3, to: Vector3, col: Color) -> void:
	effects.add_beam(from, to, col)


func on_enemy_killed(e: Enemy) -> void:
	enemies_killed += 1
	gold += e.bounty
	_remove_enemy(e)
	_refresh_hud()


func on_enemy_leaked(e: Enemy) -> void:
	lives -= e.damage
	_remove_enemy(e)
	# Debug „Unsterblich“: Leben gehen ins Minus, das Spiel läuft weiter
	if lives <= 0 and not Session.debug_immortal:
		lives = 0
		_finish(Phase.GAME_OVER)
	_refresh_hud()


func _remove_enemy(e: Enemy) -> void:
	enemies.erase(e)
	e.queue_free()


func _finish(p: Phase) -> void:
	phase = p
	Engine.time_scale = 1.0
	hud.show_game_over(p == Phase.VICTORY, mini(wave_index + 1, waves.size()), waves.size(), lives, enemies_killed, path_length)
	_refresh_hud()


# --- HUD ---------------------------------------------------------------------

func _refresh_hud() -> void:
	if hud == null:
		return
	hud.set_resources(mini(wave_index + 1, waves.size()), waves.size(), lives, gold)
	hud.set_path_length(path_length, path_length - round_path_start if phase <= Phase.CHOOSE else 0)
	hud.set_waves(_upcoming_waves(4))
	# Baubar: in der Welle aus fertigen Towern, beim Setzen und Auswählen nur aus den Gems der Runde
	var now_pool: Array = all_towers().filter(func(t): return not t.is_new) if phase == Phase.WAVE else round_towers
	# Zutaten: fixierte Tower plus nur der ausgewählte neue Gem (pro Runde behält man genau einen)
	var have: Array = all_towers().filter(func(t): return not t.is_new or t == selected)
	hud.set_owned(have.map(func(t): return [t.tower_id, t.tier, t.is_new]),
			{"pool": now_pool.map(func(t): return [t.tower_id, t.tier, t.is_new]), "wave": phase == Phase.WAVE})

	# Neue Gems, die eine Zutat für einen Spezial-Tower aus dieser Runde sind (lila markiert)
	var specials := []
	var gems := []
	for t in round_towers:
		var shot := false
		for o in choice_options(t):
			if _is_special_option(t, o):
				shot = true
				if not specials.has(Database.tower_label(o.id, o.tier)):
					specials.append(Database.tower_label(o.id, o.tier))
		gems.append({"label": t.label(), "color": t.color, "selected": t == selected, "oneshot": shot})
	var shot_text := ""
	if not specials.is_empty():
		shot_text = ("One-Shot möglich: " if phase == Phase.BUILD else "Spezial möglich: ") + ", ".join(specials)
	hud.set_round_gems(gems if phase <= Phase.CHOOSE else [], "Lila Rand: Zutat für " + ", ".join(specials) if not specials.is_empty() else "")

	match phase:
		Phase.BUILD:
			hud.set_phase("Bauphase", "Gems gesetzt: %d / %d · Steine anklicken, um sie zu entfernen" % [round_towers.size(), gems_per_round()], shot_text)
		Phase.CHOOSE:
			hud.set_phase("Wahlphase", "Wähle einen der neuen Gems und behalte ihn. Die anderen werden zu Steinen.", shot_text)
		Phase.WAVE:
			hud.set_phase("Welle %d" % (wave_index + 1), "noch %d Gegner" % (enemies.size() + spawn_queue.size()))
		Phase.GAME_OVER:
			hud.set_phase("Verloren", "")
		Phase.VICTORY:
			hud.set_phase("Gewonnen", "Alle Wellen geschafft!")

	var levels: Array = Database.balance.get("chance_levels", [])
	if chance_level + 1 < levels.size():
		var cost := int(levels[chance_level + 1].get("cost", 0))
		hud.set_chance(chance_level, cost, gold >= cost and phase < Phase.GAME_OVER)
	else:
		hud.set_chance(chance_level, -1, false)

	if selected_rock != NO_CELL:
		var cost := rock_remove_cost()
		hud.set_selection({"title": "Stein", "color": Color("6d6a63"), "used_in": null,
				"body": ""})
		hud.set_options([{"label": "Stein entfernen" + (" (%d Gold)" % cost if cost > 0 else ""), "style": "normal"}])
		hud.set_options_enabled(can_remove_rock(selected_rock))
		return
	if moving != null and is_instance_valid(moving):
		hud.set_selection({"title": moving.label() + " verschieben", "color": moving.color, "used_in": null,
				"body": "Neuen Platz anklicken (grün = möglich). Fallen dürfen auf Checkpoints und unter Tower.\nRechtsklick oder Esc bricht ab."})
		hud.set_options([{"label": "Abbrechen", "style": "normal"}])
		hud.set_options_enabled(true)
		return
	if selected == null or not is_instance_valid(selected):
		hud.set_selection({})
		hud.set_options([])
		return
	var lines := selected.info_text().split("\n")
	var used := Recipes.used_in(selected.tower_id, selected.tier)
	var body := "\n".join(lines.slice(1))
	if not selected.is_new and phase <= Phase.CHOOSE and _field_recipe_complete(used):
		body += "\nKombinieren geht erst wieder während der Welle."
	hud.set_selection({"title": lines[0], "color": selected.color, "body": body, "used_in": used})
	hud.set_options(tower_options(selected).map(func(o): return _option_view(selected, o)))
	hud.set_options_enabled(true)


## Ob eines der Rezepte mit den fertigen Towern auf dem Feld komplett wäre (für den Hinweis außerhalb der Welle).
func _field_recipe_complete(ids: Array) -> bool:
	var field: Array = all_towers().filter(func(t): return not t.is_new).map(func(t): return [t.tower_id, t.tier])
	return ids.any(func(id): return Recipes.ready_now(id, field, {"pool": field, "wave": true}))


## Vorschau der nächsten Wellen für die linke Spalte.
func _upcoming_waves(count: int) -> Array:
	var list := []
	if phase >= Phase.GAME_OVER:
		return list
	for i in range(wave_index, mini(wave_index + count, waves.size())):
		var groups: Array = waves[i].get("groups", [])
		var defs := groups.map(func(g): return Database.enemies.get(str(g.get("enemy", "")), {}))
		var total := 0
		for g in groups:
			total += int(g.get("count", 1))
		var detail := ""
		if groups.size() == 1 and not defs[0].is_empty():
			var d: Dictionary = defs[0]
			detail = "%d× %s · %d LP · Rüstung %d" % [total, d.get("name", "?"), int(d.get("hp", 0)), int(d.get("armor", 0))]
		else:
			detail = "%d Gegner: %s" % [total, ", ".join(defs.map(func(d): return str(d.get("name", "?"))))]
		var state := ""
		if i == wave_index:
			state = "läuft" if phase == Phase.WAVE else "als Nächstes"
		list.append({"number": i + 1, "type": wave_type(waves[i]), "detail": detail, "state": state})
	return list


## Wellentyp wie die Gegnerformen: Boss, Flieger, Masse (Pyramiden oder sehr viele Gegner), Boden oder Gemischt.
static func wave_type(w: Dictionary) -> String:
	if w.has("type"):
		return str(w.type)
	var groups: Array = w.get("groups", [])
	var flying := 0
	var ground := 0
	var total := 0
	for g in groups:
		var d: Dictionary = Database.enemies.get(str(g.get("enemy", "")), {})
		if d.get("boss", false):
			return "Boss"
		if d.get("flying", false):
			flying += 1
		else:
			ground += 1
		total += int(g.get("count", 1))
		if str(d.get("shape", "")) == "pyramid":
			return "Masse"
	if flying > 0 and ground > 0:
		return "Gemischt"
	if flying > 0:
		return "Flieger"
	return "Masse" if total >= 20 else "Boden"


## Wird aus dem Gem ein Spezial-Tower (One-Shot in der Bau-, Kombination in der Wahlphase)?
func _is_special_option(t: Tower, o: Dictionary) -> bool:
	return t.is_new and o.action == "keep" and o.id != t.tower_id \
			and Database.towers.get(o.id, {}).get("category", "gem") == "special"


func _option_view(t: Tower, o: Dictionary) -> Dictionary:
	var v := {"label": o.label, "style": "normal"}
	if _is_special_option(t, o):
		v.style = "oneshot"
		var hint := "Baut %s sofort und beendet die Runde." % Database.tower_label(o.id, o.tier) if phase == Phase.BUILD else ""
		hint += " Die übrigen neuen Gems werden zu Steinen."
		if not o.consume.is_empty():
			hint += " Verbraucht vom Feld: " + ", ".join(o.consume.map(func(c): return c.label()))
		v.hint = hint.strip_edges()
	elif o.action == "keep" and o.id == t.tower_id and o.tier == t.tier:
		v.style = "primary"
		v.label = "Behalten"
	return v
