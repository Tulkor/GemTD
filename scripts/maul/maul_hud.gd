class_name MaulHud
extends CanvasLayer
## Oberfläche von Shopping Maul (nach dem Mockup): Leiste oben, Übersichtskarte oben links,
## Laden der eigenen Filiale rechts, ausgewählter Tower unten links, Meldung oben in der Mitte,
## dazu Filialwahl vor Level 1 und der Endbildschirm. Liest den Zustand aus MaulGame,
## Aktionen gehen als Befehle über game.submit().

const SHOP_WIDTH := 300.0
const MAP_SIZE := 200.0

var game: MaulGame
var root: Control

var _level: Label
var _next: Label
var _timer: Label
var _gold: Label
var _value: Label
var _lives: Label
var _diff: Label
var _start_button: Button
var _speed_buttons: Array = []

var _shop_title: Label
var _shop_list: VBoxContainer
var _shop_buttons: Array = []
var _reveal_button: Button
var _shop_panel: PanelContainer

var _sel_panel: PanelContainer
var _sel_box: VBoxContainer

var _banner: Label
var _minimap: MaulMinimap
var _setup: MaulSetup
var _game_over: Control
var _menu: Control


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)
	_build_top_bar()
	_build_shop()
	_build_selection()
	_build_minimap()
	_banner = UiUtil.label("", root, 20)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 64
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.add_theme_font_override("font", UiTheme.font(true))
	_banner.add_theme_color_override("font_color", UiTheme.GOLD)
	_banner.add_theme_color_override("font_shadow_color", UiTheme.CYAN)
	_banner.add_theme_constant_override("shadow_offset_x", 2)
	_banner.add_theme_constant_override("shadow_offset_y", 2)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- Leiste oben ------------------------------------------------------------------

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	var style := UiTheme.box(UiTheme.BAR, Color.TRANSPARENT, 0, 0, 10)
	style.border_color = UiTheme.GOLD
	style.border_width_bottom = 3
	bar.add_theme_stylebox_override("panel", style)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	bar.add_child(row)
	_level = _stat(row, "Level")
	_next = _stat(row, "Nächstes")
	_timer = _stat(row, "Start in")
	_gold = _stat(row, "Gold")
	_gold.add_theme_color_override("font_color", UiTheme.COIN)
	_value = _stat(row, "Towerwert")
	_lives = _stat(row, "Leben")
	_diff = _stat(row, "Diff")
	_diff.tooltip_text = "Selbstanpassung: wer wenig durchlässt, bekommt stärkere Gegner."
	_diff.mouse_filter = Control.MOUSE_FILTER_PASS
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_start_button = UiUtil.button("Jetzt starten", row, func(): game.submit({"type": "start_now"}))
	UiTheme.accent_button(_start_button, UiTheme.GOLD, UiTheme.BAR)
	for f in [1.0, 2.0, 4.0]:
		var b := UiUtil.button("%d×" % int(f), row, func(): game.set_speed(f))
		b.toggle_mode = true
		b.custom_minimum_size.x = 40
		_speed_buttons.append(b)
	UiUtil.button("Menü", row, func(): _menu.visible = not _menu.visible)
	_build_menu()


func _stat(parent: Node, caption: String) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	parent.add_child(box)
	UiTheme.caption(caption, box)
	var l := UiUtil.label("–", box, 17)
	l.add_theme_font_override("font", UiTheme.font(true))
	return l


func _build_menu() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(16))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.visible = false
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	UiTheme.title(UiUtil.label("Menü", box), 22)
	var resume := UiUtil.button("Weiterspielen", box, func(): panel.hide())
	UiTheme.accent_button(resume, UiTheme.GOLD, UiTheme.BAR)
	UiUtil.button("Neu starten", box, func(): Session.goto(Session.MAUL))
	UiUtil.button("Hauptmenü", box, func(): Session.goto(Session.MAIN_MENU))
	_menu = panel


# --- Laden rechts -----------------------------------------------------------------

func _build_shop() -> void:
	_shop_panel = PanelContainer.new()
	_shop_panel.add_theme_stylebox_override("panel", UiTheme.panel(12))
	_shop_panel.anchor_left = 1.0
	_shop_panel.anchor_right = 1.0
	_shop_panel.offset_left = -SHOP_WIDTH - 16
	_shop_panel.offset_right = -16
	_shop_panel.offset_top = 84
	_shop_panel.visible = false
	root.add_child(_shop_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_shop_panel.add_child(box)
	_shop_title = UiTheme.title(UiUtil.label("", box), 20)
	UiTheme.caption("Tower kaufen (Taste)", box)
	_shop_list = VBoxContainer.new()
	_shop_list.add_theme_constant_override("separation", 3)
	box.add_child(_shop_list)
	_reveal_button = UiUtil.button("Aufdecken", box, func(): game.submit({"type": "reveal"}))
	_reveal_button.tooltip_text = "Macht 30 s lang alle Unsichtbaren angreifbar, danach 60 s Pause."
	var hint := UiUtil.wrap_label("Grau = zu wenig Gold. Klick oder Taste wählt, dann ins eigene Gebiet setzen. Umschalt hält die Wahl, Rechtsklick bricht ab.", box, SHOP_WIDTH - 24)
	hint.add_theme_color_override("font_color", UiTheme.MUTED)
	hint.add_theme_font_size_override("font_size", 12)


## Ladenliste für die gewählte Filiale aufbauen.
func build_shop() -> void:
	for c in _shop_list.get_children():
		c.queue_free()
	_shop_buttons.clear()
	var shop := MaulData.shop(game.shop_of())
	_shop_title.text = str(shop.get("name", ""))
	_shop_title.add_theme_color_override("font_color", Color.from_string(str(shop.get("color", "#ff4fd8")), UiTheme.GOLD))
	var list := MaulData.buyable(game.shop_of())
	for i in list.size():
		var t: Dictionary = list[i]
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(SHOP_WIDTH - 24, 30)
		b.tooltip_text = tower_text(t)
		b.toggle_mode = true
		var id := str(t.id)
		b.pressed.connect(func(): game.choose_build(id))
		var row := HBoxContainer.new()
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 6
		row.offset_right = -6
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		var key := UiUtil.label(key_label(i), row, 13)
		key.custom_minimum_size.x = 18
		key.add_theme_font_override("font", UiTheme.font(true))
		key.add_theme_color_override("font_color", UiTheme.CYAN)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name := UiUtil.label(str(t.name) + ("  ✈" if str(t.targets) == "air" else ""), row, 13)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cost := UiUtil.label(MaulHud.big(int(t.cost)), row, 13)
		cost.add_theme_color_override("font_color", UiTheme.COIN)
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shop_list.add_child(b)
		_shop_buttons.append([b, int(t.cost), id, cost])
	_reveal_button.visible = not MaulData.rules().detect_shops.has(game.shop_of())
	_shop_panel.visible = true
	refresh_shop()


## Beschriftung der Bau-Taste i (Tastaturbelegung des Systems, sonst QWERTZ).
static func key_label(i: int) -> String:
	if i >= MaulGame.BUILD_KEYS.size():
		return ""
	var key: int = MaulGame.BUILD_KEYS[i]
	var label := KEY_NONE if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_label_from_physical(key)
	if label == KEY_NONE:
		return "QWERASDFYXC"[i]
	return OS.get_keycode_string(label)


func refresh_shop() -> void:
	if game == null:
		return
	var gold: int = game.players[game.local_player].gold
	for entry in _shop_buttons:
		var b: Button = entry[0]
		b.set_pressed_no_signal(game.build_id == entry[2])
		var poor: bool = entry[1] > gold
		b.modulate = Color(1, 1, 1, 0.45) if poor else Color.WHITE
		(entry[3] as Label).add_theme_color_override("font_color", UiTheme.MISSING if poor else UiTheme.COIN)
	if _reveal_button.visible:
		var me: MaulGame.Player = game.players[game.local_player]
		var wait := me.reveal_ready - game.game_time
		var active := me.reveal_until - game.game_time
		_reveal_button.disabled = wait > 0.0
		if active > 0.0:
			_reveal_button.text = tr("Aufgedeckt: %d s") % ceili(active)
		elif wait > 0.0:
			_reveal_button.text = tr("Aufdecken in %d s") % ceili(wait)
		else:
			_reveal_button.text = tr("Aufdecken")


# --- Auswahl unten links ------------------------------------------------------------

func _build_selection() -> void:
	_sel_panel = PanelContainer.new()
	_sel_panel.add_theme_stylebox_override("panel", UiTheme.panel(12))
	_sel_panel.anchor_top = 1.0
	_sel_panel.anchor_bottom = 1.0
	_sel_panel.offset_left = 16
	_sel_panel.offset_bottom = -16
	_sel_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sel_panel.custom_minimum_size.x = 340
	_sel_panel.visible = false
	root.add_child(_sel_panel)
	_sel_box = VBoxContainer.new()
	_sel_box.add_theme_constant_override("separation", 6)
	_sel_panel.add_child(_sel_box)


func refresh_selection() -> void:
	for c in _sel_box.get_children():
		_sel_box.remove_child(c)
		c.queue_free()
	var t: MaulTower = game.selected
	_sel_panel.visible = t != null
	if t == null:
		return
	var d := t.def
	UiTheme.title(UiUtil.label(str(d.get("name", "")), _sel_box), 18)
	var sub := UiUtil.label("%s · %s" % [damage_type_name(str(d.get("damage_type", ""))), targets_name(str(d.get("targets", "both")))], _sel_box, 13)
	sub.add_theme_color_override("font_color", UiTheme.MUTED)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	_sel_box.add_child(grid)
	var dmg: Array = d.get("damage", [0, 0])
	var cd := float(d.get("cooldown", 0))
	var bonus := 1.0 + t.damage_bonus
	for pair in [["Schaden", TowerStats.dmg_text(float(dmg[0]) * bonus, float(dmg[1]) * bonus) if cd > 0.0 else "–"],
			["Tempo", (TowerStats.num(cd, 2) + " s") if cd > 0.0 else "–"],
			["Reichweite", TowerStats.num(float(d.get("range", 0)))],
			["DPS", "%d" % roundi(dps(d) * bonus)]]:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		grid.add_child(box)
		UiTheme.caption(pair[0], box)
		var v := UiUtil.label(pair[1], box, 15)
		v.add_theme_font_override("font", UiTheme.font(true))
	for line in ability_lines(d):
		UiUtil.wrap_label(line, _sel_box, 316).add_theme_font_size_override("font_size", 13)
	var done := UiUtil.label(tr("%s Schaden · %d Kills") % [MaulHud.big(roundi(t.total_damage)), t.kills], _sel_box, 13)
	done.add_theme_color_override("font_color", UiTheme.MUTED)
	if t.owner_player != game.local_player:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_sel_box.add_child(row)
	var sell := UiUtil.button(tr("Verkaufen +%s") % MaulHud.big(game.sell_value(t)), row, func(): game.submit({"type": "sell", "cell": t.cell}))
	sell.tooltip_text = "75 % des Towerwerts zurück (Taste Entf)"
	for up in d.get("upgrades_to", []):
		var ud := MaulData.tower(str(up))
		if ud.is_empty():
			continue
		var b := UiUtil.button(tr("%s +%s") % [str(ud.name), MaulHud.big(int(ud.cost))], row, func(): game.submit({"type": "upgrade", "cell": t.cell, "to": str(up)}))
		UiTheme.accent_button(b, UiTheme.GOLD, UiTheme.BAR)
		b.tooltip_text = tower_text(ud)
		b.disabled = int(ud.cost) > game.players[game.local_player].gold


# --- Texte zu Towern -----------------------------------------------------------------

static func _t(s: String) -> String:
	return str(TranslationServer.translate(s))


static func damage_type_name(dt: String) -> String:
	match dt:
		"normal":
			return _t("Normal")
		"pierce":
			return _t("Durchbohrend")
		"siege":
			return _t("Belagerung")
		"magic":
			return _t("Magisch")
		"chaos":
			return _t("Chaos")
		"hero":
			return _t("Held")
		"spells":
			return _t("Zauber")
	return dt


static func targets_name(t: String) -> String:
	match t:
		"air":
			return _t("nur Luft")
		"ground":
			return _t("nur Boden")
	return _t("Luft+Boden")


## Schaden pro Sekunde ohne Fähigkeiten (Mittelwert × Ziele / Abklingzeit).
static func dps(d: Dictionary) -> float:
	var cd := float(d.get("cooldown", 0))
	if cd <= 0.0:
		return 0.0
	var dmg: Array = d.get("damage", [0, 0])
	var n := 1
	for ab in d.get("abilities", []):
		if ab.type == "multishot":
			n = int(ab.targets)
	return (float(dmg[0]) + float(dmg[1])) / 2.0 * n / cd


static func _n(v: float) -> String:
	return TowerStats.num(v)


static func ability_lines(d: Dictionary) -> Array:
	var out := []
	for ab in d.get("abilities", []):
		match str(ab.type):
			"crit":
				out.append(_t("%d %% Chance auf %s× Schaden") % [roundi(float(ab.chance) * 100), _n(float(ab.multiplier))])
			"stun":
				if ab.has("chance"):
					out.append(_t("%d %% Chance auf %s s Betäubung") % [roundi(float(ab.chance) * 100), _n(float(ab.duration))])
				else:
					out.append(_t("Betäubt %s s") % _n(float(ab.duration)))
			"slow":
				out.append(_t("Verlangsamt um %d %% für %s s") % [roundi(float(ab.factor) * 100), _n(float(ab.duration))])
			"slow_aura":
				out.append(_t("Aura: verlangsamt um %d %% (Radius %s)") % [roundi(float(ab.factor) * 100), _n(float(ab.radius))])
			"burn_aura":
				out.append(_t("Aura: %s Schaden/s (Radius %s)") % [_n(float(ab.dps)), _n(float(ab.radius))])
			"poison":
				out.append(_t("Gift: %s Schaden/s für %s s") % [_n(float(ab.dps)), _n(float(ab.duration))])
			"splash":
				out.append(_t("Flächenschaden %d %% (Radius %s)") % [roundi(float(ab.factor) * 100), _n(float(ab.radius))])
			"multishot":
				out.append(_t("Trifft %d Ziele") % int(ab.targets))
			"detect":
				out.append(_t("Enttarnt Unsichtbare (Radius %s)") % _n(float(ab.radius)))
			"nova_spell":
				out.append(_t("Donnerschlag: %s Schaden (Radius %s), alle %s s") % [MaulHud.big(roundi(float(ab.damage))), _n(float(ab.radius)), _n(float(ab.cooldown))])
			"chain_spell":
				out.append(_t("Kettenblitz: %s Schaden, %d Ziele, alle %s s") % [MaulHud.big(roundi(float(ab.damage))), int(ab.get("targets", 3)), _n(float(ab.cooldown))])
			"wave_spell":
				out.append(_t("Schockwelle: %s Schaden, alle %s s") % [MaulHud.big(roundi(float(ab.damage))), _n(float(ab.cooldown))])
	return out


## Tooltip für Ladenknöpfe und Upgrades.
static func tower_text(d: Dictionary) -> String:
	var dmg: Array = d.get("damage", [0, 0])
	var cd := float(d.get("cooldown", 0))
	var lines := [str(d.get("name", "")) + "  ·  " + MaulHud.big(int(d.get("cost", 0))) + " " + _t("Gold")]
	lines.append(damage_type_name(str(d.get("damage_type", ""))) + " · " + targets_name(str(d.get("targets", "both"))))
	if cd > 0.0:
		lines.append(_t("Schaden %s alle %s s, Reichweite %s, DPS %d") % [TowerStats.dmg_text(float(dmg[0]), float(dmg[1])), TowerStats.num(cd, 2), TowerStats.num(float(d.get("range", 0))), roundi(dps(d))])
	else:
		lines.append(_t("Greift nicht selbst an, Reichweite %s") % TowerStats.num(float(d.get("range", 0))))
	lines.append_array(ability_lines(d))
	if not d.get("upgrades_to", []).is_empty():
		var names := []
		for up in d.upgrades_to:
			names.append(str(MaulData.tower(str(up)).get("name", up)))
		lines.append(_t("Upgrade: %s") % ", ".join(names))
	return "\n".join(lines)


## 1234567 → 1.234.567
static func big(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if v < 0 else "") + s + out


# --- Übersichtskarte -----------------------------------------------------------------

func _build_minimap() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(6))
	panel.offset_left = 16
	panel.offset_top = 84
	root.add_child(panel)
	_minimap = MaulMinimap.new()
	_minimap.custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	_minimap.game = game
	panel.add_child(_minimap)


# --- Aktualisieren -------------------------------------------------------------------

func refresh() -> void:
	if game == null or _level == null:
		return
	var regular := int(MaulData.rules().regular_levels)
	var total := game.levels.size()
	_level.text = "%d / %d" % [game.level, regular if game.level <= regular else total]
	var upcoming := game.level + 1 if game.phase == MaulGame.Phase.COUNTDOWN or game.phase == MaulGame.Phase.SETUP else game.level
	var lv := game.level_def(upcoming)
	var parts := [MaulGame.kind_name(str(lv.get("kind", "")))] if not lv.is_empty() else ["–"]
	if game.specials_on():
		for s in lv.get("specials", []):
			parts.append(MaulGame.special_name(s))
	_next.text = ", ".join(parts)
	(_next.get_parent().get_child(0) as Label).text = _t("Nächstes").to_upper() if game.phase != MaulGame.Phase.WAVE else _t("Läuft").to_upper()
	_gold.text = MaulHud.big(game.players[game.local_player].gold)
	_value.text = MaulHud.big(game.tower_value())
	_lives.text = "%d / %d" % [game.lives, game.max_lives]
	_lives.add_theme_color_override("font_color", UiTheme.HAVE if game.lives * 3 > game.max_lives else UiTheme.MISSING)
	_diff.text = "%d %%" % roundi(game.je * 100.0)
	refresh_live()
	refresh_shop()
	if game.selected != null:
		refresh_selection()


## Countdown, Gegnerzahl und Tempo (mehrmals pro Sekunde).
func refresh_live() -> void:
	if game == null or _timer == null:
		return
	var cap := _timer.get_parent().get_child(0) as Label
	if game.phase == MaulGame.Phase.COUNTDOWN:
		cap.text = _t("Start in").to_upper()
		var s := maxi(ceili(game.countdown), 0)
		_timer.text = "%d:%02d" % [s / 60, s % 60]
	elif game.phase == MaulGame.Phase.WAVE:
		cap.text = _t("Gegner").to_upper()
		_timer.text = str(game.enemies.size() + game.spawn_queue.reduce(func(a, q): return a + int(q[1]), 0))
	else:
		_timer.text = "–"
	_start_button.visible = game.phase == MaulGame.Phase.COUNTDOWN
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(is_equal_approx(Engine.time_scale, [1.0, 2.0, 4.0][i]))
	if _reveal_button.visible:
		refresh_shop()
	_minimap.queue_redraw()


func refresh_message() -> void:
	_banner.text = game.message


# --- Filialwahl und Ende -------------------------------------------------------------

func show_setup() -> void:
	_setup = MaulSetup.new()
	_setup.game = game
	root.add_child(_setup)


func hide_setup() -> void:
	if _setup != null:
		_setup.queue_free()
		_setup = null


func show_game_over(victory: bool) -> void:
	if _game_over != null:
		_game_over.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.BG, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	_game_over = dim
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(22))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	dim.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := UiTheme.title(UiUtil.label("Gewonnen!" if victory else "Totalschaden!", box), 30)
	if not victory:
		title.add_theme_color_override("font_color", UiTheme.MISSING)
	var d := MaulData.difficulty(game.difficulty)
	var stats := tr("Schwierigkeit: %s\nLevel %d von %d\nLeben übrig: %d\nGegner besiegt: %d, durchgelassen: %d\nSelbstanpassung: %d–%d %%\nSpielzeit: %d min") % [
		tr(str(d.get("name", ""))), game.level, game.levels.size(), game.lives, game.enemies_killed, game.enemies_leaked,
		roundi(game.je_min * 100), roundi(game.je_max * 100), roundi(game.play_time / 60.0)]
	UiUtil.label(stats, box, 15)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var again := UiUtil.button("Nochmal", row, func(): Session.goto(Session.MAUL))
	UiTheme.accent_button(again, UiTheme.GOLD, UiTheme.BAR)
	UiUtil.button("Hauptmenü", row, func(): Session.goto(Session.MAIN_MENU))
