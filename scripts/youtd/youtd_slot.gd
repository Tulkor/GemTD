class_name YoutdSlot
extends PanelContainer
## Ein Feld mit Icon für YouTD (Lager, Tower-Plätze, Würfel): Rahmen in Seltenheitsfarbe, Zahl unten rechts,
## Level oben links. Felder mit drag_data lassen sich ziehen, Felder mit on_drop nehmen Gezogenes an.

signal clicked(button: int)

var drag_data = null            ## Daten beim Ziehen (null = nicht ziehbar)
var on_drop := Callable()       ## func(data) -> void
var accepts := Callable()       ## func(data) -> bool; leer = alles mit on_drop
var _icon: TextureRect
var _count: Label
var _level: Label
var _border := Color.TRANSPARENT
var _hover := false


func _init(tex: Texture2D = null, border := Color.TRANSPARENT, side := 44.0) -> void:
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_border = border
	_icon = TextureRect.new()
	_icon.texture = tex
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_count = _corner_label(HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM, UiTheme.TEXT)
	_level = _corner_label(HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, UiTheme.COIN)
	_style()
	mouse_entered.connect(func(): _hover = true; _style())
	mouse_exited.connect(func(): _hover = false; _style())


func _corner_label(h: HorizontalAlignment, v: VerticalAlignment, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = h
	l.vertical_alignment = v
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)
	return l


## Zahl unten rechts (Ladungen, Anzahl), leer = keine.
func set_count(text: String) -> YoutdSlot:
	_count.text = text
	return self


## Kleine Zahl oben links (Item-Level).
func set_level(text: String) -> YoutdSlot:
	_level.text = text
	return self


## Hervorheben (gewählt, im Würfel); gedimmt = gerade nicht nutzbar.
func set_marked(on: bool, dimmed := false) -> YoutdSlot:
	set_meta("marked", on)
	modulate.a = 0.5 if dimmed else 1.0
	_style()
	return self


func _style() -> void:
	var marked := bool(get_meta("marked", false))
	var fill := UiTheme.CYAN if marked else UiTheme.BG
	var edge := _border if _border.a > 0.0 else UiTheme.BORDER
	if _hover and not marked:
		fill = UiTheme.PANEL
	var sb := UiTheme.box(fill, edge, 0, 2, 2.0)
	if _border.a <= 0.0:
		sb.border_color = Color(edge, 0.6)
	add_theme_stylebox_override("panel", sb)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		clicked.emit(ev.button_index)
		accept_event()


func _get_drag_data(_at: Vector2) -> Variant:
	if drag_data == null:
		return null
	var p := TextureRect.new()
	p.texture = _icon.texture
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.size = size
	p.position = -size * 0.5
	var c := Control.new()
	c.add_child(p)
	set_drag_preview(c)
	return drag_data


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if not on_drop.is_valid() or data == null or data == drag_data:
		return false
	return accepts.call(data) if accepts.is_valid() else true


func _drop_data(_at: Vector2, data: Variant) -> void:
	on_drop.call(data)
