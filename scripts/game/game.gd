extends Node2D
## Hauptspiel.
## Ablauf pro Runde wie in GemTD:
##   1. Bauphase: der Spieler setzt gems_per_round zufällige Gems ins Labyrinth.
##   2. Auswahl: einen davon behalten (oder kombinieren), der Rest wird zu Steinen.
##   3. Welle: Gegner laufen Spawn -> Checkpoints -> Ziel durch das Labyrinth.

const CELL := MapView.CELL

enum Phase { BUILD, CHOOSE, WAVE, GAME_OVER, VICTORY }

var map: MapData
var pathfinder: Pathfinder
var waves: Array = []
var ground_path := PackedVector2Array()
var air_path := PackedVector2Array()

var map_view: MapView
var effects: Effects
var hud: Hud

var towers: Dictionary = {}  ## Vector2i -> Tower
var rocks: Dictionary = {}   ## Vector2i -> true
var enemies: Array = []
var round_towers: Array = []
var selected: Tower = null

var phase := Phase.BUILD
var wave_index := 0
var lives := 50
var gold := 0
var chance_level := 0
var spawn_queue: Array = []
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

	map_view = MapView.new()
	map_view.map = map
	map_view.rocks = rocks
	add_child(map_view)
	effects = Effects.new()
	effects.z_index = 10
	map_view.add_child(effects)

	hud = Hud.new()
	add_child(hud)
	hud.option_chosen.connect(_on_option_chosen)
	hud.chance_upgrade_requested.connect(_upgrade_chance)
	hud.speed_selected.connect(func(f): Engine.time_scale = f)
	hud.menu_requested.connect(func(): Session.goto(Session.return_scene))
	hud.debug_tower_changed.connect(func(k): debug_tower = k)
	debug_tower = Session.test_tower
	hud.setup_debug_towers(debug_tower)

	_apply_variance()
	_update_paths()
	get_viewport().size_changed.connect(_layout)
	_layout()
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


func _layout() -> void:
	var vp := get_viewport_rect().size
	map_view.fit_into(Rect2(Vector2(12, 12), vp - Vector2(Hud.WIDTH + 24, 24)))


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
		var c := Vector2i(vr.randi_range(0, map.width - 1), vr.randi_range(0, map.height - 1))
		if can_place(c):
			rocks[c] = true
			pathfinder.set_solid(c, true)
			placed += 1


func _update_paths() -> void:
	ground_path = PackedVector2Array()
	for c in pathfinder.compute_path():
		ground_path.append(MapView.cell_center(c))
	air_path = PackedVector2Array()
	for c in map.waypoints():
		air_path.append(MapView.cell_center(c))
	map_view.path_points = ground_path
	map_view.queue_redraw()


# --- Eingabe -----------------------------------------------------------------

func _process(delta: float) -> void:
	_update_hover()
	if phase == Phase.WAVE:
		_process_wave(delta)


func _update_hover() -> void:
	var c := map_view.mouse_cell() if phase == Phase.BUILD else Vector2i(-1, -1)
	if towers.has(c):
		c = Vector2i(-1, -1)
	if c != map_view.hover_cell:
		map_view.hover_cell = c
		map_view.hover_ok = can_place(c)
		map_view.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_click(map_view.mouse_cell())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
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


func _on_click(c: Vector2i) -> void:
	if towers.has(c):
		_select(towers[c])
	elif phase == Phase.BUILD and can_place(c):
		place_gem(c)
	else:
		_select(null)


func can_place(c: Vector2i) -> bool:
	return map.is_buildable(c) and not towers.has(c) and not rocks.has(c) and not pathfinder.would_block(c)


func _select(t: Tower) -> void:
	if selected != null and is_instance_valid(selected):
		selected.selected = false
		selected.queue_redraw()
	selected = t
	if t != null:
		t.selected = true
		t.queue_redraw()
	_refresh_hud()


# --- Bauphase ----------------------------------------------------------------

func gems_per_round() -> int:
	return int(Database.balance.get("gems_per_round", 5))


func _enter_build() -> void:
	phase = Phase.BUILD
	round_towers.clear()
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
	map_view.add_child(t)
	t.setup(self, c, id, tier)
	t.is_new = true
	towers[c] = t
	round_towers.append(t)
	pathfinder.set_solid(c, true)
	_update_paths()
	_update_auras()
	map_view.hover_ok = false
	if round_towers.size() >= gems_per_round():
		phase = Phase.CHOOSE
		_select(t)
	_refresh_hud()
	return t


## Was man mit dem ausgewählten Gem dieser Runde machen kann.
## Rückgabe: [{label, id, tier}]
func choice_options(t: Tower) -> Array:
	if phase != Phase.CHOOSE or t == null or not round_towers.has(t):
		return []
	var opts := [{"label": "Behalten: " + t.label(), "id": t.tower_id, "tier": t.tier}]
	var same := round_towers.filter(func(o): return o.tower_id == t.tower_id and o.tier == t.tier).size()
	var max_tier := Database.tier_count(t.tower_id) - 1
	if same >= 2 and t.tier + 1 <= max_tier:
		opts.append({"label": "2 gleiche → " + Database.tower_label(t.tower_id, t.tier + 1), "id": t.tower_id, "tier": t.tier + 1})
	if same >= 4 and t.tier + 2 <= max_tier:
		opts.append({"label": "4 gleiche → " + Database.tower_label(t.tower_id, t.tier + 2), "id": t.tower_id, "tier": t.tier + 2})
	for sid in Database.special_ids():
		var recipe: Array = Database.towers[sid].get("recipe", [])
		if not recipe.is_empty() and _recipe_satisfied(recipe, t):
			opts.append({"label": "Kombinieren → " + Database.tower_label(sid, 0), "id": sid, "tier": 0})
	return opts


## Alle Zutaten müssen unter den Gems dieser Runde sein, der ausgewählte muss dabei sein.
func _recipe_satisfied(recipe: Array, t: Tower) -> bool:
	var pool := round_towers.filter(func(o): return o != t)
	var used_selected := false
	for ing in recipe:
		var want_id := str(ing.get("tower", ""))
		var want_tier := int(ing.get("tier", 0))
		if not used_selected and t.tower_id == want_id and t.tier == want_tier:
			used_selected = true
			continue
		var found = null
		for o in pool:
			if o.tower_id == want_id and o.tier == want_tier:
				found = o
				break
		if found == null:
			return false
		pool.erase(found)
	return used_selected


func _on_option_chosen(index: int) -> void:
	var opts := choice_options(selected)
	if index < 0 or index >= opts.size():
		return
	var o: Dictionary = opts[index]
	for t in round_towers:
		if t == selected:
			t.set_tower(o.id, o.tier)
			t.is_new = false
			t.queue_redraw()
		else:
			towers.erase(t.cell)
			rocks[t.cell] = true
			t.queue_free()
	round_towers.clear()
	map_view.queue_redraw()
	_update_auras()
	_start_wave()


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


func _update_auras() -> void:
	for t in towers.values():
		t.speed_bonus = 0.0
	for src in towers.values():
		var aura: Dictionary = src.ability("speed_aura")
		if aura.is_empty():
			continue
		for t in towers.values():
			if t != src and t.position.distance_to(src.position) <= float(aura.radius) * CELL:
				t.speed_bonus = maxf(t.speed_bonus, float(aura.bonus))


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
	e.z_index = 5
	e.setup(self, def, g, air_path if def.get("flying", false) else ground_path)
	map_view.add_child(e)
	enemies.append(e)


func find_targets(t: Tower, count: int) -> Array:
	var r := t.range_px()
	var list := enemies.filter(func(e): return not e.dead and t.can_target(e) and e.position.distance_to(t.position) <= r)
	list.sort_custom(func(a, b): return a.traveled > b.traveled)
	return list.slice(0, count)


func enemies_in_radius(pos: Vector2, radius: float) -> Array:
	return enemies.filter(func(e): return not e.dead and e.position.distance_to(pos) <= radius)


func add_beam(from: Vector2, to: Vector2, col: Color) -> void:
	effects.add_beam(from, to, col)


func on_enemy_killed(e: Enemy) -> void:
	gold += e.bounty
	_remove_enemy(e)
	_refresh_hud()


func on_enemy_leaked(e: Enemy) -> void:
	lives -= e.damage
	_remove_enemy(e)
	if lives <= 0:
		lives = 0
		_finish(Phase.GAME_OVER)
	_refresh_hud()


func _remove_enemy(e: Enemy) -> void:
	enemies.erase(e)
	e.queue_free()


func _finish(p: Phase) -> void:
	phase = p
	Engine.time_scale = 1.0
	hud.show_message("Gewonnen!" if p == Phase.VICTORY else "Verloren – Welle %d" % (wave_index + 1))
	_refresh_hud()


# --- HUD ---------------------------------------------------------------------

func _refresh_hud() -> void:
	if hud == null:
		return
	hud.set_stats("Map: %s\nWelle: %d / %d\nLeben: %d\nGold: %d" % [map.name, mini(wave_index + 1, waves.size()), waves.size(), lives, gold])
	match phase:
		Phase.BUILD:
			hud.set_phase("Bauphase: setze Gems (%d / %d)" % [round_towers.size(), gems_per_round()])
		Phase.CHOOSE:
			hud.set_phase("Wähle einen der neuen Gems (weiß umrandet) und entscheide unten, was daraus wird. Die anderen werden zu Steinen.")
		Phase.WAVE:
			hud.set_phase("Welle läuft – noch %d Gegner" % (enemies.size() + spawn_queue.size()))
		Phase.GAME_OVER:
			hud.set_phase("Spiel verloren.")
		Phase.VICTORY:
			hud.set_phase("Alle Wellen geschafft!")

	var levels: Array = Database.balance.get("chance_levels", [])
	if chance_level + 1 < levels.size():
		var cost := int(levels[chance_level + 1].get("cost", 0))
		hud.set_chance("Chance-Stufe %d → %d (%d Gold)" % [chance_level, chance_level + 1, cost], gold >= cost and phase != Phase.GAME_OVER)
	else:
		hud.set_chance("Chance-Stufe %d (max)" % chance_level, false)

	var opts := choice_options(selected)
	hud.set_options(opts.map(func(o): return o.label))
	hud.set_tower_info(selected.info_text() if selected != null and is_instance_valid(selected) else "")
