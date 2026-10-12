extends Control
## Hauptmenü: links die Aktionen, rechts die Maps als Karten mit Vorschau.

var maps: Array = []
var selected := 0
var cards_box: HFlowContainer
var play_button: Button
var cards: Array[Button] = []
var settings: Control
var lobby: LobbyPanel
var loader: LoadPanel
var net_button: Button
var history_button: Button
var history: RunHistoryPanel
var maps_view: Control


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
	var title := UiTheme.title(UiUtil.label("GemTD", left, 60))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	var sub := UiUtil.label("Gems setzen, kombinieren, Labyrinth bauen", left, 15)
	sub.add_theme_color_override("font_color", UiTheme.MUTED)
	left.add_child(_gap(28))
	play_button = _menu_button("Spielen", left, _play)
	play_button.custom_minimum_size.y = 58
	play_button.add_theme_font_size_override("font_size", 22)
	play_button.clip_text = true
	UiTheme.accent_button(play_button, UiTheme.GOLD, UiTheme.GOLD_DARK, Color(UiTheme.GOLD, 0.3))
	_difficulty_row(left)
	_mode_row(left)
	_menu_button("Spiel laden", left, func(): loader.show())
	history_button = _menu_button("Run-History", left, func(): show_history(history_button.button_pressed))
	history_button.toggle_mode = true
	history_button.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
	history_button.add_theme_stylebox_override("hover_pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
	history_button.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
	history_button.add_theme_color_override("font_hover_pressed_color", UiTheme.GOLD_DARK)
	net_button = _menu_button("Mehrspieler", left, func(): lobby.show())
	_menu_button("Map-Editor", left, _open_map_editor)
	_menu_button("Tower-Editor", left, _open_tower_editor)
	_menu_button("Einstellungen", left, _open_settings)
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
	maps_view = right
	# Run-History ersetzt rechts die Map-Auswahl, solange der Knopf gedrückt ist
	history = RunHistoryPanel.new()
	history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history.visible = false
	history.replay_requested.connect(_replay)
	row.add_child(history)
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
	_build_settings()
	lobby = LobbyPanel.new()
	add_child(lobby)
	lobby.hide()
	lobby.start_requested.connect(_start_session)
	if not maps.is_empty():
		lobby.selected_map = maps[selected].name
	loader = LoadPanel.new()
	add_child(loader)
	loader.hide()
	loader.load_requested.connect(_load_save)
	Net.players_changed.connect(_update_net_button)
	Net.connection_changed.connect(_update_net_button)
	_update_net_button()
	# Zurück aus einer Sitzung: Lobby gleich zeigen, dort geht es mit „Mitspielen“ weiter
	if Net.is_active():
		lobby.show()
	if Session.reopen_settings:
		Session.reopen_settings = false
		settings.show()


## Einstellungen: Sprache. Ein Wechsel lädt das Menü neu, damit alle Texte neu gebaut werden.
func _build_settings() -> void:
	settings = Control.new()
	settings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(settings)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(28.0))
	panel.custom_minimum_size.x = 460
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	UiTheme.title(UiUtil.label("Einstellungen", v, 26))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)

	# Sprache: Wechsel lädt das Menü neu, damit alle Texte neu gebaut werden
	var lang := _settings_option(tr("Sprache") + ("" if Loc.language == "en" else " / Language"), grid)
	for l in Loc.LANGUAGES:
		lang.add_item(l[1])
	lang.select(maxi(Loc.LANGUAGES.map(func(l): return l[0]).find(Loc.language), 0))
	lang.item_selected.connect(func(i):
		Loc.set_language(Loc.LANGUAGES[i][0])
		Session.reopen_settings = true
		get_tree().reload_current_scene())

	var mode := _settings_option(tr("Anzeige"), grid)
	mode.add_item(tr("Fenster"))
	mode.add_item(tr("Vollbild"))
	mode.select(1 if Display.fullscreen else 0)

	var res := _settings_option(tr("Auflösung"), grid)
	for r in Display.RESOLUTIONS:
		res.add_item("%d × %d" % [r.x, r.y])
	res.select(maxi(Display.RESOLUTIONS.find(Display.resolution), 0))
	res.disabled = Display.fullscreen
	res.tooltip_text = tr("Im Vollbild gilt die Auflösung des Bildschirms.") if Display.fullscreen else ""
	res.item_selected.connect(func(i): Display.set_resolution(Display.RESOLUTIONS[i]))
	mode.item_selected.connect(func(i):
		Display.set_fullscreen(i == 1)
		res.disabled = i == 1
		res.tooltip_text = tr("Im Vollbild gilt die Auflösung des Bildschirms.") if i == 1 else "")
	var hint := UiUtil.wrap_label("Änderungen gelten sofort und bleiben gespeichert.", v, 400)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", UiTheme.MUTED)
	v.add_child(_gap(4))
	var done := UiUtil.button("Fertig", v, func(): settings.hide())
	done.custom_minimum_size.y = 46
	UiTheme.accent_button(done, UiTheme.GOLD, UiTheme.GOLD_DARK, Color(UiTheme.GOLD, 0.3))
	settings.hide()


func _settings_option(text: String, grid: GridContainer) -> OptionButton:
	var l := UiUtil.label(text, grid, 15)
	l.custom_minimum_size.x = 150
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.custom_minimum_size.y = 40
	o.add_theme_font_size_override("font_size", 16)
	grid.add_child(o)
	return o


func _open_settings() -> void:
	settings.show()


func _unhandled_input(event: InputEvent) -> void:
	if settings.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		settings.hide()
	elif history.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		show_history(false)


func show_history(on: bool) -> void:
	history_button.set_pressed_no_signal(on)
	if on:
		history.reload()
	history.visible = on
	maps_view.visible = not on


## „Map nochmal spielen“: gleiche Map, Schwierigkeit und Wertung wie der Lauf.
func _replay(run: Dictionary) -> void:
	for i in maps.size():
		if maps[i].path == str(run.get("map_path", "")) or maps[i].name == str(run.get("map", "")):
			selected = i
			break
	Session.difficulty = clampi(int(run.get("difficulty", Session.difficulty)), 0, Session.DIFFICULTIES.size() - 1)
	Session.score_mode = bool(run.get("score_mode", false))
	_play()


## Schwierigkeit: drei Umschalter, genau einer aktiv.
func _difficulty_row(parent: Node) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	parent.add_child(h)
	var group := ButtonGroup.new()
	for i in Session.DIFFICULTIES.size():
		var d: Dictionary = Session.DIFFICULTIES[i]
		var idx := i
		var b := UiUtil.button(str(d.name), h, func(): Session.difficulty = idx)
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 36
		b.tooltip_text = tr("Gegner: Leben und Rüstung ×%s") % str(d.factor)
		b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
		b.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
		b.set_pressed_no_signal(i == Session.difficulty)


## Wertung: Leben (wie bisher) oder Punkte.
func _mode_row(parent: Node) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	parent.add_child(h)
	var group := ButtonGroup.new()
	var modes := [
		["Leben", false, "Wer durchkommt, kostet Leben. Bei 0 ist das Spiel verloren."],
		["Punkte", true, "Kills geben Punkte, späte Wellen mehr als frühe. Wer durchkommt, kostet die Hälfte seines Werts. Gespielt wird bis zur letzten Welle."],
	]
	for m in modes:
		var on: bool = m[1]
		var b := UiUtil.button(str(m[0]), h, func(): Session.score_mode = on)
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 36
		b.tooltip_text = str(m[2])
		b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
		b.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
		b.set_pressed_no_signal(on == Session.score_mode)


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
		info = tr("%d×%d · %d Wellen · %d Leben · %d Checkpoints") % [md.width, md.height, waves, md.lives, md.checkpoints.size()]
		var rocks := int(md.variance.get("random_rocks", 0))
		info += "\n" + tr("Weg ohne Labyrinth: %d Felder") % preview.path_length()
		if rocks > 0:
			info += " · " + tr("%d zufällige Steine") % rocks
	var l := UiUtil.label(info, v, 12)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 316
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", UiTheme.MUTED)
	b.custom_minimum_size.y = 240 + 24 + 6 * 2 + 26 + 58
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
		cards[i].add_theme_stylebox_override("hover", UiTheme.box(Color("1f1036"), UiTheme.GOLD if on else UiTheme.BORDER_2, 10, 2))
	if lobby != null and not maps.is_empty():
		lobby.selected_map = maps[selected].name
	play_button.disabled = maps.is_empty()
	play_button.text = tr("Spielen: %s") % tr(maps[selected].name) if not maps.is_empty() else tr("Spielen")


func _play() -> void:
	if maps.is_empty():
		return
	Session.map_path = maps[selected].path
	Session.map_override = null
	Session.load_state = {}
	Session.save_id = ""
	Session.test_tower = ""
	Session.return_scene = Session.MAIN_MENU
	Session.goto(Session.GAME)


func _update_net_button() -> void:
	net_button.text = tr("Mehrspieler · %d verbunden") % (Net.players.size() + 1) if Net.is_active() else tr("Mehrspieler")


## Host: Sitzung starten, eine neue auf der gewählten Map.
func _start_session() -> void:
	var m := MapData.load_file(maps[selected].path) if not maps.is_empty() else null
	if Net.session.has("coop"):
		Net.start_coop({})
	elif lobby.coop_mode and m != null and not Net.session.get("loaded", false):
		Net.start_coop(m.to_dict())
	elif m != null or not Net.session.get("map", {}).is_empty():
		Net.start_session(m.to_dict() if m != null else {})


## Spielstand laden: Einzelspiel geht direkt weiter, eine Mehrspieler-Sitzung wird gehostet.
func _load_save(data: Dictionary) -> void:
	if data.get("kind", "") in ["multi", "coop"]:
		if Net.host() == OK:
			Net.load_session(data)
		lobby.show()
		return
	var st: Dictionary = data.get("state", {})
	Session.load_state = st
	Session.save_id = str(data.get("id", ""))
	Session.map_override = MapData.from_dict(st.get("map", {}))
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
