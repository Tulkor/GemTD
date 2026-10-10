class_name UiTheme
extends RefCounted
## Gemeinsame Farben und das Godot-Theme für alle Oberflächen.

const BG := Color("0f1116")
const BAR := Color("12151c")
const PANEL := Color("161921")
const PANEL_2 := Color("1c2029")
const BORDER := Color("2c3240")
const BORDER_2 := Color("3a4152")
const TEXT := Color("ece8de")
const MUTED := Color("a3a9b6")
const DIM := Color("c9cdd6")
const GOLD := Color("e2b54a")
const GOLD_DARK := Color("1a1406")
const PURPLE := Color("7b3fe4")
const PURPLE_LIGHT := Color("a66bff")
const HAVE := Color("5fd07a")
const MISSING := Color("ef6b6b")

static var _theme: Theme


static func box(bg: Color, border := Color.TRANSPARENT, radius := 6, border_width := 1, pad := 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border.a > 0.0:
		s.border_color = border
		s.set_border_width_all(border_width)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 15
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "Button", box(PANEL_2, BORDER_2))
	t.set_stylebox("hover", "Button", box(Color("232836"), GOLD))
	t.set_stylebox("pressed", "Button", box(Color("2b2412"), GOLD))
	t.set_stylebox("disabled", "Button", box(Color("15181e"), Color("252a35")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color("5c6270"))
	t.set_stylebox("normal", "LineEdit", box(PANEL_2, BORDER_2))
	t.set_stylebox("focus", "LineEdit", box(PANEL_2, GOLD))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER, 8, 1, 12))
	t.set_stylebox("normal", "OptionButton", box(PANEL_2, BORDER_2))
	t.set_stylebox("hover", "OptionButton", box(Color("232836"), GOLD))
	t.set_stylebox("pressed", "OptionButton", box(Color("2b2412"), GOLD))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_stylebox("separator", "HSeparator", box(BORDER, Color.TRANSPARENT, 0, 0, 0))
	t.set_constant("separation", "HSeparator", 1)
	_theme = t
	return t


## Button in einer Akzentfarbe (Gold für die Hauptaktion, Lila für One-Shots).
static func accent_button(b: Button, bg: Color, fg: Color, glow: Color) -> void:
	var normal := box(bg, Color.TRANSPARENT, 8, 0, 14)
	normal.shadow_color = glow
	normal.shadow_size = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.12)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.15)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, fg)


## Kleines Label mit Großbuchstaben als Abschnittstitel.
static func caption(text: String, parent: Node) -> Label:
	var l := UiUtil.label(str(TranslationServer.translate(text)).to_upper(), parent, 12)
	l.add_theme_color_override("font_color", MUTED)
	return l
