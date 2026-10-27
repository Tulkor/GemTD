class_name RgSetupPanel
extends Control
## Einstellungen vor dem ersten Level von Randgruppen TD: Rasse (11 Karten mit ihren 7 Towern) und Schwierigkeit
## (= Leben, data/randgruppen.json). „Los geht's“ schickt den Befehl setup an rg_game.gd; das Fenster schließt sich,
## sobald die eigene Wahl beim Host angekommen ist (im Koop wählt jeder seine Rasse, nur der Host die Schwierigkeit).

var game  # rg_game.gd
var race_id := ""
var difficulty := 2
var _race_text: Label
var _diff_text: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var races: Array = game.rules.get("races", [])
	race_id = str(Session.rg_choice.get("race", races[0].id if not races.is_empty() else ""))
	difficulty = game.difficulty
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(24.0))
	panel.custom_minimum_size.x = 820
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	UiTheme.title(UiUtil.label("Randgruppen TD", v, 26))
	var info := UiUtil.wrap_label(tr("Die Randgruppen der Stadt verteidigen die Hochburg der Toleranz gegen die Spießer: %d Level, Tower frei in deine Zone bauen, die Gegner laufen hindurch.") % game.waves.size(), v, 770)
	info.add_theme_color_override("font_color", UiTheme.MUTED)

	UiTheme.caption("Rasse", v)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	var group := ButtonGroup.new()
	for r in races:
		var id := str(r.id)
		var b := _toggle(str(r.name), grid, group, id == race_id, func():
			race_id = id
			_update_text())
		b.tooltip_text = tr(str(r.hint))
		# Rassenfarben sind für dunkle Flächen gedacht, auf dem Plakatpapier abgedunkelt
		b.add_theme_color_override("font_color", Color(str(r.color)).darkened(0.45))
	_race_text = UiUtil.wrap_label("", v, 770)

	UiTheme.caption("Schwierigkeit", v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	group = ButtonGroup.new()
	var diffs: Array = game.rules.get("difficulties", [])
	for i in diffs.size():
		var idx := i
		var b := _toggle(str(diffs[i].name), h, group, i == difficulty, func():
			difficulty = idx
			_update_text())
		b.custom_minimum_size.x = 140
		b.disabled = game.local_player != 0
	_diff_text = UiUtil.wrap_label("", v, 770)
	_diff_text.add_theme_color_override("font_color", UiTheme.DIM)
	_update_text()

	var go := UiUtil.button("Los geht's", v, func(): game.submit({"type": "setup", "race": race_id, "difficulty": difficulty}))
	go.custom_minimum_size.y = 50
	go.add_theme_font_size_override("font_size", 20)
	UiTheme.accent_button(go, UiTheme.GOLD, UiTheme.GOLD_DARK)


func _process(_delta: float) -> void:
	if game.setup_done or game.rp(game.local_player).chosen:
		queue_free()


func _update_text() -> void:
	var r: Dictionary = game.race(race_id)
	var names: Array = r.get("towers", []).map(func(id): return Database.tower_label(id, 0))
	_race_text.text = tr(str(r.get("hint", ""))) + "\n" + tr("Tower: ") + ", ".join(names)
	var d: Dictionary = game.rules.difficulties[difficulty]
	_diff_text.text = tr("%d Leben für alle zusammen. Start mit %d Gold (550 minus 500 für den Baumeister).") % [int(d.lives), game.start_gold()]
	if game.local_player != 0:
		_diff_text.text = tr("Die Schwierigkeit wählt der Host.") + " " + _diff_text.text


func _toggle(text: String, parent: Node, group: ButtonGroup, on: bool, pressed: Callable) -> Button:
	var b := UiUtil.button(text, parent, pressed)
	b.toggle_mode = true
	b.button_group = group
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(190, 38)
	b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
	b.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
	b.set_pressed_no_signal(on)
	return b
