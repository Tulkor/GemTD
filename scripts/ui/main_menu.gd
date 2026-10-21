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
var lobby: LobbyPanel
var loader: LoadPanel
var net_tile: Button
var net_tile_text: Label
var history: RunHistoryPanel
var map_caption: Label
var map_info: Label
var play_label: Label
var map_scroll: ScrollContainer
var no_map_hint: Label
var single_page: Control
var history_page: Control


func _ready() -> void:
	UiTheme.use_skin(UiTheme.ARCADE)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = DecoTheme.get_theme()
	_build_hub()
	single_page = _page()
	_build_single(single_page.get_meta("box"))
	history_page = _page()
	var hv: VBoxContainer = history_page.get_meta("box")
	_back_button(hv.get_child(0), func(): show_page(""))
	DecoTheme.title(UiUtil.label("Run-History", hv.get_child(0), 44)).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DecoTheme.head_line(hv.get_child(0))
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
	var bg := DecoBackdrop.new()
	bg.rays = true
	bg.rays_from = Vector2(0.5, 0.17)
	add_child(bg)
	var margin := _margin(self)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)
	v.add_child(_gap(20))
	# Titel auf Petrol, damit die Strahlen dahinter verschwinden
	var title := DecoTheme.title(UiUtil.label("TD Hub", v, 92))
	title.uppercase = true
	title.add_theme_font_override("font", DecoTheme.display_font(16))
	title.add_theme_stylebox_override("normal", DecoTheme.box(DecoTheme.BG, Color.TRANSPARENT, 0, 0, 30))
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sub := UiUtil.label("◆  " + tr("Drei Tower Defense in einem: GemTD, eeveTD, Shopping Maul").to_upper() + "  ◆", v, 15)
	sub.add_theme_color_override("font_color", DecoTheme.GOLD)
	sub.add_theme_font_override("font", DecoTheme._variant(DecoTheme.FONT, 0.3, 4))
	sub.add_theme_stylebox_override("normal", DecoTheme.box(DecoTheme.BG, Color.TRANSPARENT, 0, 0, 16))
	sub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(center)
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 40)
	center.add_child(tiles)
	_tile(tiles, "Einzelspieler", "Allein spielen. Du wählst den TD-Modus (GemTD, eeveTD, Shopping Maul) und die Map, dann geht es los.",
		1, true, func(): show_page("single"))
	net_tile = _tile(tiles, "Mehrspieler", "Sitzung hosten oder per IP beitreten. In der Lobby stimmt ihr gemeinsam über den Modus ab.",
		3, false, func(): show_page("lobby"))
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


## Große Kachel im Hub: filled = helles Messing mit dunkler Schrift (Achteck), sonst doppelter Messingrahmen.
## Oben gems Rauten als Umriss.
func _tile(parent: Node, text: String, desc: String, gems: int, filled: bool, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(470, 260)
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	var ink := DecoTheme.GOLD_DARK if filled else DecoTheme.TEXT
	for k in ["normal", "hover", "pressed"]:
		var s: DecoBox
		if filled:
			s = DecoTheme.frame(DecoTheme.BRASS_LIGHT, Color.TRANSPARENT, Color.TRANSPARENT, 20)
			if k == "hover":
				s.bg = DecoTheme.BRASS_LIGHT.lightened(0.12)
			elif k == "pressed":
				s.bg = DecoTheme.BRASS_LIGHT.darkened(0.1)
		else:
			s = DecoTheme.frame(Color.TRANSPARENT, DecoTheme.GOLD, DecoTheme.GOLD)
			if k == "hover":
				s.bg = DecoTheme.PANEL
				s.line = DecoTheme.BRASS_LIGHT
			elif k == "pressed":
				s.bg = DecoTheme.PANEL_2
		b.add_theme_stylebox_override(k, s)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 34
	v.offset_top = 30
	v.offset_right = -34
	v.offset_bottom = -24
	v.add_theme_constant_override("separation", 14)
	b.add_child(v)
	var icons := HBoxContainer.new()
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icons.add_theme_constant_override("separation", 6)
	icons.custom_minimum_size.y = 36
	v.add_child(icons)
	for i in gems:
		var g := GemIcon.new()
		g.color = ink if filled else DecoTheme.GOLD
		g.lines = filled
		g.custom_minimum_size = Vector2(60, 36) if filled else Vector2(30, 36)
		icons.add_child(g)
	var t := DecoTheme.title(UiUtil.label(text, v, 40))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_theme_font_override("font", DecoTheme.display_font(5))
	t.add_theme_color_override("font_color", ink)
	var d := UiUtil.wrap_label(desc, v, 400)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.add_theme_font_size_override("font_size", 17)
	d.add_theme_color_override("font_color", ink if filled else DecoTheme.BRASS_LIGHT)
	if filled:
		d.add_theme_font_override("font", DecoTheme.font(true))
	var extra := UiUtil.label("", v, 15)
	extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	extra.add_theme_color_override("font_color", DecoTheme.HAVE)
	b.set_meta("text", extra)
	return b


func _foot_button(text: String, parent: Node, on_pressed: Callable) -> Button:
	var b := UiUtil.button(text, parent, on_pressed)
	b.custom_minimum_size.y = 42
	b.text = tr(text).to_upper()
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_font_override("font", DecoTheme._variant(DecoTheme.FONT, 0.3, 2))
	return b


func _margin(parent: Node) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 72)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 52)
	parent.add_child(margin)
	return margin


## Unterseite über dem Hub mit eigenem Hintergrund. Meta "box": VBox für den Inhalt, erstes Kind ist die Kopfzeile.
func _page() -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(page)
	page.add_child(DecoBackdrop.new())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_margin(page).add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	v.add_child(head)
	page.set_meta("box", v)
	page.hide()
	return page


func _back_button(head: Node, on_pressed: Callable) -> Button:
	var b := UiUtil.button("◂ " + tr("Zurück").to_upper(), head, on_pressed)
	b.custom_minimum_size.y = 40
	b.add_theme_font_override("font", DecoTheme._variant(DecoTheme.FONT, 0.3, 2))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


## Einzelspieler in drei Spalten: I. Modus, II. Map, III. Start (Angaben zur Map und Spielen).
func _build_single(v: VBoxContainer) -> void:
	var head: HBoxContainer = v.get_child(0)
	_back_button(head, func(): show_page(""))
	DecoTheme.title(UiUtil.label("Einzelspieler", head, 44)).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	DecoTheme.head_line(head)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 28)
	v.add_child(body)

	var left := _column(body, 300)
	DecoTheme.caption("I · Modus", left)
	for m in Database.modes:
		var card := ModeCard.new(m, Vector2(300, 140))
		var id: String = card.mode_id
		card.pressed.connect(func():
			Session.game_kind = id
			_fill_maps())
		left.add_child(card)
		mode_cards.append(card)

	var mid := _column(body, 0)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_caption = DecoTheme.caption("II · Map", mid)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(scroll)
	map_scroll = scroll
	no_map_hint = UiUtil.wrap_label("Dieser Modus wählt seine Karte selbst vor dem Start.", mid, 300)
	no_map_hint.add_theme_font_size_override("font_size", 16)
	no_map_hint.add_theme_color_override("font_color", DecoTheme.MUTED)
	no_map_hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_box = HFlowContainer.new()
	cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_box.add_theme_constant_override("h_separation", 16)
	cards_box.add_theme_constant_override("v_separation", 16)
	scroll.add_child(cards_box)

	var right := _column(body, 320)
	DecoTheme.caption("III · Start", right)
	map_info = UiUtil.wrap_label("", right, 320)
	map_info.add_theme_font_size_override("font_size", 15)
	map_info.add_theme_color_override("font_color", DecoTheme.BRASS_LIGHT)
	var hint := UiUtil.wrap_label("Doppelklick auf eine Map startet sie direkt. Schwierigkeit und Wertung wählst du im Spiel vor Runde 1.", right, 320)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", DecoTheme.MUTED)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(fill)
	play_button = UiUtil.button("Spielen", right, _play)
	play_button.custom_minimum_size = Vector2(320, 66)
	play_button.add_theme_font_size_override("font_size", 30)
	play_button.clip_text = true
	DecoTheme.accent_button(play_button)
	play_label = UiUtil.wrap_label("", right, 320)
	play_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_label.add_theme_color_override("font_color", DecoTheme.BRASS_LIGHT)


## Spalte der Einzelspieler-Seite (width 0 = so breit wie Platz ist).
func _column(parent: Node, width: float) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 12)
	c.custom_minimum_size.x = width
	parent.add_child(c)
	return c


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


## Einstellungen: gleiches Fenster wie im Spiel, hier in Art déco.
func _build_settings() -> void:
	settings = SettingsPanel.new(true)
	add_child(settings)


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
	b.custom_minimum_size = Vector2(250, 0)
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
	preview.custom_minimum_size = Vector2(226, 150)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.bg = DecoTheme.BG
	preview.map = md
	v.add_child(preview)
	var name_label := UiUtil.label(tr(shown_maps[i].name).to_upper(), v, 17)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_override("font", DecoTheme._variant(DecoTheme.FONT, 0.35, 2))
	var info := ""
	var short := ""
	if md != null:
		var waves: int = (Database.wave_sets.get(md.wave_set, {}).get("waves", []) as Array).size()
		info = tr("%d×%d · %d Wellen · %d Leben · %d Checkpoints") % [md.width, md.height, waves, md.lives, md.checkpoints.size()]
		short = "%d×%d · " % [md.width, md.height] + tr("%d Wellen") % waves
		var rocks := int(md.variance.get("random_rocks", 0))
		info += "\n" + tr("Weg ohne Labyrinth: %d Felder") % preview.path_length()
		if rocks > 0:
			info += " · " + tr("%d zufällige Steine") % rocks
		if not md.zones.is_empty():
			var seats := {}
			for z in md.zones:
				seats[z.player] = true
			info += "\n" + tr("Koop: %d Zonen, %d Bahnen") % [seats.size(), md.lane_count()]
	var l := UiUtil.label(short, v, 15)
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", DecoTheme.MUTED)
	b.set_meta("info", info.replace(" · ", "\n").replace("\n\n", "\n"))
	b.custom_minimum_size.y = 150 + 24 + 6 * 2 + 24 + 20
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
		cards[i].add_theme_stylebox_override("normal", DecoTheme.box(DecoTheme.PANEL, DecoTheme.BRASS_LIGHT if on else DecoTheme.BORDER, 0, 2 if on else 1))
		cards[i].add_theme_stylebox_override("pressed", DecoTheme.box(DecoTheme.PANEL, DecoTheme.BRASS_LIGHT, 0, 2))
		cards[i].add_theme_stylebox_override("hover", DecoTheme.box(DecoTheme.PANEL_2, DecoTheme.BRASS_LIGHT if on else DecoTheme.GOLD, 0, 2 if on else 1))
	var needs_map := _needs_map()
	map_caption.visible = needs_map
	map_scroll.visible = needs_map
	no_map_hint.visible = not needs_map
	var ok := (not needs_map or not shown_maps.is_empty()) and Database.mode_allows(Session.game_kind, 1)
	play_button.disabled = not ok
	var mode_name := str(Database.mode(Session.game_kind).get("name", Session.game_kind))
	play_button.text = tr("Spielen")
	if not ok:
		play_label.text = ""
		map_info.text = ""
	elif needs_map:
		play_label.text = "%s · %s" % [mode_name, tr(shown_maps[selected].name)]
		map_info.text = "%s · %s\n%s" % [mode_name, tr(shown_maps[selected].name), cards[selected].get_meta("info", "")]
	else:
		play_label.text = mode_name
		map_info.text = mode_name


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
	elif lobby.coop_selected() and m != null and not Net.session.get("loaded", false):
		Net.start_coop(m.to_dict())
	elif m != null or not Net.session.get("map", {}).is_empty():
		# Eigene Felder, gemischt mit Koop-Gruppen (gleiche Feldnummer in der Lobby)
		Net.start_session(m.to_dict() if m != null else {}, lobby.field_groups())


## Spielstand laden: Einzelspiel geht direkt weiter, eine Mehrspieler-Sitzung wird gehostet.
func _load_save(data: Dictionary) -> void:
	if data.get("kind", "") in ["multi", "coop"]:
		if Net.host_default() == OK:
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


## Raute als Umriss auf den Hub-Kacheln, lines: mit Strichen links und rechts (Art déco).
class GemIcon extends Control:
	var color := Color.WHITE
	var lines := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var h := size.y
		var m := size.x / 2
		var r := h * 0.45
		var pts := PackedVector2Array([Vector2(m, h / 2 - r), Vector2(m + r * 0.8, h / 2), Vector2(m, h / 2 + r), Vector2(m - r * 0.8, h / 2), Vector2(m, h / 2 - r)])
		draw_polyline(pts, color, 2.5, true)
		if lines:
			draw_line(Vector2(0, h / 2), Vector2(m - r * 0.8 - 3, h / 2), color, 2.0)
			draw_line(Vector2(m + r * 0.8 + 3, h / 2), Vector2(size.x, h / 2), color, 2.0)
