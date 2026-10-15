extends Control
## Hauptmenü als Hub: zuerst Einzelspieler oder Mehrspieler, darunter Laden, Run-History, Editoren, Einstellungen.
## Einzelspieler: TD-Modus (data/modes.json) und Map wählen, dann Spielen.
## Mehrspieler: Lobby (lobby_panel.gd), dort stimmen alle über den Modus ab.

var maps: Array = []   ## alle Maps (Database.list_maps())
var shown_maps: Array = []   ## Maps des gewählten Modus, in der Einzelspieler-Auswahl
var selected := 0   ## Index in shown_maps
var cards_box: HFlowContainer
var play_button: Button
var cards: Array[Button] = []
var mode_cards: Array[ModeCard] = []
var settings: Control
var ui_scale_slider: HSlider
var lobby: LobbyPanel
var loader: LoadPanel
var net_tile: Button
var net_tile_text: Label
var history: RunHistoryPanel
var map_caption: Label
var map_scroll: ScrollContainer
var no_map_hint: Label
var single_page: Control
var history_page: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	_build_hub()
	single_page = _page()
	_build_single(single_page.get_meta("box"))
	history_page = _page()
	var hv: VBoxContainer = history_page.get_meta("box")
	_back_button(hv.get_child(0), func(): show_page(""))
	history = RunHistoryPanel.new()
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history.replay_requested.connect(_replay)
	hv.add_child(history)
	_reload()
	_build_settings()
	lobby = LobbyPanel.new()
	lobby.maps = maps
	add_child(lobby)
	lobby.hide()
	lobby.start_requested.connect(_start_session)
	loader = LoadPanel.new()
	add_child(loader)
	loader.hide()
	loader.load_requested.connect(_load_save)
	Net.players_changed.connect(_update_net_tile)
	Net.connection_changed.connect(_update_net_tile)
	_update_net_tile()
	show_page("")
	# Zurück aus einer Sitzung: Lobby gleich zeigen, dort geht es mit „Mitspielen“ weiter
	if Net.is_active():
		lobby.show()
	if Session.reopen_settings:
		Session.reopen_settings = false
		settings.show()


## Seite zeigen: "" = Hub, "single" = Einzelspieler, "history" = Run-History, "lobby" = Mehrspieler.
func show_page(page: String) -> void:
	single_page.visible = page == "single"
	history_page.visible = page == "history"
	lobby.visible = page == "lobby"
	if page == "history":
		history.reload()
	if page == "single":
		_update_selection()


func _build_hub() -> void:
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := _margin(self)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)
	var title := UiTheme.title(UiUtil.label("GemTD", v, 60))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	var sub := UiUtil.label("Gems setzen, kombinieren, Labyrinth bauen", v, 15)
	sub.add_theme_color_override("font_color", UiTheme.MUTED)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(center)
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 48)
	center.add_child(tiles)
	_tile(tiles, "Einzelspieler", "Allein spielen. Du wählst den TD-Modus (GemTD, eeveTD, Shopping Maul) und die Map, dann geht es los.",
		[UiTheme.GOLD], UiTheme.GOLD, UiTheme.CYAN, func(): show_page("single"))
	net_tile = _tile(tiles, "Mehrspieler", "Sitzung hosten oder per IP beitreten. In der Lobby stimmt ihr gemeinsam über den Modus ab.",
		[UiTheme.CYAN, UiTheme.PURPLE_LIGHT, UiTheme.HAVE], UiTheme.CYAN, UiTheme.GOLD, func(): show_page("lobby"))
	net_tile_text = net_tile.get_meta("text")
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	v.add_child(foot)
	_foot_button("Spiel laden", foot, func(): loader.show())
	_foot_button("Run-History", foot, func(): show_page("history"))
	_foot_button("Map-Editor", foot, _open_map_editor)
	_foot_button("Tower-Editor", foot, _open_tower_editor)
	_foot_button("Einstellungen", foot, _open_settings)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(fill)
	var reload := _foot_button("Daten neu laden", foot, _reload)
	reload.tooltip_text = "JSON-Dateien unter data/ neu einlesen"
	_foot_button("Beenden", foot, func(): get_tree().quit())


## Große Kachel im Hub: Rahmenfarbe border, Schatten shadow, oben kleine Gems in den Farben gems.
func _tile(parent: Node, text: String, desc: String, gems: Array, border: Color, shadow: Color, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(500, 300)
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	for k in ["normal", "hover", "pressed"]:
		var s := UiTheme.panel(28.0, 0.95, border)
		s.shadow_color = shadow
		if k == "hover":
			s.bg_color = UiTheme.PANEL_2
		elif k == "pressed":
			s.bg_color = UiTheme.PANEL_2
			s.shadow_offset = Vector2(2, 2)
		b.add_theme_stylebox_override(k, s)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 30
	v.offset_top = 30
	v.offset_right = -30
	v.offset_bottom = -26
	v.add_theme_constant_override("separation", 14)
	b.add_child(v)
	var icons := HBoxContainer.new()
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icons.add_theme_constant_override("separation", 10)
	icons.custom_minimum_size.y = 54
	v.add_child(icons)
	for i in gems.size():
		var g := GemIcon.new()
		g.color = gems[i]
		g.custom_minimum_size = Vector2(34, 52) if i == 0 else Vector2(26, 42)
		g.size_flags_vertical = Control.SIZE_SHRINK_END
		icons.add_child(g)
	var t := UiTheme.title(UiUtil.label(text, v, 34))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_theme_color_override("font_color", border)
	t.add_theme_color_override("font_shadow_color", shadow)
	t.add_theme_constant_override("shadow_offset_x", 3)
	t.add_theme_constant_override("shadow_offset_y", 3)
	var d := UiUtil.wrap_label(desc, v, 440)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.add_theme_font_size_override("font_size", 16)
	d.add_theme_color_override("font_color", UiTheme.MUTED)
	var extra := UiUtil.label("", v, 15)
	extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	extra.add_theme_color_override("font_color", UiTheme.HAVE)
	b.set_meta("text", extra)
	return b


func _foot_button(text: String, parent: Node, on_pressed: Callable) -> Button:
	var b := UiUtil.button(text, parent, on_pressed)
	b.custom_minimum_size.y = 42
	b.add_theme_font_size_override("font_size", 15)
	return b


func _margin(parent: Node) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	parent.add_child(margin)
	return margin


## Unterseite über dem Hub mit eigenem Hintergrund. Meta "box": VBox für den Inhalt, erstes Kind ist die Kopfzeile.
func _page() -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(page)
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(bg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_margin(page).add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	v.add_child(head)
	page.set_meta("box", v)
	page.hide()
	return page


func _back_button(head: Node, on_pressed: Callable) -> Button:
	var b := UiUtil.button("‹ " + tr("Zurück"), head, on_pressed)
	b.custom_minimum_size.y = 40
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


## Einzelspieler: 1. Modus, 2. Map, Spielen.
func _build_single(v: VBoxContainer) -> void:
	var head: HBoxContainer = v.get_child(0)
	_back_button(head, func(): show_page(""))
	UiTheme.title(UiUtil.label("Einzelspieler", head, 28)).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiTheme.caption("1 · Modus", v)
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 14)
	v.add_child(modes)
	for m in Database.modes:
		var card := ModeCard.new(m)
		var id: String = card.mode_id
		card.pressed.connect(func():
			Session.game_kind = id
			_fill_maps())
		modes.add_child(card)
		mode_cards.append(card)
	map_caption = UiTheme.caption("2 · Map", v)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	map_scroll = scroll
	no_map_hint = UiUtil.label("Dieser Modus wählt seine Karte selbst vor dem Start.", v, 15)
	no_map_hint.add_theme_color_override("font_color", UiTheme.MUTED)
	no_map_hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_box = HFlowContainer.new()
	cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_box.add_theme_constant_override("h_separation", 18)
	cards_box.add_theme_constant_override("v_separation", 18)
	scroll.add_child(cards_box)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 18)
	v.add_child(foot)
	var hint := UiUtil.label("Doppelklick auf eine Map startet sie direkt. Schwierigkeit und Wertung wählst du im Spiel vor Runde 1.", foot, 13)
	hint.add_theme_color_override("font_color", UiTheme.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_button = UiUtil.button("Spielen", foot, _play)
	play_button.custom_minimum_size = Vector2(440, 58)
	play_button.add_theme_font_size_override("font_size", 22)
	play_button.clip_text = true
	UiTheme.accent_button(play_button, UiTheme.GOLD, UiTheme.GOLD_DARK, Color(UiTheme.GOLD, 0.3))


func _update_modes() -> void:
	if not Database.mode_allows(Session.game_kind, 1):
		for m in Database.modes:
			if Database.mode_allows(str(m.id), 1):
				Session.game_kind = str(m.id)
				break
	for card in mode_cards:
		var ok := Database.mode_allows(card.mode_id, 1)
		var tag := ""
		if not bool(Database.mode(card.mode_id).get("ready", false)):
			tag = tr("Kommt noch")
		elif not ok:
			tag = tr("Nicht solo")
		card.set_state(card.mode_id == Session.game_kind, ok, tag)


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
	ui_scale_slider = _ui_scale_row(grid)
	var hint := UiUtil.wrap_label("Änderungen gelten sofort und bleiben gespeichert.", v, 400)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", UiTheme.MUTED)
	v.add_child(_gap(4))
	var done := UiUtil.button("Fertig", v, func(): settings.hide())
	done.custom_minimum_size.y = 46
	UiTheme.accent_button(done, UiTheme.GOLD, UiTheme.GOLD_DARK, Color(UiTheme.GOLD, 0.3))
	settings.hide()


## UI-Größe 50–100 %: die Zahl folgt dem Regler sofort, umgestellt wird beim Loslassen,
## sonst springt der Regler beim Ziehen unter der Maus weg.
func _ui_scale_row(grid: GridContainer) -> HSlider:
	var l := UiUtil.label(tr("UI-Größe"), grid, 15)
	l.custom_minimum_size.x = 150
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(h)
	var s := HSlider.new()
	s.min_value = Display.UI_SCALE_MIN * 100.0
	s.max_value = Display.UI_SCALE_MAX * 100.0
	s.step = 5
	s.value = roundf(Display.ui_scale * 100.0)
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size.y = 24
	s.tooltip_text = tr("Verkleinert Menüs und Spieloberfläche, die Spielansicht bleibt gleich.")
	h.add_child(s)
	var n := UiUtil.label("%d %%" % roundi(s.value), h, 16)
	n.custom_minimum_size.x = 64
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	n.add_theme_font_override("font", UiTheme.font(true))
	n.add_theme_color_override("font_color", UiTheme.CYAN)
	var dragging := [false]
	s.drag_started.connect(func(): dragging[0] = true)
	s.drag_ended.connect(func(_changed):
		dragging[0] = false
		Display.set_ui_scale(s.value / 100.0))
	s.value_changed.connect(func(v):
		n.text = "%d %%" % roundi(v)
		if not dragging[0]:
			Display.set_ui_scale(v / 100.0))
	return s


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


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _open_settings() -> void:
	settings.show()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		return
	if settings.visible:
		settings.hide()
	elif single_page.visible or history_page.visible:
		show_page("")
	else:
		return
	get_viewport().set_input_as_handled()


## „Map nochmal spielen“: gleiche Map, Schwierigkeit und Wertung wie der Lauf (Run-History kennt nur GemTD).
func _replay(run: Dictionary) -> void:
	Session.game_kind = str(run.get("mode", "gemtd"))
	_fill_maps()
	for i in shown_maps.size():
		if shown_maps[i].path == str(run.get("map_path", "")) or shown_maps[i].name == str(run.get("map", "")):
			selected = i
			break
	Session.difficulty = clampi(int(run.get("difficulty", Session.difficulty)), 0, Session.DIFFICULTIES.size() - 1)
	Session.score_mode = bool(run.get("score_mode", false))
	_play()


func _reload() -> void:
	Database.reload()
	maps = Database.list_maps()
	if lobby != null:
		lobby.maps = maps
	_fill_maps()


## Map-Karten für den gewählten Modus neu aufbauen.
func _fill_maps() -> void:
	_update_modes()
	shown_maps = Database.maps_for_mode(Session.game_kind, maps)
	selected = maxi(shown_maps.map(func(m): return m.path).find(Session.map_path), 0)
	for c in cards_box.get_children():
		cards_box.remove_child(c)
		c.queue_free()
	cards.clear()
	for i in shown_maps.size():
		cards.append(_map_card(i))
	_update_selection()


func _map_card(i: int) -> Button:
	var md := MapData.load_file(shown_maps[i].path)
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
	UiUtil.label(shown_maps[i].name, v, 19).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info := ""
	if md != null:
		var waves: int = (Database.wave_sets.get(md.wave_set, {}).get("waves", []) as Array).size()
		info = tr("%d×%d · %d Wellen · %d Leben · %d Checkpoints") % [md.width, md.height, waves, md.lives, md.checkpoints.size()]
		var rocks := int(md.variance.get("random_rocks", 0))
		info += "\n" + tr("Weg ohne Labyrinth: %d Felder") % preview.path_length()
		if rocks > 0:
			info += " · " + tr("%d zufällige Steine") % rocks
		if not md.zones.is_empty():
			var seats := {}
			for z in md.zones:
				seats[z.player] = true
			info += "\n" + tr("Koop: %d Zonen, %d Bahnen") % [seats.size(), md.lane_count()]
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
		cards[i].add_theme_stylebox_override("hover", UiTheme.box(UiTheme.PANEL_2, UiTheme.GOLD if on else UiTheme.BORDER_2, 10, 2))
	var needs_map := _needs_map()
	map_caption.visible = needs_map
	map_scroll.visible = needs_map
	no_map_hint.visible = not needs_map
	var ok := (not needs_map or not shown_maps.is_empty()) and Database.mode_allows(Session.game_kind, 1)
	play_button.disabled = not ok
	var mode_name := str(Database.mode(Session.game_kind).get("name", Session.game_kind))
	if not ok:
		play_button.text = tr("Spielen")
	elif needs_map:
		play_button.text = tr("Spielen: %s · %s") % [mode_name, tr(shown_maps[selected].name)]
	else:
		play_button.text = tr("Spielen: %s") % mode_name


## Wählt der Modus eine Map aus data/maps (needs_map in data/modes.json)?
func _needs_map() -> bool:
	return bool(Database.mode(Session.game_kind).get("needs_map", true))


func _play() -> void:
	if not Database.mode_allows(Session.game_kind, 1) or (_needs_map() and shown_maps.is_empty()):
		return
	if _needs_map():
		Session.map_path = shown_maps[selected].path
	Session.map_override = null
	Session.load_state = {}
	Session.save_id = ""
	Session.test_tower = ""
	Session.return_scene = Session.MAIN_MENU
	Session.goto(Session.game_scene())


func _update_net_tile() -> void:
	net_tile_text.text = tr("%d verbunden") % (Net.players.size() + 1) if Net.is_active() else ""
	net_tile_text.visible = Net.is_active()


## Host: Sitzung starten, eine neue auf der in der Lobby gewählten Map.
func _start_session() -> void:
	var path := lobby.map_path()
	var m := MapData.load_file(path) if path != "" else null
	if Net.session.has("coop"):
		Net.start_coop({})
	elif lobby.no_map_mode() and not Net.session.get("loaded", false):
		# Modus mit eigener Karte (Shopping Maul): alle zusammen in einer Partie
		Net.session.mode = Net.vote_winner(false)
		Net.start_coop({"name": str(Database.mode(Net.session.mode).get("name", ""))})
	elif lobby.coop_mode and m != null and not Net.session.get("loaded", false):
		Net.start_coop(m.to_dict())
	elif m != null or not Net.session.get("map", {}).is_empty():
		Net.start_session(m.to_dict() if m != null else {})


## Spielstand laden: Einzelspiel geht direkt weiter, eine Mehrspieler-Sitzung wird gehostet.
func _load_save(data: Dictionary) -> void:
	if data.get("kind", "") in ["multi", "coop"]:
		if Net.host() == OK:
			Net.load_session(data)
		show_page("lobby")
		return
	var st: Dictionary = data.get("state", {})
	Session.game_kind = str(data.get("mode", "gemtd"))
	Session.load_state = st
	Session.save_id = str(data.get("id", ""))
	Session.map_override = MapData.from_dict(st.get("map", {}))
	Session.test_tower = ""
	Session.return_scene = Session.MAIN_MENU
	Session.goto(Session.game_scene())


func _open_map_editor() -> void:
	Session.editor_map = null
	if not shown_maps.is_empty():
		Session.editor_map = MapData.load_file(shown_maps[selected].path)
	Session.goto(Session.MAP_EDITOR)


func _open_tower_editor() -> void:
	Session.goto(Session.TOWER_EDITOR)


## Kleiner Gem (Raute) als Symbol auf den Hub-Kacheln.
class GemIcon extends Control:
	var color := Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_colored_polygon(PackedVector2Array([Vector2(w / 2, 0), Vector2(w, h * 0.45), Vector2(w / 2, h), Vector2(0, h * 0.45)]), color)
