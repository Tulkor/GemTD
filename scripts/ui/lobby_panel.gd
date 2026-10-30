class_name LobbyPanel
extends Control
## Mehrspieler-Lobby (Seite des Hauptmenüs). Links: Name, hosten oder per IP beitreten; verbunden die Spieler
## mit ihrer Stimme und (Host) Map und Spielart. Rechts: Abstimmung über den TD-Modus, jeder klickt einen an.
## Wählbar sind nur Modi, die spielbar und für die Spielerzahl erlaubt sind (data/modes.json).
## Gleichstand: die Stimme des Hosts zählt, sonst das Los (Net.vote_winner).
## Als Host: „Starten“; als Mitspieler: Stand der Sitzung und „Mitspielen“, auch später noch zum Wiedereinsteigen.
## Gespeicherte Sitzungen lädt der Host über „Spiel laden“ (load_panel.gd), sie bringen ihren Modus mit.

signal start_requested

## Alle Maps (Database.list_maps()), setzt das Hauptmenü.
var maps: Array = []
## Koop gewählt: alle spielen zusammen auf einem Feld (der Host rechnet, siehe coop_sync.gd).
var coop_mode := false
## Feldwahl des Hosts: uid -> Feldnummer (ab 0). Gleiche Nummer = zusammen auf einem Feld (Koop-Gruppe),
## so geht auch gemischt, z. B. zwei allein und zwei zusammen. Neue Spieler bekommen die Vorgabe von coop_mode.
var fields: Dictionary = {}

var _name_edit: LineEdit
var _ip_edit: LineEdit
var _server_edit: LineEdit
var _port_hint: Label
var _status: Label
var _offline: VBoxContainer
var _online: VBoxContainer
var _addresses: Label
var _internet: Label
var _copy_button: Button
var _session_text: Label
var _players_caption: Label
var _list: VBoxContainer
var _start_button: Button
var _host_box: VBoxContainer
var _map_option: OptionButton
var _map_paths: Array = []
var _map_path := ""
var _mode_buttons: Array[Button] = []
var _vote_caption: Label
const VOTE_CARD_W := 270.0  ## längster Modusname (Randgruppen) passt bei 28 px ohne Trennung
var _vote_row: GridContainer
var _vote_cards: Array[ModeCard] = []
var _summary: Label
var _summary_panel: PanelContainer
var _play_button: Button
var _leave_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(DecoBackdrop.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 72)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 52)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	margin.add_child(page)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	page.add_child(head)
	var back := UiUtil.button("◂ " + tr("Zurück").to_upper(), head, hide)
	back.custom_minimum_size.y = 40
	back.add_theme_font_override("font", DecoTheme.font(true))
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.tooltip_text = "Zurück zum Hauptmenü, die Verbindung bleibt bestehen"
	DecoTheme.title(UiUtil.label("Lobby", head, 44)).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status = UiUtil.label("", head, 15)
	_status.add_theme_color_override("font_color", DecoTheme.BRASS_LIGHT)
	_status.add_theme_font_override("font", DecoTheme.font(true))
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status.custom_minimum_size.x = 380
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	DecoTheme.head_line(head)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 28)
	page.add_child(body)

	# Links: Verbindung, Spieler, Host-Einstellungen
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", DecoTheme.box(DecoTheme.PANEL, DecoTheme.GOLD, 0, 1, 22))
	panel.custom_minimum_size.x = 420
	body.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	v.add_child(name_row)
	UiUtil.label("Name", name_row, 15).custom_minimum_size.x = 70
	_name_edit = LineEdit.new()
	_name_edit.text = Net.my_name
	_name_edit.max_length = 24
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(func(t): Net.set_my_name(t))
	name_row.add_child(_name_edit)

	# Ohne Verbindung: hosten oder beitreten
	_offline = VBoxContainer.new()
	_offline.add_theme_constant_override("separation", 10)
	v.add_child(_offline)
	var server_row := HBoxContainer.new()
	server_row.add_theme_constant_override("separation", 10)
	_offline.add_child(server_row)
	UiUtil.label("Server", server_row, 15).custom_minimum_size.x = 70
	_server_edit = LineEdit.new()
	_server_edit.text = Net.relay_server
	_server_edit.placeholder_text = tr("leer = direkt per IP")
	_server_edit.tooltip_text = "Relay-Server: Host und Mitspieler verbinden sich nur mit ihm, niemand muss einen Port freigeben"
	_server_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_server_edit.text_changed.connect(func(_t): _update_join_hint())
	_server_edit.text_submitted.connect(func(_t): _save_server())
	_server_edit.focus_exited.connect(_save_server)
	server_row.add_child(_server_edit)
	var host := UiUtil.button("Neue Sitzung hosten", _offline, func(): _save_server(); Net.host_default())
	host.custom_minimum_size.y = 44
	_muted(UiUtil.wrap_label("Eine gespeicherte Sitzung setzt du über „Spiel laden“ im Hauptmenü fort.", _offline, 370)).add_theme_font_size_override("font_size", 15)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 10)
	_offline.add_child(join_row)
	_ip_edit = LineEdit.new()
	_ip_edit.text = Net.last_ip
	_ip_edit.placeholder_text = "Code oder IP-Adresse des Hosts"
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_edit.text_submitted.connect(func(_t): _join())
	join_row.add_child(_ip_edit)
	UiUtil.button("Beitreten", join_row, _join).custom_minimum_size.x = 120
	_port_hint = _muted(UiUtil.wrap_label("", _offline, 370))
	_port_hint.add_theme_font_size_override("font_size", 15)
	_update_join_hint()

	# Verbunden: Adresse, Spieler, Host-Einstellungen
	_online = VBoxContainer.new()
	_online.add_theme_constant_override("separation", 10)
	v.add_child(_online)
	var net_row := HBoxContainer.new()
	net_row.add_theme_constant_override("separation", 10)
	_online.add_child(net_row)
	_internet = UiUtil.label("", net_row, 15)
	_internet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_internet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_copy_button = UiUtil.button("Kopieren", net_row, func(): DisplayServer.clipboard_set(Net.room_code() if Net.room_code() != "" else Net.public_ip))
	_copy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_copy_button.tooltip_text = "Adresse in die Zwischenablage kopieren, um sie den Mitspielern zu schicken"
	_addresses = _muted(UiUtil.label("", _online, 15))
	_addresses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_addresses.custom_minimum_size.x = 370
	_players_caption = DecoTheme.caption("Spieler", _online)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_online.add_child(_list)

	_host_box = VBoxContainer.new()
	_host_box.add_theme_constant_override("separation", 6)
	_online.add_child(_host_box)
	_host_box.add_child(_gap(6))
	DecoTheme.caption("Host-Einstellungen", _host_box)
	_muted(UiUtil.label("Map", _host_box, 15))
	_map_option = OptionButton.new()
	_map_option.focus_mode = Control.FOCUS_NONE
	_map_option.custom_minimum_size.y = 38
	_map_option.item_selected.connect(func(i): _map_path = str(_map_paths[i]) if i < _map_paths.size() else "")
	_host_box.add_child(_map_option)
	_muted(UiUtil.label("Spielfeld", _host_box, 15))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 6)
	_host_box.add_child(modes)
	var group := ButtonGroup.new()
	for coop in [false, true]:
		var on: bool = coop
		var b := UiUtil.button("Koop" if coop else "Eigene Felder", modes, func():
			coop_mode = on
			fields = {}
			_refresh())
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 36
		b.tooltip_text = tr("Alle bauen zusammen ein Labyrinth: jeder setzt und wählt seine eigenen Gems, hat eigenes Gold und kombiniert nur eigene Tower. Die Leben sind gemeinsam.") if coop \
			else tr("Jeder spielt sein eigenes Feld, über „Zuschauen“ sieht man die anderen.")
		b.add_theme_stylebox_override("pressed", DecoTheme.box(DecoTheme.CYAN, DecoTheme.CYAN, 0, 2))
		b.add_theme_color_override("font_pressed_color", DecoTheme.GOLD_DARK)
		b.set_pressed_no_signal(coop == coop_mode)
		_mode_buttons.append(b)

	# Rechts: Abstimmung und Start
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 16)
	body.add_child(right)
	_vote_caption = DecoTheme.caption("Modus abstimmen · Klick = deine Stimme", right)
	# Raster statt Reihe: fünf Karten passen bei 16:9 nicht nebeneinander, ohne dass die Namen brechen.
	# Spaltenzahl folgt der Breite, Zeilen gleichmäßig gefüllt (3 + 2 statt 4 + 1).
	_vote_row = GridContainer.new()
	_vote_row.add_theme_constant_override("h_separation", 14)
	_vote_row.add_theme_constant_override("v_separation", 14)
	right.add_child(_vote_row)
	right.resized.connect(func(): _fit_vote_columns(right.size.x))
	for m in Database.modes:
		var card := ModeCard.new(m, Vector2(VOTE_CARD_W, 150))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # breite Fenster: Karten teilen sich die Breite
		var id: String = card.mode_id
		card.pressed.connect(func(): Net.vote("" if Net.my_vote() == id else id))
		_vote_row.add_child(card)
		_vote_cards.append(card)
	_summary_panel = PanelContainer.new()
	_summary_panel.add_theme_stylebox_override("panel", DecoTheme.box(Color.TRANSPARENT, DecoTheme.GOLD, 0, 1, 16))
	right.add_child(_summary_panel)
	_summary = UiUtil.label("", _summary_panel, 15)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size.x = 400
	_session_text = UiUtil.label("", right, 15)
	_session_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_session_text.custom_minimum_size.x = 400
	_session_text.add_theme_color_override("font_color", DecoTheme.DIM)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(fill)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	right.add_child(buttons)
	_leave_button = UiUtil.button("Trennen", buttons, func(): Net.leave())
	_leave_button.custom_minimum_size = Vector2(130, 46)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(gap)
	_start_button = UiUtil.button("Starten", buttons, func(): start_requested.emit())
	_start_button.custom_minimum_size = Vector2(560, 62)
	_start_button.add_theme_font_size_override("font_size", 28)
	_start_button.clip_text = true
	DecoTheme.accent_button(_start_button, DecoTheme.GOLD, DecoTheme.GOLD_DARK)
	_play_button = UiUtil.button("Mitspielen", buttons, func(): Net.join_session())
	_play_button.custom_minimum_size = Vector2(300, 62)
	_play_button.add_theme_font_size_override("font_size", 28)
	DecoTheme.accent_button(_play_button, DecoTheme.GOLD, DecoTheme.GOLD_DARK)

	Net.players_changed.connect(_refresh)
	Net.connection_changed.connect(_refresh)
	Net.session_changed.connect(_refresh)
	visibility_changed.connect(_refresh)
	_refresh()


## Spalten der Abstimmungskarten für die verfügbare Breite, Zeilen möglichst gleich voll.
func _fit_vote_columns(width: float) -> void:
	var n := _vote_cards.size()
	var most := clampi(int((width + 14.0) / (VOTE_CARD_W + 14.0)), 1, maxi(n, 1))
	var rows := ceili(float(n) / most)
	_vote_row.columns = ceili(float(n) / rows)


## Wählt der Modus, der gerade vorne liegt, seine Karte selbst (needs_map false, z. B. Shopping Maul)?
## Dann spielen alle zusammen in einer Partie (Koop), Map und Spielfeld-Wahl entfallen.
func no_map_mode() -> bool:
	return not bool(Database.mode(Net.vote_winner(false)).get("needs_map", true))


## Startet die Sitzung als reiner Koop (alle auf einem Feld)? Modi mit coop_only (YouTD) immer.
func coop_selected() -> bool:
	if bool(Database.mode(Net.vote_winner(false)).get("coop_only", false)):
		return true
	var g := field_groups()
	return g.size() == 1 and (g[0].size() > 1 or coop_mode)


## Verbundene Spieler (uids) in der Reihenfolge der Spielerliste.
func _online_uids() -> Array:
	return Net.session_slots().filter(func(sl): return sl.get("online", false)).map(func(sl): return str(sl.uid))


func field_of(u: String) -> int:
	if fields.has(u):
		return int(fields[u])
	return 0 if coop_mode else _online_uids().find(u)


## Spieler nach Feld: [[uid, ...], ...], ein Eintrag je belegtem Feld.
func field_groups() -> Array:
	var by := {}
	for u in _online_uids():
		var f := field_of(u)
		if not by.has(f):
			by[f] = []
		by[f].append(u)
	var keys := by.keys()
	keys.sort()
	return keys.map(func(k): return by[k])


## Feld eines Spielers weiterschalten (Host, Klick in der Spielerliste).
func _next_field(u: String) -> void:
	var n := maxi(_online_uids().size(), 1)
	for x in _online_uids():
		fields[x] = field_of(x)
	fields[u] = (field_of(u) + 1) % n
	_refresh()


## Pfad der gewählten Map für eine neue Sitzung ("" = keine).
func map_path() -> String:
	return _map_path


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _unhandled_input(event: InputEvent) -> void:
	if visible and is_visible_in_tree() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide()
		get_viewport().set_input_as_handled()


func _muted(l: Label) -> Label:
	l.add_theme_color_override("font_color", DecoTheme.MUTED)
	return l


func _join() -> void:
	var ip := _ip_edit.text.strip_edges()
	if ip != "":
		_save_server()
		Net.join_any(ip)


func _save_server() -> void:
	if _server_edit != null and _server_edit.text.strip_edges() != Net.relay_server:
		Net.set_relay_server(_server_edit.text)
	_update_join_hint()


func _update_join_hint() -> void:
	if _port_hint == null:
		return
	var relay := _server_edit.text.strip_edges() != ""
	if relay:
		_port_hint.text = tr("Mit Server: Der Host bekommt einen Code, Mitspieler geben ihn oben ein. Niemand muss einen Port freigeben. Eine IP-Adresse statt Code verbindet weiter direkt.")
	else:
		_port_hint.text = tr("Im selben Netzwerk reicht die angezeigte Adresse. Übers Internet muss der Host UDP-Port %d am Router freigeben, oder ihr nutzt ein virtuelles LAN wie Tailscale oder ZeroTier.") % Net.DEFAULT_PORT




func _refresh() -> void:
	if _list == null or not visible:
		return
	var online := Net.is_active()
	var busy := online or Net.is_connecting()
	_offline.visible = not busy
	_online.visible = online
	_leave_button.visible = busy
	_status.text = Net.status_text
	_status.visible = Net.status_text != ""
	_start_button.visible = false
	_play_button.visible = false
	_host_box.visible = false
	if not online:
		_show_votes(false, false)
		_summary.text = tr("Erst eine Sitzung hosten oder beitreten, dann stimmt ihr hier gemeinsam über den Modus ab.")
		_session_text.text = ""
		return

	var started := false
	var loaded := false
	var mode_name := _mode_name(Net.vote_winner(false))
	if Net.is_host():
		_show_addresses()
		var s := Net.session
		started = bool(s.get("started", false))
		loaded = bool(s.get("loaded", false))
		var voting := not started and not loaded
		var no_map := no_map_mode()
		_host_box.visible = voting and not no_map
		# Feldwahl: Koop = alle auf Feld 1, Eigene Felder = jeder seins, sonst gemischt (keiner gedrückt)
		var groups := field_groups()
		var plan := {}
		for g in groups:
			for u in g:
				plan[u] = field_of(u)
		Net.set_fields(plan if voting and not no_map else {})
		var all_own := groups.all(func(g): return g.size() == 1) and not coop_selected()
		_mode_buttons[0].set_pressed_no_signal(all_own)
		_mode_buttons[1].set_pressed_no_signal(coop_selected())
		if voting:
			_fill_maps(Net.vote_winner(false))
		var map_name := tr(str(s.get("map_name", ""))) if str(s.get("map_name", "")) != "" else tr(_map_name())
		if no_map and str(s.get("map_name", "")) == "":
			map_name = mode_name
		if not started and s.has("coop"):
			_session_text.text = tr("Gespeicherter Koop auf %s. „Starten“ setzt das gemeinsame Feld fort, wer fehlt, kann später einsteigen.") % map_name
		elif started and s.has("coop"):
			_session_text.text = tr("Koop auf %s läuft. Mitspieler, die das Spiel verlassen haben, steigen über „Mitspielen“ wieder ein.") % map_name
		elif voting and no_map:
			_session_text.text = tr("%s: „Starten“ startet alle Verbundenen zusammen, jeder mit eigenem Gebiet und eigenem Gold, die Leben sind gemeinsam. Schwierigkeit und Modus wählt der Host.") % mode_name
		elif not started and coop_selected() and not loaded:
			_session_text.text = tr("Koop auf %s: „Starten“ startet alle Verbundenen auf einem gemeinsamen Feld, Schwierigkeit und Wertung vom Host.") % map_name
		elif voting and not coop_selected() and groups.any(func(g): return g.size() > 1):
			_session_text.text = tr("Gemischt auf %s: wer dieselbe Feldnummer hat, spielt zusammen auf einem Feld, die anderen allein. Klick auf „Feld“ in der Spielerliste ändert die Zuordnung.") % map_name
		elif started:
			_session_text.text = tr("Die Sitzung läuft auf %s. Wer dazukommt, steigt über „Mitspielen“ ein, mit seinem gespeicherten Stand, falls es einen gibt.") % map_name
		elif loaded:
			_session_text.text = tr("Gespeicherte Sitzung auf %s. „Starten“ setzt für jeden Verbundenen seinen Stand fort, wer fehlt, kann später einsteigen.") % map_name
		else:
			_session_text.text = tr("Neue Sitzung auf %s: „Starten“ startet alle Verbundenen gleichzeitig.") % map_name
		_start_button.visible = not started
		_start_button.text = (tr("Starten: %s") % mode_name if no_map else tr("Starten: %s · %s") % [mode_name, map_name]) if voting else tr("Starten")
		_start_button.disabled = voting and ((_map_path == "" and not no_map) or Net.vote_tally().is_empty())
		_play_button.visible = started
	else:
		_addresses.visible = false
		_internet.get_parent().visible = false
		var info := Net.session_info
		started = bool(info.get("started", false))
		loaded = bool(info.get("loaded", false))
		var own := tr("Dein gespeicherter Stand: Welle %d.") % int(info.get("wave", 0)) if info.get("has_state", false) else tr("Du startest neu.")
		if info.get("coop", false):
			own = tr("Koop: ihr spielt zusammen auf einem Feld.")
		if info.is_empty():
			_session_text.text = tr("Warte auf den Host …")
		elif started:
			_session_text.text = tr("Die Sitzung läuft auf %s.") % tr(str(info.get("map", ""))) + " " + own
		else:
			_session_text.text = tr("Warte, bis der Host die Sitzung startet.") + " " + own
		_play_button.visible = true
		_play_button.disabled = not started

	if started or loaded:
		_show_votes(false, true)
		var fixed := str(Net.session.get("mode", "") if Net.is_host() else Net.session_info.get("mode", ""))
		_summary.text = tr("Modus dieser Sitzung: %s") % _mode_name(fixed if fixed != "" else Session.game_kind)
	else:
		_show_votes(true, true)
		_summary.text = _vote_text()

	var n := Net.player_count()
	_players_caption.text = (tr("Spieler · %d") % n).to_upper()
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var v := Net.votes()
	for slot in Net.session_slots():
		_slot_row(slot, str(v.get(str(slot.get("uid", "")), "")) if not (started or loaded) else "")


## Abstimmungskarten: sichtbar nur, solange abgestimmt wird; active false = grau (nicht verbunden).
func _show_votes(voting: bool, active: bool) -> void:
	_vote_caption.visible = voting or not active
	_vote_row.visible = voting or not active
	var n := Net.player_count()
	var mine := Net.my_vote()
	var counts := {}
	for e in Net.vote_tally():
		counts[e.id] = e
	for card in _vote_cards:
		var m := Database.mode(card.mode_id)
		var ok := active and Database.mode_allows(card.mode_id, n)
		var tag := ""
		if not bool(m.get("ready", false)):
			tag = tr("Kommt noch")
		elif active and not ok:
			tag = Database.mode_players_text(card.mode_id)
		card.set_state(mine == card.mode_id, ok, tag)
		if ok and counts.has(card.mode_id):
			card.set_votes(int(counts[card.mode_id].count), n, counts[card.mode_id].names)
		elif active and bool(m.get("ready", false)):
			card.set_votes(0, n, [], tr("nicht für %d Spieler") % n)
		else:
			card.hide_votes()


func _vote_text() -> String:
	var tally := Net.vote_tally()
	if tally.is_empty():
		return tr("Kein Modus ist für %d Spieler erlaubt.") % Net.player_count()
	var leaders := Net.vote_leaders()
	var n := Net.player_count()
	if int(tally[0].count) == 0:
		return tr("Noch keine Stimmen. Ohne Stimmen gilt %s.") % _mode_name(Net.vote_winner(false))
	if leaders.size() == 1:
		return tr("Vorne: %s mit %d von %d Stimmen.") % [_mode_name(leaders[0]), int(tally[0].count), n]
	var names := " / ".join(leaders.map(func(id): return _mode_name(id)))
	var winner := Net.vote_winner(false)
	var host_vote := ""
	for slot in Net.session_slots():
		if int(slot.get("peer", -1)) == 1:
			host_vote = str(Net.votes().get(str(slot.get("uid", "")), ""))
	if leaders.has(host_vote):
		return tr("Gleichstand: %s. Die Stimme des Hosts entscheidet: %s.") % [names, _mode_name(winner)]
	return tr("Gleichstand: %s. Der Host hat keinen davon gewählt, beim Start entscheidet das Los.") % names


func _mode_name(id: String) -> String:
	return str(Database.mode(id).get("name", id))


## Map-Auswahl des Hosts für den Modus, der gerade vorne liegt (Auswahl bleibt, solange die Map passt).
func _fill_maps(mode_id: String) -> void:
	var list := Database.maps_for_mode(mode_id, maps)
	var paths := list.map(func(m): return str(m.path))
	if paths == _map_paths:
		return
	_map_paths = paths
	_map_option.clear()
	for m in list:
		_map_option.add_item(tr(str(m.name)))
	if not paths.has(_map_path):
		_map_path = Session.map_path if paths.has(Session.map_path) else (str(paths[0]) if not paths.is_empty() else "")
	if _map_path != "":
		_map_option.select(paths.find(_map_path))


func _map_name() -> String:
	var i := _map_paths.find(_map_path)
	return _map_option.get_item_text(i) if i >= 0 else ""


## Host: Adresse fürs Internet (öffentliche IP, Portfreigabe per UPnP) und fürs eigene Netzwerk.
func _show_addresses() -> void:
	_internet.get_parent().visible = true
	if Net.via_relay():
		_internet.text = tr("Code: %s") % Net.room_code()
		_internet.add_theme_color_override("font_color", DecoTheme.GOLD)
		_internet.add_theme_font_size_override("font_size", 20)
		_copy_button.visible = true
		_copy_button.tooltip_text = tr("Code in die Zwischenablage kopieren, um ihn den Mitspielern zu schicken")
		_addresses.text = tr("Über den Server %s. Mitspieler geben den Code ein, niemand muss einen Port freigeben.") % Net.relay_connection()
		_addresses.visible = true
		return
	_copy_button.tooltip_text = tr("Adresse in die Zwischenablage kopieren, um sie den Mitspielern zu schicken")
	_internet.add_theme_font_size_override("font_size", 14)
	if Net.public_ip != "":
		_internet.text = tr("Internet: %s") % Net.public_ip
	else:
		_internet.text = tr("Internet: Adresse nicht ermittelbar") if Net.public_ip_failed else tr("Internet: Adresse wird ermittelt …")
	_internet.add_theme_color_override("font_color", DecoTheme.TEXT)
	_copy_button.visible = Net.public_ip != ""
	var port := Net.host_port
	var lines := []
	match Net.upnp_state:
		"busy":
			lines.append(tr("Router wird gefragt, ob er UDP-Port %d freigibt …") % port)
		"open":
			if Net.behind_cgnat():
				lines.append(tr("Dein Anschluss hat keine eigene öffentliche Adresse (CGNAT), Mitspieler aus dem Internet erreichen dich so nicht. Nutzt ein virtuelles LAN wie Tailscale oder ZeroTier."))
			else:
				lines.append(tr("UDP-Port %d ist im Router freigegeben, Mitspieler aus dem Internet können beitreten.") % port)
		"failed":
			lines.append(tr("Der Router hat UDP-Port %d nicht automatisch freigegeben (UPnP aus?). Gib ihn im Router von Hand für diesen PC frei, oder nutzt Tailscale oder ZeroTier.") % port)
	var addrs := Net.local_addresses()
	if not addrs.is_empty():
		lines.append(tr("Im selben Netzwerk: %s") % ", ".join(addrs))
	_addresses.text = "\n".join(lines)
	_addresses.visible = not lines.is_empty()


## Zeile in der Spielerliste; vote: Modus, für den der Spieler gestimmt hat ("" = keine Stimme).
func _slot_row(slot: Dictionary, vote: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_list.add_child(row)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color = DecoTheme.HAVE if slot.get("online", false) else DecoTheme.BORDER_2
	row.add_child(dot)
	var peer := int(slot.get("peer", -1))
	var me := peer == Net.my_id()
	var n := UiUtil.label(str(slot.get("name", "?")) + ("  " + tr("(du)") if me else ""), row, 14)
	n.custom_minimum_size.x = 170
	n.clip_text = true
	var parts := []
	if not slot.get("online", false):
		parts.append(tr("nicht verbunden"))
	elif Net.players.has(peer):
		parts.append(NetPanel.status_text(Net.player_status(peer)))
	if slot.get("has_state", false):
		parts.append(tr("gespeichert: Welle %d") % int(slot.get("wave", 0)))
	var info := UiUtil.label(" · ".join(parts), row, 15)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_color_override("font_color", DecoTheme.MUTED)
	var field := int(slot.get("field", -1))
	if field >= 0 and slot.get("online", false):
		var u := str(slot.get("uid", ""))
		var fb := UiUtil.button(tr("Feld %d") % (field + 1), row, func(): _next_field(u))
		fb.focus_mode = Control.FOCUS_NONE
		fb.custom_minimum_size = Vector2(84, 28)
		fb.disabled = not Net.is_host()
		fb.tooltip_text = tr("Gleiche Feldnummer = zusammen auf einem Feld (Koop). Klick = nächstes Feld.") if Net.is_host() \
			else tr("Der Host teilt die Felder ein.")
		var same: int = Net.session_slots().filter(func(sl): return int(sl.get("field", -1)) == field and sl.get("online", false)).size()
		if same > 1:
			fb.add_theme_stylebox_override("normal", DecoTheme.box(DecoTheme.CYAN, DecoTheme.CYAN, 0, 2, 4))
			fb.add_theme_stylebox_override("disabled", DecoTheme.box(DecoTheme.CYAN, DecoTheme.CYAN, 0, 2, 4))
			fb.add_theme_color_override("font_color", DecoTheme.GOLD_DARK)
			fb.add_theme_color_override("font_disabled_color", DecoTheme.GOLD_DARK)
	if vote != "":
		var vl := UiUtil.label(_mode_name(vote), row, 15)
		vl.add_theme_color_override("font_color", DecoTheme.GOLD)
