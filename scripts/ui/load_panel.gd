class_name LoadPanel
extends Control
## „Spiel laden“ im Hauptmenü: alle Spielstände, neueste zuerst. Einzelspiele gehen direkt weiter,
## Mehrspieler-Sitzungen werden gehostet und in der Lobby fortgesetzt.

signal load_requested(data: Dictionary)

var _list: VBoxContainer
var _empty: Label
var _confirm_id := ""   ## Spielstand, dessen „Löschen“ einmal gedrückt wurde


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(DecoTheme.BAR, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", DecoTheme.panel(24.0))
	panel.custom_minimum_size = Vector2(680, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	DecoTheme.title(UiUtil.label("Spiel laden", v, 38)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := UiUtil.wrap_label("Spielstände sind verschlüsselt und lassen sich nach einer Änderung nicht mehr laden.", v, 620)
	hint.add_theme_color_override("font_color", DecoTheme.MUTED)
	hint.add_theme_font_size_override("font_size", 13)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	_empty = UiUtil.label("Noch keine Spielstände. Beim Verlassen einer Partie fragt das Spiel, ob es speichern soll.", v, 14)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.custom_minimum_size.x = 620
	_empty.add_theme_color_override("font_color", DecoTheme.MUTED)

	var buttons := HBoxContainer.new()
	v.add_child(buttons)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(fill)
	UiUtil.button("Schließen", buttons, hide).custom_minimum_size.y = 46
	visibility_changed.connect(func():
		if visible:
			_confirm_id = ""
			refresh())


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var saves := SaveGame.list()
	_empty.visible = saves.is_empty()
	_list.get_parent().visible = not saves.is_empty()
	for s in saves:
		_row(s)


func _row(s: Dictionary) -> void:
	var id := str(s.id)
	var m: Dictionary = s.meta
	var multi: bool = s.kind in ["multi", "coop"]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", DecoTheme.box(DecoTheme.PANEL_2, DecoTheme.BORDER, 0, 2, 12))
	_list.add_child(card)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 4)
	h.add_child(texts)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	texts.add_child(top)
	var kind := UiUtil.label(tr("Koop") if s.kind == "coop" else tr("Mehrspieler") if multi else tr("Einzelspiel"), top, 12)
	kind.add_theme_color_override("font_color", DecoTheme.CYAN if multi else DecoTheme.PURPLE_LIGHT)
	kind.uppercase = true
	UiUtil.label(tr(str(m.get("map", "?"))), top, 17)

	var diff: Dictionary = Session.DIFFICULTIES[clampi(int(m.get("difficulty", 1)), 0, Session.DIFFICULTIES.size() - 1)]
	var line := [tr("Welle %d/%d") % [int(m.get("wave", 1)), int(m.get("waves", 0))], tr("Punkte %d") % int(m.get("score", 0)) if m.get("score_mode", false) else tr("Leben %d") % int(m.get("lives", 0)),
		tr(str(diff.name)), _date(int(m.get("time", 0)))]
	var info := UiUtil.label(" · ".join(line), texts, 13)
	info.add_theme_color_override("font_color", DecoTheme.MUTED)
	if multi:
		var who := UiUtil.label(tr("Spieler: %s") % ", ".join(m.get("players", [])), texts, 13)
		who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		who.custom_minimum_size.x = 380
		who.add_theme_color_override("font_color", DecoTheme.DIM)

	var del := UiUtil.button(tr("Wirklich löschen?") if _confirm_id == id else tr("Löschen"), h, func(): _delete(id))
	del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	del.custom_minimum_size.y = 42
	del.add_theme_color_override("font_color", DecoTheme.MISSING)
	del.add_theme_color_override("font_hover_color", DecoTheme.MISSING.lightened(0.2))
	var open := UiUtil.button(tr("Hosten") if multi else tr("Laden"), h, func(): _load(id))
	open.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	open.custom_minimum_size = Vector2(120, 42)
	DecoTheme.accent_button(open, DecoTheme.GOLD, DecoTheme.GOLD_DARK)
	if multi:
		open.tooltip_text = tr("Startet die Sitzung als Host, die Mitspieler treten wieder bei.")


func _load(id: String) -> void:
	var data := SaveGame.read(SaveGame.path_for(id))
	if data.is_empty():
		refresh()
		return
	hide()
	load_requested.emit(data)


func _delete(id: String) -> void:
	if _confirm_id != id:
		_confirm_id = id
		refresh()
		return
	_confirm_id = ""
	SaveGame.remove(id)
	refresh()


## Datum in Ortszeit, z. B. 11.10.2026 14:05
static func _date(t: int) -> String:
	if t <= 0:
		return ""
	var local := t + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(local)
	return "%02d.%02d.%d %02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute]
