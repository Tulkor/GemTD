extends "res://scripts/game/game.gd"
## YouTD (Vorbild: YouTD 2, MIT, github.com/Praytic/youtd2; Regeln in docs/youtd.md und data/youtd/rules.json).
##
## Kein Mazing: Gegner laufen einen festen Weg ("_"-Felder der Karte), Tower stehen auf den Bauflächen daneben
## und versperren nie etwas. Man erforscht mit Wissensbüchern Elemente; je nach Spielmodus würfelt jede Welle
## Tower der erforschten Elemente ins Lager (Zufall) oder man kauft sie frei (Bauen). Tower sammeln Erfahrung,
## tragen Items und lassen sich zur nächsten Stufe ihrer Familie aufwerten.
## Wellen kommen nach einem Timer (180 s vor der ersten, dann 15 s nach dem Ende der letzten), mit N auch früher;
## dann laufen mehrere Wellen gleichzeitig. Das Portal hat 100 % Leben.
## Am Ende werden die Punkte zu Spieler-XP (youtd_progress.gd), die über Partien hinweg bleibt.
##
## Etappe 1: nur Einzelspieler, ohne Spielstand; Tower- und Item-Fähigkeiten aus eigenen Skripten kommen später.

const MODE_IDS := ["random_with_upgrades", "build", "totally_random"]

var rules: Dictionary = {}
var mode_index := 0          ## Index in rules.modes
var length_index := 1        ## Index in rules.lengths
var difficulty := 2          ## Index in rules.difficulties
var wave_seed := 0
var wave_rng := RandomNumberGenerator.new()   ## Wellen und Gegnerabstände
var roll_rng := RandomNumberGenerator.new()   ## Würfeln von Towern und Items

## Spieler (Etappe 1: einer)
var tomes := 0
var food_cap := 0
var elements := {}           ## Element -> Stufe
var stash: Array = []        ## gewürfelte Tower-IDs, die noch gebaut werden können
var item_stash: Array = []   ## Item-IDs im Lager
var can_reroll := true       ## Startwurf wiederholen, bis der erste Tower steht
var portal := 100.0          ## Leben des Portals in Prozent
var youtd_score := 0.0
var build_id := ""           ## Tower, der gerade gesetzt wird (lokal)
var picked_item := -1        ## Index im Item-Lager, das gerade eingelegt wird (lokal)
var log_lines: Array = []

## Weisheits-Boni (vor dem Start gewählt) und was daraus folgt
var wisdom: Array = []
var wisdom_mods := {}
var range_bonus := 0.0
var tower_exp_bonus := 0.0
var element_max_bonus := 0
var tower_max_bonus := 0
var player_level_at_start := 0

## Wellen: nächste Welle, Zeit bis dahin, laufende Spawner und lebende Gegner je Welle
var next_wave := 1
var next_wave_in := 0.0
var spawners: Array = []     ## {wave, index, timer}
var alive := {}              ## Welle -> noch lebende oder kommende Gegner
var waves_done := 0
var xp_result := {}
var youtd_panel: YoutdPanel
var scenery: EeveScenery


func _ready() -> void:
	UiTheme.use_skin(UiTheme.DRUID)
	FieldStyle.night = true
	rules = YoutdData.rules()
	Session.score_mode = false
	super._ready()
	if map == null:
		return
	scenery = EeveScenery.add_to(self)
	_style_hud()
	if setup_done and waves.is_empty():
		# ohne Einstellungsfenster (Session.skip_setup, Screenshots): Standardwerte
		setup_done = false
		_apply_setup({"mode": mode_index, "length": length_index, "difficulty": difficulty, "wisdom": YoutdProgress.wisdom()})
	_refresh_hud()


func _exit_tree() -> void:
	super._exit_tree()
	UiTheme.use_skin(UiTheme.ARCADE)
	FieldStyle.night = false


func _style_hud() -> void:
	hud.title_label.text = "YouTD"
	hud.recipes_button.hide()
	hud.chance_value.get_parent().get_parent().hide()
	hud.path_value.get_parent().get_parent().hide()
	hud.pinned_panel.hide()
	youtd_panel = YoutdPanel.new()
	youtd_panel.game = self
	hud.left_col.add_child(youtd_panel)
	hud.left_col.move_child(youtd_panel, 0)


func mode_id() -> String:
	return str((rules.get("modes", []) as Array)[mode_index].get("id", "random_with_upgrades"))


func is_build_mode() -> bool:
	return mode_id() == "build"


func wave_count() -> int:
	return int((rules.get("lengths", []) as Array)[length_index].get("waves", 120))


func diff_rules() -> Dictionary:
	var list: Array = rules.get("difficulties", [{}])
	return list[clampi(difficulty, 0, list.size() - 1)]


# --- Einstellungen ---------------------------------------------------------------

func _make_setup_panel() -> Control:
	var setup := YoutdSetupPanel.new()
	setup.game = self
	return setup


func _make_waves() -> Array:
	return []


func _apply_variance() -> void:
	pass


func save_mode() -> String:
	return "none"


func _execute(cmd: Dictionary) -> bool:
	match str(cmd.get("type", "")):
		"setup":
			if setup_done:
				return false
			_apply_setup(cmd)
			return true
		"research":
			return research(str(cmd.get("element", "")))
		"roll":
			return roll_start()
		"build":
			return build_tower(str(cmd.get("id", "")), cmd.get("cell", NO_CELL))
		"item_put":
			return put_item(tower_from_ref(cmd.get("tower", {})), int(cmd.get("index", -1)))
		"next_wave":
			if not setup_done or phase >= Phase.GAME_OVER or next_wave > max_wave():
				return false
			_start_next_wave()
			return true
		"option":
			var t := tower_from_ref(cmd.get("tower", {}))
			var opts := tower_options(t)
			var i := int(cmd.get("index", -1))
			if i < 0 or i >= opts.size():
				return false
			var o: Dictionary = opts[i]
			if o.action != cmd.get("action") or o.id != cmd.get("id"):
				return false
			return _apply_option(t, o)
		"debug_place":
			return debug_place(str(cmd.get("id", "")), cmd.get("cell", NO_CELL))
		"place", "replace_rocks", "remove_rocks", "take_back", "move_trap":
			return false
	return super._execute(cmd)


func _apply_setup(cmd: Dictionary) -> void:
	mode_index = clampi(int(cmd.get("mode", 0)), 0, (rules.get("modes", []) as Array).size() - 1)
	length_index = clampi(int(cmd.get("length", 1)), 0, (rules.get("lengths", []) as Array).size() - 1)
	difficulty = clampi(int(cmd.get("difficulty", 2)), 0, (rules.get("difficulties", []) as Array).size() - 1)
	wave_seed = int(cmd.get("seed", rng.randi()))
	wave_rng.seed = wave_seed
	roll_rng.seed = wave_seed * 31 + 7
	Session.set_meta("youtd_choice", {"mode": mode_index, "length": length_index, "difficulty": difficulty})
	_apply_wisdom(cmd.get("wisdom", []))
	var st: Dictionary = rules.get("start", {})
	gold = int(st.get("gold", 70))
	tomes += int(st.get("tomes", 90))
	food_cap = mini(food_cap + int(st.get("food", 55)), int(st.get("food_max", 300)))
	portal += float(st.get("lives", 100)) - 100.0
	for el in YoutdData.elements():
		elements[el] = 0
	waves = []
	for i in wave_count():
		waves.append(_wave(i + 1))
	next_wave = 1
	next_wave_in = float(rules.get("time", {}).get("first_wave", 180))
	setup_done = true
	hud.setup_debug(0, waves.size())
	_note(tr("Erforsche ein Element mit Wissensbüchern, dann würfle deine ersten Tower.") if not is_build_mode()
			else tr("Erforsche ein Element mit Wissensbüchern, dann kaufe Tower im Baumenü."))
	_refresh_hud()


func _wave(level: int) -> Dictionary:
	var w := YoutdWaves.generate(level, diff_rules(), wave_rng)
	w["type"] = {"mass": "Masse", "air": "Flieger", "boss": "Boss", "challenge_boss": "Boss", "challenge_mass": "Masse"}.get(w.size, "Boden")
	return w


## Weisheits-Boni anwenden. Stärke = 1 + Synergie + 0,1 % je nicht verteiltem Spielerlevel (Pfad des Aufstiegs).
func _apply_wisdom(list: Array) -> void:
	player_level_at_start = YoutdProgress.level()
	var allowed := YoutdProgress.wisdom_points(player_level_at_start)
	wisdom = list.slice(0, allowed)
	var all: Array = rules.get("wisdom", [])
	var by_id := {}
	for w in all:
		by_id[w.id] = w
	var strength := 1.0
	for id in wisdom:
		var w: Dictionary = by_id.get(id, {})
		strength += float(w.get("strength", 0.0))
		if w.has("strength_per_free_level"):
			var spent := wisdom.size() * int(rules.get("player", {}).get("levels_per_wisdom", 6))
			strength += float(w.strength_per_free_level) * maxi(0, player_level_at_start - spent)
	for id in wisdom:
		var w: Dictionary = by_id.get(id, {})
		for m in w.get("mods", []):
			wisdom_mods[m[0]] = float(wisdom_mods.get(m[0], 0.0)) + float(m[1]) * strength
		tomes += floori(float(w.get("tomes", 0)) * strength)
		food_cap += floori(float(w.get("food", 0)) * strength)
		portal += float(w.get("lives", 0)) * strength
		tower_exp_bonus += float(w.get("tower_exp", 0)) * strength
		range_bonus += float(w.get("range", 0)) * strength
		element_max_bonus += int(w.get("element_max", 0))
		tower_max_bonus += int(w.get("tower_max", 0))


func max_element_level() -> int:
	return int(rules.get("elements", {}).get("max_level", 15)) + element_max_bonus


func max_tower_level() -> int:
	var tl: Dictionary = rules.get("tower_levels", {})
	return mini(int(tl.get("max", 25)) + tower_max_bonus, int(tl.get("max_bonus", 30)))


func max_wave() -> int:
	return waves.size()


# --- Elemente, Würfeln, Bauen ------------------------------------------------------

func research_cost(el: String) -> int:
	return int(rules.get("elements", {}).get("research_base", 20)) + int(elements.get(el, 0))


func can_research(el: String) -> bool:
	return setup_done and elements.has(el) and int(elements[el]) < max_element_level() and tomes >= research_cost(el)


func research(el: String) -> bool:
	if not can_research(el):
		return false
	tomes -= research_cost(el)
	elements[el] = int(elements[el]) + 1
	_refresh_hud()
	return true


func any_element() -> bool:
	return elements.values().any(func(v): return int(v) > 0)


## Startwurf (Zufallsmodi): 6 Tower der erforschten Elemente; wiederholbar, bis der erste Tower steht.
func roll_start() -> bool:
	if is_build_mode() or not can_reroll or not any_element():
		return false
	stash = YoutdRoll.with_count(self, int(rules.get("start", {}).get("tower_rolls", 6)))
	_note(tr("Gewürfelt: %s") % ", ".join(stash.map(func(id): return YoutdData.tower(id).get("name", id))))
	_refresh_hud()
	return true


func food_used() -> int:
	var n := 0
	for t in towers.values():
		if t is YoutdTower:
			n += YoutdData.food_cost(t.yid)
	return n


## Warum Tower id gerade nicht gebaut werden kann ("" = geht). from: Tower, der aufgewertet wird.
func build_reason(id: String, from: YoutdTower = null) -> String:
	var t := YoutdData.tower(id)
	if t.is_empty():
		return tr("unbekannt")
	var cost := int(t.cost) - (int(YoutdData.tower(from.yid).get("cost", 0)) if from != null else 0)
	if is_build_mode() or from != null:
		var el := str(t.element)
		var need := YoutdData.required_element_level(id)
		if int(elements.get(el, 0)) < need:
			return tr("%s %d nötig") % [YoutdData.element_name(el), need]
		var wave := YoutdData.required_wave(id, is_build_mode())
		if current_wave() < wave:
			return tr("ab Welle %d") % wave
	if gold < cost:
		return tr("zu wenig Gold")
	if tomes < YoutdData.tome_cost(id, is_build_mode()):
		return tr("zu wenig Wissensbücher")
	var food := YoutdData.food_cost(id) - (YoutdData.food_cost(from.yid) if from != null else 0)
	if food_used() + food > food_cap:
		return tr("zu wenig Food")
	return ""


## Tower, die man gerade bauen kann: im Baumodus alle der erforschten Elemente (Stufe 1 jeder Familie), sonst das Lager.
func buildable() -> Array:
	if not is_build_mode():
		return stash.duplicate()
	var out := []
	var all := YoutdData.towers()
	for id in all:
		var t: Dictionary = all[id]
		if int(t.tier) == 1 and int(elements.get(str(t.element), 0)) > 0:
			out.append(id)
	out.sort_custom(func(a, b): return int(all[a].cost) < int(all[b].cost))
	return out


func can_build(a: Vector2i) -> bool:
	return can_place(a)


## Tower stehen nur auf Bauflächen und versperren nichts (kein Mazing).
func can_place(a: Vector2i, any_zone := false) -> bool:
	if not setup_done or phase >= Phase.GAME_OVER:
		return false
	for c in Board3D.footprint(a):
		if not map.is_buildable(c) or occupied.has(c) or not (any_zone or map.can_build_for(c, acting)):
			return false
	return true


func _occupy(a: Vector2i, on: bool, _solid: bool) -> void:
	for c in Board3D.footprint(a):
		if on:
			occupied[c] = a
		else:
			occupied.erase(c)


func build_tower(id: String, a: Vector2i) -> bool:
	if not can_place(a) or build_reason(id) != "":
		return false
	if not is_build_mode() and not stash.has(id):
		return false
	var t := _new_tower(id, a)
	gold -= int(YoutdData.tower(id).cost)
	t.spent = int(YoutdData.tower(id).cost)
	tomes -= YoutdData.tome_cost(id, is_build_mode())
	if not is_build_mode():
		stash.erase(id)
	can_reroll = false
	if t.owner_player == local_player and not stash.has(build_id) and not is_build_mode():
		build_id = ""
	_refresh_hud()
	return true


func _new_tower(id: String, a: Vector2i) -> YoutdTower:
	var t := YoutdTower.new()
	t.game = self
	t.cell = a
	t.owner_player = acting
	board.add_child(t)
	t.set_youtd(id)
	if tower_exp_bonus > 0.0:
		t.add_exp(tower_exp_bonus)
	_register(t)
	run_stats.built(t, "build", current_wave())
	Sfx.play("place")
	return t


## Debug: Tower id ohne Kosten und Voraussetzungen setzen.
func debug_place(id: String, a: Vector2i) -> bool:
	if not can_place(a) or YoutdData.tower(id).is_empty():
		return false
	_new_tower(id, a)
	_refresh_hud()
	return true


# --- Items -----------------------------------------------------------------------

## Item i aus dem Lager in Tower t legen: Öle wirken sofort dauerhaft, normale Items belegen einen Platz.
func put_item(t: Tower, i: int) -> bool:
	if not t is YoutdTower or i < 0 or i >= item_stash.size():
		return false
	var yt := t as YoutdTower
	var id := str(item_stash[i])
	var it := YoutdData.item(id)
	match str(it.get("type", "")):
		"oil":
			yt.oils.append(id)
		"regular":
			if yt.items.size() >= yt.slots():
				return false
			yt.items.append(id)
		_:
			return false
	item_stash.remove_at(i)
	yt._update_mods()
	if picked_item == i:
		picked_item = -1
	_refresh_hud()
	return true


func take_item(t: YoutdTower, k: int) -> bool:
	if t == null or k < 0 or k >= t.items.size() or item_stash.size() >= int(rules.get("items", {}).get("stash_max", 40)):
		return false
	item_stash.append(t.items[k])
	t.items.remove_at(k)
	t._update_mods()
	_refresh_hud()
	return true


## Itemdrop beim Kill (ItemDropCalc): Chance 4,75 % je Wurf, Würfe nach Gegnergröße; 40 % Öl oder Verbrauch.
func _roll_items(e: YoutdEnemy, t: YoutdTower) -> void:
	var ir: Dictionary = rules.get("items", {})
	var rolls := int(rules.get("sizes", {}).get(e.creep_size, {}).get("items", 1))
	var chance := float(ir.get("drop_chance", 0.0475)) * maxf(0.0, 1.0 + (t.mod("MOD_ITEM_CHANCE_ON_KILL") if t != null else 0.0)) * maxf(0.0, e.item_chance)
	var quality := maxf(0.0, 1.0 + (t.mod("MOD_ITEM_QUALITY_ON_KILL") if t != null else 0.0)) * e.item_quality
	for r in rolls:
		if roll_rng.randf() >= chance:
			continue
		var id := YoutdRoll.item(self, e.level, quality)
		if id == "" or item_stash.size() >= int(ir.get("stash_max", 40)):
			continue
		item_stash.append(id)
		var it := YoutdData.item(id)
		_note(tr("Item gefunden: %s (%s)") % [str(it.get("name", id)), YoutdData.rarity_name(str(it.get("rarity", "")))])


# --- Wellen ----------------------------------------------------------------------

func _enter_build() -> void:
	phase = Phase.BUILD


func current_wave() -> int:
	return maxi(next_wave - 1, 0)


func is_wave_running() -> bool:
	return phase == Phase.WAVE


func _process(delta: float) -> void:
	if phase < Phase.GAME_OVER:
		play_time += delta / maxf(Engine.time_scale, 0.001)
	_update_hover()
	if not setup_done or phase >= Phase.GAME_OVER or mirror:
		return
	# Timer läuft nur, wenn gerade keine Welle mehr kommt oder lebt (wie im Original nach dem Ende der Welle)
	if alive.is_empty() and next_wave <= max_wave():
		var before := ceili(next_wave_in)
		next_wave_in -= delta
		if next_wave_in <= 0.0:
			_start_next_wave()
		elif ceili(next_wave_in) != before and youtd_panel != null:
			youtd_panel.refresh_timer()
	_process_wave(delta)


func _start_next_wave() -> void:
	if next_wave > max_wave():
		return
	var w: Dictionary = waves[next_wave - 1]
	wave_index = next_wave - 1
	spawners.append({"wave": w, "index": 0, "timer": 0.5})
	alive[int(w.level)] = (w.creeps as Array).size()
	next_wave += 1
	next_wave_in = float(rules.get("time", {}).get("between_waves", 15))
	phase = Phase.WAVE
	wave_live = {"gone_hp": 0.0, "gone_dealt": 0.0, "killed": 0, "leaked": 0}
	Sfx.play("wave_start")
	_refresh_hud()


func _process_wave(delta: float) -> void:
	for s in spawners.duplicate():
		s.timer -= delta
		while s.timer <= 0.0 and s.index < (s.wave.creeps as Array).size():
			_spawn_youtd(s.wave, str(s.wave.creeps[s.index]))
			s.index += 1
			s.timer += YoutdWaves.creep_delay(str(s.wave.size), wave_rng)
		if s.index >= (s.wave.creeps as Array).size():
			spawners.erase(s)


func _spawn_youtd(w: Dictionary, size_id: String) -> void:
	var e := YoutdEnemy.new()
	e.net_id = _next_enemy_id
	_next_enemy_id += 1
	board.add_child(e)
	var lp: Dictionary = lane_paths[0]
	e.setup_youtd(self, w, size_id, lp.air if size_id == "air" else lp.ground, 1.0)
	e.final_boss = int(w.level) == max_wave() and size_id.contains("boss")
	enemies.append(e)
	if e.boss:
		Sfx.play("boss")


func queued_hp() -> float:
	var total := 0.0
	for s in spawners:
		var w: Dictionary = s.wave
		for i in range(int(s.index), (w.creeps as Array).size()):
			total += float(w.hp) * float(rules.get("sizes", {}).get(str(w.creeps[i]), {}).get("hp", 1.0))
	return total


func idle_speed_factor() -> float:
	return 1.0


## Punkte für einen Gegner (Creep.get_score): Schadensanteil × (Welle/8 + 1) × Schwierigkeit × Modus × Länge × Größe.
func creep_score(e: YoutdEnemy) -> float:
	var m: Dictionary = (rules.get("modes", []) as Array)[mode_index]
	var l: Dictionary = (rules.get("lengths", []) as Array)[length_index]
	var settings := float(diff_rules().get("score", 1.0)) * float(m.get("score", 1.0)) * float(l.get("score", 1.0))
	var size := float(rules.get("sizes", {}).get(e.creep_size, {}).get("score", 1))
	return e.damage_done() * (int(e.level / 8) + 1) * settings * size


func on_enemy_killed(e: Enemy) -> void:
	enemies_killed += 1
	var ye := e as YoutdEnemy
	var t: YoutdTower = ye.last_tower if ye != null and is_instance_valid(ye.last_tower) else null
	if ye != null:
		var bounty := ye.bounty * maxf(0.0, 1.0 + (t.mod("MOD_BOUNTY_RECEIVED") if t != null else 0.0))
		earn_gold(bounty, e.last_hit_by)
		if t != null:
			t.add_exp(float(rules.get("sizes", {}).get(ye.creep_size, {}).get("xp", 1)) * maxf(0.0, ye.exp_factor))
		youtd_score += creep_score(ye)
		_roll_items(ye, t)
		_creep_gone(ye)
	_remove_enemy(e)
	_refresh_hud()


## Durchgelaufen: Portalschaden 2,5 % × Größenfaktor × (1 − Schadensanteil^5) (Boss ^4), Challenges nichts,
## der Endboss alles. Punkte gibt es anteilig für den Schaden.
func on_enemy_leaked(e: Enemy) -> void:
	var ye := e as YoutdEnemy
	if ye != null:
		var dmg := 0.0
		if int(ye.level) == max_wave() and ye.final_boss:
			dmg = 100.0
		elif not ye.creep_size.begins_with("challenge"):
			var p := 4.0 if ye.creep_size == "boss" else 5.0
			dmg = 2.5 * float(rules.get("sizes", {}).get(ye.creep_size, {}).get("portal", 1)) * (1.0 - pow(ye.damage_done(), p))
		youtd_score += creep_score(ye)
		leaks_per_wave[ye.level - 1] = int(leaks_per_wave.get(ye.level - 1, 0)) + 1
		if dmg > 0.0:
			portal -= dmg
			_note(tr("%s durchgelaufen: −%s %% Leben") % [ye.display_name(), TowerStats.num(dmg)])
			Sfx.play("leak")
		_creep_gone(ye)
	_remove_enemy(e)
	if portal <= 0.0 and not Session.debug_immortal:
		portal = 0.0
		_finish(Phase.GAME_OVER)
	_refresh_hud()


## Ein Gegner der Welle ist weg; ist die Welle leer: Einkommen, Bücher, neue Tower (Zufallsmodi).
func _creep_gone(e: YoutdEnemy) -> void:
	var lvl := e.level
	if not alive.has(lvl):
		return
	alive[lvl] = int(alive[lvl]) - 1
	if int(alive[lvl]) > 0:
		return
	alive.erase(lvl)
	_wave_finished(lvl)


func _wave_finished(lvl: int) -> void:
	waves_done = maxi(waves_done, lvl)
	var inc: Dictionary = rules.get("income", {})
	var upkeep := int(inc.get("base", 20)) + lvl * int(inc.get("per_level", 2))
	var interest := floori(minf(gold * float(inc.get("interest", 0.05)), float(inc.get("interest_max", 1000))))
	gold += upkeep + interest
	tomes += int(inc.get("tomes", 8))
	_note(tr("Welle %d geschafft: +%d Gold, +%d Zinsen, +%d Bücher") % [lvl, upkeep, interest, int(inc.get("tomes", 8))])
	if not is_build_mode():
		var rolled := YoutdRoll.per_wave(self)
		stash.append_array(rolled)
		if not rolled.is_empty():
			_note(tr("Neue Tower: %s") % ", ".join(rolled.map(func(id): return YoutdData.tower(id).get("name", id))))
	run_stats.wave_done(all_towers(), lvl, int(leaks_per_wave.get(lvl - 1, 0)), 0)
	if lvl >= max_wave() and alive.is_empty() and spawners.is_empty():
		_finish(Phase.VICTORY)
		return
	if alive.is_empty() and spawners.is_empty():
		phase = Phase.BUILD
		next_wave_in = float(rules.get("time", {}).get("between_waves", 15))


func _remove_enemy(e: Enemy) -> void:
	wave_live.gone_hp += e.max_hp
	wave_live.gone_dealt += clampf(e.max_hp - e.hp, 0.0, e.max_hp)
	if e.hp <= 0.0:
		wave_live.killed += 1
	else:
		wave_live.leaked += 1
	enemies.erase(e)
	e.queue_free()


func _finish(p: Phase) -> void:
	if phase >= Phase.GAME_OVER:
		return
	phase = p
	if not debug_used:
		xp_result = YoutdProgress.record(youtd_score, waves_done, p == Phase.VICTORY, enemies_killed)
	record_profile(p == Phase.VICTORY)
	Engine.time_scale = 1.0
	lives = ceili(portal)
	hud.show_game_over(p == Phase.VICTORY, mini(waves_done + 1, waves.size()), waves.size(), lives, enemies_killed, 0, null, {})
	var text := tr("Welle %d von %d · Portal %s %%\nGegner besiegt: %d\nPunkte: %d") % [waves_done, waves.size(), TowerStats.num(portal), enemies_killed, roundi(youtd_score)]
	if not xp_result.is_empty():
		text += "\n" + tr("Spieler-XP: +%s (Level %d)") % [TowerStats.num(float(xp_result.xp)), int(xp_result.level_after)]
		if int(xp_result.level_after) > int(xp_result.level_before):
			text += " · " + tr("Level aufgestiegen!")
	else:
		text += "\n" + tr("Debug-Menü benutzt: keine Spieler-XP")
	hud.game_over_stats.text = text
	_refresh_hud()


func profile_mode() -> String:
	return "youtd"


func profile_extra() -> Dictionary:
	return {"elements": elements.duplicate(), "mode": mode_id(), "score": roundi(youtd_score), "wisdom": wisdom.duplicate()}


func _note(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 5:
		log_lines.pop_front()


# --- Wegsuche: nur auf dem Weg ------------------------------------------------------

var _road_locked := false


## Gegner laufen nur über "_"-Felder: alle Bauflächen sind für die Wegsuche gesperrt (einmalig).
func _update_paths() -> void:
	if not _road_locked:
		_road_locked = true
		var cells: Array[Vector2i] = []
		for y in map.height:
			for x in map.width:
				var c := Vector2i(x, y)
				if map.is_buildable(c):
					cells.append(c)
		pathfinder.set_solid_cells(cells, true)
	super._update_paths()


# --- Tower-Optionen --------------------------------------------------------------

func tower_options(t: Tower) -> Array:
	if not t is YoutdTower or not is_instance_valid(t) or phase >= Phase.GAME_OVER or t.owner_player != acting:
		return []
	var yt := t as YoutdTower
	var opts := []
	if mode_id() != "totally_random":
		var up := YoutdData.upgrade_of(yt.yid)
		if up != "":
			var cost := int(YoutdData.tower(up).cost) - int(YoutdData.tower(yt.yid).cost)
			opts.append({"label": tr("Aufwerten: %s") % str(YoutdData.tower(up).get("name", up)), "action": "upgrade", "id": up, "tier": 0,
					"cost": cost, "reason": build_reason(up, yt)})
	for k in yt.items.size():
		var it := YoutdData.item(str(yt.items[k]))
		opts.append({"label": tr("Herausnehmen: %s") % str(it.get("name", "")), "action": "take_item", "id": str(yt.items[k]), "tier": k,
				"cost": 0, "reason": ""})
	opts.append({"label": tr("Verkaufen"), "action": "sell", "id": yt.yid, "tier": 0, "cost": 0, "reason": ""})
	return opts


func sell_value(t: YoutdTower) -> int:
	var m: Dictionary = (rules.get("modes", []) as Array)[mode_index]
	return floori(int(YoutdData.tower(t.yid).get("cost", 0)) * float(m.get("sell", 0.5)))


func _apply_option(t: Tower, o: Dictionary) -> bool:
	var yt := t as YoutdTower
	if yt == null or o.get("reason", "") != "":
		return false
	match str(o.action):
		"sell":
			gold += sell_value(yt)
			for id in yt.items:
				item_stash.append(id)
			run_stats.flush(yt)
			_unregister(yt)
			if yt == selected:
				_select(null)
			yt.queue_free()
			_refresh_hud()
			return true
		"take_item":
			return take_item(yt, int(o.tier))
		"upgrade":
			if gold < int(o.cost):
				return false
			gold -= int(o.cost)
			yt.spent += int(o.cost)
			run_stats.flush(yt)
			_unregister(yt)
			yt.set_youtd(str(o.id))
			_register(yt)
			run_stats.built(yt, "upgrade", current_wave())
			if yt == selected:
				yt.set_selected(true)
			_refresh_hud()
			return true
	return false


func _on_option_chosen(index: int) -> void:
	var opts := tower_options(selected)
	if index < 0 or index >= opts.size():
		return
	var o: Dictionary = opts[index]
	submit({"type": "option", "tower": tower_ref(selected), "index": index, "action": o.action, "id": o.id, "tier": o.tier})


# --- Eingabe -----------------------------------------------------------------------

## Tower zum Setzen wählen (Lager oder Baumenü), nochmal = abbrechen.
func choose_build(id: String) -> void:
	build_id = "" if build_id == id else id
	picked_item = -1
	_refresh_hud()


## Item aus dem Lager wählen: mit ausgewähltem Tower sofort einlegen, sonst danach einen Tower anklicken.
func pick_item(i: int) -> void:
	if selected is YoutdTower:
		submit({"type": "item_put", "tower": tower_ref(selected), "index": i})
		return
	picked_item = -1 if picked_item == i else i
	build_id = ""
	_refresh_hud()


func _update_hover() -> void:
	var c := NO_CELL
	if setup_done and phase < Phase.GAME_OVER and (build_id != "" or debug_tower != "") and not occupied.has(board.mouse_cell(camera_rig.camera)):
		c = board.mouse_anchor(camera_rig.camera)
	if c != board.hover_cell or board.hover_size != Board3D.TOWER_CELLS:
		board.hover_cell = c
		board.hover_size = Board3D.TOWER_CELLS
		board.hover_ok = can_place(c) and (debug_tower != "" or build_reason(build_id) == "")
		board.refresh_hover()


func _on_click(c: Vector2i, anchor: Vector2i, _add := false) -> void:
	var a: Vector2i = occupied.get(c, NO_CELL)
	if towers.has(a):
		if picked_item >= 0:
			submit({"type": "item_put", "tower": tower_ref(towers[a]), "index": picked_item})
			picked_item = -1
			return
		_select(towers[a])
	elif debug_tower != "":
		var id := debug_tower.trim_prefix(YoutdTower.PREFIX).get_slice(":", 0)
		if can_place(anchor):
			submit({"type": "debug_place", "id": id, "cell": anchor})
	elif build_id != "":
		if can_place(anchor) and build_reason(build_id) == "":
			submit({"type": "build", "id": build_id, "cell": anchor})
		else:
			Sfx.play("error")
	else:
		_select(null)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and setup_done:
		if event.keycode == KEY_N:
			submit({"type": "next_wave"})
			return
		if event.keycode == KEY_ESCAPE and (build_id != "" or picked_item >= 0):
			build_id = ""
			picked_item = -1
			_refresh_hud()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed \
			and (build_id != "" or picked_item >= 0) and not camera_rig.right_dragged:
		build_id = ""
		picked_item = -1
		_refresh_hud()
		return
	super._unhandled_input(event)


func _box_select(_r: Rect2, _add := false) -> void:
	pass


# --- Anzeige -----------------------------------------------------------------------

func _refresh_hud_local() -> void:
	lives = ceili(portal)
	hud.set_resources(mini(maxi(current_wave(), 1), maxi(waves.size(), 1)), maxi(waves.size(), 1), lives, gold, false)
	hud.set_waves(_upcoming_waves(4))
	hud.set_round_gems([], "")
	if build_id != "" and phase < Phase.GAME_OVER:
		var t := YoutdData.tower(build_id)
		hud.set_phase(str(t.get("name", "")), tr("Baufläche anklicken · Esc oder Rechtsklick = abbrechen"))
	elif picked_item >= 0 and picked_item < item_stash.size():
		hud.set_phase(str(YoutdData.item(str(item_stash[picked_item])).get("name", "")), tr("Tower anklicken, um das Item einzulegen · Esc = abbrechen"))
	else:
		match phase:
			Phase.BUILD:
				hud.set_phase(tr("Vorbereitung") if next_wave == 1 else tr("Pause"),
						tr("Welle %d kommt in %d s · N = sofort") % [next_wave, ceili(maxf(next_wave_in, 0.0))] if setup_done else "")
			Phase.WAVE:
				hud.set_phase(tr("Welle %d") % current_wave(), tr("%d Gegner unterwegs · N = nächste Welle schon jetzt") % enemies.size())
			Phase.GAME_OVER:
				hud.set_phase(tr("Verloren"), "")
			Phase.VICTORY:
				hud.set_phase(tr("Gewonnen"), tr("Alle Wellen geschafft!"))
	_refresh_selection()
	if youtd_panel != null:
		youtd_panel.refresh()


func _refresh_selection() -> void:
	if selected == null or not is_instance_valid(selected) or not selected is YoutdTower:
		hud.set_selection({})
		hud.set_options([])
		return
	var yt := selected as YoutdTower
	var body := tr("Level %d · Erfahrung %d") % [yt.level, floori(yt.xp)]
	var table := YoutdData.tower_exp_table()
	if yt.level + 1 < table.size() and yt.level < max_tower_level():
		body += tr(" (nächstes Level bei %d)") % int(table[yt.level + 1])
	body += "\n" + tr("Items: %d / %d") % [yt.items.size(), yt.slots()]
	for id in yt.items:
		body += "\n  · " + str(YoutdData.item(str(id)).get("name", id))
	if not yt.oils.is_empty():
		body += "\n" + tr("Öle: %s") % ", ".join(yt.oils.map(func(id): return YoutdData.item(str(id)).get("name", id)))
	body += "\n" + tr("Verkaufswert: %d Gold") % sell_value(yt)
	hud.set_selection({"title": yt.label(), "color": yt.color, "body": body, "used_in": null, "stats": yt.view()})
	hud.set_options(tower_options(yt).map(func(o): return _option_view(yt, o)))
	hud.set_options_enabled(true)


func _option_view(_t: Tower, o: Dictionary) -> Dictionary:
	match str(o.action):
		"sell":
			return {"label": o.label, "sub": tr("+%d Gold") % sell_value(_t as YoutdTower), "style": "normal",
					"tooltip": tr("Tower verkaufen, Items gehen ins Lager.")}
		"take_item":
			return {"label": o.label, "style": "normal", "tooltip": tr("Item zurück ins Lager legen.")}
	var sub := tr("%d Gold") % int(o.cost)
	if o.get("reason", "") != "":
		sub += " · " + str(o.reason)
	return {"label": o.label, "sub": sub, "style": "primary", "icon": "up", "disabled": o.get("reason", "") != "", "tooltip": o.label}


func _upcoming_waves(count: int) -> Array:
	var list := []
	if phase >= Phase.GAME_OVER or not setup_done:
		return list
	var first := maxi(current_wave(), 1) if phase == Phase.WAVE else next_wave
	for i in range(first - 1, mini(first - 1 + count, waves.size())):
		var w: Dictionary = waves[i]
		list.append({"number": i + 1, "type": str(w.type), "detail": wave_detail(w), "state": _wave_state(int(w.level))})
	return list


func _wave_state(lvl: int) -> String:
	if alive.has(lvl):
		return tr("läuft")
	if lvl == next_wave and alive.is_empty():
		return tr("in %d s") % ceili(maxf(next_wave_in, 0.0))
	return ""


## „15× Normal, 2× Champion · Lua · Ork · 1.234 LP · Schnell“
func wave_detail(w: Dictionary) -> String:
	var counts := {}
	for s in w.creeps:
		counts[s] = int(counts.get(s, 0)) + 1
	var parts := []
	for s in counts:
		parts.append("%d× %s" % [counts[s], YoutdData.size_name(str(s))])
	var hp := float(w.hp) * float(rules.get("sizes", {}).get(str(w.size), {}).get("hp", 1.0)) * (1.0 + YoutdWaves.hp_modifier(w.specials))
	var text := "%s · %s · %s · %s %s" % [", ".join(parts), YoutdData.armor_name(str(w.armor_type)), YoutdData.race_name(str(w.race)),
			_big(hp), tr("LP")]
	if not (w.specials as Array).is_empty():
		text += " · " + ", ".join((w.specials as Array).map(func(id): return YoutdData.special_name(id)))
	return text


static func _big(x: float) -> String:
	if x >= 1e6:
		return TowerStats.num(x / 1e6, 1) + " Mio."
	if x >= 1e4:
		return "%d k" % roundi(x / 1000.0)
	return str(roundi(x))
