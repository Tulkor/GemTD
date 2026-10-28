class_name YoutdPanel
extends PanelContainer
## Seitenleiste oben links von YouTD: Wissensbücher und Food, Elemente erforschen, Startwurf, nächste Welle und die
## letzten Meldungen. Tower- und Item-Lager liegen unten links (youtd_store.gd). Dazu Tooltip-Texte für Tower,
## Items und Würfel-Rezepte.

const LOG_LINES := 4

var game  # youtd_game.gd
var _tomes: Label
var _food: Label
var _rows := {}   ## Element -> {level: Label, plus: Button}
var _roll: Button
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

	var el_head := UiUtil.label("Elemente", v, 15)
	UiTheme.heading(el_head)
	el_head.tooltip_text = tr("Elemente erforschen und Tower würfeln")
	el_head.mouse_filter = Control.MOUSE_FILTER_PASS
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
	_log.text = "\n".join(game.log_lines.slice(maxi(0, game.log_lines.size() - LOG_LINES)))
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



## Name eines Rezepts.
static func recipe_name(r: Dictionary) -> String:
	match str(r.get("id", "")):
		"rebrew":
			return _t("Neu brauen")
		"distill":
			return _t("Destillieren")
		"reassemble":
			return _t("Umbauen")
		"perfect":
			return _t("Vervollkommnen")
		"liquefy":
			return _t("Verflüssigen")
		"precipitate":
			return _t("Ausfällen")
		"imbue":
			return _t("Durchtränken")
	return str(r.get("name", ""))


## „3 Items gleicher Seltenheit → 1 Item, Level +5 bis +25“.
static func recipe_text(r: Dictionary) -> String:
	var parts := []
	if int(r.get("permanent", 0)) > 0:
		parts.append(_t("%d Items") % int(r.permanent))
	if int(r.get("usable", 0)) > 0:
		parts.append(_t("%d Öle/Verbrauch") % int(r.usable))
	var res := _t("Öl/Verbrauch") if str(r.get("result", "")) == "usable" else _t("Item")
	var text := _t("%s gleicher Seltenheit → %d× %s") % [" + ".join(parts), int(r.get("count", 1)), res]
	var change := int(r.get("rarity_change", 0))
	if change > 0:
		text += ", " + _t("%d Seltenheit höher") % change
	elif change < 0:
		text += ", " + _t("%d Seltenheit niedriger") % -change
	if str(r.get("id", "")) == "precipitate":
		text += ", " + _t("beliebiges Level")
	elif int(r.get("level_max", 0)) > 0:
		text += ", " + _t("Level +%d bis +%d") % [int(r.level_min), int(r.level_max)]
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
