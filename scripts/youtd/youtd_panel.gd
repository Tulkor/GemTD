class_name YoutdPanel
extends PanelContainer
## Seitenleiste von YouTD: Gold-unabhängige Vorräte (Wissensbücher, Food), die neun Elemente mit Forschen-Knopf,
## Startwurf, Tower-Lager bzw. Baumenü, Item-Lager, nächste Welle und die letzten Meldungen.

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
var _next: Button
var _log: Label


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

	var head := UiUtil.label("Elemente", v, 15)
	UiTheme.heading(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
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

	_roll = UiUtil.button("Tower würfeln", v, func(): game.submit({"type": "roll"}))
	_roll.focus_mode = Control.FOCUS_NONE
	_roll.custom_minimum_size.y = 32
	_roll.tooltip_text = tr("Sechs zufällige Tower der erforschten Elemente ins Lager. Bis der erste Tower steht, darfst du neu würfeln.")

	_towers_head = UiUtil.label("", v, 15)
	UiTheme.heading(_towers_head)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(256, 150)
	v.add_child(scroll)
	_towers = VBoxContainer.new()
	_towers.add_theme_constant_override("separation", 3)
	_towers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_towers)

	_items_head = UiUtil.label("", v, 15)
	UiTheme.heading(_items_head)
	_items_head.tooltip_text = tr("Item anklicken, dann einen Tower: Items belegen einen Platz, Öle wirken dauerhaft und brauchen keinen.")
	_items_head.mouse_filter = Control.MOUSE_FILTER_PASS
	_items = HFlowContainer.new()
	_items.add_theme_constant_override("h_separation", 3)
	_items.add_theme_constant_override("v_separation", 3)
	v.add_child(_items)

	_next = UiUtil.button("", v, func(): game.submit({"type": "next_wave"}))
	_next.focus_mode = Control.FOCUS_NONE
	_next.custom_minimum_size.y = 40
	_next.tooltip_text = tr("Nächste Welle sofort schicken (Taste N); laufende Wellen bleiben auf dem Feld.")
	UiTheme.accent_button(_next, UiTheme.GOLD, UiTheme.GOLD_DARK)
	_log = UiUtil.wrap_label("", v, 256)
	_log.add_theme_font_size_override("font_size", 12)
	_log.add_theme_color_override("font_color", UiTheme.MUTED)
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


func _refresh_items() -> void:
	var key: String = str(game.item_stash) + str(game.picked_item)
	if key == _items_key:
		return
	_items_key = key
	_items_head.text = tr("Items (%d)") % game.item_stash.size()
	for c in _items.get_children():
		_items.remove_child(c)
		c.queue_free()
	if game.item_stash.is_empty():
		var hint := UiUtil.wrap_label(tr("Getötete Gegner lassen manchmal Items fallen."), _items, 250)
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", UiTheme.MUTED)
		return
	for i in game.item_stash.size():
		var id := str(game.item_stash[i])
		var it := YoutdData.item(id)
		var short := str(it.get("name", id))
		var b := UiUtil.button(short.left(10), _items, func(): game.pick_item(i))
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(80, 26)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_color_override("font_color", YoutdData.rarity_color(str(it.get("rarity", "common"))))
		b.tooltip_text = item_tip(id)
		if game.picked_item == i:
			b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN))
			b.add_theme_color_override("font_color", UiTheme.BG)


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
	if t.has("script"):
		lines.append(_t("Eigene Fähigkeit folgt in Etappe 2."))
	return "\n".join(lines)


static func item_tip(id: String) -> String:
	var it := YoutdData.item(id)
	var type_name := str(TranslationServer.translate(str(YoutdData.rules().get("items", {}).get("type_names", {}).get(str(it.get("type", "")), ""))))
	var lines := [str(it.get("name", id)) + " · " + YoutdData.rarity_name(str(it.get("rarity", ""))) + " · " + type_name]
	lines.append_array(mod_lines(it.get("mods", [])))
	if it.has("script"):
		lines.append(_t("Eigene Wirkung folgt in Etappe 3."))
	return "\n".join(lines)


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
