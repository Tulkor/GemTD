class_name LobbyPanel
extends Control
## Mehrspieler-Fenster im Hauptmenü: Name, Hosten, Beitreten per IP, Spielerliste.
## Modus 1: jeder spielt sein eigenes Feld und startet unabhängig über „Spielen“;
## der Host kann zusätzlich alle gleichzeitig auf der gewählten Map starten.

signal start_all_requested

var _name_edit: LineEdit
var _ip_edit: LineEdit
var _status: Label
var _addresses: Label
var _list: VBoxContainer
var _host_button: Button
var _join_button: Button
var _leave_button: Button
var _start_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL, UiTheme.BORDER_2, 12, 1, 24))
	panel.custom_minimum_size.x = 560
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var title := UiUtil.label("Mehrspieler", v, 26)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	var hint := UiUtil.wrap_label("Jeder spielt sein eigenes Feld und startet, wann er will. Im Spiel kannst du über „Zuschauen“ die Felder der anderen ansehen.", v, 500)
	hint.add_theme_color_override("font_color", UiTheme.MUTED)

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

	var host_row := HBoxContainer.new()
	host_row.add_theme_constant_override("separation", 10)
	v.add_child(host_row)
	_host_button = UiUtil.button("Spiel hosten", host_row, func(): Net.host())
	_addresses = UiUtil.label("", host_row, 13)
	_addresses.add_theme_color_override("font_color", UiTheme.MUTED)
	_addresses.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_addresses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 10)
	v.add_child(join_row)
	_ip_edit = LineEdit.new()
	_ip_edit.text = Net.last_ip
	_ip_edit.placeholder_text = "IP-Adresse des Hosts"
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_edit.text_submitted.connect(func(_t): _join())
	join_row.add_child(_ip_edit)
	_join_button = UiUtil.button("Beitreten", join_row, _join)

	_status = UiUtil.label("", v, 14)
	_status.add_theme_color_override("font_color", UiTheme.GOLD)

	UiTheme.caption("Spieler", v)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	v.add_child(_list)

	var port_hint := UiUtil.wrap_label(tr("Im selben Netzwerk reicht die angezeigte Adresse. Übers Internet muss der Host UDP-Port %d am Router freigeben, oder ihr nutzt ein virtuelles LAN wie Tailscale oder ZeroTier.") % Net.DEFAULT_PORT, v, 500)
	port_hint.add_theme_color_override("font_color", UiTheme.MUTED)
	port_hint.add_theme_font_size_override("font_size", 12)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	v.add_child(buttons)
	_start_button = UiUtil.button("Alle starten", buttons, func(): start_all_requested.emit())
	_start_button.tooltip_text = "Startet alle Verbundenen gleichzeitig auf der gewählten Map"
	UiTheme.accent_button(_start_button, UiTheme.GOLD, UiTheme.GOLD_DARK, Color(UiTheme.GOLD, 0.3))
	_leave_button = UiUtil.button("Trennen", buttons, func(): Net.leave())
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(fill)
	UiUtil.button("Schließen", buttons, hide)

	Net.players_changed.connect(_refresh)
	Net.connection_changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide()
		get_viewport().set_input_as_handled()


func _join() -> void:
	var ip := _ip_edit.text.strip_edges()
	if ip != "":
		Net.join(ip)


func _refresh() -> void:
	if _list == null:
		return
	var online := Net.is_active() or Net.is_connecting()
	_host_button.disabled = online
	_join_button.disabled = online
	_ip_edit.editable = not online
	_leave_button.disabled = not online
	_start_button.visible = Net.is_host()
	_start_button.disabled = Net.players.is_empty()
	_status.text = Net.status_text
	_status.visible = Net.status_text != ""
	if Net.is_host():
		var addrs := Net.local_addresses()
		_addresses.text = tr("Deine Adresse: %s") % ", ".join(addrs) if not addrs.is_empty() else ""
	else:
		_addresses.text = ""
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if not Net.is_active():
		UiUtil.label("Nicht verbunden", _list, 13).add_theme_color_override("font_color", UiTheme.MUTED)
		return
	UiUtil.label(Net.my_name + "  " + tr("(du)"), _list, 14)
	var ids := Net.players.keys()
	ids.sort()
	for id in ids:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_list.add_child(row)
		UiUtil.label(Net.player_name(id), row, 14)
		UiUtil.label(NetPanel.status_text(Net.player_status(id)), row, 13).add_theme_color_override("font_color", UiTheme.MUTED)
