class_name MaulGame
extends Node3D
## Shopping Maul: Spielablauf. Jeder Spieler eröffnet eine Filiale und kauft deren Tower in sein
## Gebiet, die Gewerbeaufsicht läuft von 12 Spawns über Teleports zur Mall in P1. Das Team teilt
## sich die Leben. Regeln aus data/maul/rules.json, Level aus waves.json (siehe Designdokument).
##
## Wie in game.gd laufen alle Spieleraktionen als Befehle über submit(cmd) → execute(cmd) mit
## Spielernummer, damit Koop später nur noch die Befehle übertragen muss (der Host rechnet).
## Tower und Gegner sind die GemTD-Klassen (MaulTower, MaulEnemy) und rufen dieselben
## Funktionen auf wie in game.gd (find_targets, enemies_in_radius, on_enemy_killed …).

enum Phase { SETUP, COUNTDOWN, WAVE, GAME_OVER, VICTORY }

const NO_CELL := Vector2i(-1, -1)
## Bau-Tasten wie im WC3-Raster (physische Tasten, auf QWERTZ unten links „Y“)
const BUILD_KEYS := [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_A, KEY_S, KEY_D, KEY_F, KEY_Z, KEY_X, KEY_C]

class Player:
	var name := ""
	var shop := ""
	var gold := 0
	var zone := 0
	var kills := 0
	var level_kills := 0
	var reveal_until := -1.0
	var reveal_ready := 0.0

var rules: Dictionary
var levels: Array
var map: MaulMap
var board: MaulBoard
var effects: Effects
var camera_rig: MaulCamera
var hud: MaulHud
var pathfinder: Pathfinder   ## mit Towern
var ghost_finder: Pathfinder ## nur Gelände (Geist-Level)

## Koop-Platzhalter: im Koop rechnet nur der Host, mirror = Mitspieler
var mirror := false
var local_player := 0
var acting := 0
var players: Array = []

var phase := Phase.SETUP
var difficulty := 1
var mode := "group"
var level := 0               ## zuletzt gestartetes Level (1-basiert)
var countdown := 0.0
var lives := 150
var max_lives := 150
var game_time := 0.0
var play_time := 0.0

var towers := {}             ## Anker → MaulTower
var occupied := {}           ## Feld → Anker
var enemies: Array = []
var selected: MaulTower = null
var build_id := ""           ## gewählter Tower zum Bauen (nur lokal)
var message := ""
var message_time := 0.0

# Level
var income_pot := 185
var prev_budget := 0.0
var adapt_raw: Array = [1.0]
var streak := 0
var je := 1.0
var je_min := 1.0
var je_max := 1.0
var level_lost := 0          ## in diesem Level verlorene Leben
var level_kind := ""
var level_specials: Array = []
var level_hp := 0.0          ## Leben pro Gegner
var level_count := 0         ## Gegner gesamt
var spawn_queue: Array = []  ## je Spawn: [Spawn-Index, noch zu erzeugen]
var spawn_timer := 0.0
var enemies_killed := 0
var enemies_leaked := 0
var _next_enemy_id := 1
var _alternate := {}         ## Route → Zähler für abwechselnde Abzweigungen

var _path_cache := {}        ## Schlüssel → {path, wp}
var _zone_towers: Array = [] ## Tower je Zone
var _frost_level := false
var _detect_towers: Array = []
var _range_preview: MeshInstance3D
var _range_preview_r := -1.0
var _hud_timer := 0.0


func _ready() -> void:
	rules = MaulData.rules()
	levels = MaulData.levels()
	map = MaulMap.create()
	pathfinder = Pathfinder.new(map)
	ghost_finder = Pathfinder.new(map)
	_zone_towers.resize(map.zones.size())
	_zone_towers.fill(0)
	difficulty = int(rules.get("default_difficulty", 1))
	var p := Player.new()
	p.name = tr("Du")
	p.zone = 0
	players.append(p)

	CameraRig.add_environment(self)
	board = MaulBoard.new()
	board.map = map
	add_child(board)
	effects = Effects.new()
	board.add_child(effects)
	camera_rig = MaulCamera.new()
	add_child(camera_rig)
	camera_rig.frame_map(map.width * Board3D.CELL, map.height * Board3D.CELL)
	camera_rig.look_at_point(map.zone_center(0), 42.0)
	_range_preview = MeshInstance3D.new()
	_range_preview.visible = false
	_range_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_range_preview)

	hud = MaulHud.new()
	hud.game = self
	add_child(hud)
	_refresh_paths()
	hud.show_setup()


# --- Start ---------------------------------------------------------------------

## Nach der Filialwahl: Gold, Leben und Countdown bis Level 1.
func start_game(shop_id: String, diff: int, play_mode: String) -> void:
	if phase != Phase.SETUP:
		return
	difficulty = clampi(diff, 0, rules.get("difficulties", []).size() - 1)
	mode = play_mode
	var d := MaulData.difficulty(difficulty)
	max_lives = int(d.get("lives", 150))
	lives = max_lives
	adapt_raw = [1.0]
	je = 1.0
	je_min = 1.0
	je_max = 1.0
	income_pot = int(rules.income.start)
	var m := players.size()
	for i in m:
		var pl: Player = players[i]
		pl.gold = int(rules.start_gold) / m + (int(rules.start_gold_red) if i == 0 else 0)
	players[local_player].shop = shop_id
	countdown = float(rules.first_delay_many if m >= 4 else rules.first_delay)
	phase = Phase.COUNTDOWN
	hud.hide_setup()
	hud.build_shop()
	_refresh_hud()


func shop_of(p := -1) -> String:
	return players[local_player if p < 0 else p].shop


func pl(p := -1) -> Player:
	return players[acting if p < 0 else p]


# --- Ablauf ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if phase == Phase.SETUP:
		return
	if phase < Phase.GAME_OVER:
		game_time += delta
		play_time += delta / maxf(Engine.time_scale, 0.001)
	if message_time > 0.0:
		message_time -= delta / maxf(Engine.time_scale, 0.001)
		if message_time <= 0.0:
			message = ""
			hud.refresh_message()
	_update_hover()
	if not mirror:
		match phase:
			Phase.COUNTDOWN:
				countdown -= delta
				if countdown <= 0.0:
					_start_level(level + 1)
			Phase.WAVE:
				_process_wave(delta)
	_hud_timer -= delta / maxf(Engine.time_scale, 0.001)
	if _hud_timer <= 0.0:
		_hud_timer = 0.2
		hud.refresh_live()


func is_wave_running() -> bool:
	return phase == Phase.WAVE


func current_wave() -> int:
	return level


func level_def(n: int) -> Dictionary:
	return levels[n - 1] if n >= 1 and n <= levels.size() else {}


## Gegner pro Spawnpunkt für ein Level dieser Art.
func per_spawn(kind: String) -> int:
	var e: Array = rules.enemies_per_spawn.get(kind, [2, 1])
	return int(e[0]) + int(e[1]) * players.size()


func spawn_count() -> int:
	return rules_spawns().size()


func rules_spawns() -> Array:
	return map.maul.get("spawns", [])


## Spielerfaktor Yx: 0,5·(1 + (11 − m)·0,02), +0,2 ab Level 36, 40, 41 und 49.
func player_factor(n: int) -> float:
	var pf: Dictionary = rules.player_factor
	var y := float(pf.base) * (1.0 + (int(pf.max_players) - players.size()) * float(pf.per_missing))
	for s in pf.steps_before:
		if n >= int(s):
			y += float(pf.step)
	return y


## HP-Budget der ganzen Welle (Jv'), mindestens +5 % zum Vorlevel.
func level_budget(n: int) -> float:
	var lv := level_def(n)
	var d := MaulData.difficulty(difficulty)
	var b := float(lv.get("jv", 1)) * float(d.get("hp", 180))
	if n > 1:
		b *= je * player_factor(n) * float(d.get("factor", 1.0))
		b = maxf(b, prev_budget * float(rules.min_growth))
	return b


func specials_on() -> bool:
	return bool(MaulData.difficulty(difficulty).get("specials", true))


func _start_level(n: int) -> void:
	if n > levels.size():
		_finish(Phase.VICTORY)
		return
	level = n
	var lv := level_def(n)
	level_kind = str(lv.get("kind", "ground"))
	level_specials = lv.get("specials", []) if specials_on() else []
	_frost_level = level_specials.has("frost")
	var per := per_spawn(level_kind)
	level_count = per * spawn_count()
	var budget := level_budget(n)
	prev_budget = budget
	level_hp = budget / level_count
	if level_kind == "boss":
		level_hp /= float(rules.boss_hp_divisor)
	level_lost = 0
	for p in players:
		p.level_kills = 0
	spawn_queue.clear()
	for i in spawn_count():
		spawn_queue.append([i, per])
	spawn_timer = 0.0
	phase = Phase.WAVE
	_alternate.clear()
	show_message(level_title(n), 4.0)
	_refresh_hud()


## „Level 7: Boden, Schnell“
func level_title(n: int) -> String:
	var lv := level_def(n)
	var parts := [kind_name(str(lv.get("kind", "")))]
	if specials_on():
		for s in lv.get("specials", []):
			parts.append(special_name(s))
	return tr("Level %d: %s") % [n, ", ".join(parts)]


static func kind_name(kind: String) -> String:
	match kind:
		"air":
			return TranslationServer.translate("Luft")
		"boss":
			return TranslationServer.translate("Boss")
	return TranslationServer.translate("Boden")


static func special_name(s: String) -> String:
	match s:
		"invisible":
			return TranslationServer.translate("Unsichtbar")
		"fast":
			return TranslationServer.translate("Schnell")
		"spell_resist":
			return TranslationServer.translate("Zauberresistent")
		"frost":
			return TranslationServer.translate("Frost")
		"ghost":
			return TranslationServer.translate("Geist")
	return s


func _process_wave(delta: float) -> void:
	if not spawn_queue.is_empty():
		spawn_timer -= delta
		var line := mode == "line"
		var interval := float(rules.modes[1].get("interval", 0.8)) if line else float(rules.get("spawn_interval_group", 0.25))
		var max_alive := int(rules.modes[1].get("max_alive", 120)) if line else 1000000
		while spawn_timer <= 0.0 and not spawn_queue.is_empty():
			if enemies.size() >= max_alive:
				spawn_timer = interval
				break
			for q in spawn_queue:
				_spawn(int(q[0]))
				q[1] -= 1
			spawn_queue = spawn_queue.filter(func(q): return q[1] > 0)
			spawn_timer += interval
	if spawn_queue.is_empty() and enemies.is_empty():
		_end_level()


func _spawn(index: int) -> void:
	var s: Dictionary = rules_spawns()[index]
	var route: Dictionary = map.maul.routes[s.route]
	var lv := level_def(level)
	var e := MaulEnemy.new()
	e.net_id = _next_enemy_id
	_next_enemy_id += 1
	e.route = str(s.route)
	var start := MaulMap.cell(s.cell)
	var legs: Array = route.legs
	e.legs = [{"start": start, "points": legs[0]}]
	for i in range(1, legs.size()):
		e.legs.append({"start": MaulMap.cell(legs[i][0]), "points": legs[i].slice(1)})
	e.chose = not route.has("choices")
	var specials := level_specials
	var sp: Dictionary = rules.specials
	var speed := float(lv.get("speed", 300)) + randi_range(-int(rules.speed_random), int(rules.speed_random))
	var armor := float(lv.get("armor", 0))
	var spell := 1.0
	if specials.has("fast"):
		speed *= 1.0 + float(sp.fast.speed)
	if specials.has("invisible"):
		armor += float(sp.invisible.armor)
		e.invisible = true
	if specials.has("ghost"):
		armor += float(sp.ghost.armor)
		spell *= float(sp.ghost.spell_factor)
		e.ghost = true
	if specials.has("spell_resist"):
		spell *= float(sp.spell_resist.spell_factor)
	e.frost = specials.has("frost")
	e.spell_factor = spell
	var boss := level_kind == "boss"
	var lk: Dictionary = rules.leak
	if boss:
		e.leak_cost = int(lk.boss_40) if level == int(rules.regular_levels) else int(lk.boss)
	else:
		e.leak_cost = clampi(int(lk.budget) / maxi(level_count, 1), 1, int(lk.max))
	var def := {
		"id": str(lv.get("unit", "")),
		"flying": level_kind == "air",
		"boss": boss,
		"color": _enemy_color(),
	}
	var o := {
		"hp": level_hp,
		"speed": speed / 128.0,
		"armor": armor,
		"bounty": float(lv.get("bounty", 1)),
		"armor_type": str(lv.get("armor_type", "medium")),
		"size": 1.6 if boss else 1.0,
	}
	board.add_child(e)
	var leg := _leg_path(e, 0)
	e.setup(self, def, o, leg.path)
	e.waypoint_at = leg.wp
	enemies.append(e)


func _enemy_color() -> String:
	if level_kind == "boss":
		return "#ff4f4f"
	if level_kind == "air":
		return "#7fd4ff"
	if level_specials.has("ghost"):
		return "#b38cff"
	if level_specials.has("frost"):
		return "#bfefff"
	if level_specials.has("fast"):
		return "#ffd166"
	return "#d7cdea"


func _end_level() -> void:
	effects.clear()
	var n := level
	var air := level_kind == "air"
	# Selbstanpassung (JE) nach der Leckquote
	var quota := float(level_lost) / float(maxi(max_lives, 1))
	var a: Dictionary = rules.adapt
	var raw: float = adapt_raw.back()
	if quota <= float(a.quota) and not air:
		streak = mini(streak + 1, int(a.streak_max))
		if streak > 1:
			raw += streak * float(a.streak_step)
	else:
		raw -= quota / 2.0
		streak = maxi(streak - floori(30.0 * quota), 0)
		if quota >= float(a.reset_quota):
			streak = 0
	var d := MaulData.difficulty(difficulty)
	raw = clampf(raw, float(d.get("adapt_min", 0.75)), float(d.get("adapt_max", 7.5)))
	adapt_raw.append(raw)
	var last := adapt_raw.slice(maxi(adapt_raw.size() - int(a.average), 0))
	var sum := 0.0
	for v in last:
		sum += float(v)
	je = sum / last.size()
	je_min = minf(je_min, je)
	je_max = maxf(je_max, je)
	# Fehlerfrei: +5 Leben
	if level_lost == 0:
		lives = mini(lives + int(rules.leak.no_leak_bonus), max_lives)
	# Einkommen
	var inc: Dictionary = rules.income
	income_pot = floori((income_pot + int(inc.add)) * float(inc.growth))
	if n == 10 or n == 20 or n == 30:
		income_pot += int(inc.boss_bonus)
	var m := players.size()
	for i in m:
		var share := income_pot / m
		if i == 0:
			share += floori(income_pot * float(inc.red_share) / m)
		players[i].gold += share
	# Obi: jede Runde −1 % Towerwert
	for t in towers.values():
		if shop_of(t.owner_player) == "obi":
			t.value = floori(t.value * 0.99)
	if n >= levels.size():
		_finish(Phase.VICTORY)
		return
	phase = Phase.COUNTDOWN
	if n == int(rules.regular_levels):
		countdown = float(rules.level_delay_after_40)
		show_message(tr(str(rules.get("level_40_text", ""))), 8.0)
	else:
		countdown = float(rules.level_delay)
		show_message(tr("Level %d geschafft: +%d Gold") % [n, income_pot / m + (floori(income_pot * float(inc.red_share) / m) if local_player == 0 else 0)], 4.0)
	_refresh_hud()


func _finish(p: Phase) -> void:
	phase = p
	Engine.time_scale = 1.0
	build_id = ""
	hud.show_game_over(p == Phase.VICTORY)


# --- Wege --------------------------------------------------------------------------

## Weg eines Abschnitts: {path: PackedVector2Array (Feldmitten), wp: Index im Pfad je Wegpunkt}.
## Boden mit Towern, Geister nur übers Gelände, Flieger gerade von Punkt zu Punkt.
func _route(start: Vector2i, points: Array, how: String) -> Dictionary:
	var key := "%s|%s|%s" % [how, start, points]
	if _path_cache.has(key):
		return _path_cache[key]
	var res := _compute_route(start, points, how, pathfinder)
	_path_cache[key] = res
	return res


func _compute_route(start: Vector2i, points: Array, how: String, finder: Pathfinder) -> Dictionary:
	var path := PackedVector2Array([Board3D.cell_center(start)])
	var wp: Array = []
	var from := start
	var f := ghost_finder if how == "ghost" else finder
	for p in points:
		var to := MaulMap.cell(p)
		if how == "air":
			path.append(Board3D.cell_center(to))
		else:
			if f.astar.is_point_solid(from) or f.astar.is_point_solid(to):
				return {"path": PackedVector2Array(), "wp": []}
			var seg := f.astar.get_id_path(from, to)
			if seg.is_empty():
				return {"path": PackedVector2Array(), "wp": []}
			for j in range(1, seg.size()):
				path.append(Board3D.cell_center(seg[j]))
		wp.append(path.size() - 1)
		from = to
	return {"path": path, "wp": wp}


func _how(e: MaulEnemy) -> String:
	return "air" if e.flying else ("ghost" if e.ghost else "ground")


func _leg_path(e: MaulEnemy, i: int) -> Dictionary:
	var leg: Dictionary = e.legs[i]
	var how := "air" if level_kind == "air" else ("ghost" if e.ghost else "ground")
	return _route(leg.start, leg.points, how)


## Alle Abschnitte aller Routen (mit beiden Abzweigungen) als [Start, Punkte].
func all_legs() -> Array:
	var list := []
	for s in rules_spawns():
		var r: Dictionary = map.maul.routes[s.route]
		list.append([MaulMap.cell(s.cell), r.legs[0]])
		for i in range(1, r.legs.size()):
			list.append([MaulMap.cell(r.legs[i][0]), r.legs[i].slice(1)])
		for ch in r.get("choices", []):
			for leg in ch.legs:
				list.append([MaulMap.cell(leg[0]), leg.slice(1)])
	return list


## Neu berechnen nach Bauen/Verkaufen; zeigt die Wege als Punkte.
func _refresh_paths() -> void:
	_path_cache.clear()
	var pts := PackedVector2Array()
	var seen := {}
	for leg in all_legs():
		var r := _route(leg[0], leg[1], "ground")
		for i in range(0, r.path.size(), 2):
			var p: Vector2 = r.path[i]
			if not seen.has(p):
				seen[p] = true
				pts.append(p)
	board.path_points = pts
	board.refresh_path()


## Würde ein Tower auf diesen Feldern einen der Wege versperren?
func would_block(cells: Array[Vector2i]) -> bool:
	var changed: Array[Vector2i] = []
	for c in cells:
		if not pathfinder.astar.is_point_solid(c):
			pathfinder.astar.set_point_solid(c, true)
			changed.append(c)
	var blocked := false
	var tried := {}
	for leg in all_legs():
		var key := "%s|%s" % [leg[0], leg[1]]
		if tried.has(key):
			continue
		tried[key] = true
		if _compute_route(leg[0], leg[1], "ground", pathfinder).path.is_empty():
			blocked = true
			break
	for c in changed:
		pathfinder.astar.set_point_solid(c, false)
	return blocked


## Gegner, deren restlicher Weg über neue Tower führt, laufen von ihrer Stelle aus neu.
func _repath_enemies(cells: Array[Vector2i]) -> void:
	var blocked := {}
	for c in cells:
		blocked[Board3D.cell_center(c)] = true
	for e in enemies:
		if e.dead or e.flying or e.ghost:
			continue
		var hit := false
		for i in range(e.path_index, e.path.size()):
			if blocked.has(e.path[i]):
				hit = true
				break
		if not hit:
			continue
		var rest: Array = []
		var pts: Array = e.legs[e.leg].points
		for k in e.waypoint_at.size():
			if int(e.waypoint_at[k]) >= e.path_index:
				rest.append(pts[k])
		var here := Vector2i(floori(e.pos.x / Board3D.CELL), floori(e.pos.y / Board3D.CELL))
		var r := _compute_route(here, rest, "ground", pathfinder)
		if r.path.is_empty():
			continue
		var path: PackedVector2Array = r.path
		path[0] = e.pos
		e.path = path
		e.path_index = 1
		var wp: Array = []
		var skipped := pts.size() - rest.size()
		for k in skipped:
			wp.append(-1)
		wp.append_array(r.wp)
		e.waypoint_at = wp


# --- Gegner: Schnittstelle für Enemy/Tower -----------------------------------------

func on_enemy_killed(e) -> void:
	enemies_killed += 1
	var p: int = e.last_hit_by if e.last_hit_by >= 0 and e.last_hit_by < players.size() else 0
	players[p].gold += int(e.bounty)
	players[p].kills += 1
	players[p].level_kills += 1
	_remove_enemy(e)
	_refresh_hud()


## Ende eines Abschnitts: Teleport zum nächsten Abschnitt, sonst Leak.
func on_enemy_leaked(e) -> void:
	var me: MaulEnemy = e
	if me.leg + 1 < me.legs.size():
		_teleport(me, me.leg + 1)
		return
	if not me.chose:
		var route: Dictionary = map.maul.routes[me.route]
		var ch: Dictionary = _choose(me.route, route.choices)
		me.chose = true
		var base := me.legs.size()
		for leg in ch.legs:
			me.legs.append({"start": MaulMap.cell(leg[0]), "points": leg.slice(1)})
		_teleport(me, base)
		return
	enemies_leaked += 1
	var cost := mini(me.leak_cost, lives)
	lives -= cost
	level_lost += cost
	_remove_enemy(me)
	if lives <= 0 and not Session.debug_immortal:
		lives = 0
		_finish(Phase.GAME_OVER)
	_refresh_hud()


## Abzweigung links/rechts: ist eines der Gebiete leer, gehen alle ins bebaute, sonst abwechselnd.
func _choose(route: String, choices: Array) -> Dictionary:
	var built := choices.filter(func(c): return _zone_towers[int(c.zone)] > 1)
	if built.size() == 1:
		return built[0]
	var n: int = _alternate.get(route, 0)
	_alternate[route] = n + 1
	return choices[n % choices.size()]


func _teleport(e: MaulEnemy, leg: int) -> void:
	var from := e.position
	e.leg = leg
	var r := _leg_path(e, leg)
	if r.path.is_empty():
		r = _route(e.legs[leg].start, e.legs[leg].points, "ghost")
	e.path = r.path
	e.waypoint_at = r.wp
	e.path_index = 1
	e.pos = e.path[0]
	e.dead = false
	e._sync_position()
	add_beam(from + Vector3(0, 0.3, 0), e.position + Vector3(0, 0.3, 0), Color("b38cff"))


func _remove_enemy(e) -> void:
	enemies.erase(e)
	if selected_enemy == e:
		selected_enemy = null
	e.queue_free()


var selected_enemy = null


## Leere Gebiete (ohne Tower) laufen die Gegner dreimal so schnell durch.
func is_covered(e) -> bool:
	var c := Vector2i(floori(e.pos.x / Board3D.CELL), floori(e.pos.y / Board3D.CELL))
	var z := map.zone_at(c)
	return z < 0 or _zone_towers[z] > 0


func idle_speed_factor() -> float:
	return float(rules.get("empty_zone_speed", 3.0))


func free_stretch(_e) -> Array:
	return [-1.0, -1.0]


func is_detected(e) -> bool:
	if not e.invisible:
		return true
	if e.detected_until > game_time:
		return true
	for p in players:
		if MaulData.rules().detect_shops.has(p.shop) or p.reveal_until > game_time:
			return true
	for t in _detect_towers:
		if is_instance_valid(t) and e.pos.distance_to(t.pos) <= float(t.ability("detect").radius):
			e.detected_until = game_time + 0.5
			return true
	return false


## Frost-Level: Tower im Umkreis eines Frostgegners greifen 33 % langsamer an.
func frost_factor(t) -> float:
	if not _frost_level:
		return 1.0
	var f: Dictionary = rules.specials.frost
	var r := float(f.radius) / 128.0
	for e in enemies:
		if e.frost and not e.dead and e.pos.distance_to(t.pos) <= r:
			return 1.0 / (1.0 - float(f.attack_slow))
	return 1.0


func find_targets(t, count: int) -> Array:
	var list := enemies.filter(func(e): return not e.dead and t.can_target(e) and t.in_range(e))
	list.sort_custom(func(a, b): return a.traveled > b.traveled)
	return list.slice(0, count)


func find_targets_in(t, r: float, count: int) -> Array:
	var list := enemies.filter(func(e): return not e.dead and t.can_target(e) and e.pos.distance_to(t.pos) <= r)
	list.sort_custom(func(a, b): return a.traveled > b.traveled)
	return list.slice(0, count)


func enemies_in_radius(p: Vector2, radius: float) -> Array:
	return enemies.filter(func(e): return not e.dead and e.pos.distance_to(p) <= radius)


## fx (Schuss-/Treffer-Effekt der GemTD-Tower) gibt es im Maul noch nicht, nur die Linie
func add_beam(from: Vector3, to: Vector3, col: Color, _fx: String = "") -> void:
	effects.add_beam(from, to, col)


## Ring aus kurzen Strahlen (Donnerschlag).
func add_ring(p: Vector2, r: float, col: Color) -> void:
	var n := 16
	for i in n:
		var a := TAU * i / n
		var b := TAU * (i + 1) / n
		effects.add_beam(Board3D.to_3d(p + Vector2(cos(a), sin(a)) * r, 0.15), Board3D.to_3d(p + Vector2(cos(b), sin(b)) * r, 0.15), col)


func add_gold(amount: int, p := -1) -> void:
	players[acting if p < 0 else p].gold += amount
	_refresh_hud()


# --- Bauen -------------------------------------------------------------------------

func boss_alive() -> bool:
	for e in enemies:
		if e.boss and not e.dead:
			return true
	return false


func tower_count(p: int) -> int:
	var n := 0
	for t in towers.values():
		if t.owner_player == p:
			n += 1
	return n


func tower_value(p := -1) -> int:
	var n := 0
	var who := local_player if p < 0 else p
	for t in towers.values():
		if t.owner_player == who:
			n += t.value
	return n


## Grund, warum Spieler p hier nicht bauen kann ("" = geht). check_path: Wege prüfen (teuer).
func build_problem(id: String, a: Vector2i, p: int, check_path := false) -> String:
	var def := MaulData.tower(id)
	if def.is_empty() or str(def.get("shop", "")) != shop_of(p):
		return tr("Kein Tower deiner Filiale")
	if phase == Phase.SETUP or phase >= Phase.GAME_OVER:
		return tr("Gerade kann nicht gebaut werden")
	var cells := Board3D.footprint(a)
	var zone: int = players[p].zone
	for c in cells:
		if not map.in_bounds(c) or map.get_tile(c) != MapData.FLOOR or map.zone_at(c) != zone:
			return tr("Nur im eigenen Gebiet")
		if map.is_marker_zone(c):
			return tr("Zu nah am Wegpunkt")
		if occupied.has(c):
			return tr("Hier steht schon ein Tower")
	if int(def.get("cost", 0)) > players[p].gold:
		return tr("Zu wenig Gold")
	if tower_count(p) >= int(rules.food):
		return tr("Kein Platz mehr (höchstens %d Tower)") % int(rules.food)
	if boss_alive():
		return tr("Solange ein Boss lebt, wird nicht gebaut")
	var here := {}
	for c in cells:
		here[c] = true
	for e in enemies:
		if not e.flying and here.has(Vector2i(floori(e.pos.x / Board3D.CELL), floori(e.pos.y / Board3D.CELL))):
			return tr("Ein Gegner steht im Weg")
	if check_path and would_block(cells):
		return tr("Würde den Weg versperren")
	return ""


func submit(cmd: Dictionary) -> bool:
	if not cmd.has("player"):
		cmd.player = local_player
	return execute(cmd)


func execute(cmd: Dictionary) -> bool:
	var p := int(cmd.get("player", -1))
	if p < 0 or p >= players.size():
		return false
	acting = p
	var ok := _execute(cmd)
	acting = local_player
	if ok:
		_refresh_hud()
	return ok


func _execute(cmd: Dictionary) -> bool:
	var p := acting
	match str(cmd.get("type", "")):
		"build":
			var a: Vector2i = cmd.cell
			var id := str(cmd.tower)
			var why := build_problem(id, a, p, true)
			if why != "":
				if p == local_player:
					show_message(why)
				return false
			var def := MaulData.tower(id)
			players[p].gold -= int(def.cost)
			var t := MaulTower.new()
			t.owner_player = p
			board.add_child(t)
			t.setup(self, a, id, 0)
			t.value = int(def.get("value", def.cost))
			_register(t)
			return true
		"sell":
			var t: MaulTower = towers.get(cmd.cell, null)
			if t == null or t.owner_player != p:
				return false
			players[p].gold += sell_value(t)
			_unregister(t)
			t.queue_free()
			return true
		"upgrade":
			var t: MaulTower = towers.get(cmd.cell, null)
			var to := str(cmd.to)
			if t == null or t.owner_player != p or not t.def.get("upgrades_to", []).has(to):
				return false
			var def := MaulData.tower(to)
			if int(def.cost) > players[p].gold:
				if p == local_player:
					show_message(tr("Zu wenig Gold"))
				return false
			players[p].gold -= int(def.cost)
			t.set_tower(to, 0)
			t.value += int(def.cost)
			t.set_selected(t == selected)
			_update_detect()
			if t == selected:
				hud.refresh_selection()
			return true
		"start_now":
			if phase == Phase.COUNTDOWN and p == 0:
				countdown = 0.0
				return true
			return false
		"reveal":
			var me: Player = players[p]
			if me.reveal_ready > game_time or MaulData.rules().detect_shops.has(me.shop):
				return false
			me.reveal_until = game_time + float(rules.reveal.duration)
			me.reveal_ready = game_time + float(rules.reveal.cooldown)
			return true
	return false


func sell_value(t: MaulTower) -> int:
	return floori(t.value * float(rules.sell_refund))


func _register(t: MaulTower) -> void:
	towers[t.cell] = t
	var cells := Board3D.footprint(t.cell)
	for c in cells:
		occupied[c] = t.cell
		pathfinder.set_solid(c, true)
	var z := map.zone_at(t.cell)
	if z >= 0:
		_zone_towers[z] += 1
	_update_detect()
	_refresh_paths()
	_repath_enemies(cells)


func _unregister(t: MaulTower) -> void:
	towers.erase(t.cell)
	for c in Board3D.footprint(t.cell):
		occupied.erase(c)
		pathfinder.set_solid(c, false)
	var z := map.zone_at(t.cell)
	if z >= 0:
		_zone_towers[z] -= 1
	if selected == t:
		select(null)
	_update_detect()
	_refresh_paths()


func _update_detect() -> void:
	_detect_towers = towers.values().filter(func(t): return not t.ability("detect").is_empty())


# --- Eingabe -----------------------------------------------------------------------

func select(t: MaulTower) -> void:
	if selected != null and is_instance_valid(selected):
		selected.set_selected(false)
	selected = t
	if t != null:
		t.set_selected(true)
		build_id = ""
	hud.refresh_selection()
	hud.refresh_shop()


func choose_build(id: String) -> void:
	build_id = id if build_id != id else ""
	if build_id != "":
		select(null)
		build_id = id
	_range_preview_r = -1.0
	hud.refresh_shop()


func _update_hover() -> void:
	var c := NO_CELL
	if build_id != "" and camera_rig.camera != null:
		c = board.mouse_anchor(camera_rig.camera)
	if c != board.hover_cell:
		board.hover_cell = c
		board.hover_ok = c != NO_CELL and build_problem(build_id, c, local_player) == ""
		board.refresh_hover()
	_range_preview.visible = c != NO_CELL
	if c != NO_CELL:
		var r := float(MaulData.tower(build_id).get("range", 0))
		if r != _range_preview_r:
			_range_preview_r = r
			var torus := TorusMesh.new()
			torus.inner_radius = maxf(r - 0.06, 0.01)
			torus.outer_radius = maxf(r, 0.07)
			torus.rings = 64
			torus.ring_segments = 4
			_range_preview.mesh = torus
			_range_preview.material_override = Board3D.make_material(Color(0.13, 0.77, 0.93, 0.7), true)
		_range_preview.position = Board3D.to_3d(Board3D.footprint_center(c), 0.05)


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.SETUP:
		return
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_click(event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT and not camera_rig.right_dragged:
			build_id = ""
			select(null)
	elif event is InputEventKey and event.pressed and not event.echo:
		var i := BUILD_KEYS.find(event.physical_keycode)
		if i >= 0 and not event.ctrl_pressed:
			var list := MaulData.buyable(shop_of())
			if i < list.size():
				choose_build(str(list[i].id))
			return
		match event.keycode:
			KEY_ESCAPE:
				build_id = ""
				select(null)
			KEY_1:
				set_speed(1.0)
			KEY_2:
				set_speed(2.0)
			KEY_3:
				set_speed(4.0)
			KEY_DELETE:
				if selected != null:
					submit({"type": "sell", "cell": selected.cell})


func _on_click(keep := false) -> void:
	var c := board.mouse_cell(camera_rig.camera)
	if build_id != "":
		var a := board.mouse_anchor(camera_rig.camera)
		if submit({"type": "build", "tower": build_id, "cell": a}) and not keep:
			build_id = ""
			hud.refresh_shop()
		return
	if occupied.has(c):
		select(towers[occupied[c]])
	else:
		select(null)


func set_speed(f: float) -> void:
	Engine.time_scale = f
	hud.refresh_live()


func show_message(text: String, seconds := 2.5) -> void:
	message = text
	message_time = seconds
	if hud != null:
		hud.refresh_message()


func _refresh_hud() -> void:
	if hud != null:
		hud.refresh()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
