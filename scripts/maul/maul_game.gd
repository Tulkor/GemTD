class_name MaulGame
extends Node3D
## Shopping Maul: Spielablauf. Jeder Spieler eröffnet eine Filiale und kauft deren Tower in sein
## Gebiet, die Gewerbeaufsicht läuft von 12 Spawns über Teleports zur Mall in P1. Das Team teilt
## sich die Leben. Regeln aus data/maul/rules.json, Level aus waves.json (siehe Designdokument).
##
## Wie in game.gd laufen alle Spieleraktionen als Befehle über submit(cmd) → execute(cmd) mit
## Spielernummer. Im Koop (maul_sync.gd) rechnet nur der Host, die Mitspieler schicken ihre Befehle
## und zeigen den gemeldeten Stand. Spieler i baut in Gebiet P(i+1), der Host im Zentrum.
## Tower und Gegner sind die GemTD-Klassen (MaulTower, MaulEnemy) und rufen dieselben
## Funktionen auf wie in game.gd (find_targets, enemies_in_radius, on_enemy_killed …).
##
## Etappe 2 (pro.json): Hauptgebäude mit Bonus (+5 % Schaden je Stufe) oder Rabatt (5 % des
## Kaufpreises zurück), XP über Spiele hinweg (maul_xp.gd) mit XPert-Towern, die Profi-Filialen
## mit Items (Post, IKEA, Fitness, Waffenladen), Wasser (Gärtnerei), Zombies und Drohnen (maul_unit.gd).

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
	var bonus := 0            ## Stufe Bonus-Upgrade bzw. Rabatt im Hauptgebäude (0–5)
	var xp := 10              ## Erfahrung in Zehnteln (10 = 1,0 XP)
	var xp_pot := 0.0
	var research := {}        ## TUI: Forschung → Stufe
	var aok_lives := 0        ## AOK: in diesem Level zurückgeholte Leben
	var away := false

var rules: Dictionary
var levels: Array
var map: MaulMap
var board: MaulBoard
var effects: Effects
var camera_rig: MaulCamera
var hud: MaulHud
var pathfinder: Pathfinder   ## mit Towern
var ghost_finder: Pathfinder ## nur Gelände (Geist-Level)

## Koop (maul_sync.gd): im Koop rechnet nur der Host, mirror = Mitspieler
var sync: MaulSync = null
## Für Net._coop_end (verlässt der Host die Partie, gehen die Mitspieler zurück ins Menü)
var coop: MaulSync:
	get:
		return sync
var mirror := false
var local_player := 0
var acting := 0
var players: Array = []
var sandbox := false        ## Option „Sandbox“: feste 800 XP (alles offen), Durchbrüche kosten keine Leben, keine XP
var levels_done := 0
## Debug-Menü (maul_debug.gd): freies Bauen = Tower aller Filialen ohne Voraussetzungen und Towerlimit,
## alle Items ohne Laden. debug_xp: XP verändert, dann wird am Levelende nichts gespeichert.
var debug_free := false
var debug_xp := false
var xp_start := 0           ## XP beim Start (Endbildschirm zeigt den Zuwachs)

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
var units: Array = []        ## Zombies und Drohnen (MaulUnit)
var selected: MaulTower = null
var selected_unit: MaulUnit = null
var pending := {}            ## wartende Klick-Aktion: {type: "move_items", from: Anker}
var _next_unit_id := 1
var notes := {}              ## Koop: Spieler → [Zähler, Meldung] für Mitspieler
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
var show_all_paths := false  ## Mehrspieler: auch die Wege durch fremde Gebiete zeigen
var _own_path_pts := PackedVector2Array()
var _other_path_pts := PackedVector2Array()
var _zone_towers: Array = [] ## Tower je Zone
var _frost_level := false
var _detect_towers: Array = []
var _range_preview: MeshInstance3D
var _range_preview_r := -1.0
var _hud_timer := 0.0


func _ready() -> void:
	# Art déco für Oberfläche und Spielfeld (Petrol, Messing), vor dem Bau von HUD und Board
	UiTheme.use_skin(UiTheme.DECO)
	rules = MaulData.rules()
	levels = MaulData.levels()
	map = MaulMap.create()
	pathfinder = Pathfinder.new(map)
	ghost_finder = Pathfinder.new(map)
	_zone_towers.resize(map.zones.size())
	_zone_towers.fill(0)
	difficulty = int(rules.get("default_difficulty", 1))
	var coop_info: Dictionary = Session.coop
	Session.coop = {}
	var names: Array = coop_info.get("names", [])
	if coop_info.is_empty():
		names = [tr("Du")]
	local_player = int(coop_info.get("player", 0))
	acting = local_player
	mirror = coop_info.get("role", "") == "client"
	for i in mini(names.size(), map.zones.size()):
		var p := Player.new()
		p.name = str(names[i])
		p.zone = i
		players.append(p)
	players[local_player].xp = MaulXp.load_xp()
	xp_start = players[local_player].xp

	CameraRig.add_environment(self)
	board = MaulBoard.new()
	board.own_zone = players[local_player].zone
	board.players = players.size()
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
	camera_rig.look_at_point(map.zone_center(players[local_player].zone), 42.0)
	hud.show_setup()
	if not coop_info.is_empty():
		sync = MaulSync.new()
		sync.game = self
		sync.host = not mirror
		add_child(sync)
		Net.game = self


# --- Start ---------------------------------------------------------------------

## Nach der Filialwahl: Gold, Leben und Countdown bis Level 1. Im Koop startet der Host (Schwierigkeit,
## Modus, Sandbox gelten für alle), die Mitspieler wählen ihre Filiale mit dem Befehl "shop".
func start_game(shop_id: String, diff: int, play_mode: String, sandbox_on := false) -> void:
	if mirror:
		submit({"type": "shop", "shop": shop_id, "xp": players[local_player].xp})
		return
	if phase != Phase.SETUP:
		return
	difficulty = clampi(diff, 0, rules.get("difficulties", []).size() - 1)
	mode = play_mode
	sandbox = sandbox_on
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
		if sandbox:
			pl.xp = int(MaulXp.cfg().get("sandbox", 8000))
	countdown = float(rules.first_delay_many if m >= 4 else rules.first_delay)
	phase = Phase.COUNTDOWN
	_pick_shop(local_player, shop_id)
	_refresh_hud()


## Filiale für Spieler p eröffnen (Zufall: "random" = Standard, "random_pro" = Profi).
func _pick_shop(p: int, shop_id: String) -> bool:
	var pl: Player = players[p]
	if pl.shop != "" or phase == Phase.SETUP or phase >= Phase.GAME_OVER:
		return false
	var pro_ok := MaulXp.pro_unlocked(pl.xp) and specials_on()
	if shop_id == "random" or shop_id == "random_pro":
		var kind := "pro" if shop_id == "random_pro" else "standard"
		var pool := MaulData.shops().filter(func(s): return str(s.kind) == kind)
		if pool.is_empty():
			return false
		shop_id = str(pool[randi() % pool.size()].id)
	var s := MaulData.shop(shop_id)
	if s.is_empty() or str(s.kind) == "xpert" or (str(s.kind) == "pro" and not pro_ok):
		return false
	pl.shop = shop_id
	if p == local_player:
		hud.hide_setup()
		hud.build_shop()
	return true


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
		_water(delta)
	elif phase == Phase.COUNTDOWN:
		countdown = maxf(countdown - delta, 0.0)
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
		p.aok_lives = 0
	spawn_queue.clear()
	for i in spawn_count():
		spawn_queue.append([i, per])
	spawn_timer = 0.0
	phase = Phase.WAVE
	Sfx.play("boss" if level_kind == "boss" else "wave_start")
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
	levels_done = n
	_end_level_pro(n)
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
	_fitness_upkeep()
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


## Neu berechnen nach Bauen/Verkaufen; zeigt die Wege als Punkte. Im Mehrspieler erst nur die
## Abschnitte durchs eigene Gebiet, die übrigen über show_all_paths (Knopf an der Übersichtskarte).
func _refresh_paths() -> void:
	_path_cache.clear()
	var zone: int = players[local_player].zone
	var own := {}
	var other := {}
	for leg in all_legs():
		var r := _route(leg[0], leg[1], "ground")
		var mine := players.size() <= 1
		for p in r.path:
			if mine:
				break
			mine = map.zone_at(Vector2i(floori(p.x / Board3D.CELL), floori(p.y / Board3D.CELL))) == zone
		for i in range(0, r.path.size(), 2):
			(own if mine else other)[r.path[i]] = true
	_own_path_pts = PackedVector2Array(own.keys())
	_other_path_pts = PackedVector2Array(other.keys().filter(func(p): return not own.has(p)))
	_show_paths()


func has_other_paths() -> bool:
	return not _other_path_pts.is_empty()


func set_show_all_paths(on: bool) -> void:
	show_all_paths = on
	if hud.paths_button != null:
		hud.paths_button.set_pressed_no_signal(on)
	_show_paths()


func _show_paths() -> void:
	board.path_points = _own_path_pts + _other_path_pts if show_all_paths else _own_path_pts
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
	# AOK: 10 % Chance, Leben zurückzuholen (die Hälfte der Leckkosten, höchstens 30 pro Level)
	var aok: Dictionary = MaulData.pro().aok
	if players[p].shop == "aok" and lives < max_lives and randf() < float(aok.life_chance):
		var room: int = int(aok.life_max_per_level) - players[p].aok_lives
		var gain := mini(maxi(e.leak_cost / 2, 1), room)
		if gain > 0:
			players[p].aok_lives += gain
			gain_lives(gain)
	# Contained Darkness frisst Leichen in der Nähe, nach 5 wird sie für 30 s zur Unleashed Darkness
	var dk: Dictionary = MaulData.pro().undertaker.darkness
	for t in towers.values():
		if t.tower_id == str(dk.tower) and not t.is_unleashed() and t.pos.distance_to(e.pos) <= float(dk.radius):
			t.corpses += 1
			if t.corpses >= int(dk.corpses):
				t.corpses = 0
				t.unleashed_until = game_time + float(dk.duration)
				if t == selected:
					hud.refresh_selection()
	_remove_enemy(e)
	_refresh_hud()


func gain_lives(n: int) -> void:
	lives = mini(lives + n, max_lives)
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
	var cost := 0 if sandbox else mini(me.leak_cost, lives)
	lives -= cost
	level_lost += cost
	if cost > 0:
		Sfx.play("leak")
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
	for u in units:
		var r: float = u.detect_radius()
		if r > 0.0 and e.pos.distance_to(u.pos) <= r:
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


## fx wie bei game.gd ("t:<tower>:<stufe>"); FxData wählt den Effekt nach Filialfarbe und Fähigkeit.
func add_beam(from: Vector3, to: Vector3, col: Color, fx: String = "") -> void:
	effects.add_beam(from, to, col, fx)
	if sync != null and not mirror:
		sync.add_beam(from, to, col, fx)


## Ring aus kurzen Strahlen (Donnerschlag).
func add_ring(p: Vector2, r: float, col: Color) -> void:
	var n := 16
	for i in n:
		var a := TAU * i / n
		var b := TAU * (i + 1) / n
		add_beam(Board3D.to_3d(p + Vector2(cos(a), sin(a)) * r, 0.15), Board3D.to_3d(p + Vector2(cos(b), sin(b)) * r, 0.15), col)


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


func food_limit(p: int) -> int:
	var small := ["tui", "waffenladen"]
	return int(MaulData.pro().get("food_small", 6)) if small.has(shop_of(p)) else int(rules.food)


## Ist ein Tower ein XP-Tower (Token n00B) oder ein Ultimate-Tower (n00H, auch deren Upgrades)?
static func tower_slot(def: Dictionary) -> String:
	var t := def
	while not t.is_empty():
		var req: Array = t.get("requires", [])
		if req.has("n00B"):
			return "xp"
		if req.has("n00H"):
			return "ultimate"
		if t.get("upgrade_from") == null:
			break
		t = MaulData.tower(str(t.upgrade_from))
	return ""


## Fehlende Voraussetzung eines Towers für Spieler p ("" = erfüllt): XP, Level 20 geschafft, kein AOK,
## höchstens ein XP- und ein Ultimate-Tower. ignore: Tower, der gerade aufgewertet wird.
func requirement_problem(def: Dictionary, p: int, ignore: MaulTower = null) -> String:
	if debug_free:
		return ""
	for req in def.get("requires", []):
		var need := MaulXp.needed(str(req))
		if need > 0 and players[p].xp < need:
			return tr("Braucht %d XP") % (need / 10)
		match str(req):
			"R00S":
				if levels_done < int(MaulData.pro().get("ultimate_level", 20)):
					return tr("Erst ab Level %d") % (int(MaulData.pro().get("ultimate_level", 20)) + 1)
			"R00U":
				if shop_of(p) == "aok":
					return tr("Nicht mit der AOK")
	var slot := tower_slot(def)
	if slot != "" and ignore == null:
		for t in towers.values():
			if t.owner_player == p and tower_slot(t.def) == slot:
				return tr("Nur ein XP-Tower erlaubt") if slot == "xp" else tr("Nur ein Ultimate-Tower erlaubt")
	if str(def.get("id", "")) == str(MaulData.pro().drones.charger):
		for t in towers.values():
			if t.owner_player == p and t.tower_id == def.id:
				return tr("Nur ein Drone Charger erlaubt")
	return ""


## Grund, warum Spieler p hier nicht bauen kann ("" = geht). check_path: Wege prüfen (teuer).
func build_problem(id: String, a: Vector2i, p: int, check_path := false) -> String:
	var def := MaulData.tower(id)
	var own := str(def.get("shop", ""))
	if def.is_empty() or (own != shop_of(p) and own != "xpert" and not debug_free) or shop_of(p) == "":
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
	var why := requirement_problem(def, p)
	if why != "":
		return why
	if int(def.get("cost", 0)) > players[p].gold:
		return tr("Zu wenig Gold")
	if tower_count(p) >= food_limit(p) and not debug_free:
		return tr("Kein Platz mehr (höchstens %d Tower)") % food_limit(p)
	if boss_alive() and not debug_free:
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
	var ok := true
	if mirror:
		sync.send(cmd)
	else:
		ok = execute(cmd)
	Sfx.command_sound(cmd, ok)
	return ok


func execute(cmd: Dictionary) -> bool:
	var p := int(cmd.get("player", -1))
	if p < 0 or p >= players.size():
		return false
	acting = p
	var ok := _execute(cmd)
	acting = local_player
	if ok:
		_refresh_hud()
		if selected != null and is_instance_valid(selected):
			hud.refresh_selection()
	return ok


## Gold ausgeben; Filialen mit Rabatt bekommen 5 % je Stufe zurück.
func _pay(p: int, cost: int) -> void:
	var pl: Player = players[p]
	pl.gold -= cost
	if str(MaulData.shop(pl.shop).get("bonus", "")) == "rebate" and pl.bonus > 0:
		pl.gold += floori(cost * float(MaulData.pro().bonus.rebate_step) * pl.bonus)


func _tower(p: int, cell) -> MaulTower:
	var t: MaulTower = towers.get(cell, null) if cell is Vector2i else null
	return t if t != null and t.owner_player == p else null


func _execute(cmd: Dictionary) -> bool:
	var p := acting
	match str(cmd.get("type", "")):
		"shop":
			if mirror:
				return false
			players[p].xp = clampi(int(cmd.get("xp", players[p].xp)), 0, int(MaulXp.cfg().get("max", 9999))) if not sandbox else players[p].xp
			if _pick_shop(p, str(cmd.get("shop", ""))):
				return true
			_tell(p, tr("Diese Filiale ist gesperrt"))
			return false
		"build":
			var a: Vector2i = cmd.cell
			var id := str(cmd.tower)
			var why := build_problem(id, a, p, true)
			if why != "":
				_tell(p, why)
				return false
			var def := MaulData.tower(id)
			_pay(p, int(def.cost))
			var t := MaulTower.new()
			t.owner_player = p
			board.add_child(t)
			t.setup(self, a, id, 0)
			t.value = int(def.get("value", def.cost))
			_register(t)
			return true
		"sell":
			var t: MaulTower = towers.get(cmd.cell, null)
			if t == null or (t.owner_player != p and map.zone_at(t.cell) != players[p].zone):
				return false
			players[t.owner_player].gold += sell_value(t)
			_unregister(t)
			t.queue_free()
			return true
		"upgrade":
			var t := _tower(p, cmd.get("cell"))
			var to := str(cmd.get("to", ""))
			if t == null or not t.def.get("upgrades_to", []).has(to):
				return false
			var def := MaulData.tower(to)
			var why := requirement_problem(def, p, t)
			if why == "" and int(def.cost) > players[p].gold:
				why = tr("Zu wenig Gold")
			if why != "":
				_tell(p, why)
				return false
			_pay(p, int(def.cost))
			t.set_tower(to, 0)
			t.value = int(def.value) if def.get("swap", false) else t.value + int(def.cost)
			t.set_selected(t == selected)
			_update_detect()
			return true
		"start_now":
			if phase == Phase.COUNTDOWN and p == 0:
				countdown = 0.0
				return true
			return false
		"speed":
			Engine.time_scale = clampf(float(cmd.get("f", 1.0)), 1.0, 4.0)
			return true
		"reveal":
			var me: Player = players[p]
			if me.reveal_ready > game_time or MaulData.rules().detect_shops.has(me.shop):
				return false
			me.reveal_until = game_time + float(rules.reveal.duration)
			me.reveal_ready = game_time + float(rules.reveal.cooldown)
			return true
		"bonus":
			var me: Player = players[p]
			var kind := str(MaulData.shop(me.shop).get("bonus", ""))
			if not has_bonus(p) or me.bonus >= int(MaulData.pro().bonus.levels):
				return false
			var cost := MaulData.bonus_cost(me.bonus + 1, kind == "rebate", players.size())
			if cost > me.gold:
				_tell(p, tr("Zu wenig Gold"))
				return false
			me.gold -= cost
			me.bonus += 1
			return true
		"research":
			var me: Player = players[p]
			var r: Dictionary = MaulData.pro().tui.research.get(str(cmd.get("id", "")), {})
			var lv: int = me.research.get(str(cmd.id), 0)
			if me.shop != "tui" or r.is_empty() or lv >= int(r.max):
				return false
			if int(r.cost) > me.gold:
				_tell(p, tr("Zu wenig Gold"))
				return false
			me.gold -= int(r.cost)
			me.research[str(cmd.id)] = lv + 1
			return true
		"item":
			return _buy_item(p, _tower(p, cmd.get("cell")), str(cmd.get("item", "")))
		"item_sell":
			var t := _tower(p, cmd.get("cell"))
			var i := int(cmd.get("slot", -1))
			if t == null or i < 0 or i >= t.items.size():
				return false
			players[p].gold += floori(int(MaulData.item(str(t.items[i])).get("cost", 0)) * float(rules.sell_refund))
			t.items.remove_at(i)
			return true
		"move_items":
			var from := _tower(p, cmd.get("from"))
			var to := _tower(p, cmd.get("to"))
			if from == null or to == null or from == to or from.slots() == 0 or to.slots() == 0:
				return false
			while not from.items.is_empty() and to.items.size() < to.slots():
				to.items.append(from.items.pop_front())
				_combine(to)
			return true
		"copy":
			var t := _tower(p, cmd.get("cell"))
			var to := str(cmd.get("to", ""))
			var cs: Dictionary = MaulData.pro().copyshop
			var def := MaulData.tower(to)
			if t == null or t.tower_id != str(cs.copier) or def.is_empty() or not cs.shops.has(str(def.shop)):
				return false
			var cost := copy_cost(to)
			if cost > players[p].gold:
				_tell(p, tr("Zu wenig Gold"))
				return false
			players[p].gold -= cost
			t.set_tower(to, 0)
			t.value = int(def.get("value", def.cost))
			_update_detect()
			return true
		"summon":
			var t := _tower(p, cmd.get("cell"))
			var id := str(cmd.get("unit", ""))
			if t == null or not MaulData.pro().undertaker.summons.get(t.tower_id, []).has(id):
				return false
			if float(t.summon_ready.get(id, 0.0)) > game_time:
				return false
			t.summon_ready[id] = game_time + float(MaulData.unit(id).get("summon_cd", 10))
			spawn_unit(id, p, t)
			return true
		"drone":
			var t := _tower(p, cmd.get("cell"))
			var kind := str(cmd.get("kind", ""))
			var dr: Dictionary = MaulData.pro().drones
			if t == null or t.tower_id != str(dr.charger) or not ["battle", "support"].has(kind):
				return false
			if units.filter(func(u): return u.owner_player == p and u.drone).size() >= int(dr.max):
				_tell(p, tr("Höchstens %d Drohnen") % int(dr.max))
				return false
			var cost := int(MaulData.unit(kind).get("cost", 20))
			if cost > players[p].gold:
				_tell(p, tr("Zu wenig Gold"))
				return false
			_pay(p, cost)
			spawn_unit(kind, p, t)
			return true
		"module":
			return _buy_module(p, unit_by_id(int(cmd.get("unit", -1))), str(cmd.get("item", "")))
		"module_sell":
			var u := unit_by_id(int(cmd.get("unit", -1)))
			var slot := str(cmd.get("slot", ""))
			if u == null or u.owner_player != p or not u.modules.has(slot):
				return false
			players[p].gold += floori(int(MaulData.item(str(u.modules[slot])).get("cost", 0)) * float(rules.sell_refund))
			u.modules.erase(slot)
			u.energy = minf(u.energy, u.max_energy())
			return true
		"post":
			var u := unit_by_id(int(cmd.get("unit", -1)))
			if u == null or u.owner_player != p:
				return false
			var at := Vector2(float(cmd.get("x", 0)), float(cmd.get("y", 0)))
			if map.zone_at(Vector2i(floori(at.x / Board3D.CELL), floori(at.y / Board3D.CELL))) != players[p].zone:
				_tell(p, tr("Nur im eigenen Gebiet"))
				return false
			u.post = at
			return true
	return false


## Meldung an Spieler p: lokal sofort, an Mitspieler über den nächsten Stand (maul_sync.gd → notes).
func _tell(p: int, text: String) -> void:
	if p == local_player:
		show_message(text)
	elif sync != null:
		notes[p] = [int(notes.get(p, [0, ""])[0]) + 1, text]


func has_bonus(p: int) -> bool:
	var s := shop_of(p)
	return s != "" and str(MaulData.shop(s).get("bonus", "")) != "" and not ["gaertnerei", "waffenladen"].has(s)


## Copyshop: Punktwert × 1,05 − 9 Gold (Tower unter 9 Gold sind gratis).
func copy_cost(id: String) -> int:
	var cs: Dictionary = MaulData.pro().copyshop
	var v := int(MaulData.tower(id).get("value", 0))
	return 0 if v < int(cs.minus) else floori(v * float(cs.factor) - float(cs.minus))


## Läden, die Spieler p für dieses Item gebaut hat (Item gibt es nur, wenn so ein Laden steht).
func store_has(p: int, item_id: String) -> bool:
	if debug_free:
		return not MaulData.item(item_id).is_empty()
	var st: Dictionary = MaulData.pro().stores
	for t in towers.values():
		if t.owner_player == p and st.get(t.tower_id, []).has(item_id):
			return true
	return false


## Items, die Spieler p gerade kaufen kann (aus seinen Läden), nach Preis.
func items_for(p: int, kind: String) -> Array:
	var st: Dictionary = MaulData.pro().stores
	var seen := {}
	if debug_free:
		for id in MaulData.pro().get("items", {}):
			if str(MaulData.item(id).get("kind", "weapon")) == kind:
				seen[str(id)] = true
	for t in towers.values():
		if t.owner_player == p:
			for id in st.get(t.tower_id, []):
				var it := MaulData.item(str(id))
				if str(it.get("kind", "weapon")) == kind:
					seen[str(id)] = true
	var list := seen.keys()
	list.sort_custom(func(x, y): return int(MaulData.item(x).cost) < int(MaulData.item(y).cost))
	return list


func _buy_item(p: int, t: MaulTower, id: String) -> bool:
	var it := MaulData.item(id)
	if t == null or it.is_empty() or not store_has(p, id):
		return false
	var cost := int(it.get("cost", 0))
	if cost > players[p].gold:
		_tell(p, tr("Zu wenig Gold"))
		return false
	if str(it.get("kind", "weapon")) == "drug":
		if not MaulData.pro().fitness.upkeep.has(t.tower_id):
			return false
		_pay(p, cost)
		_take_drug(t, it)
		return true
	if t.items.size() >= t.slots():
		_tell(p, tr("Alle Slots belegt"))
		return false
	_pay(p, cost)
	t.items.append(id)
	_combine(t)
	return true


## IKEA: zwei passende Teile im selben Show House werden zu einem besseren (auch mehrstufig).
func _combine(t: MaulTower) -> void:
	var again := true
	while again:
		again = false
		for c in MaulData.pro().get("combos", []):
			var i := t.items.find(c[0])
			if i < 0:
				continue
			var j := -1
			for k in t.items.size():
				if k != i and t.items[k] == c[1]:
					j = k
					break
			if j < 0:
				continue
			t.items.remove_at(maxi(i, j))
			t.items.remove_at(mini(i, j))
			t.items.append(str(c[2]))
			_tell(t.owner_player, tr("Combo: %s") % MaulData.item_name(str(c[2])))
			again = true
			break


## Fitness: Doping wirkt sofort und dauerhaft; starke Mittel bringen Nebenwirkungen (Dosis/300 Stufen).
func _take_drug(t: MaulTower, it: Dictionary) -> void:
	var fit: Dictionary = MaulData.pro().fitness
	var dmg := 0.0
	if it.has("damage"):
		var d = it.damage
		dmg = randf_range(float(d[0]), float(d[1])) if d is Array else float(d)
	t.flat += roundf(dmg)
	var s = it.get("side", 0)
	var add := 0.0
	if str(s) == "dose":
		add = dmg / float(fit.side_dose)
	else:
		add = float(s)
	if add > 0.0:
		add *= float(fit.resist.get(t.tower_id, 1.0))
	t.side = maxi(t.side + roundi(add), 0)
	if it.has("stun"):
		t.drugs["stun"] = [float(it.stun_chance), float(it.stun)]
	if it.has("frost"):
		t.drugs["frost"] = float(it.frost)
	if it.has("slow_aura"):
		t.drugs["slow_aura"] = float(it.slow_aura)
	t._update_extra()


func _buy_module(p: int, u: MaulUnit, id: String) -> bool:
	var it := MaulData.item(id)
	if u == null or u.owner_player != p or not u.drone or str(it.get("kind", "")) != "module" or not store_has(p, id):
		return false
	var slot := str(it.slot)
	if it.get("battle_only", false) and u.unit_id != "battle":
		_tell(p, tr("Hilfsdrohnen tragen keine Kanonen"))
		return false
	if u.modules.has(slot):
		_tell(p, tr("Dieser Modultyp ist schon eingebaut"))
		return false
	if u.modules.size() >= int(MaulData.pro().drones.slots):
		_tell(p, tr("Alle Slots belegt"))
		return false
	if int(it.cost) > players[p].gold:
		_tell(p, tr("Zu wenig Gold"))
		return false
	_pay(p, int(it.cost))
	u.modules[slot] = id
	return true


func sell_value(t: MaulTower) -> int:
	return floori((t.value + t.items_value()) * float(rules.sell_refund))


# --- Profi-Filialen: Schaden, Wasser, Einheiten, Levelende -------------------------------

## Faktor auf den Schaden aller Tower von Spieler p: Bonus-Upgrade +5 % je Stufe, AOK mit vollen
## Leben +33 %, First/Second Aid +40/+50 % (nicht stapelbar).
func damage_factor_for(p: int) -> float:
	if p < 0 or p >= players.size():
		return 1.0
	var pl: Player = players[p]
	var f := 1.0
	if has_bonus(p) and str(MaulData.shop(pl.shop).get("bonus", "")) == "damage":
		f += pl.bonus * float(MaulData.pro().bonus.damage_step)
	if pl.shop == "aok":
		var aok: Dictionary = MaulData.pro().aok
		if lives >= max_lives:
			f += float(aok.full_lives_bonus)
		var aura := 0.0
		for t in towers.values():
			if t.owner_player == p:
				aura = maxf(aura, float(aok.auras.get(t.tower_id, 0.0)))
		f += aura
	return f


func damage_factor(t) -> float:
	return damage_factor_for(t.owner_player)


## Zusätzlicher Schaden pro Treffer: TUI-Forschung (Grundschaden, Profischaden für die Endstufen).
func flat_bonus_for(t) -> float:
	var pl: Player = players[t.owner_player] if t.owner_player < players.size() else null
	if pl == null or pl.shop != "tui" or str(t.def.get("shop", "")) != "tui":
		return 0.0
	var r: Dictionary = MaulData.pro().tui.research
	var v := float(pl.research.get("damage", 0)) * float(r.damage.step)
	if r.advanced.towers.has(t.tower_id):
		v += float(pl.research.get("advanced", 0)) * float(r.advanced.step)
	return v


func range_bonus_for(t) -> float:
	var pl: Player = players[t.owner_player] if t.owner_player < players.size() else null
	if pl == null or pl.shop != "tui" or str(t.def.get("shop", "")) != "tui":
		return 0.0
	return float(pl.research.get("range", 0)) * float(MaulData.pro().tui.research.range.step)


## Gärtnerei: Bewässerungsanlagen füllen alle eigenen Pflanzen in Reichweite auf.
func _water(delta: float) -> void:
	if phase == Phase.SETUP or phase >= Phase.GAME_OVER:
		return
	var g: Dictionary = MaulData.pro().garden
	var irr: Dictionary = g.irrigation
	var r := float(g.radius)
	for src in towers.values():
		if not irr.has(src.tower_id):
			continue
		var rate := float(irr[src.tower_id]) * delta
		for t in towers.values():
			if t.owner_player != src.owner_player:
				continue
			var pl: Dictionary = t.plant()
			if pl.is_empty() or t.pos.distance_to(src.pos) > r:
				continue
			t.water = minf(t.water + rate, float(pl.water))


## Kultstätten heilen die Zombies ihres Besitzers in der Nähe (HP pro Sekunde).
func cult_heal_at(at: Vector2, p: int) -> float:
	var u: Dictionary = MaulData.pro().undertaker
	var best := 0.0
	for t in towers.values():
		if t.owner_player == p and u.cults.has(t.tower_id) and t.pos.distance_to(at) <= float(u.cult_radius):
			best = maxf(best, float(u.cults[t.tower_id]))
	return best


func charger_of(p: int) -> MaulTower:
	var id := str(MaulData.pro().drones.charger)
	for t in towers.values():
		if t.owner_player == p and t.tower_id == id:
			return t
	return null


func spawn_unit(id: String, p: int, from: MaulTower) -> MaulUnit:
	var u := MaulUnit.new()
	u.net_id = _next_unit_id
	_next_unit_id += 1
	u.home = from.cell if from != null else NO_CELL
	board.add_child(u)
	u.setup(self, id, p, from.pos + Vector2(0.8, 0.0) if from != null else map.zone_center(players[p].zone))
	units.append(u)
	return u


func remove_unit(u: MaulUnit) -> void:
	units.erase(u)
	if selected_unit == u:
		select_unit(null)
	u.queue_free()


func unit_by_id(id: int) -> MaulUnit:
	for u in units:
		if u.net_id == id:
			return u
	return null


## Fitness: nach jedem Level Anabolika zahlen (3/25/75/200 Gold), dafür gibt es gleich viel Stärke.
## Fehlt das Geld, setzt der Tower ein Level aus. Nebenwirkungen sinken um eine Stufe.
func _fitness_upkeep() -> void:
	var up: Dictionary = MaulData.pro().fitness.upkeep
	for t in towers.values():
		if not up.has(t.tower_id):
			continue
		var cost := int(up[t.tower_id])
		var pl: Player = players[t.owner_player]
		t.side = maxi(t.side - 1, 0)
		if pl.gold >= cost:
			pl.gold -= cost
			t.flat += cost
			t.paused = false
		else:
			t.paused = true
			_tell(t.owner_player, tr("Kalter Entzug: %s setzt ein Level aus") % t.label())


## AOK-Bonus und XP am Levelende.
func _end_level_pro(n: int) -> void:
	var aok: Dictionary = MaulData.pro().aok
	for p in players:
		if p.shop == "aok" and level_lost > 0:
			p.gold += mini(n * floori(float(aok.gold_factor) * level_lost), n * int(aok.gold_cap))
	var x := MaulXp.cfg()
	if sandbox or debug_xp or players.size() < int(x.get("min_players", 1)):
		return
	var ke := float(MaulData.difficulty(difficulty).get("xp", 1.0))
	for i in players.size():
		var pl: Player = players[i]
		var before := pl.xp
		var res := MaulXp.gain(pl.xp, pl.xp_pot, n, players.size(), ke)
		pl.xp = int(res[0])
		pl.xp_pot = float(res[1])
		if i == local_player and pl.xp != before:
			MaulXp.save_xp(pl.xp)
			_announce_unlocks(before, pl.xp)


func _announce_unlocks(before: int, now: int) -> void:
	if not MaulXp.pro_unlocked(before) and MaulXp.pro_unlocked(now):
		show_message(tr("%s XP: Profi-Filialen freigeschaltet!") % MaulXp.text(now), 6.0)
		return
	for t in MaulData.xpert().get("towers", []):
		for req in t.get("requires", []):
			var need := MaulXp.needed(str(req))
			if need > before and need <= now:
				show_message(tr("%s XP: %s freigeschaltet!") % [MaulXp.text(now), str(t.name)], 6.0)


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
	pending = {}
	if t != null:
		t.set_selected(true)
		build_id = ""
		if selected_unit != null and is_instance_valid(selected_unit):
			selected_unit.set_selected(false)
		selected_unit = null
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
			select_unit(null)
	elif event is InputEventKey and event.pressed and not event.echo:
		var i := BUILD_KEYS.find(event.physical_keycode)
		if i >= 0 and not event.ctrl_pressed:
			var list := MaulData.buyable(shop_of())
			if i < list.size():
				choose_build(str(list[i].id))
			return
		match event.keycode:
			KEY_ESCAPE:
				# Erst Bauwahl und Auswahl aufheben, sonst Menü öffnen oder schließen
				if build_id != "" or selected != null or selected_unit != null or not pending.is_empty():
					build_id = ""
					select(null)
					select_unit(null)
				else:
					hud.toggle_menu()
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
	if pending.get("type", "") == "move_items":
		var from: Vector2i = pending.from
		pending = {}
		if occupied.has(c):
			submit({"type": "move_items", "from": from, "to": occupied[c]})
		hud.refresh_selection()
		return
	var hit = board._mouse_ground(camera_rig.camera)
	var u := unit_at(hit) if hit != null else null
	if u != null:
		select_unit(u)
		return
	# Gewählte eigene Einheit: Klick ins Gelände setzt ihren Posten
	if selected_unit != null and selected_unit.owner_player == local_player and hit != null and not occupied.has(c):
		submit({"type": "post", "unit": selected_unit.net_id, "x": hit.x, "y": hit.y})
		return
	if occupied.has(c):
		select(towers[occupied[c]])
	else:
		select(null)


## Einheit unter dem Mauszeiger (Weltkoordinaten), sonst null.
func unit_at(at: Vector2) -> MaulUnit:
	var best := 0.45
	var out: MaulUnit = null
	for u in units:
		var d: float = u.pos.distance_to(at)
		if d < best:
			best = d
			out = u
	return out


func select_unit(u: MaulUnit) -> void:
	if selected_unit != null and is_instance_valid(selected_unit):
		selected_unit.set_selected(false)
	selected_unit = u
	pending = {}
	if u != null:
		u.set_selected(true)
		if selected != null and is_instance_valid(selected):
			selected.set_selected(false)
		selected = null
		build_id = ""
	hud.refresh_selection()


## Spieltempo: im Koop bestimmt es der Host, Mitspieler schicken ihren Wunsch als Befehl.
func set_speed(f: float) -> void:
	if mirror:
		submit({"type": "speed", "f": f})
		return
	Engine.time_scale = f
	hud.refresh_live()


# --- Debug-Menü ------------------------------------------------------------------

## Debug: XP des eigenen Spielers erhöhen (Zehntel, -1 = alles frei wie in der Sandbox). Wird nicht gespeichert.
func debug_add_xp(tenths: int) -> void:
	var me: Player = players[local_player]
	var before := me.xp
	var top := int(MaulXp.cfg().get("sandbox", 8000))
	me.xp = top if tenths < 0 else mini(me.xp + tenths, int(MaulXp.cfg().get("max", 9999)))
	debug_xp = true
	_announce_unlocks(before, me.xp)
	_refresh_hud()


## Debug: eigene Filiale wechseln (alle Standard- und Profi-Filialen); gebaute Tower bleiben stehen.
func debug_set_shop(shop_id: String) -> void:
	if MaulData.shop(shop_id).is_empty() or phase == Phase.SETUP or phase >= Phase.GAME_OVER:
		return
	players[local_player].shop = shop_id
	build_id = ""
	select(null)
	hud.build_shop()
	_refresh_hud()


## Debug: Level n (ab 1). Läuft ein Level, verschwinden seine Gegner und n startet sofort, im Countdown kommt n als nächstes.
func debug_jump_to_level(n: int) -> void:
	if mirror or phase == Phase.SETUP or phase >= Phase.GAME_OVER:
		return
	n = clampi(n, 1, levels.size())
	for e in enemies.duplicate():
		_remove_enemy(e)
	spawn_queue.clear()
	effects.clear()
	levels_done = maxi(levels_done, n - 1)
	if phase == Phase.WAVE:
		_start_level(n)
	else:
		level = n - 1
	_refresh_hud()


func show_message(text: String, seconds := 2.5) -> void:
	message = text
	message_time = seconds
	if hud != null:
		hud.refresh_message()


func _refresh_hud() -> void:
	if hud != null:
		hud.refresh()


func _exit_tree() -> void:
	UiTheme.use_skin(UiTheme.ARCADE)
	Engine.time_scale = 1.0
	if Net.game == self:
		Net.game = null
	if sync != null and not mirror:
		Net.end_coop()
