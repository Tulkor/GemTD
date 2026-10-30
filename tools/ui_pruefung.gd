class_name UiPruefung
extends RefCounted
## Sucht Überlappungen in der sichtbaren Oberfläche (für tools/screenshot.sh --ueberlappung).
## Meldet je Fund eine Zeile "UI <art> …" und malt die Stellen rot ins Bild:
##   panel   zwei Panels liegen übereinander (keins steckt im anderen)
##   inhalt  zwei Texte/Knöpfe überdecken sich
##   rand    ein Element ragt aus dem Fenster
##   text    Text ist abgeschnitten (zu lang für die Breite oder mehr Zeilen als Platz)

const MIN_PX := 4.0  ## kleinere Überschneidungen (Rahmenkanten) zählen nicht


static func check(root: Node, img: Image) -> PackedStringArray:
	var view := Rect2(Vector2.ZERO, Vector2(img.get_width(), img.get_height()))
	var panels: Array = []
	var leaves: Array = []
	_collect(root, view, panels, leaves)
	var out := PackedStringArray()
	var marks: Array = []
	for i in panels.size():
		for j in range(i + 1, panels.size()):
			var a: Dictionary = panels[i]
			var b: Dictionary = panels[j]
			if _related(a.node, b.node):
				continue
			var r: Rect2 = a.rect.intersection(b.rect)
			if r.size.x >= MIN_PX and r.size.y >= MIN_PX:
				out.append("UI panel %s <-> %s  %s" % [_label(a.node), _label(b.node), _fmt(r)])
				marks.append(r)
	for i in leaves.size():
		for j in range(i + 1, leaves.size()):
			var a: Dictionary = leaves[i]
			var b: Dictionary = leaves[j]
			if _related(a.node, b.node):
				continue
			var r: Rect2 = a.rect.intersection(b.rect)
			if r.size.x >= MIN_PX and r.size.y >= MIN_PX:
				out.append("UI inhalt %s <-> %s  %s" % [_label(a.node), _label(b.node), _fmt(r)])
				marks.append(r)
	for d in panels + leaves:
		var full: Rect2 = d.full
		if not view.grow(1).encloses(full) and not _in_scroll(d.node):
			out.append("UI rand %s  %s" % [_label(d.node), _fmt(full)])
			marks.append(full.intersection(view))
	for d in leaves:
		var why := _cut_text(d.node)
		if why != "":
			out.append("UI text %s  %s  %s" % [_label(d.node), why, _fmt(d.rect)])
			marks.append(d.rect)
	for r in marks:
		_frame(img, r)
	return out


static func _collect(n: Node, clip: Rect2, panels: Array, leaves: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Window and n != n.get_tree().root and not (n as Window).visible:
		return
	var inner := clip
	if n is Control:
		var c := n as Control
		if c.modulate.a < 0.05 or c.self_modulate.a < 0.05 and c.get_child_count() == 0:
			return
		var full := _screen_rect(c)
		var r := full.intersection(clip)
		if c.clip_contents or c is ScrollContainer:
			inner = r
		if r.size.x > 1 and r.size.y > 1:
			var whole_screen := full.size.x >= clip.size.x * 0.95 and full.size.y >= clip.size.y * 0.95
			# Vollbild-Sperre (Fenster mit Abdunklung, Menüseite mit eigenem Hintergrund):
			# alles davor Gezeichnete ist verdeckt oder nicht bedienbar, zählt also nicht.
			if whole_screen and _covers(c):
				panels.clear()
				leaves.clear()
			if (c is PanelContainer or c is Panel) and not whole_screen and _has_panel_look(c):
				panels.append({"node": c, "rect": r, "full": full})
			elif _is_leaf(c):
				leaves.append({"node": c, "rect": r, "full": full})
	for ch in n.get_children():
		_collect(ch, inner, panels, leaves)


static func _covers(c: Control) -> bool:
	if c.mouse_filter == Control.MOUSE_FILTER_STOP and not (c is Container):
		return true
	if c is ColorRect:
		return (c as ColorRect).color.a > 0.3
	if c is TextureRect:
		return (c as TextureRect).texture != null
	return (c is PanelContainer or c is Panel) and _has_panel_look(c)


## Nur Panels mit sichtbarem Hintergrund zählen (reine Layout-Panels ohne Stil nicht).
static func _has_panel_look(c: Control) -> bool:
	var sb: StyleBox = c.get_theme_stylebox("panel")
	return sb != null and not (sb is StyleBoxEmpty)


static func _is_leaf(c: Control) -> bool:
	if c is Label:
		return (c as Label).text.strip_edges() != ""
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text().strip_edges() != ""
	return c is BaseButton or c is LineEdit or c is Range and not (c is ScrollBar)


static func _cut_text(c: Control) -> String:
	if c is Label:
		var l := c as Label
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var w := l.get_theme_font("font").get_multiline_string_size(l.text, l.horizontal_alignment, -1, l.get_theme_font_size("font_size")).x
			if w > l.size.x + 2:
				return "Breite %d > %d" % [w, l.size.x]
		elif l.get_line_count() > l.get_visible_line_count() and l.max_lines_visible < 0:
			return "Zeilen %d > %d" % [l.get_line_count(), l.get_visible_line_count()]
	elif c is Button:
		var b := c as Button
		if b.text != "" and b.autowrap_mode == TextServer.AUTOWRAP_OFF and (b.clip_text or b.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING):
			var w := b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
			var pad := b.get_theme_stylebox("normal").get_minimum_size().x
			if b.icon:
				pad += b.icon.get_width()
			if w + pad > b.size.x + 2:
				return "Knopf %d > %d" % [w + pad, b.size.x]
	return ""


static func _screen_rect(c: Control) -> Rect2:
	var t := c.get_viewport().get_final_transform() * c.get_global_transform_with_canvas()
	return t * Rect2(Vector2.ZERO, c.size)


static func _in_scroll(n: Node) -> bool:
	for i in 64:
		n = n.get_parent()
		if n == null:
			return false
		if n is ScrollContainer:
			return true
	return false


static func _related(a: Node, b: Node) -> bool:
	return a.is_ancestor_of(b) or b.is_ancestor_of(a)


static func _label(c: Control) -> String:
	var parts: Array = []
	var n: Node = c
	for i in 3:
		if n == null or n is Window:
			break
		parts.push_front(String(n.name))
		n = n.get_parent()
	var s := "/".join(parts)
	var txt := ""
	if c is Label:
		txt = (c as Label).text
	elif c is Button:
		txt = (c as Button).text
	elif c is RichTextLabel:
		txt = (c as RichTextLabel).get_parsed_text()
	elif c is PanelContainer:
		txt = _first_text(c)
	txt = txt.strip_edges().replace("\n", " ")
	if txt.length() > 24:
		txt = txt.substr(0, 24) + "…"
	return "%s[%s]" % [s, txt] if txt != "" else s


static func _first_text(n: Node) -> String:
	for ch in n.get_children():
		if ch is Label and (ch as Label).text.strip_edges() != "":
			return (ch as Label).text
		var t := _first_text(ch)
		if t != "":
			return t
	return ""


static func _fmt(r: Rect2) -> String:
	return "(%d,%d %dx%d)" % [r.position.x, r.position.y, r.size.x, r.size.y]


static func _frame(img: Image, r: Rect2) -> void:
	var ri := Rect2i(r).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if ri.size.x <= 0 or ri.size.y <= 0:
		return
	var red := Color(1, 0.1, 0.1)
	for k in 3:
		var g := ri.grow(k)
		g = g.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
		img.fill_rect(Rect2i(g.position.x, g.position.y, g.size.x, 1), red)
		img.fill_rect(Rect2i(g.position.x, g.end.y - 1, g.size.x, 1), red)
		img.fill_rect(Rect2i(g.position.x, g.position.y, 1, g.size.y), red)
		img.fill_rect(Rect2i(g.end.x - 1, g.position.y, 1, g.size.y), red)
