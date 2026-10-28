class_name YoutdPanel
extends PanelContainer
## Seitenleiste von YouTD: Gold-unabhängige Vorräte (Wissensbücher, Food), darunter drei Schalter zum Auf- und
## Zuklappen: Elemente (Forschen, Startwurf), Lager (Tower-Lager bzw. Baumenü und Items) und Würfel (Horadrischer
## Würfel, braucht das Lager offen). Unten immer nächste Welle und die letzten Meldungen.

var game  # youtd_game.gd
var _tomes: Label
var _food: Label
var _rows := {}   ## Element -> {level: Label, plus: Button}
var _roll: Button
var _towers_head: Label
var _towers: VBoxContainer
var _towers_key := ""
var _items_head: Label
var _items: HFlowContainer
var _items_key := ""
var _cube_box: VBoxContainer
var _cube_info: Label
var _cube_go: Button
var _cube_recipes: HFlowContainer
var cube_open := false     ## Würfel offen: Item-Klick legt in den Würfel statt in einen Tower
var cube: Array = []       ## Items im Würfel (YtItem, lokal)
var _next: Button
var _log: Label
var _sections := {}        ## "elements"/"store"/"cube" -> {button, box}
## Welche Bereiche offen sind (bleibt für die Sitzung, auch in der nächsten Partie)
static var open_sections := {"elements": true, "store": true, "cube": false}


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel(12.0, 0.94))
	custom_minimum_size.x = 280
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)

	var res := HBoxContainer.new()
	res.add_theme_constant_override("separation", 14)
	v.add_child(res)
	_tomes = _value("Bücher", res, UiTheme.HAVE)
	_tomes.get_parent().tooltip_text = tr("Wissensbücher: damit erforschst du Elemente. Jede geschaffte Welle bringt 8 dazu.")
	_food = _value("Food", res, UiTheme.TEXT)
	_food.get_parent().tooltip_text = tr("Jeder Tower braucht Food nach Seltenheit: gewöhnlich 2, ungewöhnlich 3, selten 4, einzigartig 6.")

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	v.add_child(bar)
	var el_box := _section("elements", "Elemente", bar, v, tr("Elemente erforschen und Tower würfeln"))
	var store_box := _section("store", "Lager", bar, v, tr("Tower-Lager bzw. Baumenü und Items"))
	var cube_box := _section("cube", "Würfel", bar, v, tr("Horadrischer Würfel: aus Items im Lager neue machen"))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	el_box.add_child(grid)
	for el in YoutdData.elements():
		var id := str(el)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(row)
		var sw := ColorRect.new()
		sw.color = YoutdData.element_color(id)
		sw.custom_minimum_size = Vector2(10, 10)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sw)
		var name := UiUtil.label(YoutdData.element_name(id), row, 12)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lvl := UiUtil.label("0", row, 13)
		lvl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var plus := UiUtil.button("+", row, func(): game.submit({"type": "research", "element": id}))
		plus.focus_mode = Control.FOCUS_NONE
		plus.custom_minimum_size = Vector2(24, 22)
		plus.add_theme_font_size_override("font_size", 12)
		_rows[id] = {"level": lvl, "plus": plus, "row": row}

	_roll = UiUtil.button("Tower würfeln", el_box, func(): game.submit({"type": "roll"}))
	_roll.focus_mode = Control.FOCUS_NONE
	_roll.custom_minimum_size.y = 32
	_roll.tooltip_text = tr("Sechs zufällige Tower der erforschten Elemente ins Lager. Bis der erste Tower steht, darfst du neu würfeln.")

	_towers_head = UiUtil.label("", store_box, 15)
	UiTheme.heading(_towers_head)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(256, 150)
	store_box.add_child(scroll)
	_towers = VBoxContainer.new()
	_towers.add_theme_constant_override("separation", 3)
	_towers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_towers)

	_items_head = UiUtil.label("", store_box, 15)
	UiTheme.heading(_items_head)
	_items_head.tooltip_text = tr("Item anklicken, dann einen Tower: Items belegen einen Platz, Öle wirken dauerhaft und brauchen keinen.")
	_items_head.mouse_filter = Control.MOUSE_FILTER_PASS
	_items = HFlowContainer.new()
	_items.add_theme_constant_override("h_separation", 3)
	_items.add_theme_constant_override("v_separation", 3)
	store_box.add_child(_items)
	_build_cube(cube_box)
	_apply_sections()

	_next = UiUtil.button("", v, func(): game.submit({"type": "next_wave"}))
	_next.focus_mode = Control.FOCUS_NONE
	_next.custom_minimum_size.y = 40
	_next.tooltip_text = tr("Nächste Welle sofort schicken (Taste N); laufende Wellen bleiben auf dem Feld.")
	UiTheme.accent_button(_next, UiTheme.GOLD, UiTheme.GOLD_DARK)
	_log = UiUtil.wrap_label("", v, 256)
	_log.add_theme_font_size_override("font_size", 12)
	_log.add_theme_color_override("font_color", UiTheme.MUTED)
	refresh()


## Schalter in der Leiste oben und der Bereich, den er auf- und zuklappt.
func _section(id: String, text: String, bar: HBoxContainer, v: VBoxContainer, tip: String) -> VBoxContainer:
	var b := UiUtil.button(text, bar, func(): toggle_section(id))
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 30
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
	b.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
	b.tooltip_text = tip
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	v.add_child(box)
	_sections[id] = {"button": b, "box": box}
	return box


## Bereich id auf- oder zuklappen. Der Würfel braucht das Lager (dort legt man die Items hinein).
func toggle_section(id: String) -> void:
	open_sections[id] = not bool(open_sections.get(id, false))
	if id == "cube" and open_sections.cube:
		open_sections.store = true
	elif id == "store" and not open_sections.store:
		open_sections.cube = false
	_apply_sections()


func _apply_sections() -> void:
	for id in _sections:
		var sec: Dictionary = _sections[id]
		var on := bool(open_sections.get(id, false))
		(sec.button as Button).set_pressed_no_signal(on)
		(sec.box as Control).visible = on
	if cube_open != bool(open_sections.cube):
		cube_open = bool(open_sections.cube)
		cube.clear()
		if game != null:
			game.picked_item = -1
		items_dirty()
		if _tomes != null and game != null:
			refresh()


func _value(caption: String, parent: Node, color: Color) -> Label:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(h)
	UiUtil.label(caption, h, 12).add_theme_color_override("font_color", UiTheme.MUTED)
	var l := UiUtil.label("", h, 16)
	l.add_theme_color_override("font_color", color)
	return l


func refresh() -> void:
	if _tomes == null:
		return
	visible = game.setup_done
	_tomes.text = str(game.tomes)
	_food.text = "%d / %d" % [game.food_used(), game.food_cap]
	_food.add_theme_color_override("font_color", UiTheme.MISSING if game.food_used() >= game.food_cap else UiTheme.TEXT)
	for id in _rows:
		var r: Dictionary = _rows[id]
		var lvl := int(game.elements.get(id, 0))
		(r.level as Label).text = str(lvl)
		(r.level as Label).add_theme_color_override("font_color", YoutdData.element_color(id) if lvl > 0 else UiTheme.MUTED)
		var plus: Button = r.plus
		plus.disabled = not game.can_research(id)
		var tip := YoutdData.element_name(id) + " " + tr("Stufe %d / %d") % [lvl, game.max_element_level()]
		if lvl < game.max_element_level():
			tip += "\n" + tr("Erforschen: %d Bücher") % game.research_cost(id)
		(r.row as Control).tooltip_text = tip
		plus.tooltip_text = tip
	_roll.visible = not game.is_build_mode() and game.can_reroll
	_roll.disabled = not game.any_element()
	_roll.text = tr("Tower würfeln") if game.stash.is_empty() else tr("Neu würfeln")
	_refresh_towers()
	_refresh_items()
	_log.text = "\n".join(game.log_lines)
	refresh_timer()


func refresh_timer() -> void:
	if _next == null:
		return
	var more: bool = game.setup_done and game.phase < game.Phase.GAME_OVER and game.next_wave <= game.max_wave()
	_next.visible = more
	if not more:
		return
	if game.alive.is_empty():
		_next.text = tr("Welle %d · %d s") % [game.next_wave, ceili(maxf(game.next_wave_in, 0.0))]
	else:
		_next.text = tr("Welle %d schon schicken") % game.next_wave


## Lager (Zufallsmodi) oder Baumenü (Baumodus); neu gebaut nur, wenn sich etwas ändert.
func _refresh_towers() -> void:
	var ids: Array = game.buildable()
	var list := []
	for id in ids:
		list.append([id, game.build_reason(id)])
	var key: String = str(list) + game.build_id
	if key == _towers_key:
		return
	_towers_key = key
	_towers_head.text = tr("Baumenü") if game.is_build_mode() else tr("Lager (%d)") % ids.size()
	for c in _towers.get_children():
		_towers.remove_child(c)
		c.queue_free()
	if list.is_empty():
		var hint := UiUtil.wrap_label(tr("Erforsche zuerst ein Element.") if not game.any_element()
				else (tr("Nach jeder Welle kommen neue Tower dazu.") if not game.is_build_mode() else ""), _towers, 250)
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", UiTheme.MUTED)
		return
	for entry in list:
		var id: String = entry[0]
		var t := YoutdData.tower(id)
		var b := UiUtil.button("%s · %d G" % [str(t.get("name", id)), int(t.get("cost", 0))], _towers, func(): game.choose_build(id))
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.custom_minimum_size = Vector2(250, 28)
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_color_override("font_color", YoutdData.rarity_color(str(t.get("rarity", "common"))))
		b.tooltip_text = tower_tip(id) + ("\n" + str(entry[1]) if entry[1] != "" else "")
		if game.build_id == id:
			b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN))
			b.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN))
			b.add_theme_color_override("font_color", UiTheme.BG)
			b.add_theme_color_override("font_hover_color", UiTheme.BG)
		elif entry[1] != "":
			b.modulate.a = 0.55


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
	_items_head.text = tr("Items (%d)") % game.item_stash.size()
	for c in _items.get_children():
		_items.remove_child(c)
		c.queue_free()
	_refresh_cube()
	if game.item_stash.is_empty():
		var hint := UiUtil.wrap_label(tr("Getötete Gegner lassen manchmal Items fallen."), _items, 250)
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", UiTheme.MUTED)
		return
	for i in game.item_stash.size():
		var it: YtItem = game.item_stash[i]
		var rarity := str(YoutdData.item(str(it.get_id())).get("rarity", "common"))
		var text: String = game.item_label(it)
		if it.horadric_lock:
			text = "# " + text
		var b := UiUtil.button(text.left(11), _items, func(): _item_clicked(i))
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(80, 26)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_color_override("font_color", YoutdData.rarity_color(rarity))
		b.tooltip_text = item_tip_for(it) + "\n" + (tr("Rechtsklick: für den Würfel sperren/freigeben") if cube_open
				else (tr("Klick: benutzen") if it.is_consumable() else tr("Klick, dann Tower anklicken: einlegen")))
		b.gui_input.connect(func(ev): _item_input(ev, it))
		if game.picked_item == i or cube.has(it):
			b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN))
			b.add_theme_color_override("font_color", UiTheme.BG)


func _item_clicked(i: int) -> void:
	if not cube_open:
		game.pick_item(i)
		return
	var it: YtItem = game.item_stash[i]
	if cube.has(it):
		cube.erase(it)
	elif cube.size() < 6:
		cube.append(it)
	items_dirty()
	_refresh_items()


func _item_input(ev: InputEvent, it: YtItem) -> void:
	if cube_open and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		game.submit({"type": "item_lock", "uid": it.get_uid()})
		items_dirty()


# --- Horadrischer Würfel -------------------------------------------------------------

func _build_cube(v: VBoxContainer) -> void:
	var head := UiUtil.label("Horadrischer Würfel", v, 15)
	UiTheme.heading(head)
	_cube_box = VBoxContainer.new()
	_cube_box.add_theme_constant_override("separation", 4)
	v.add_child(_cube_box)
	_cube_info = UiUtil.wrap_label("", _cube_box, 256)
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
		_cube_info.text = tr("Items anklicken, um sie in den Würfel zu legen, oder unten ein Rezept wählen.")
	elif r.is_empty():
		_cube_info.text = tr("Im Würfel: %d Items · kein passendes Rezept") % cube.size()
	else:
		_cube_info.text = tr("Rezept: %s\n%s") % [recipe_name(r), recipe_text(r)]
	_cube_go.disabled = r.is_empty()
	for c in _cube_recipes.get_children():
		_cube_recipes.remove_child(c)
		c.queue_free()
	for rec in YoutdCube.recipes():
		if not YoutdCube.unlocked(rec, p):
			continue
		var fill := YoutdCube.autofill(rec, game.item_stash)
		var b := UiUtil.button(recipe_name(rec), _cube_recipes, func():
			cube = YoutdCube.autofill(rec, game.item_stash)
			items_dirty()
			_refresh_items())
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(80, 24)
		b.add_theme_font_size_override("font_size", 11)
		b.disabled = fill.is_empty()
		b.tooltip_text = recipe_text(rec) + ("\n" + tr("Zu wenige passende Items im Lager.") if fill.is_empty() else "")


## Name eines Rezepts.
func recipe_name(r: Dictionary) -> String:
	match str(r.get("id", "")):
		"rebrew":
			return tr("Neu brauen")
		"distill":
			return tr("Destillieren")
		"reassemble":
			return tr("Umbauen")
		"perfect":
			return tr("Vervollkommnen")
		"liquefy":
			return tr("Verflüssigen")
		"precipitate":
			return tr("Ausfällen")
		"imbue":
			return tr("Durchtränken")
	return str(r.get("name", ""))


## „3 Items gleicher Seltenheit → 1 Item, Level +5 bis +25“.
func recipe_text(r: Dictionary) -> String:
	var parts := []
	if int(r.get("permanent", 0)) > 0:
		parts.append(tr("%d Items") % int(r.permanent))
	if int(r.get("usable", 0)) > 0:
		parts.append(tr("%d Öle/Verbrauch") % int(r.usable))
	var res := tr("Öl/Verbrauch") if str(r.get("result", "")) == "usable" else tr("Item")
	var text := tr("%s gleicher Seltenheit → %d× %s") % [" + ".join(parts), int(r.get("count", 1)), res]
	var change := int(r.get("rarity_change", 0))
	if change > 0:
		text += ", " + tr("%d Seltenheit höher") % change
	elif change < 0:
		text += ", " + tr("%d Seltenheit niedriger") % -change
	if str(r.get("id", "")) == "precipitate":
		text += ", " + tr("beliebiges Level")
	elif int(r.get("level_max", 0)) > 0:
		text += ", " + tr("Level +%d bis +%d") % [int(r.level_min), int(r.level_max)]
	return text


static func _t(text: String) -> String:
	return str(TranslationServer.translate(text))


## Kurzinfo zu einem Tower für Tooltips.
static func tower_tip(id: String) -> String:
	var t := YoutdData.tower(id)
	var lines := [str(t.get("name", id)) + " · " + YoutdData.rarity_name(str(t.get("rarity", ""))) + " · " + YoutdData.element_name(str(t.get("element", "")))]
	var d: Array = t.get("damage", [0, 0])
	lines.append(_t("Schaden %d–%d (%s) · alle %s s · Reichweite %d") % [int(d[0]), int(d[1]), YoutdData.attack_name(str(t.get("attack_type", ""))),
			TowerStats.num(float(t.get("cooldown", 1.0)), 2), int(t.get("range", 0))])
	lines.append(_t("Kosten %d Gold · Food %d · Stufe %d") % [int(t.get("cost", 0)), YoutdData.food_cost(id), int(t.get("tier", 1))])
	lines.append_array(mod_lines(t.get("mods", [])))
	for a in ability_names(t):
		lines.append(a)
	return "\n".join(lines)


static func item_tip(id: String) -> String:
	var it := YoutdData.item(id)
	var type_name := str(TranslationServer.translate(str(YoutdData.rules().get("items", {}).get("type_names", {}).get(str(it.get("type", "")), ""))))
	var lines := [str(it.get("name", id)) + " · " + YoutdData.rarity_name(str(it.get("rarity", ""))) + " · " + type_name]
	lines.append(_t("Ab Welle %d") % int(it.get("level", 0)) if int(it.get("level", 0)) > 0 else "")
	lines.append_array(mod_lines(it.get("mods", [])))
	lines.append_array(ability_names(it))
	return "\n".join(lines.filter(func(l): return l != ""))


## Tooltip eines Items im Lager: wie item_tip, dazu Ladungen und Werte des Skripts.
static func item_tip_for(it: YtItem) -> String:
	var text := item_tip(str(it.get_id()))
	if it.uses_charges():
		text += "\n" + _t("Ladungen: %d") % it.get_charges()
	if it.horadric_lock:
		text += "\n" + _t("Für den Würfel gesperrt")
	return text


## Fähigkeiten, Auren und Zauber eines Towers oder Items (Namen aus YouTD 2, englisch).
static func ability_names(d: Dictionary) -> Array:
	var out := []
	for id in d.get("abilities", []):
		var a := YtAbilityData.ability(int(id))
		if not a.is_empty():
			out.append(_t("Fähigkeit: %s") % str(a.get("name", "")))
	for id in d.get("auras", []):
		var a := YtAbilityData.aura(int(id))
		if not a.is_empty() and not bool(a.get("hidden", false)) and str(a.get("name", "")) != "":
			out.append(_t("Aura: %s") % str(a.name))
	for id in d.get("autocasts", []):
		var a := YtAbilityData.autocast(int(id))
		if not a.is_empty():
			out.append(_t("Zauber: %s") % str(a.get("name", "")))
	return out


## "+25 % Schaden" usw. aus [[MOD, Wert, je Level]].
static func mod_lines(mods: Array) -> Array:
	var out := []
	var r := YoutdData.rules()
	for m in mods:
		var key := str(m[0])
		var flat: bool = (r.get("mod_flat", []) as Array).has(key)
		var name := str(TranslationServer.translate(str(r.get("mod_names", {}).get(key, key))))
		var line := "%s %s" % [_amount(float(m[1]), flat), name]
		if m.size() > 2 and float(m[2]) != 0.0:
			line += " " + _t("(%s je Level)") % _amount(float(m[2]), flat)
		out.append(line)
	return out


static func _amount(v: float, flat: bool) -> String:
	var sign := "+" if v >= 0.0 else ""
	return sign + (TowerStats.num(v, 1) if flat else TowerStats.num(v * 100.0, 2) + " %")
