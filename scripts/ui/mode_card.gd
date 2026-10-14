class_name ModeCard
extends Button
## Karte für einen TD-Modus (Einzelspieler-Auswahl und Lobby): Name, Beschreibung, erlaubte Spielerzahl.
## Ausgewählt (bzw. eigene Stimme) wie alle gedrückten Knöpfe: Cyan mit dunkler Schrift.
## In der Lobby kommen unter die Beschreibung Stimmen-Balken und Namen (set_votes).

var mode_id := ""
var _labels: Array[Label] = []
var _name: Label
var _hint: Label
var _players: Label
var _tag: Label
var _votes_box: VBoxContainer
var _bar_fill: ColorRect
var _count: Label
var _who: Label


func _init(m: Dictionary, card_size := Vector2(330, 190)) -> void:
	mode_id = str(m.get("id", ""))
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = card_size
	add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL_2, UiTheme.BORDER, 0, 2))
	add_theme_stylebox_override("hover", UiTheme.box(UiTheme.PANEL_2, UiTheme.GOLD, 0, 2))
	add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
	add_theme_stylebox_override("hover_pressed", UiTheme.box(UiTheme.CYAN, UiTheme.GOLD, 0, 2))
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_top = 14
	v.offset_right = -16
	v.offset_bottom = -14
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	_name = _label(str(m.get("name", mode_id)).to_upper(), v, 21)
	_name.add_theme_font_override("font", UiTheme.font(true))
	# Hinweis („Kommt noch“, erlaubte Spielerzahl) unter dem Namen, damit lange Namen Platz haben
	_tag = _label("", v, 11)
	_tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_hint = _label(tr(str(m.get("hint", ""))), v, 13)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = card_size.x - 32
	_votes_box = VBoxContainer.new()
	_votes_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_votes_box.add_theme_constant_override("separation", 4)
	_votes_box.visible = false
	v.add_child(_votes_box)
	var bar := ColorRect.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.color = UiTheme.BORDER
	bar.custom_minimum_size.y = 10
	_votes_box.add_child(bar)
	_bar_fill = ColorRect.new()
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill.color = UiTheme.GOLD
	_bar_fill.anchor_bottom = 1.0
	bar.add_child(_bar_fill)
	_count = _label("", _votes_box, 15)
	_who = _label("", _votes_box, 12)
	_who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_who.custom_minimum_size.x = card_size.x - 32
	var fill := Control.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	_players = _label(Database.mode_players_text(mode_id), v, 13)
	set_state(false, true)


func _label(text: String, parent: Node, font_size: int) -> Label:
	var l := UiUtil.label(text, parent, font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_labels.append(l)
	return l


## on: ausgewählt / eigene Stimme. enabled false: grau, nicht anklickbar. tag: kleiner Hinweis oben rechts.
func set_state(on: bool, enabled: bool, tag := "") -> void:
	disabled = not enabled
	set_pressed_no_signal(on and enabled)
	_players.text = Database.mode_players_text(mode_id)
	_tag.text = tag.to_upper()
	_tag.visible = tag != ""
	var dark := on and enabled
	var main := UiTheme.GOLD_DARK if dark else (UiTheme.TEXT if enabled else UiTheme.BORDER_2)
	var soft := UiTheme.GOLD_DARK if dark else (UiTheme.MUTED if enabled else UiTheme.BORDER_2)
	_name.add_theme_color_override("font_color", main)
	_count.add_theme_color_override("font_color", main)
	_hint.add_theme_color_override("font_color", soft)
	_who.add_theme_color_override("font_color", soft)
	_players.add_theme_color_override("font_color", UiTheme.GOLD_DARK if dark else (UiTheme.CYAN if enabled else UiTheme.BORDER_2))
	var tag_box := UiTheme.box(Color.TRANSPARENT, soft, 0, 2, 5)
	_tag.add_theme_stylebox_override("normal", tag_box)
	_tag.add_theme_color_override("font_color", soft)


## Lobby: Stimmen anzeigen (total = alle Spieler, für die Balkenlänge). note ersetzt den Zähler.
func set_votes(count: int, total: int, names: Array, note := "") -> void:
	_votes_box.visible = true
	_bar_fill.get_parent().visible = note == ""
	_bar_fill.anchor_right = float(count) / maxf(total, 1)
	_count.text = note if note != "" else (tr("%d Stimme") % count if count == 1 else tr("%d Stimmen") % count)
	_who.text = ", ".join(names)
	_who.visible = not names.is_empty()


func hide_votes() -> void:
	_votes_box.visible = false
