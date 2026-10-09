extends Control
## Hauptmenü: links die Aktionen, rechts die Maps als Karten mit Vorschau.

var maps: Array = []
var selected := 0
var cards_box: HFlowContainer
var play_button: Button
var cards: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 72)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 56)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 56)
	margin.add_child(row)

	# Links: Titel und Aktionen
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 320
	left.add_theme_constant_override("separation", 12)
	row.add_child(left)
	var title := UiUtil.label("GemTD", left, 64)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	var sub := UiUtil.label("Gems setzen, kombinieren, Labyrinth bauen", left, 15)
	sub.add_theme_color_override("font_color", UiTheme.MUTED)
	left.add_child(_gap(28))
	play_button = _menu_button("Spielen", left, _play)
	play_button.custom_minimum_size.y = 58
	play_button.add_theme_font_size_override("font_size", 22)
	play_button.clip_text = true
	UiTheme.accent_button(play_button, UiTheme.GOLD, UiTheme.GOLD_DARK, Color(UiTheme.GOLD, 0.3))
	_menu_button("Map-Editor", left, _open_map_editor)
	_menu_button("Tower-Editor", left, _open_tower_editor)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(fill)
	var reload := _menu_button("Daten neu laden", left, _reload)
	reload.tooltip_text = "JSON-Dateien unter data/ neu einlesen"
	_menu_button("Beenden", left, func(): get_tree().quit())

	# Rechts: Map-Auswahl
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 16)
	row.add_child(right)
	UiUtil.label("Map wählen", right, 22)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	cards_box = HFlowContainer.new()
	cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_box.add_theme_constant_override("h_separation", 18)
	cards_box.add_theme_constant_override("v_separation", 18)
	scroll.add_child(cards_box)
	var hint := UiUtil.label("Doppelklick auf eine Map startet sie direkt.", right, 13)
	hint.add_theme_color_override("font_color", UiTheme.MUTED)
	_reload()


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _menu_button(text: String, parent: Node, on_pressed: Callable) -> Button:
	var b := UiUtil.button(text, parent, on_pressed)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = 48
	b.add_theme_font_size_override("font_size", 17)
	return b


func _reload() -> void:
	Database.reload()
	maps = Database.list_maps()
	selected = maxi(maps.map(func(m): return m.path).find(Session.map_path), 0)
	for c in cards_box.get_children():
		cards_box.remove_child(c)
		c.queue_free()
	cards.clear()
	for i in maps.size():
		cards.append(_map_card(i))
	_update_selection()


func _map_card(i: int) -> Button:
	var md := MapData.load_file(maps[i].path)
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(340, 0)
	b.focus_mode = Control.FOCUS_NONE
	cards_box.add_child(b)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_top = 12
	v.offset_right = -12
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 6)
	b.add_child(v)
	var preview := MapPreview.new()
	preview.custom_minimum_size = Vector2(316, 240)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.map = md
	v.add_child(preview)
	UiUtil.label(maps[i].name, v, 19).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info := ""
	if md != null:
		var waves: int = (Database.wave_sets.get(md.wave_set, {}).get("waves", []) as Array).size()
		info = "%d×%d · %d Wellen · %d Leben · %d Checkpoints" % [md.width, md.height, waves, md.lives, md.checkpoints.size()]
		var rocks := int(md.variance.get("random_rocks", 0))
		info += "\nWeg ohne Labyrinth: %d Felder" % preview.path_length()
		if rocks > 0:
			info += " · %d zufällige Steine" % rocks
	var l := UiUtil.label(info, v, 13)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", UiTheme.MUTED)
	b.custom_minimum_size.y = 240 + 24 + 6 * 2 + 26 + 40
	b.pressed.connect(func():
		selected = i
		_update_selection())
	b.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.double_click and e.button_index == MOUSE_BUTTON_LEFT:
			selected = i
			_play())
	return b


func _update_selection() -> void:
	for i in cards.size():
		var on := i == selected
		cards[i].set_pressed_no_signal(on)
		cards[i].add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL_2, UiTheme.GOLD if on else UiTheme.BORDER, 10, 2))
		cards[i].add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.PANEL_2, UiTheme.GOLD, 10, 2))
		cards[i].add_theme_stylebox_override("hover", UiTheme.box(Color("232836"), UiTheme.GOLD if on else UiTheme.BORDER_2, 10, 2))
	play_button.disabled = maps.is_empty()
	play_button.text = "Spielen: " + maps[selected].name if not maps.is_empty() else "Spielen"


func _play() -> void:
	if maps.is_empty():
		return
	Session.map_path = maps[selected].path
	Session.map_override = null
	Session.test_tower = ""
	Session.return_scene = Session.MAIN_MENU
	Session.goto(Session.GAME)


func _open_map_editor() -> void:
	Session.editor_map = null
	if not maps.is_empty():
		Session.editor_map = MapData.load_file(maps[selected].path)
	Session.goto(Session.MAP_EDITOR)


func _open_tower_editor() -> void:
	Session.goto(Session.TOWER_EDITOR)
