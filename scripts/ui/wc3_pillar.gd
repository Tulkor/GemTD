class_name Wc3Pillar
extends MarginContainer
## Steinsäule rechts im Hauptmenü (Wc3Theme): Steintextur mit abgeschnittenen Ecken, doppelter Messingrahmen,
## Messing-Eckbeschläge mit Schrauben, oben ein blauer Kristall in Messingfassung. Die Knöpfe kommen in box.
## Ohne Kristall (with_gem false) auch als Steintafel der Einzelspieler-Seite.

const CUT := 30.0
const GEM := "res://assets/textures/menu/kristall_blau.png"

var box: VBoxContainer
## Kristall oben (Hub-Säule); die Tafeln der Einzelspieler-Seite haben keinen.
var gem := true
var _stone: Texture2D
var _gem: Texture2D


func _init(with_gem := true, width := 420.0) -> void:
	gem = with_gem
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_theme_constant_override("margin_left", 44 if gem else 36)
	add_theme_constant_override("margin_right", 44 if gem else 36)
	add_theme_constant_override("margin_top", 64 if gem else 40)
	add_theme_constant_override("margin_bottom", 54 if gem else 40)
	custom_minimum_size.x = width
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	_stone = load(Wc3Theme.STONE)
	_gem = load(GEM)
	resized.connect(queue_redraw)


## Knopf anhängen; parent = box oder eine Zeile aus row().
func button(text_de: String, main: bool, description: String, on_pressed: Callable, parent: Node = null) -> Wc3Button:
	var b := Wc3Button.new(text_de, main)
	b.description = description
	b.pressed.connect(on_pressed)
	if parent is HBoxContainer:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(parent if parent != null else box).add_child(b)
	return b


func row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	box.add_child(h)
	return h


func separator() -> void:
	box.add_child(Wc3Theme.Divider.new())


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var shape := Wc3Theme.cut_rect(r, CUT)
	Wc3Theme.fill_textured(self, shape, _stone, 256.0, Wc3Theme.PILLAR_SHADE)
	# Innenschatten zum Rand hin
	for i in 10:
		draw_polyline(Wc3Theme.closed(Wc3Theme.cut_rect(r.grow(-10 - i * 4), maxf(CUT - 4 - i * 2, 4))), Color(0, 0, 0, 0.13 - i * 0.012), 4.0, true)
	# Rahmen von außen nach innen: dunkel, hell, Messing, dunkel, Abstand, dunkles Messing
	for ring in [[1.5, Wc3Theme.INK, 3.0], [4.0, Wc3Theme.GOLD_HI, 2.0], [6.0, Wc3Theme.GOLD, 2.0], [8.0, Wc3Theme.INK, 2.0], [12.5, Wc3Theme.GOLD_LO, 1.0]]:
		var d: float = ring[0]
		draw_polyline(Wc3Theme.closed(Wc3Theme.cut_rect(r.grow(-d), CUT - d * 0.41)), ring[1], ring[2], true)
	# Feine Doppellinie innen
	draw_rect(r.grow(-22.5), Wc3Theme.GOLD, false, 1.0)
	draw_rect(r.grow(-18.5), Color(Wc3Theme.GOLD_LO, 0.9), false, 1.0)
	# Beschläge an den vier abgeschnittenen Ecken
	var w := size.x
	var h := size.y
	Wc3Theme.corner(self, Vector2(0, 0), Vector2.RIGHT, Vector2.DOWN)
	Wc3Theme.corner(self, Vector2(w, 0), Vector2.DOWN, Vector2.LEFT)
	Wc3Theme.corner(self, Vector2(w, h), Vector2.LEFT, Vector2.UP)
	Wc3Theme.corner(self, Vector2(0, h), Vector2.UP, Vector2.RIGHT)
	if gem:
		_draw_gem()


## Blauer Kristall oben in einer Messingfassung (Trapez), dahinter ein blaues Leuchten.
func _draw_gem() -> void:
	var cx := size.x / 2
	var mount := Rect2(cx - 37, 50, 74, 16)
	var trap := PackedVector2Array([Vector2(mount.position.x + 10, mount.position.y), Vector2(mount.end.x - 10, mount.position.y),
		mount.end, Vector2(mount.position.x, mount.end.y)])
	for i in 6:
		draw_circle(Vector2(cx, 34), 30 - i * 4, Color(0.35, 0.67, 1.0, 0.05))
	var gh := 66.0
	var gw := gh * _gem.get_width() / _gem.get_height()
	var gr := Rect2(cx - gw / 2, mount.position.y + 6 - gh, gw, gh)
	draw_texture_rect(_gem, Rect2(gr.position + Vector2(0, 3), gr.size), false, Color(0, 0, 0, 0.8))
	draw_texture_rect(_gem, gr, false)
	draw_polyline(Wc3Theme.closed(trap), Wc3Theme.INK, 4.0, true)
	draw_colored_polygon(trap, Wc3Theme.GOLD)
	draw_line(trap[0] + Vector2(0, 1), trap[1] + Vector2(0, 1), Wc3Theme.GOLD_HI, 2.0)
	draw_line(trap[3] - Vector2(0, 1), trap[2] - Vector2(0, 1), Wc3Theme.GOLD_LO, 2.0)
