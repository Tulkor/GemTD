class_name LobbyPanel
extends Control
## Mehrspieler-Lobby im Hauptmenü. Ohne Verbindung: Name, Sitzung hosten, per IP beitreten.
## Spielart (Host, vor dem Start): jeder auf seinem eigenen Feld, oder Koop auf einem gemeinsamen Feld.
## Als Host: Sitzung mit allen Plätzen (auch gespeicherte von Mitspielern, die gerade fehlen) und „Starten“.
## Als Mitspieler: Stand der Sitzung und „Mitspielen“, auch später noch zum Wiedereinsteigen.
## Gespeicherte Sitzungen lädt der Host über „Spiel laden“ (load_panel.gd).

signal start_requested

## Name der im Hauptmenü gewählten Map (für eine neue Sitzung).
var selected_map := ""
## Koop gewählt: alle spielen zusammen auf einem Feld (der Host rechnet, siehe coop_sync.gd).
var coop_mode := false

var _name_edit: LineEdit
var _ip_edit: LineEdit
var _status: Label
var _offline: VBoxContainer
var _online: VBoxContainer
var _addresses: Label
var _internet: Label
var _copy_button: Button
var _session_text: Label
var _list: VBoxContainer
var _start_button: Button
var _mode_box: VBoxContainer
var _mode_buttons: Array[Button] = []
var _play_button: Button
var _leave_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(24.0))
	panel.custom_minimum_size.x = 600
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	UiTheme.title(UiUtil.label("Mehrspieler", v, 26))
	_muted(UiUtil.wrap_label("Zwei Spielarten: jeder auf seinem eigenen Feld (über „Zuschauen“ siehst du die anderen) oder Koop auf einem gemeinsamen Feld. Nur der Host speichert, für alle.", v, 540))

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	v.add_child(name_row)
	UiUtil.label("Name", name_row, 15).custom_minimum_size.x = 90
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
	var host := UiUtil.button("Neue Sitzung hosten", _offline, func(): Net.host())
	host.custom_minimum_size.y = 44
	_muted(UiUtil.wrap_label("Eine gespeicherte Sitzung setzt du über „Spiel laden“ im Hauptmenü fort.", _offline, 540)).add_theme_font_size_override("font_size", 13)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 10)
	_offline.add_child(join_row)
	_ip_edit = LineEdit.new()
	_ip_edit.text = Net.last_ip
	_ip_edit.placeholder_text = "IP-Adresse des Hosts"
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_edit.text_submitted.connect(func(_t): _join())
	join_row.add_child(_ip_edit)
	UiUtil.button("Beitreten", join_row, _join).custom_minimum_size.x = 130
	var port_hint := _muted(UiUtil.wrap_label(tr("Im selben Netzwerk reicht die angezeigte Adresse. Übers Internet muss der Host UDP-Port %d am Router freigeben, oder ihr nutzt ein virtuelles LAN wie Tailscale oder ZeroTier.") % Net.DEFAULT_PORT, _offline, 540))
	port_hint.add_theme_font_size_override("font_size", 12)

	_status = UiUtil.label("", v, 14)
	_status.add_theme_color_override("font_color", UiTheme.CYAN)

	# Verbunden: Sitzung und Plätze
	_online = VBoxContainer.new()
	_online.add_theme_constant_override("separation", 10)
	v.add_child(_online)
	var net_row := HBoxContainer.new()
	net_row.add_theme_constant_override("separation", 10)
	_online.add_child(net_row)
	_internet = UiUtil.label("", net_row, 15)
	_internet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_internet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_copy_button = UiUtil.button("Kopieren", net_row, func(): DisplayServer.clipboard_set(Net.public_ip))
	_copy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_copy_button.tooltip_text = "Adresse in die Zwischenablage kopieren, um sie den Mitspielern zu schicken"
	_addresses = _muted(UiUtil.label("", _online, 13))
	_addresses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_addresses.custom_minimum_size.x = 540
	_mode_box = VBoxContainer.new()
	_mode_box.add_theme_constant_override("separation", 6)
	_online.add_child(_mode_box)
	UiTheme.caption("Spielart", _mode_box)
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 6)
	_mode_box.add_child(modes)
	var group := ButtonGroup.new()
	for coop in [false, true]:
		var on: bool = coop
		var b := UiUtil.button("Koop: ein gemeinsames Feld" if coop else "Jeder sein eigenes Feld", modes, func():
			coop_mode = on
			_refresh())
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 36
		b.tooltip_text = tr("Alle bauen zusammen ein Labyrinth: jeder setzt und wählt seine eigenen Gems, hat eigenes Gold und kombiniert nur eigene Tower. Die Leben sind gemeinsam.") if coop \
			else tr("Jeder spielt sein eigenes Feld, über „Zuschauen“ sieht man die anderen.")
		b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
		b.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
		b.set_pressed_no_signal(coop == coop_mode)
		_mode_buttons.append(b)
	UiTheme.caption("Sitzung", _online)
	_session_text = UiUtil.wrap_label("", _online, 540)
	_session_text.add_theme_color_override("font_color", UiTheme.DIM)
	UiTheme.caption("Spieler", _online)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_online.add_child(_list)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	v.add_child(buttons)
	_start_button = UiUtil.button("Starten", buttons, func(): start_requested.emit())
	_start_button.custom_minimum_size = Vector2(150, 46)
	UiTheme.accent_button(_start_button, UiTheme.GOLD, UiTheme.GOLD_DARK)
	_play_button = UiUtil.button("Mitspielen", buttons, func(): Net.join_session())
	_play_button.custom_minimum_size = Vector2(150, 46)
	UiTheme.accent_button(_play_button, UiTheme.GOLD, UiTheme.GOLD_DARK)
	_leave_button = UiUtil.button("Trennen", buttons, func(): Net.leave())
	_leave_button.custom_minimum_size.y = 46
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(fill)
	UiUtil.button("Schließen", buttons, hide).custom_minimum_size.y = 46

	Net.players_changed.connect(_refresh)
	Net.connection_changed.connect(_refresh)
	Net.session_changed.connect(_refresh)
	visibility_changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide()
		get_viewport().set_input_as_handled()


func _muted(l: Label) -> Label:
	l.add_theme_color_override("font_color", UiTheme.MUTED)
	return l


func _join() -> void:
	var ip := _ip_edit.text.strip_edges()
	if ip != "":
		Net.join(ip)


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
	if not online:
		return

	var started := false
	if Net.is_host():
		_show_addresses()
		var s := Net.session
		started = bool(s.get("started", false))
		var map_name := tr(str(s.get("map_name", ""))) if str(s.get("map_name", "")) != "" else tr(selected_map)
		# Spielart wählt man nur für eine neue Sitzung, eine gespeicherte bringt ihre mit
		_mode_box.visible = not started and not s.get("loaded", false)
		if not started and s.has("coop"):
			_session_text.text = tr("Gespeicherter Koop auf %s. „Starten“ setzt das gemeinsame Feld fort, wer fehlt, kann später einsteigen.") % map_name
		elif started and s.has("coop"):
			_session_text.text = tr("Koop auf %s läuft. Mitspieler, die das Spiel verlassen haben, steigen über „Mitspielen“ wieder ein.") % map_name
		elif not started and coop_mode and not s.get("loaded", false):
			_session_text.text = tr("Koop auf %s (Map im Hauptmenü wählen). „Starten“ startet alle Verbundenen auf einem gemeinsamen Feld, Schwierigkeit und Wertung vom Host.") % map_name
		elif started:
			_session_text.text = tr("Die Sitzung läuft auf %s. Wer dazukommt, steigt über „Mitspielen“ ein, mit seinem gespeicherten Stand, falls es einen gibt.") % map_name
		elif s.get("loaded", false):
			_session_text.text = tr("Gespeicherte Sitzung auf %s. „Starten“ setzt für jeden Verbundenen seinen Stand fort, wer fehlt, kann später einsteigen.") % map_name
		else:
			_session_text.text = tr("Neue Sitzung auf %s (Map im Hauptmenü wählen). „Starten“ startet alle Verbundenen gleichzeitig.") % map_name
		_start_button.visible = not started
		_play_button.visible = started
	else:
		_addresses.visible = false
		_internet.get_parent().visible = false
		_mode_box.visible = false
		var info := Net.session_info
		started = bool(info.get("started", false))
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

	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for slot in Net.session_slots():
		_slot_row(slot)


## Host: Adresse fürs Internet (öffentliche IP, Portfreigabe per UPnP) und fürs eigene Netzwerk.
func _show_addresses() -> void:
	_internet.get_parent().visible = true
	if Net.public_ip != "":
		_internet.text = tr("Internet: %s") % Net.public_ip
	else:
		_internet.text = tr("Internet: Adresse nicht ermittelbar") if Net.public_ip_failed else tr("Internet: Adresse wird ermittelt …")
	_internet.add_theme_color_override("font_color", UiTheme.TEXT)
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


func _slot_row(slot: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_list.add_child(row)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color = UiTheme.HAVE if slot.get("online", false) else UiTheme.BORDER_2
	row.add_child(dot)
	var peer := int(slot.get("peer", -1))
	var me := peer == Net.my_id()
	var n := UiUtil.label(str(slot.get("name", "?")) + ("  " + tr("(du)") if me else ""), row, 14)
	n.custom_minimum_size.x = 200
	n.clip_text = true
	var parts := []
	if not slot.get("online", false):
		parts.append(tr("nicht verbunden"))
	elif Net.players.has(peer):
		parts.append(NetPanel.status_text(Net.player_status(peer)))
	if slot.get("has_state", false):
		parts.append(tr("gespeichert: Welle %d") % int(slot.get("wave", 0)))
	var info := UiUtil.label(" · ".join(parts), row, 13)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_color_override("font_color", UiTheme.MUTED)
