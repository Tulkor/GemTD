class_name RecipeBook
extends Control
## Rezeptbuch (Taste R): alle Spezial-Rezepte, Zutaten grün (vorhanden) oder rot (fehlt), Pins.

signal pins_changed
signal closed

const COLUMNS := 4

var owned: Array = []
var filter := "all"
var grid: GridContainer
var search: LineEdit
var tabs := {}


static func is_pinned(id: String) -> bool:
	return Session.pinned_recipes.has(id)


static func toggle_pin(id: String) -> void:
	if Session.pinned_recipes.has(id):
		Session.pinned_recipes.erase(id)
	else:
		Session.pinned_recipes.append(id)


## Karte für ein Rezept. on_pin wird nach dem Umschalten des Pins aufgerufen.
static func card(id: String, have: Array, on_pin: Callable, compact := false) -> PanelContainer:
	var st := Recipes.status(id, have)
	var pinned := is_pinned(id)
	var p := PanelContainer.new()
	var border := UiTheme.HAVE if st.missing == 0 else (UiTheme.GOLD if pinned else UiTheme.BORDER)
	p.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, border, 8, 1, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var sw := ColorRect.new()
	sw.color = Color(str(Database.towers[id].get("color", "#ffffff")))
	sw.custom_minimum_size = Vector2(12, 12)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(sw)
	var name_l := UiUtil.label(Database.tower_label(id, 0), head, 15)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	var status_l := UiUtil.label("baubar" if st.missing == 0 else "noch %d" % st.missing, head, 12)
	status_l.add_theme_color_override("font_color", UiTheme.HAVE if st.missing == 0 else UiTheme.MISSING)
	var pin := Button.new()
	pin.text = "Gepinnt" if pinned else "Pin"
	pin.tooltip_text = "Rezept lösen" if pinned else "Rezept anpinnen: erscheint im Spiel links oben"
	pin.focus_mode = Control.FOCUS_NONE
	pin.add_theme_font_size_override("font_size", 12)
	if pinned:
		for k in ["normal", "hover", "pressed"]:
			pin.add_theme_stylebox_override(k, UiTheme.box(UiTheme.GOLD if k != "hover" else UiTheme.GOLD.lightened(0.12)))
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			pin.add_theme_color_override(k, UiTheme.GOLD_DARK)
	pin.pressed.connect(func():
		toggle_pin(id)
		on_pin.call())
	head.add_child(pin)
	for line in st.lines:
		var text: String = line.text
		var col := UiTheme.DIM
		if line.have != null:
			text = ("✓ " if line.have else "✗ ") + text
			col = UiTheme.HAVE if line.have else UiTheme.MISSING
		var l := UiUtil.label(("    " if line.indent > 0 else "") + text, v, 13 if not compact else 12)
		l.add_theme_color_override("font_color", col)
	p.set_meta("missing", st.missing)
	return p


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 60
	panel.offset_right = -60
	panel.offset_top = 40
	panel.offset_bottom = -40
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL, UiTheme.BORDER, 12, 1, 20))
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var title := UiUtil.label("Rezeptbuch", head, 26)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	var group := ButtonGroup.new()
	for f in [["all", "Alle"], ["ready", "Baubar"], ["pinned", "Angepinnt"]]:
		var b := Button.new()
		b.text = f[1]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = f[0] == filter
		b.toggled.connect(func(on):
			if on:
				filter = f[0]
				refresh())
		head.add_child(b)
		tabs[f[0]] = b
		b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.GOLD, Color.TRANSPARENT))
		b.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
	search = LineEdit.new()
	search.placeholder_text = "Suche, z. B. Opal"
	search.custom_minimum_size.x = 220
	search.text_changed.connect(func(_t): refresh())
	head.add_child(search)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	for leg in [["✓ hast du", UiTheme.HAVE], ["✗ fehlt", UiTheme.MISSING], ["am wenigsten fehlt zuerst", UiTheme.MUTED]]:
		UiUtil.label(leg[0], head, 13).add_theme_color_override("font_color", leg[1])
	var close_b := UiUtil.button("Schließen (R)", head, close)
	close_b.focus_mode = Control.FOCUS_NONE

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	var hint := UiUtil.label("Angepinnte Rezepte stehen im Spiel links oben und zeigen, was noch fehlt. Gezählt werden alle Tower auf dem Feld und die neuen Gems dieser Runde.", v, 13)
	hint.add_theme_color_override("font_color", UiTheme.MUTED)
	hide()


func open(have: Array) -> void:
	owned = have
	show()
	refresh()


func close() -> void:
	hide()
	closed.emit()


func refresh() -> void:
	if grid == null:
		return
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	var q := search.text.strip_edges().to_lower()
	var cards := []
	for id in Recipes.ids():
		if filter == "pinned" and not is_pinned(id):
			continue
		if q != "":
			var hay := Database.tower_label(id, 0).to_lower()
			for line in Recipes.status(id, []).lines:
				hay += " " + str(line.text).to_lower()
			if not q in hay:
				continue
		var c := card(id, owned, func():
			refresh.call_deferred()
			pins_changed.emit())
		if filter == "ready" and int(c.get_meta("missing")) > 0:
			c.free()
			continue
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards.append(c)
	cards.sort_custom(func(a, b): return int(a.get_meta("missing")) < int(b.get_meta("missing")))
	for c in cards:
		grid.add_child(c)
	if cards.is_empty():
		UiUtil.label("Keine Rezepte für diesen Filter.", grid).add_theme_color_override("font_color", UiTheme.MUTED)
