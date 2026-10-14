class_name MaulSetup
extends ColorRect
## Vor Level 1: Schwierigkeit, Modus und Filiale wählen („Filiale eröffnen“).
## Die 11 Standard-Filialen sind wählbar, die Profi-Filialen stehen gesperrt darunter.

const CARD_WIDTH := 236.0

var game: MaulGame
var _shop := ""
var _difficulty := 1
var _mode := "group"
var _cards := {}
var _diff_buttons: Array = []
var _mode_buttons: Array = []
var _detail: Label
var _open: Button


func _ready() -> void:
	color = Color(UiTheme.BG, 0.82)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_difficulty = int(MaulData.rules().get("default_difficulty", 1))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(20))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	UiTheme.title(UiUtil.label("Filiale eröffnen", box), 28)

	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 30)
	box.add_child(opts)
	var diff_box := VBoxContainer.new()
	opts.add_child(diff_box)
	UiTheme.caption("Schwierigkeit", diff_box)
	var diff_row := HBoxContainer.new()
	diff_box.add_child(diff_row)
	var diffs: Array = MaulData.rules().get("difficulties", [])
	for i in diffs.size():
		var d: Dictionary = diffs[i]
		var b := UiUtil.button(str(d.name), diff_row, _set_difficulty.bind(i))
		b.tooltip_text = tr("%d Leben, Gegner-Leben ×%s") % [int(d.lives), TowerStats.num(float(d.factor), 2)]
		_diff_buttons.append(b)
	var mode_box := VBoxContainer.new()
	opts.add_child(mode_box)
	UiTheme.caption("Modus", mode_box)
	var mode_row := HBoxContainer.new()
	mode_box.add_child(mode_row)
	for m in [["group", "Gruppe", "Alle Gegner eines Levels kommen auf einmal."], ["line", "Linie", "Die Gegner kommen nacheinander, alle 0,8 s einer pro Spawn."]]:
		var id: String = m[0]
		var b := UiUtil.button(m[1], mode_row, _set_mode.bind(id))
		b.tooltip_text = m[2]
		_mode_buttons.append([b, id])

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	var pro := []
	for s in MaulData.shops():
		if str(s.kind) != "standard":
			pro.append(str(s.name))
			continue
		_add_card(grid, str(s.id), str(s.name), str(s.get("text", "")), Color.from_string(str(s.color), UiTheme.GOLD), str(s.bonus))
	_add_card(grid, "random", tr("Zufall"), tr("Eine der 11 Standard-Filialen"), UiTheme.PURPLE_LIGHT, "")
	var locked := UiUtil.wrap_label(tr("Profi-Filialen (gesperrt, ab 25 XP): %s") % ", ".join(pro), box, CARD_WIDTH * 4 + 30)
	locked.add_theme_color_override("font_color", UiTheme.MUTED)
	locked.add_theme_font_size_override("font_size", 13)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	box.add_child(bottom)
	_detail = UiUtil.label("", bottom, 14)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiUtil.button("Zurück", bottom, func(): Session.goto(Session.MAIN_MENU))
	_open = UiUtil.button("Filiale eröffnen", bottom, _start)
	UiTheme.accent_button(_open, UiTheme.GOLD, UiTheme.BAR)
	_refresh()


func _add_card(grid: GridContainer, id: String, name: String, text: String, col: Color, bonus: String) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(CARD_WIDTH, 112)
	b.toggle_mode = true
	b.pressed.connect(_set_shop.bind(id))
	grid.add_child(b)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 8)
	b.add_child(m)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	m.add_child(v)
	var title := UiUtil.label(name.to_upper(), v, 14)
	title.add_theme_font_override("font", UiTheme.font(true))
	title.add_theme_color_override("font_color", col)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var short := text.replace("Reichweite:", tr("Reichweite")).replace("  ", " ")
	var info := UiUtil.label(short, v, 11)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.custom_minimum_size.x = CARD_WIDTH - 20
	info.max_lines_visible = 5
	info.add_theme_color_override("font_color", UiTheme.DIM)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bonus != "":
		var tag := UiUtil.label(tr("Rabatt statt Bonus") if bonus == "rebate" else tr("Bonus-Upgrade"), v, 11)
		tag.add_theme_color_override("font_color", UiTheme.CYAN)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards[id] = [b, title, info]


func _set_difficulty(i: int) -> void:
	_difficulty = i
	_refresh()


func _set_mode(id: String) -> void:
	_mode = id
	_refresh()


func _set_shop(id: String) -> void:
	_shop = id
	_refresh()


func _refresh() -> void:
	for i in _diff_buttons.size():
		_diff_buttons[i].set_pressed_no_signal(i == _difficulty)
		_diff_buttons[i].toggle_mode = true
		_diff_buttons[i].set_pressed_no_signal(i == _difficulty)
	for e in _mode_buttons:
		e[0].toggle_mode = true
		e[0].set_pressed_no_signal(e[1] == _mode)
	for id in _cards:
		var on: bool = id == _shop
		_cards[id][0].set_pressed_no_signal(on)
		# Ausgewählt: Cyan-Fläche, darauf dunkle Schrift
		_cards[id][1].add_theme_color_override("font_color", UiTheme.BAR if on else _card_color(id))
		_cards[id][2].add_theme_color_override("font_color", UiTheme.BAR if on else UiTheme.DIM)
	_open.disabled = _shop == ""
	if _shop == "":
		_detail.text = tr("Wähle eine Filiale.")
	elif _shop == "random":
		_detail.text = tr("Zufall: eine der 11 Standard-Filialen")
	else:
		var list := MaulData.buyable(_shop)
		var s := MaulData.shop(_shop)
		_detail.text = tr("%s: %d Tower von %s bis %s Gold") % [str(s.name), list.size(), MaulHud.big(int(list[0].cost)), MaulHud.big(int(list[-1].cost))] if not list.is_empty() else str(s.name)


func _card_color(id: String) -> Color:
	if id == "random":
		return UiTheme.PURPLE_LIGHT
	return Color.from_string(str(MaulData.shop(id).get("color", "#ff4fd8")), UiTheme.GOLD)


func _start() -> void:
	var id := _shop
	if id == "random":
		var std := MaulData.shops().filter(func(s): return str(s.kind) == "standard")
		id = str(std[randi() % std.size()].id)
	game.start_game(id, _difficulty, _mode)
