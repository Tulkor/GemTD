class_name SetupPanel
extends Control
## Einstellungen vor Runde 1, wenn die Map schon geladen ist: Schwierigkeit und Wertung. Stil wie das HUD (Arcade).
## „Los geht's“ schickt den Befehl setup (game.gd). Im Koop wählt nur der Host, die Mitspieler warten hier,
## bis sein Stand kommt. Das Fenster schließt sich von selbst, sobald game.setup_done gesetzt ist.

const MODES := [
	["Leben", false, "Wer durchkommt, kostet Leben. Bei 0 ist das Spiel verloren."],
	["Punkte", true, "Kills geben Punkte, späte Wellen mehr als frühe. Wer durchkommt, kostet die Hälfte seines Werts. Gespielt wird bis zur letzten Welle."],
]

## Spielvarianten: [Name, Roguelike an, Erklärung]
const VARIANTS := [
	["Klassisch", false, "GemTD wie im Original."],
	["Roguelike", true, "Nach jeder zehnten Welle wählst du einen von drei zufälligen Boni: mehr Schaden, Tempo oder Reichweite für einen Grund-Gem in allen Stufen oder für einen Spezialtower."],
]

var game  # game.gd
var difficulty := 1
var score_mode := false
var rogue := false
var _mode_text: Label
var _variant_text: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	# Nur das Fenster fängt Klicks, die Leiste oben (Menü) bleibt bedienbar; das Feld sperrt game.gd
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	difficulty = Session.difficulty
	score_mode = Session.score_mode
	rogue = Session.rogue
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(24.0))
	panel.custom_minimum_size.x = 520
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	UiTheme.title(UiUtil.label("Einstellungen", v, 26))
	var info := UiUtil.label(tr(game.map.name) + " · " + tr("%d Wellen") % game.waves.size(), v, 15)
	info.add_theme_color_override("font_color", UiTheme.MUTED)
	var host: bool = game.local_player == 0

	UiTheme.caption("Schwierigkeit", v)
	var h := _row(v)
	var group := ButtonGroup.new()
	for i in Session.DIFFICULTIES.size():
		var d: Dictionary = Session.DIFFICULTIES[i]
		var idx := i
		var b := _toggle(str(d.name), h, group, i == difficulty, func(): difficulty = idx)
		b.tooltip_text = tr("Gegner: Leben und Rüstung ×%s") % str(d.factor)
		b.disabled = not host

	UiTheme.caption("Wertung", v)
	h = _row(v)
	group = ButtonGroup.new()
	for m in MODES:
		var on: bool = m[1]
		var b := _toggle(str(m[0]), h, group, on == score_mode, func():
			score_mode = on
			_update_text())
		b.tooltip_text = str(m[2])
		b.disabled = not host
	_mode_text = UiUtil.wrap_label("", v, 470)
	_mode_text.add_theme_color_override("font_color", UiTheme.DIM)
	_update_text()

	UiTheme.caption("Variante", v)
	h = _row(v)
	group = ButtonGroup.new()
	for m in VARIANTS:
		var on: bool = m[1]
		var b := _toggle(str(m[0]), h, group, on == rogue, func():
			rogue = on
			_update_text())
		b.tooltip_text = str(m[2])
		b.disabled = not host
	_variant_text = UiUtil.wrap_label("", v, 470)
	_variant_text.add_theme_color_override("font_color", UiTheme.DIM)
	_update_text()

	if host:
		var go := UiUtil.button("Los geht's", v, func(): game.submit({"type": "setup", "difficulty": difficulty, "score_mode": score_mode, "rogue": rogue}))
		go.custom_minimum_size.y = 50
		go.add_theme_font_size_override("font_size", 20)
		UiTheme.accent_button(go, UiTheme.GOLD, UiTheme.GOLD_DARK)
	else:
		var wait := UiUtil.wrap_label("Der Host wählt die Einstellungen, gleich geht es los …", v, 470)
		wait.add_theme_color_override("font_color", UiTheme.CYAN)


func _process(_delta: float) -> void:
	if game.setup_done:
		queue_free()


func _update_text() -> void:
	_mode_text.text = tr(str(MODES[1 if score_mode else 0][2]))
	if _variant_text != null:
		_variant_text.text = tr(str(VARIANTS[1 if rogue else 0][2]))


func _row(parent: Node) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	parent.add_child(h)
	return h


func _toggle(text: String, parent: Node, group: ButtonGroup, on: bool, pressed: Callable) -> Button:
	var b := UiUtil.button(text, parent, pressed)
	b.toggle_mode = true
	b.button_group = group
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 38
	b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
	b.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
	b.set_pressed_no_signal(on)
	return b
