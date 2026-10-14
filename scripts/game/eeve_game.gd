extends "res://scripts/game/game.gd"
## eeveTD (Vorbild: eeve! TD v1.01 von geX). Regeln in data/eeve.json, Tower und Gegner unter
## data/towers/eeve_*.json und data/enemies/eeve_*.json (erzeugt von tools/wc3/eeve/eeve_daten.py).
##
## Anders als GemTD gibt es keine Bau- und Wahlrunden: man baut jederzeit Barrikaden (2 Gold, 1 Food) und wertet
## sie gegen Gold zu Tower der sechs Elemente auf. Elementpunkte schalten höhere Tower frei. Zwischen zwei Leveln
## läuft eine Pause (Phase BUILD), danach startet das nächste Level (Phase WAVE), bis alle Gegner weg sind.
## Zu Beginn jedes Levels gibt es Zinsen, Einkommen und Food, alle 7 Level einen Elementpunkt und Holz,
## nach jeder Golem-Challenge einen zufälligen Elementpunkt.
## Fallen (Elementstufe 4) baut man direkt auf den Weg, Gegner laufen darüber. Ab 3 Punkten in zwei Elementen
## wird eine Barrikade zum Dual-Grundturm und der kostenlos zum Dual-Tower dieser beiden Elemente.
## Tower und Fallen sind EeveTower (eeve_tower.gd) mit den Sonderfähigkeiten der Dual-Tower und Fallen.

const ELEMENT_IDS := ["nature", "earth", "fire", "storm", "magic", "water"]
const BARRICADE := "eeve_barricade"

var rules: Dictionary = {}
var difficulty := 2        ## Index in rules.difficulties
var field_type := 0        ## Index in rules.fields
var level_pause := 0.0     ## Sekunden bis zum nächsten Level (nur Phase BUILD)
var lumber := 0
var food_cap := 40
var points := 0            ## noch nicht verteilte Elementpunkte
var elements := {}         ## Element -> Stufe
var element_caps := {}     ## Element -> höchste Stufe (4 + zufällige Punkte)
var log_lines: Array = []  ## letzte Meldungen (Einkommen, Punkte) für die Seitenleiste
var clock := 0.0           ## Spielzeit in Wellen (für zeitlich begrenzte Effekte der Tower)
var placing_trap := ""     ## Falle, die gerade gesetzt wird (Klick aufs Feld), "" = keine
var eeve_panel: EevePanel


func _ready() -> void:
	rules = Database.eeve
	for id in ELEMENT_IDS:
		elements[id] = 0
		element_caps[id] = int(rules.get("point_max_normal", 4))
	points = int(rules.get("start_points", 1))
	food_cap = int(rules.get("start_food", 40))
	super._ready()
	if map == null:
		return
	lives = int(rules.get("lives", 50))
	gold = int(rules.get("start_gold", 200))
	level_pause = float(rules.get("first_pause", 45))
	_style_hud()
	_refresh_hud()


func _style_hud() -> void:
	hud.title_label.text = "eeveTD"
	hud.recipes_button.hide()
	hud.chance_value.get_parent().get_parent().hide()
	hud.pinned_panel.hide()
	hud.debug_button.hide()
	eeve_panel = EevePanel.new()
	eeve_panel.game = self
	hud.left_col.add_child(eeve_panel)
	hud.left_col.move_child(eeve_panel, 0)


# --- Einstellungen und Wellen ------------------------------------------------------

func _make_setup_panel() -> Control:
	var setup := EeveSetupPanel.new()
	setup.game = self
	return setup


## Felsen kommen erst mit den Einstellungen (Feldtyp), siehe _apply_setup.
func _apply_variance() -> void:
	pass


func diff_rules() -> Dictionary:
	var list: Array = rules.get("difficulties", [{}])
	return list[clampi(difficulty, 0, list.size() - 1)]


func _make_waves() -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = rng.randi()
	return EeveWaves.generate(rules, diff_rules(), r)


func _execute(cmd: Dictionary) -> bool:
	match str(cmd.get("type", "")):
		"setup":
			if setup_done or acting != 0:
				return false
			_apply_setup(int(cmd.get("difficulty", 2)), int(cmd.get("field", 0)))
			return true
		"build":
			return build_barricade(cmd.get("cell", NO_CELL))
		"trap":
			return build_trap(str(cmd.get("id", "")), cmd.get("cell", NO_CELL))
		"element":
			return add_element_point(str(cmd.get("element", "")))
		"start_level":
			if phase != Phase.BUILD or not setup_done:
				return false
			level_pause = 0.0
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
		"place", "replace_rocks", "remove_rocks", "take_back":
			return false
	return super._execute(cmd)


func _apply_setup(diff: int, field: int) -> void:
	difficulty = clampi(diff, 0, (rules.get("difficulties", []) as Array).size() - 1)
	field_type = clampi(field, 0, (rules.get("fields", []) as Array).size() - 1)
	waves = _make_waves()
	_place_field_rocks(int(rules.fields[field_type].get("rocks", 0)))
	level_pause = float(rules.get("first_pause", 45))
	setup_done = true
	hud.setup_debug(0, waves.size())
	_refresh_hud()


## Zufällige Felsen (Felsen- und WTF-Feld); sie meiden Wegpunkte und versperren nie den Weg.
func _place_field_rocks(count: int) -> void:
	var placed := 0
	for attempt in count * 30:
		if placed >= count:
			break
		var c := Vector2i(rng.randi_range(1, map.width - 3), rng.randi_range(1, map.height - 3))
		if can_place(c, true):
			rocks[c] = true
			_occupy(c, true, true)
			placed += 1
	_update_paths()
	board.refresh_rocks()


# --- Ablauf: Pause, Level, Pause … --------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if phase == Phase.BUILD and setup_done and not mirror:
		level_pause -= delta
		if level_pause <= 0.0:
			_start_level()
		elif ceili(level_pause) != ceili(level_pause + delta):
			_refresh_hud()


func _enter_build() -> void:
	phase = Phase.BUILD
	for p in players:
		p.stage = Phase.BUILD
	# Nach jeder Golem-Challenge (Level 11, 22, 33, 44) ein zufälliger Elementpunkt über die Grenze hinaus
	var done := wave_index  # gerade beendetes Level (1-basiert)
	if done > 0 and str(rules.get("challenges", {}).get(str(done), {}).get("enemy", "")) != "" and done % 11 == 0 and done <= 44:
		var el: String = ELEMENT_IDS[rng.randi() % ELEMENT_IDS.size()]
		if elements[el] < int(rules.get("point_max", 8)):
			element_caps[el] = mini(element_caps[el] + 1, int(rules.get("point_max", 8)))
			elements[el] += 1
			_note(tr("Challenge geschafft: +1 Stufe %s (zufällig)") % element_name(el))
			_update_auras()
	level_pause = float(diff_rules().get("pause", 20)) if wave_index > 0 else float(rules.get("first_pause", 45))
	_refresh_hud()


## Neues Level: Zinsen, Einkommen und Food, alle 7 Level ein Elementpunkt und Holz, dann die Welle.
func _start_level() -> void:
	if wave_index >= waves.size():
		_finish(Phase.VICTORY)
		return
	var level := wave_index + 1
	for p in players.size():
		var ps: PlayerState = players[p]
		var interest := floori(ps.gold * float(rules.get("interest", 0.05)))
		var income: int = level * int(rules.income.per_level) + int(rules.income.base)
		ps.gold += interest + income
		if p == local_player:
			_note(tr("Level %d: +%d Gold Zinsen, +%d Gold Einkommen") % [level, interest, income])
	var food_steps: Array = rules.get("food_per_level", [1, 2])
	food_cap += int(food_steps[level % food_steps.size()])
	if level % int(rules.get("point_every", 7)) == 0:
		points += 1
		lumber += 1
		_note(tr("Neuer Elementpunkt und 1 Holz!"))
	super._start_wave()


func _start_wave() -> void:
	# Das nächste Level startet nur über die Pause (_start_level), nicht über die Runden von GemTD
	_start_level()


func _process_wave(delta: float) -> void:
	clock += delta
	super._process_wave(delta)


func gold_income_factor(_wave: int) -> float:
	return 1.0


func _note(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 4:
		log_lines.pop_front()


func add_ring(p: Vector2, r: float, col: Color) -> void:
	var n := 24
	for i in n:
		var a := TAU * i / n
		var b := TAU * (i + 1) / n
		effects.add_beam(Board3D.to_3d(p + Vector2(cos(a), sin(a)) * r, 0.15), Board3D.to_3d(p + Vector2(cos(b), sin(b)) * r, 0.15), col)


## Brennende Gegner (Flammenrost) explodieren beim Tod und treffen alle Gegner im Umkreis.
func on_enemy_killed(e: Enemy) -> void:
	super.on_enemy_killed(e)
	var burn: Dictionary = e.get_meta("eeve_burn", {})
	if burn.is_empty() or float(burn.until) < clock or not is_instance_valid(burn.tower):
		return
	var t: Tower = burn.tower
	add_ring(e.pos, float(burn.radius), Color("ff7a30"))
	for other in enemies_in_radius(e.pos, float(burn.radius)):
		if other.flying:
			continue
		other.last_hit_by = t.owner_player
		t.total_damage += other.take_damage(float(burn.damage), "spells")
		if other.dead:
			t.kills += 1


func _finish(p: Phase) -> void:
	phase = p
	Engine.time_scale = 1.0
	hud.show_game_over(p == Phase.VICTORY, mini(wave_index + 1, waves.size()), waves.size(), lives, enemies_killed, path_length,
		null, run_summary())
	_refresh_hud()


# --- Gegner ------------------------------------------------------------------------

## Leben, Rüstung und Eigenschaften stehen schon in der Welle (eeve_waves.gd), dazu der Zauber-Faktor.
func _apply_enemy_difficulty(e: Enemy, g: Dictionary) -> void:
	e.spell_factor = float(diff_rules().get("spells", 1.0))
	var props: Array = g.get("props", [])
	if props.has("immune"):
		e.spell_factor = 0.0
	if props.has("reduct"):
		e.hit_reduction = float(EeveWaves.prop(rules, "reduct").get("reduction", 15))


func queued_hp() -> float:
	var total := 0.0
	for g in spawn_queue:
		total += _group_hp(g)
	return total


# --- Elemente ----------------------------------------------------------------------

func element_name(id: String) -> String:
	for e in rules.get("elements", []):
		if e.id == id:
			return tr(str(e.name))
	return id


func element_color(id: String) -> Color:
	for e in rules.get("elements", []):
		if e.id == id:
			return Color(str(e.color))
	return UiTheme.TEXT


func can_add_point(el: String) -> bool:
	return points > 0 and elements.has(el) and elements[el] < element_caps[el] and phase < Phase.GAME_OVER


func add_element_point(el: String) -> bool:
	if not can_add_point(el):
		return false
	points -= 1
	elements[el] += 1
	_update_auras()
	_refresh_hud()
	return true


## Auren wie in GemTD, dazu der Elementbonus: +10 % Grundschaden je Stufe im Element des Towers
## (Dual-Tower: Mittel ihrer beiden Elemente) und der Buff der Feuerbeeren, solange er wirkt.
func _update_auras() -> void:
	super._update_auras()
	var per := float(rules.get("element_bonus_per_level", 0.1))
	for t in all_towers():
		var e: Dictionary = t.def.get("eeve", {})
		var els: Array = e.get("elements", [e.get("element", "")])
		var lvl := 0.0
		for el in els:
			lvl += elements.get(el, 0)
		lvl /= maxf(els.size(), 1)
		if lvl <= 0.0:
			continue
		var aura: String = t.damage_source
		t.damage_bonus += per * lvl
		var names := " + ".join(els.map(func(el): return element_name(el)))
		t.damage_source = tr("%s Stufe %s") % [names, str(snappedf(lvl, 0.5))] + (" + " + aura if aura != "" else "")
	for src in all_towers():
		if not src is EeveTower or src.rage_left <= 0.0:
			continue
		var ab: Dictionary = src.ability("rage")
		for t in all_towers():
			if t.pos.distance_to(src.pos) <= float(ab.radius):
				t.damage_bonus += float(ab.bonus)
				t.damage_source += " + " + src.label()


# --- Bauen und Aufwerten -------------------------------------------------------------

func food_used() -> int:
	return own_towers().size()


func can_build(a: Vector2i) -> bool:
	if not (setup_done and phase < Phase.GAME_OVER and gold >= barricade_cost() and food_used() < food_cap and can_place(a)):
		return false
	# nicht auf Fallen bauen, sonst läuft dort nie ein Gegner darüber
	return Board3D.footprint(a).all(func(c): return not trap_cells.has(c))


func barricade_cost() -> int:
	return int(Database.towers.get(BARRICADE, {}).get("eeve", {}).get("cost", 2))


func build_barricade(a: Vector2i) -> bool:
	if not can_build(a):
		return false
	gold -= barricade_cost()
	var t := EeveTower.new()
	t.owner_player = acting
	board.add_child(t)
	t.setup(self, a, BARRICADE, 0)
	t.set_meta("spent", barricade_cost())
	_register(t)
	_update_paths()
	_update_auras()
	board.hover_ok = can_build(a)
	board.refresh_hover()
	_refresh_hud()
	return true


# --- Fallen ---------------------------------------------------------------------------

## Fallen aller Elemente in der Reihenfolge der Elemente.
func trap_ids() -> Array:
	var out := []
	for el in ELEMENT_IDS:
		for id in Database.towers:
			var e: Dictionary = Database.towers[id].get("eeve", {})
			if e.get("trap", false) and str(e.get("element", "")) == el:
				out.append(id)
	return out


## Warum die Falle gerade nicht gebaut werden kann ("" = geht).
func trap_reason(id: String) -> String:
	var e: Dictionary = Database.towers.get(id, {}).get("eeve", {})
	if elements.get(str(e.get("element", "")), 0) < int(e.get("level", 4)):
		return tr("%s %d nötig") % [element_name(str(e.element)), int(e.level)]
	if gold < int(e.get("cost", 0)):
		return tr("zu wenig Gold")
	if lumber < int(e.get("lumber", 0)):
		return tr("zu wenig Holz")
	if food_used() >= food_cap:
		return tr("kein Food frei")
	return ""


## Fallen liegen auf begehbaren Feldern (3×3), nicht unter Barrikaden, Felsen oder anderen Fallen.
func can_build_trap(id: String, a: Vector2i) -> bool:
	if not setup_done or phase >= Phase.GAME_OVER or a == NO_CELL or trap_reason(id) != "":
		return false
	for c in Board3D.footprint(a, Board3D.TRAP_CELLS):
		if not map.is_walkable(c) or occupied.has(c) or trap_cells.has(c):
			return false
	return true


func build_trap(id: String, a: Vector2i) -> bool:
	if not can_build_trap(id, a):
		return false
	var e: Dictionary = Database.towers[id].eeve
	gold -= int(e.cost)
	lumber -= int(e.get("lumber", 0))
	var t := EeveTower.new()
	t.owner_player = acting
	board.add_child(t)
	t.setup(self, a, id, 0)
	t.set_meta("spent", int(e.cost))
	_register(t)
	_update_auras()
	if acting == local_player:
		placing_trap = ""
		board.hover_cell = NO_CELL
	_refresh_hud()
	return true


## Falle zum Setzen auswählen (Knopf in der Seitenleiste), nochmal drücken bricht ab.
func start_trap_placement(id: String) -> void:
	_select(null)
	placing_trap = "" if placing_trap == id or trap_reason(id) != "" else id
	board.hover_cell = NO_CELL
	_refresh_hud()


func _select_rocks(list: Array, t: Tower = null) -> void:
	placing_trap = ""
	super._select_rocks(list, t)


# --- Dual-Tower --------------------------------------------------------------------------

## Elementpaare mit mindestens 3 Punkten in beiden Elementen.
func dual_pair_ready(els: Array) -> bool:
	return els.size() == 2 and els.all(func(el): return elements.get(el, 0) >= dual_level())


func dual_level() -> int:
	return int(Database.towers.get("eeve_dual_element_base_tower", {}).get("eeve", {}).get("level", 3))


func any_dual_ready() -> bool:
	var ready := []
	for el in ELEMENT_IDS:
		if elements.get(el, 0) >= dual_level():
			ready.append(el)
	return ready.size() >= 2


## Felsen gehören zum Feld und lassen sich nicht entfernen.
func can_remove_rock(_c: Vector2i) -> bool:
	return false


func tower_options(t: Tower) -> Array:
	if t == null or not is_instance_valid(t) or phase >= Phase.GAME_OVER or t.owner_player != acting:
		return []
	var opts := []
	for id in t.def.get("eeve", {}).get("next", []):
		var nd: Dictionary = Database.towers.get(id, {}).get("eeve", {})
		if nd.is_empty():
			continue
		var cost := int(nd.get("cost", 0))
		var wood := int(nd.get("lumber", 0))
		var el := str(nd.get("element", ""))
		var need := int(nd.get("level", 1))
		var reason := ""
		# Dual-Grundturm zeigt nur die Dual-Tower, deren beide Elemente auf Stufe 3 sind
		if nd.has("elements") and not dual_pair_ready(nd.elements):
			continue
		if nd.get("dual_base", false) and not any_dual_ready():
			reason = tr("zwei Elemente auf Stufe %d nötig") % need
		elif not nd.get("dual_base", false) and el != "" and elements.get(el, 0) < need:
			reason = tr("%s %d nötig") % [element_name(el), need]
		elif gold < cost:
			reason = tr("zu wenig Gold")
		elif lumber < wood:
			reason = tr("zu wenig Holz")
		opts.append({"label": Database.tower_label(id, 0), "action": "eeve_upgrade", "id": id, "tier": 0, "consume": [],
				"cost": cost, "lumber": wood, "element": el, "level": need, "reason": reason})
	opts.append({"label": tr("Abreißen"), "action": "scrap", "id": t.tower_id, "tier": t.tier, "consume": [], "cost": 0, "reason": ""})
	return opts


func _apply_option(t: Tower, o: Dictionary) -> bool:
	if t == null or o.get("reason", "") != "":
		return false
	if o.action == "scrap":
		# Abreißen gibt kein Gold zurück (wie im Original)
		_unregister(t)
		if t == selected:
			_select(null)
		t.queue_free()
		_update_paths()
		_update_auras()
		_refresh_hud()
		return true
	if o.action != "eeve_upgrade" or gold < int(o.cost) or lumber < int(o.get("lumber", 0)):
		return false
	gold -= int(o.cost)
	lumber -= int(o.get("lumber", 0))
	t.set_meta("spent", int(t.get_meta("spent", 0)) + int(o.cost))
	_unregister(t)
	t.set_tower(o.id, 0)
	_register(t)
	if t == selected:
		t.set_selected(true)
	_update_paths()
	_update_auras()
	_refresh_hud()
	return true


# --- Eingabe -----------------------------------------------------------------------

func _update_hover() -> void:
	if placing_trap != "":
		var a := board.mouse_anchor(camera_rig.camera, Board3D.TRAP_CELLS)
		if a != board.hover_cell or board.hover_size != Board3D.TRAP_CELLS:
			board.hover_cell = a
			board.hover_size = Board3D.TRAP_CELLS
			board.hover_ok = can_build_trap(placing_trap, a)
			board.refresh_hover()
		return
	var c := NO_CELL
	if setup_done and phase < Phase.GAME_OVER and not occupied.has(board.mouse_cell(camera_rig.camera)):
		c = board.mouse_anchor(camera_rig.camera)
	if c != board.hover_cell or board.hover_size != Board3D.TOWER_CELLS:
		board.hover_cell = c
		board.hover_size = Board3D.TOWER_CELLS
		board.hover_ok = can_build(c)
		board.refresh_hover()


func _on_click(c: Vector2i, anchor: Vector2i, _add := false) -> void:
	if placing_trap != "":
		var at := board.mouse_anchor(camera_rig.camera, Board3D.TRAP_CELLS)
		if can_build_trap(placing_trap, at):
			submit({"type": "trap", "id": placing_trap, "cell": at})
		return
	var a: Vector2i = occupied.get(c, NO_CELL)
	var trap: Tower = traps.get(trap_cells.get(c, NO_CELL), null)
	if towers.has(a):
		_select(towers[a])
	elif rocks.has(a):
		_select(null, a)
	elif trap != null:
		_select(trap)
	elif can_build(anchor):
		submit({"type": "build", "cell": anchor})
	else:
		_select(null)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_N and phase == Phase.BUILD:
			submit({"type": "start_level"})
			return
		if event.keycode == KEY_Z:
			return
		if event.keycode == KEY_ESCAPE and placing_trap != "":
			placing_trap = ""
			_refresh_hud()
			return
	super._unhandled_input(event)


func _box_select(_r: Rect2, _add := false) -> void:
	pass


func _on_option_chosen(index: int) -> void:
	if not selected_rocks.is_empty():
		return
	var opts := tower_options(selected)
	if index < 0 or index >= opts.size():
		return
	var o: Dictionary = opts[index]
	submit({"type": "option", "tower": tower_ref(selected), "index": index, "action": o.action, "id": o.id, "tier": o.tier})


# --- Anzeige -----------------------------------------------------------------------

func _refresh_hud_local() -> void:
	hud.set_resources(mini(wave_index + 1, waves.size()), waves.size(), lives, gold, false)
	hud.set_path_length(path_length, 0)
	hud.set_waves(_upcoming_waves(4))
	hud.set_round_gems([], "")
	if placing_trap != "" and phase < Phase.GAME_OVER:
		hud.set_phase(Database.tower_label(placing_trap, 0), tr("Falle auf den Weg setzen · Esc oder Rechtsklick = abbrechen"))
		_refresh_selection()
		if eeve_panel != null:
			eeve_panel.refresh()
		return
	match phase:
		Phase.BUILD:
			var next := wave_index + 1
			var title := tr("Pause") if wave_index > 0 else tr("Aufbau")
			hud.set_phase(title, tr("Level %d startet gleich · N = sofort starten · freies Feld anklicken = Barrikade") % next)
		Phase.WAVE:
			var w: Dictionary = waves[wave_index] if wave_index < waves.size() else {}
			hud.set_phase(tr("Level %d") % (wave_index + 1), tr("noch %d Gegner") % (enemies.size() + spawn_queue.size()) + _props_text(w))
		Phase.GAME_OVER:
			hud.set_phase(tr("Verloren"), "")
		Phase.VICTORY:
			hud.set_phase(tr("Gewonnen"), tr("Alle Level geschafft!"))
	_refresh_selection()
	if eeve_panel != null:
		eeve_panel.refresh()


func _props_text(w: Dictionary) -> String:
	var props: Array = w.get("eeve", {}).get("props", [])
	if props.is_empty():
		return ""
	return " · " + ", ".join(props.map(func(p): return tr(str(EeveWaves.prop(rules, p).get("name", p)))))


func _refresh_selection() -> void:
	if not selected_rocks.is_empty():
		hud.set_selection({"title": tr("Fels"), "color": Color("6d6a63"), "used_in": null,
				"body": tr("Felsen gehören zum Feld und lassen sich nicht entfernen.")})
		hud.set_options([])
		return
	if selected == null or not is_instance_valid(selected):
		hud.set_selection({})
		hud.set_options([])
		return
	var view := TowerStats.view(selected)
	var e: Dictionary = selected.def.get("eeve", {})
	if e.get("barricade", false):
		view.subtitle = tr("Barrikade · zum Grundturm eines Elements aufwerten")
	elif e.get("trap", false):
		view.subtitle = tr("Falle · %s · Gegner laufen darüber, trifft nur Bodengegner") % element_name(str(e.get("element", "")))
	elif e.get("dual_base", false):
		view.subtitle = tr("Dual-Grundturm · kostenlos zum Dual-Tower zweier Elemente mit Stufe %d aufwerten") % dual_level()
	elif e.has("elements"):
		view.subtitle = tr("Dual-Tower · %s") % " + ".join((e.elements as Array).map(func(el): return element_name(el))) + " · " + TowerStats.targets_text(selected.target_mode())
	else:
		view.subtitle = tr("%s · Elementstufe %d") % [element_name(str(e.get("element", ""))), int(e.get("level", 1))] + " · " + TowerStats.targets_text(selected.target_mode())
	var body := ""
	for todo in e.get("todo", []):
		body += tr("Kommt noch: ") + tr(str(todo)) + "\n"
	body += tr("Ausgegeben: %d Gold") % int(selected.get_meta("spent", 0))
	hud.set_selection({"title": selected.label(), "color": selected.color, "body": body.strip_edges(), "used_in": null, "stats": view})
	hud.set_options(tower_options(selected).map(func(o): return _option_view(selected, o)))
	hud.set_options_enabled(true)


func _option_view(t: Tower, o: Dictionary) -> Dictionary:
	if o.action == "scrap":
		return {"label": o.label, "style": "normal", "tooltip": tr("Tower oder Barrikade entfernen. Gold gibt es nicht zurück, das Food wird frei.")}
	var sub := tr("%d Gold") % int(o.cost) if int(o.cost) > 0 else tr("kostenlos")
	if int(o.get("lumber", 0)) > 0:
		sub += " + " + tr("%d Holz") % int(o.lumber)
	if o.get("reason", "") != "":
		sub += " · " + str(o.reason)
	var v := {"label": o.label, "sub": sub, "style": "normal", "icon": "up", "disabled": o.get("reason", "") != "",
			"tooltip": o.label}
	v.preview_range = Tower.ring_radius(Database.tower_tier(o.id, 0), false)
	var nd: Dictionary = Database.towers.get(o.id, {}).get("eeve", {})
	if nd.has("elements"):
		v.label = "%s (%s)" % [o.label, " + ".join((nd.elements as Array).map(func(el): return element_name(el)))]
	v.diff = TowerStats.diff(t, o.id, 0)
	return v


## Nächste Level für die linke Spalte, mit Typ, Leben und Eigenschaften.
func _upcoming_waves(count: int) -> Array:
	var list := []
	if phase >= Phase.GAME_OVER:
		return list
	for i in range(wave_index, mini(wave_index + count, waves.size())):
		var w: Dictionary = waves[i]
		var g: Dictionary = w.groups[0]
		var d: Dictionary = Database.enemies.get(str(g.enemy), {})
		var detail := tr("%d× %s · %d LP · Rüstung %d") % [int(g.count), tr(str(d.get("name", "?"))), roundi(float(g.hp)), roundi(float(g.armor))]
		detail += _props_text(w)
		var state := ""
		if i == wave_index:
			state = tr("läuft") if phase == Phase.WAVE else tr("in %d s") % ceili(maxf(level_pause, 0.0))
		list.append({"number": i + 1, "type": str(w.type), "detail": detail, "state": state})
	return list
