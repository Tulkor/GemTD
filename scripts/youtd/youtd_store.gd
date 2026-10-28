class_name YoutdStore
extends PanelContainer
## Lager unten links von YouTD: Tower-Lager (im Baumodus das Baumenü) und Item-Lager übereinander, jedes für sich
## einklappbar. Tower und Items als Icons. Items zieht man auf einen Tower (auf der Karte oder auf die Plätze der
## Auswahlkarte) und von dort zurück ins Lager. Im Item-Lager: „Öle kombinieren“ und der Horadrische Würfel.

const COLS := 7
const SLOT := 40.0
const ROWS_TOWERS := 2
const ROWS_ITEMS := 3

## Welche Teile offen sind (bleibt für die Sitzung, auch in der nächsten Partie)
static var open := {"towers": true, "items": true}

var game  # youtd_game.gd
var cube_open := false     ## Würfel offen: Item-Klick legt in den Würfel statt in einen Tower
var cube: Array = []       ## Items im Würfel (YtItem, lokal)
var _parts := {}           ## "towers"/"items" -> {head: Label, toggle: Button, box: Control}
var _towers: GridContainer
var _towers_scroll: ScrollContainer
var _towers_key := ""
var _merge: Button
var _items: GridContainer
var _items_scroll: ScrollContainer
var _items_key := ""
var _oils: Button
var _cube_toggle: Button
var _cube_box: VBoxContainer
var _cube_slots: HBoxContainer
var _cube_info: Label
var _cube_go: Button
var _cube_recipes: HFlowContainer


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel(10.0, 0.94))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)

	var tbox := _part("towers", v)
	_towers_scroll = _grid_scroll(tbox, ROWS_TOWERS)
	_towers = _towers_scroll.get_child(0)
	_merge = _head_button("towers", "6 → 1", func(): _merge_pressed())

	var ibox := _part("items", v)
	_items_scroll = _grid_scroll(ibox, ROWS_ITEMS)
	_items = _items_scroll.get_child(0)
	_oils = _head_button("items", "Öle", func(): game.submit({"type": "oil_merge"}))
	_oils.tooltip_text = tr("Öle kombinieren: alle Öle so oft wie möglich im Würfel destillieren, je 4 gleicher Seltenheit ergeben 1 der nächsten.")
	_cube_toggle = _head_button("items", "Würfel", func(): set_cube(not cube_open))
	_cube_toggle.toggle_mode = true
	_cube_toggle.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
	_cube_toggle.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
	_cube_toggle.tooltip_text = tr("Horadrischer Würfel: aus Items im Lager neue machen")
	_build_cube(ibox)
	_apply_parts()
	refresh()


## Kopfzeile mit Titel und Auf-/Zuklappen, darunter der Bereich.
func _part(id: String, v: VBoxContainer) -> VBoxContainer:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	head.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			toggle(id))
	v.add_child(head)
	var title := UiUtil.label("", head, 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.heading(title)
	var b := UiUtil.button("–", head, func(): toggle(id))
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(26, 22)
	b.add_theme_font_size_override("font_size", 13)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	v.add_child(box)
	_parts[id] = {"head": title, "toggle": b, "box": box, "row": head}
	return box


## Kleiner Knopf in der Kopfzeile, links vom Auf-/Zuklappen.
func _head_button(id: String, text: String, on_pressed: Callable) -> Button:
	var row: HBoxContainer = _parts[id].row
	var b := UiUtil.button(text, row, on_pressed)
	row.move_child(b, row.get_child_count() - 2)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 24
	b.add_theme_font_size_override("font_size", 12)
	return b


func _grid_scroll(parent: Control, rows: int) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.custom_minimum_size = Vector2(COLS * (SLOT + 3), rows * (SLOT + 3))
	parent.add_child(s)
	var g := GridContainer.new()
	g.columns = COLS
	g.add_theme_constant_override("h_separation", 3)
	g.add_theme_constant_override("v_separation", 3)
	s.add_child(g)
	return s


## Tower- oder Item-Lager auf- oder zuklappen.
func toggle(id: String) -> void:
	open[id] = not bool(open.get(id, true))
	if id == "items" and not open[id]:
		set_cube(false)
	_apply_parts()


func _apply_parts() -> void:
	for id in _parts:
		var p: Dictionary = _parts[id]
		var on := bool(open.get(id, true))
		(p.box as Control).visible = on
		(p.toggle as Button).text = "–" if on else "+"
		(p.toggle as Button).tooltip_text = tr("Einklappen") if on else tr("Ausklappen")


## Würfel öffnen oder schließen; beim Öffnen klappt das Item-Lager auf.
func set_cube(on: bool) -> void:
	if on and not open.items:
		open.items = true
		_apply_parts()
	cube_open = on
	cube.clear()
	_cube_toggle.set_pressed_no_signal(on)
	if game != null:
		game.picked_item = -1
	items_dirty()
	refresh()


func refresh() -> void:
	if game == null or _towers == null:
		return
	visible = game.setup_done
	_refresh_towers()
	_refresh_items()


# --- Tower ------------------------------------------------------------------------

func _refresh_towers() -> void:
	var ids: Array = game.buildable()
	var list := []
	for id in ids:
		list.append([id, game.build_reason(id)])
	var key: String = str(list) + game.build_id
	if key == _towers_key:
		return
	_towers_key = key
	(_parts.towers.head as Label).text = tr("Baumenü") if game.is_build_mode() else tr("Tower-Lager (%d)") % ids.size()
	_clear(_towers)
	var merge: Dictionary = game.merge_option()
	_merge.visible = not game.is_build_mode()
	_merge.disabled = merge.is_empty()
	_merge.tooltip_text = tr("6 Tower gleicher Seltenheit aus dem Lager werden zu 1 zufälligen Tower der nächsten Seltenheit (die ältesten zuerst).") \
			+ ("\n" + tr("Jetzt: 6× %s → 1× %s") % [YoutdData.rarity_name(merge.from), YoutdData.rarity_name(merge.to)] if not merge.is_empty()
			else "\n" + tr("Noch keine 6 Tower gleicher Seltenheit."))
	if list.is_empty():
		var hint := UiUtil.wrap_label(tr("Erforsche zuerst ein Element.") if not game.any_element()
				else tr("Nach jeder Welle kommen neue Tower dazu."), _towers, COLS * SLOT)
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", UiTheme.MUTED)
		return
	for entry in list:
		var id: String = entry[0]
		var t := YoutdData.tower(id)
		var s := YoutdSlot.new(YoutdData.tower_icon(id), YoutdData.rarity_color(str(t.get("rarity", "common"))), SLOT)
		s.set_marked(game.build_id == id, entry[1] != "")
		s.set_roles(YoutdData.tower_roles(id))
		s.tooltip_text = YoutdPanel.tower_tip(id) + ("\n" + s.roles_text() if s.roles_text() != "" else "") \
				+ ("\n" + str(entry[1]) if entry[1] != "" else "\n" + tr("Klick: bauen"))
		s.clicked.connect(func(button):
			if button == MOUSE_BUTTON_LEFT:
				game.choose_build(id))
		_towers.add_child(s)


func _merge_pressed() -> void:
	var m: Dictionary = game.merge_option()
	if not m.is_empty():
		game.submit({"type": "tower_merge", "rarity": m.from})


# --- Items ------------------------------------------------------------------------

## Lager neu zeichnen (Item gefunden, eingelegt, verwandelt).
func items_dirty() -> void:
	_items_key = ""


func _refresh_items() -> void:
	cube = cube.filter(func(it): return is_instance_valid(it) and game.item_stash.has(it))
	var key: String = str(game.item_stash.map(func(it): return [it.get_uid(), game.item_label(it), it.horadric_lock])) + str(game.picked_item) \
			+ str(cube.map(func(it): return it.get_uid())) + str(cube_open)
	if key == _items_key:
		return
	_items_key = key
	(_parts.items.head as Label).text = tr("Item-Lager (%d)") % game.item_stash.size()
	_clear(_items)
	_oils.disabled = not game.can_merge_oils()
	_refresh_cube()
	var n: int = game.item_stash.size()
	var total := maxi(COLS * ROWS_ITEMS, ceili((n + 1) / float(COLS)) * COLS)
	for i in total:
		var s: YoutdSlot
		if i < n:
			var it: YtItem = game.item_stash[i]
			var d := YoutdData.item(str(it.get_id()))
			s = YoutdSlot.new(YoutdData.item_icon(str(it.get_id())), YoutdData.rarity_color(str(d.get("rarity", "common"))), SLOT)
			s.set_count(str(it.get_charges()) if it.uses_charges() else "")
			s.set_marked(game.picked_item == i or cube.has(it), cube_open and it.horadric_lock)
			s.drag_data = {"yt_item": it.get_uid()}
			s.tooltip_text = YoutdPanel.item_tip_for(it) + "\n" + (tr("Klick: in den Würfel · Rechtsklick: für den Würfel sperren/freigeben") if cube_open
					else (tr("Klick: benutzen") if it.is_consumable() else tr("Auf einen Tower ziehen oder anklicken und dann den Tower")))
			s.clicked.connect(func(button): _item_clicked(it, button))
		else:
			s = YoutdSlot.new(null, Color.TRANSPARENT, SLOT)
			s.mouse_default_cursor_shape = Control.CURSOR_ARROW
		s.on_drop = func(data): _drop_back(data)
		s.accepts = func(data): return data is Dictionary and data.has("tower_item")
		_items.add_child(s)


## Ein Item aus einem Tower (Plätze der Auswahlkarte) zurück ins Lager.
func _drop_back(data: Dictionary) -> void:
	game.submit({"type": "item_take", "tower": data.tower, "index": int(data.tower_item)})


func _item_clicked(it: YtItem, button: int) -> void:
	var i: int = game.item_stash.find(it)
	if i < 0:
		return
	if button == MOUSE_BUTTON_RIGHT:
		if cube_open:
			game.submit({"type": "item_lock", "uid": it.get_uid()})
			items_dirty()
		return
	if not cube_open:
		game.pick_item(i)
		return
	if cube.has(it):
		cube.erase(it)
	elif cube.size() < 6 and not it.horadric_lock:
		cube.append(it)
	items_dirty()
	_refresh_items()


# --- Horadrischer Würfel -------------------------------------------------------------

func _build_cube(v: VBoxContainer) -> void:
	_cube_box = VBoxContainer.new()
	_cube_box.add_theme_constant_override("separation", 4)
	v.add_child(_cube_box)
	var head := UiUtil.label("Horadrischer Würfel", _cube_box, 14)
	UiTheme.heading(head)
	_cube_slots = HBoxContainer.new()
	_cube_slots.add_theme_constant_override("separation", 3)
	_cube_box.add_child(_cube_slots)
	_cube_info = UiUtil.wrap_label("", _cube_box, COLS * (SLOT + 3))
	_cube_info.add_theme_font_size_override("font_size", 12)
	_cube_go = UiUtil.button("Verwandeln", _cube_box, func():
		game.submit({"type": "transmute", "uids": cube.map(func(it): return it.get_uid())})
		cube.clear()
		items_dirty())
	_cube_go.focus_mode = Control.FOCUS_NONE
	_cube_go.custom_minimum_size.y = 30
	UiTheme.accent_button(_cube_go, UiTheme.GOLD, UiTheme.GOLD_DARK)
	var rhead := UiUtil.label("Rezepte", _cube_box, 12)
	rhead.add_theme_font_override("font", UiTheme.font(true))
	_cube_recipes = HFlowContainer.new()
	_cube_recipes.add_theme_constant_override("h_separation", 3)
	_cube_recipes.add_theme_constant_override("v_separation", 3)
	_cube_box.add_child(_cube_recipes)


func _refresh_cube() -> void:
	_cube_box.visible = cube_open
	if not cube_open:
		return
	var p: YtPlayer = game.yp()
	var r := YoutdCube.current_recipe(p, cube)
	if cube.is_empty():
		_cube_info.text = tr("Items anklicken oder hierher ziehen, oder unten ein Rezept wählen.")
	elif r.is_empty():
		_cube_info.text = tr("Im Würfel: %d Items · kein passendes Rezept") % cube.size()
	else:
		_cube_info.text = tr("Rezept: %s\n%s") % [YoutdPanel.recipe_name(r), YoutdPanel.recipe_text(r)]
	_cube_go.disabled = r.is_empty()
	_clear(_cube_slots)
	for k in 6:
		var it: YtItem = cube[k] if k < cube.size() else null
		var s: YoutdSlot
		if it != null:
			var d := YoutdData.item(str(it.get_id()))
			s = YoutdSlot.new(YoutdData.item_icon(str(it.get_id())), YoutdData.rarity_color(str(d.get("rarity", "common"))), SLOT - 4)
			s.tooltip_text = it.get_display_name() + "\n" + tr("Klick: aus dem Würfel nehmen")
			s.clicked.connect(func(_b):
				cube.erase(it)
				items_dirty()
				_refresh_items())
		else:
			s = YoutdSlot.new(null, Color.TRANSPARENT, SLOT - 4)
		s.on_drop = func(data): _drop_in_cube(data)
		s.accepts = func(data): return data is Dictionary and data.has("yt_item")
		_cube_slots.add_child(s)
	_clear(_cube_recipes)
	for rec in YoutdCube.recipes():
		if not YoutdCube.unlocked(rec, p):
			continue
		var fill := YoutdCube.autofill(rec, game.item_stash)
		var b := UiUtil.button(YoutdPanel.recipe_name(rec), _cube_recipes, func():
			cube = YoutdCube.autofill(rec, game.item_stash)
			items_dirty()
			_refresh_items())
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(80, 24)
		b.add_theme_font_size_override("font_size", 11)
		b.disabled = fill.is_empty()
		b.tooltip_text = YoutdPanel.recipe_text(rec) + ("\n" + tr("Zu wenige passende Items im Lager.") if fill.is_empty() else "")


func _drop_in_cube(data: Dictionary) -> void:
	var i: int = game.stash_index(int(data.yt_item))
	if i < 0:
		return
	var it: YtItem = game.item_stash[i]
	if not cube.has(it) and cube.size() < 6 and not it.horadric_lock:
		cube.append(it)
	items_dirty()
	_refresh_items()


func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
