class_name UiTheme
extends RefCounted
## Gemeinsame Farben und das Godot-Theme für alle Oberflächen.
## Stil „Arcade“: Monospace-Schrift, eckige Kanten, dicke rosa Rahmen mit türkisem Versatz-Schatten.

const BG := Color("07040e")
const BAR := Color("0d0618")
const PANEL := Color("0d0618")
const PANEL_2 := Color("160b28")
const BORDER := Color("3b2560")
const BORDER_2 := Color("5b3a8a")
const TEXT := Color("f2eaff")
const MUTED := Color("a99cc8")
const DIM := Color("d7cdea")
## Akzentfarbe (Hauptaktion, Auswahl, Titel). Heißt aus historischen Gründen GOLD.
const GOLD := Color("ff4fd8")
## Text auf der Akzentfarbe.
const GOLD_DARK := Color("0d0618")
const CYAN := Color("22c4ee")
## Farbe für Goldbeträge.
const COIN := Color("ffd166")
const PURPLE := Color("8a4dff")
const PURPLE_LIGHT := Color("b38cff")
const HAVE := Color("5fe08a")
const MISSING := Color("ff5d7a")

const FONT := "res://assets/fonts/DejaVuSansMono.ttf"
const FONT_BOLD := "res://assets/fonts/DejaVuSansMono-Bold.ttf"

static var _theme: Theme


## Fläche mit optionalem Rahmen. Im Arcade-Stil immer eckig (radius bleibt für alte Aufrufe erhalten).
static func box(bg: Color, border := Color.TRANSPARENT, _radius := 0, border_width := 2, pad := 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	if border.a > 0.0:
		s.border_color = border
		s.set_border_width_all(maxi(border_width, 2) if border_width > 0 else 0)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


## Hauptpanel: dicker rosa Rahmen, harter türkiser Schatten nach rechts unten.
static func panel(pad := 14.0, alpha := 0.95, border := GOLD) -> StyleBoxFlat:
	var s := box(Color(PANEL, alpha), border, 0, 3, pad)
	s.shadow_color = CYAN
	s.shadow_size = 1
	s.shadow_offset = Vector2(5, 5)
	return s


static func font(bold := false) -> Font:
	return load(FONT_BOLD if bold else FONT)


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 14
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "Button", box(PANEL_2, BORDER))
	t.set_stylebox("hover", "Button", box(PANEL_2, GOLD))
	t.set_stylebox("pressed", "Button", box(CYAN, CYAN))
	t.set_stylebox("disabled", "Button", box(Color("0b0614"), Color("24183a")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", BAR)
	t.set_color("font_hover_pressed_color", "Button", BAR)
	t.set_color("font_disabled_color", "Button", Color("5a4d74"))
	t.set_stylebox("normal", "LineEdit", box(PANEL_2, BORDER))
	t.set_stylebox("focus", "LineEdit", box(PANEL_2, CYAN))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("panel", "PanelContainer", panel(12.0))
	for k in ["normal", "hover", "pressed", "focus"]:
		var s := box(PANEL_2, CYAN if k == "pressed" else (GOLD if k == "hover" else BORDER))
		t.set_stylebox(k, "OptionButton", s if k != "focus" else StyleBoxEmpty.new())
	t.set_color("font_pressed_color", "OptionButton", TEXT)
	t.set_stylebox("panel", "PopupMenu", box(BAR, GOLD, 0, 2, 6))
	t.set_stylebox("hover", "PopupMenu", box(PANEL_2, CYAN, 0, 0, 4))
	t.set_color("font_separator_color", "PopupMenu", CYAN)
	t.set_stylebox("panel", "TooltipPanel", box(BAR, CYAN, 0, 2, 8))
	t.set_stylebox("separator", "HSeparator", box(BORDER, Color.TRANSPARENT, 0, 0, 0))
	t.set_constant("separation", "HSeparator", 2)
	t.set_stylebox("panel", "TabContainer", box(PANEL, BORDER, 0, 2, 12))
	t.set_stylebox("panel", "ItemList", box(PANEL, BORDER, 0, 2, 8))
	t.set_stylebox("scroll", "VScrollBar", box(Color("0b0614"), Color.TRANSPARENT, 0, 0, 0))
	t.set_stylebox("grabber", "VScrollBar", box(BORDER_2, Color.TRANSPARENT, 0, 0, 3))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(GOLD, Color.TRANSPARENT, 0, 0, 3))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(CYAN, Color.TRANSPARENT, 0, 0, 3))
	_theme = t
	return t


## Button in einer Akzentfarbe (Rosa für die Hauptaktion, Lila für One-Shots), mit hartem Versatz-Schatten.
static func accent_button(b: Button, bg: Color, fg: Color, _glow: Color = Color.TRANSPARENT) -> void:
	var normal := box(bg, Color.TRANSPARENT, 0, 0, 14)
	normal.shadow_color = CYAN if bg != CYAN else GOLD
	normal.shadow_size = 1
	normal.shadow_offset = Vector2(4, 4)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.15)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.15)
	pressed.shadow_offset = Vector2(1, 1)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_font_override("font", font(true))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, fg)


## Kleines Label mit Großbuchstaben als Abschnittstitel.
static func caption(text: String, parent: Node) -> Label:
	var l := UiUtil.label(str(TranslationServer.translate(text)).to_upper(), parent, 12)
	l.add_theme_color_override("font_color", MUTED)
	return l


## Überschrift im Arcade-Stil: Großbuchstaben, fett, rosa mit türkisem Schatten.
static func title(l: Label, size := 0) -> Label:
	l.uppercase = true
	l.add_theme_font_override("font", font(true))
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_color_override("font_shadow_color", CYAN)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l
