class_name DecoTheme
extends RefCounted
## Art-déco-Stil der Menüs vor dem Spiel (Hub, Einzelspieler, Lobby, Laden, Run-History, Einstellungen vor Runde 1).
## Petrol und Messing, doppelte Messingrahmen, keine runden Ecken. Die Oberfläche im Spiel bleibt Arcade (UiTheme).
## Schriftregel (Lukas): ab etwa 28 px Limelight mit verdickten Haarstrichen (display_font), alles Kleinere Federo.
## Dieselben Namen wie UiTheme (GOLD = Akzent, CYAN = ausgewählt, GOLD_DARK = Schrift darauf), damit Menüs beide nutzen können.

const BG := Color("0f2a2c")
const BAR := Color("0a1d1f")
const PANEL := Color("133537")
const PANEL_2 := Color("17393b")
const BORDER := Color("2f5a5c")
const BORDER_2 := Color("4d7a78")
const TEXT := Color("efe4cf")
const MUTED := Color("9fb8b5")
const DIM := Color("d8cfbb")
## Messing: Rahmen, Akzent, Abschnittstitel.
const GOLD := Color("c9a36a")
## Helles Messing: Hauptknöpfe und Auswahl.
const BRASS_LIGHT := Color("d8b97f")
## Schrift auf Messing.
const GOLD_DARK := Color("0a1d1f")
## Ausgewählt / gedrückt (wie CYAN im Arcade-Stil): helles Messing.
const CYAN := BRASS_LIGHT
const CREAM := TEXT
const COIN := Color("e8c87a")
const PURPLE := Color("6f9c98")
const PURPLE_LIGHT := Color("b9d3cf")
const HAVE := Color("9fd3b6")
const MISSING := Color("e08a7a")

## Ab dieser Schriftgröße gilt Limelight statt Federo.
const DISPLAY_SIZE := 28

const FONT := "res://assets/fonts/Federo-Regular.ttf"
const FONT_DISPLAY := "res://assets/fonts/Limelight-Regular.ttf"
const FONT_FALLBACK := "res://assets/fonts/DejaVuSansMono.ttf"

static var _theme: Theme
static var _fonts: Dictionary = {}


## Federo (bold: leicht verdickt, Federo hat keinen fetten Schnitt). Zeichen wie ◆ kommen aus DejaVu.
static func font(bold := false) -> Font:
	return _variant(FONT, 0.35 if bold else 0.0, 0)


## Limelight kräftig: dünne Striche verdickt, etwas Buchstabenabstand.
static func display_font(spacing := 3) -> Font:
	return _variant(FONT_DISPLAY, 0.55, spacing)


static func _variant(path: String, embolden: float, spacing: int) -> Font:
	var key := "%s|%s|%d" % [path, embolden, spacing]
	if _fonts.has(key):
		return _fonts[key]
	var f := FontVariation.new()
	f.base_font = load(path)
	f.variation_embolden = embolden
	f.spacing_glyph = spacing
	f.fallbacks = [load(FONT_FALLBACK)]
	_fonts[key] = f
	return f


## Fläche mit dünnem Rahmen, immer eckig (radius bleibt für Aufrufe wie bei UiTheme.box erhalten).
static func box(bg: Color, border := Color.TRANSPARENT, _radius := 0, border_width := 1, pad := 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	if border.a > 0.0 and border_width > 0:
		s.border_color = border
		s.set_border_width_all(clampi(border_width, 1, 2))
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


## Wie UiTheme.chamfer: schräg abgeschnittene Ecken (Tooltips).
static func chamfer(bg: Color, border: Color, cut := 10, pad := 10.0) -> StyleBox:
	var s := DecoBox.new()
	s.bg = bg
	s.line = border
	s.cut = cut
	s.set_content_margin_all(pad)
	return s


## Hauptpanel: doppelter Messingrahmen, Messing-Dreiecke in den Ecken.
static func panel(pad := 14.0, alpha := 0.97, border := GOLD) -> StyleBox:
	var s := DecoBox.new()
	s.bg = Color(BG, alpha)
	s.line = border
	s.inner = border
	s.corners = 0
	s.set_content_margin_all(pad + 10.0)
	return s


## Kasten mit doppeltem Rahmen; cut > 0 schneidet alle vier Ecken ab (Achteck), point: spitze Enden links und rechts.
static func frame(bg: Color, line: Color, inner := Color.TRANSPARENT, cut := 0, point := false, pad := 12.0) -> DecoBox:
	var s := DecoBox.new()
	s.bg = bg
	s.line = line
	s.inner = inner
	s.cut = cut
	s.point = point
	s.set_content_margin_all(pad)
	return s


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 15
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "Button", box(Color.TRANSPARENT, GOLD, 0, 1, 10))
	t.set_stylebox("hover", "Button", box(PANEL, BRASS_LIGHT, 0, 1, 10))
	t.set_stylebox("pressed", "Button", box(BRASS_LIGHT, BRASS_LIGHT, 0, 1, 10))
	t.set_stylebox("hover_pressed", "Button", box(BRASS_LIGHT, CREAM, 0, 1, 10))
	t.set_stylebox("disabled", "Button", box(Color.TRANSPARENT, BORDER, 0, 1, 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", CREAM)
	t.set_color("font_pressed_color", "Button", GOLD_DARK)
	t.set_color("font_hover_pressed_color", "Button", GOLD_DARK)
	t.set_color("font_disabled_color", "Button", Color("54797a"))
	t.set_stylebox("normal", "LineEdit", box(BG, GOLD, 0, 1, 10))
	t.set_stylebox("focus", "LineEdit", box(BG, BRASS_LIGHT, 0, 2, 10))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.7))
	t.set_color("caret_color", "LineEdit", BRASS_LIGHT)
	t.set_color("selection_color", "LineEdit", Color(GOLD, 0.4))
	t.set_stylebox("panel", "PanelContainer", panel(12.0))
	for k in ["normal", "hover", "pressed", "disabled"]:
		var s := box(PANEL, BRASS_LIGHT if k == "hover" else (BORDER if k == "disabled" else GOLD), 0, 1, 10)
		t.set_stylebox(k, "OptionButton", s)
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_color("font_pressed_color", "OptionButton", TEXT)
	t.set_color("font_hover_pressed_color", "OptionButton", TEXT)
	t.set_stylebox("panel", "PopupMenu", box(BAR, GOLD, 0, 1, 6))
	t.set_stylebox("hover", "PopupMenu", box(PANEL, BRASS_LIGHT, 0, 1, 4))
	t.set_color("font_hover_color", "PopupMenu", CREAM)
	t.set_color("font_separator_color", "PopupMenu", GOLD)
	t.set_stylebox("panel", "TooltipPanel", chamfer(BAR, GOLD, 10, 12))
	t.set_color("font_color", "TooltipLabel", TEXT)
	var sep := StyleBoxLine.new()
	sep.color = GOLD
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 2)
	t.set_stylebox("panel", "TabContainer", box(BG, GOLD, 0, 1, 14))
	t.set_stylebox("tab_selected", "TabContainer", box(BRASS_LIGHT, BRASS_LIGHT, 0, 1, 12))
	t.set_stylebox("tab_unselected", "TabContainer", box(Color.TRANSPARENT, BORDER, 0, 1, 12))
	t.set_stylebox("tab_hovered", "TabContainer", box(PANEL, BRASS_LIGHT, 0, 1, 12))
	t.set_stylebox("tab_disabled", "TabContainer", box(Color.TRANSPARENT, BORDER, 0, 1, 12))
	t.set_color("font_selected_color", "TabContainer", GOLD_DARK)
	t.set_color("font_unselected_color", "TabContainer", TEXT)
	t.set_color("font_hovered_color", "TabContainer", CREAM)
	t.set_color("font_disabled_color", "TabContainer", Color("54797a"))
	t.set_stylebox("panel", "ItemList", box(BG, GOLD, 0, 1, 8))
	t.set_stylebox("scroll", "VScrollBar", box(BAR, Color.TRANSPARENT, 0, 0, 0))
	t.set_stylebox("grabber", "VScrollBar", box(BORDER_2, Color.TRANSPARENT, 0, 0, 3))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(GOLD, Color.TRANSPARENT, 0, 0, 3))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(BRASS_LIGHT, Color.TRANSPARENT, 0, 0, 3))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", CREAM)
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_color("font_hover_pressed_color", "CheckBox", CREAM)
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(k, "CheckBox", box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, 4))
	t.set_icon("checked", "CheckBox", _diamond_icon(BRASS_LIGHT, true, 18))
	t.set_icon("unchecked", "CheckBox", _diamond_icon(GOLD, false, 18))
	t.set_icon("checked_disabled", "CheckBox", _diamond_icon(BORDER, true, 18))
	t.set_icon("unchecked_disabled", "CheckBox", _diamond_icon(BORDER, false, 18))
	# Regler: dünne Spur, gefüllter Teil Messing, Raute als Griff
	var track := box(BORDER, Color.TRANSPARENT, 0, 0, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	var filled := box(BRASS_LIGHT, Color.TRANSPARENT, 0, 0, 0)
	filled.content_margin_top = 3
	filled.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	t.set_icon("grabber", "HSlider", _diamond_icon(CREAM, true, 20))
	t.set_icon("grabber_highlight", "HSlider", _diamond_icon(BRASS_LIGHT, true, 20))
	t.set_icon("grabber_disabled", "HSlider", _diamond_icon(BORDER, true, 20))
	_theme = t
	return t


## Raute (gefüllt oder als Umriss), z. B. Regler-Griff und Häkchen.
static func _diamond_icon(c: Color, filled: bool, px: int) -> Texture2D:
	var h := px / 2.0
	var shape := 'points="%s,1 %s,%s %s,%s 1,%s"' % [h, px - 1, h, h, px - 1, h]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"><polygon %s fill="%s" stroke="#%s" stroke-width="2"/></svg>' \
		% [px, px, shape, ("#" + c.to_html(false)) if filled else "none", c.to_html(false)]
	var img := Image.new()
	img.load_svg_from_string(svg)
	return ImageTexture.create_from_image(img)


## Hauptaktion: helles Messing mit dunkler Schrift, spitze Enden (point) oder abgeschrägte Ecken.
## Schrift ab DISPLAY_SIZE in Limelight kräftig, sonst Federo.
static func accent_button(b: Button, bg: Color = BRASS_LIGHT, fg: Color = GOLD_DARK, _glow: Color = Color.TRANSPARENT, point := true) -> void:
	if bg == GOLD:
		bg = BRASS_LIGHT
	var normal := frame(bg, Color.TRANSPARENT, Color.TRANSPARENT, 14, point, 14)
	normal.content_margin_left = 30 if point else 14
	normal.content_margin_right = normal.content_margin_left
	var hover := normal.duplicate() as DecoBox
	hover.bg = bg.lightened(0.12)
	var pressed := normal.duplicate() as DecoBox
	pressed.bg = bg.darkened(0.12)
	var off := normal.duplicate() as DecoBox
	off.bg = Color.TRANSPARENT
	off.line = BORDER
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", off)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, fg)
	var size := b.get_theme_font_size("font_size") if b.has_theme_font_size_override("font_size") else 0
	b.add_theme_font_override("font", display_font(2) if size >= DISPLAY_SIZE else font(true))


## Großer Text in Limelight kräftig (Knopf oder Label), Größe mindestens DISPLAY_SIZE.
static func display(c: Control, size := DISPLAY_SIZE, spacing := 3) -> Control:
	c.add_theme_font_override("font", display_font(spacing))
	c.add_theme_font_size_override("font_size", maxi(size, DISPLAY_SIZE))
	return c


## Abschnittstitel: Messing, Großbuchstaben, gesperrt.
static func caption(text: String, parent: Node) -> Label:
	var l := UiUtil.label(str(TranslationServer.translate(text)).to_upper(), parent, 13)
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_font_override("font", _variant(FONT, 0.3, 3))
	return l


## Überschrift: Limelight kräftig in Creme. Unter DISPLAY_SIZE bleibt es Federo (Schriftregel).
static func title(l: Label, size := 0) -> Label:
	var s := size if size > 0 else l.get_theme_font_size("font_size")
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	l.add_theme_font_override("font", display_font(maxi(2, s / 10)) if s >= DISPLAY_SIZE else _variant(FONT, 0.3, 2))
	l.add_theme_color_override("font_color", TEXT)
	return l


## Kopfzeile einer Seite: Titel, eine Messinglinie bis zum Rand und eine Raute.
static func head_line(parent: Node) -> void:
	var line := HSeparator.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(line)
	var d := UiUtil.label("◆", parent, 18)
	d.add_theme_color_override("font_color", GOLD)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
