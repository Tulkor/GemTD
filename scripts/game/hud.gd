class_name Hud
extends CanvasLayer
## Oberfläche im Spiel: Leiste oben, Phasenbanner, angepinnte Rezepte links,
## Auswahlkarte unten (neue Gems, Werte, "Wird gebraucht für", Aktionen) und Rezeptbuch.

signal option_chosen(index: int)
signal round_gem_selected(index: int)
signal speed_selected(factor: float)
signal menu_requested
signal main_menu_requested
signal restart_requested
signal debug_tower_changed(key: String)
signal debug_immortal_changed(on: bool)
signal debug_gems_changed(count: int)
signal debug_gold_requested(amount: int)
signal debug_lives_requested(amount: int)
signal debug_wave_requested(number: int)

const BANNER_TOP := 64.0
const LEFT_TOP := 120.0
const SPEEDS := [1.0, 2.0, 4.0]

var root: Control
var wave_value: Label
var lives_value: Label
var gold_value: Label
var path_value: Label
var game_over: Control
var leave_confirm: Control
var game_over_title: Label
var game_over_stats: Label
var editor_button: Button
var chance_value: Label
var left_col: VBoxContainer
var speed_buttons: Array[Button] = []
var debug_option: OptionButton
var debug_button: Button
var debug_panel: PanelContainer
var debug_gems: SpinBox
var debug_wave: SpinBox
var immortal_button: Button
var debug_keys: Array[String] = []

var banner: PanelContainer
var phase_title: Label
var phase_label: Label
var oneshot_pill: PanelContainer
var oneshot_label: Label

var pinned_panel: PanelContainer
var waves_panel: PanelContainer
var waves_box: VBoxContainer
var _waves: Array = []
var pinned_box: VBoxContainer

var bottom: PanelContainer
var strip_col: VBoxContainer
var strip_row: HBoxContainer
var strip_hint: Label
var info_col: VBoxContainer
var info_title: Label
var info_swatch: ColorRect
var info_body: Label
var used_col: VBoxContainer
var used_row: HBoxContainer
var used_prev: Button
var used_next: Button
var used_page_label: Label
var used_page := 0
var _used_ids: Variant = null
var actions_col: VBoxContainer
var separators: Array[Control] = []

var help_panel: PanelContainer
var message_label: Label
var recipe_book: RecipeBook

var owned: Array = []
var owned_now := {}
var _options: Array = []
var _main_index := -1
var _main_button: Button
var _gems: Array = []
var _used_key := []
var _selection: Dictionary = {}
var _speed := -1.0


func _ready() -> void:
	# Läuft auch bei pausiertem Spiel weiter, damit die Rückfrage beim Verlassen bedienbar bleibt
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top_bar()
	_build_banner()
	_build_pinned()
	_build_bottom()
	_build_help()
	_build_debug()

	message_label = Label.new()
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message_label.add_theme_font_size_override("font_size", 48)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 8)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(message_label)

	recipe_book = RecipeBook.new()
	root.add_child(recipe_book)
	_build_game_over()
	_build_leave_confirm()
	recipe_book.pins_changed.connect(_refresh_pinned)
	_refresh_pinned()


func _process(_delta: float) -> void:
	if Engine.time_scale != _speed:
		_speed = Engine.time_scale
		for i in SPEEDS.size():
			speed_buttons[i].set_pressed_no_signal(is_equal_approx(SPEEDS[i], _speed))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if game_over != null and game_over.visible:
		return
	if leave_confirm != null and leave_confirm.visible:
		if event.keycode == KEY_ESCAPE:
			close_leave_confirm()
		get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_R:
			toggle_recipe_book()
		KEY_ESCAPE:
			if recipe_book.visible:
				recipe_book.close()
			elif help_panel.visible:
				help_panel.hide()
			else:
				return
		KEY_SPACE:
			if recipe_book.visible or _main_button == null or _main_button.disabled:
				return
			option_chosen.emit(_main_index)
		_:
			return
	get_viewport().set_input_as_handled()


# --- Aufbau ------------------------------------------------------------------

func _button(text: String, parent: Node, on_pressed: Callable) -> Button:
	var b := UiUtil.button(text, parent, on_pressed)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _chip(caption: String, parent: Node, color := UiTheme.TEXT) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, UiTheme.BORDER, 0, 2, 10))
	parent.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	UiUtil.label(caption, h, 12).add_theme_color_override("font_color", UiTheme.MUTED)
	var v := UiUtil.label("", h, 16)
	v.add_theme_color_override("font_color", color)
	return v


func _vsep(parent: Node) -> void:
	var s := ColorRect.new()
	s.color = UiTheme.BORDER
	s.custom_minimum_size.x = 1
	parent.add_child(s)
	separators.append(s)


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	var bar_style := UiTheme.box(UiTheme.BAR, Color.TRANSPARENT, 0, 0, 14)
	bar_style.border_color = UiTheme.GOLD
	bar_style.border_width_bottom = 3
	bar_style.shadow_color = UiTheme.CYAN
	bar_style.shadow_size = 1
	bar_style.shadow_offset = Vector2(0, 4)
	bar.add_theme_stylebox_override("panel", bar_style)
	bar.anchor_right = 1.0
	bar.custom_minimum_size.y = 52
	root.add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	bar.add_child(h)
	UiTheme.title(UiUtil.label("GemTD", h, 22))
	h.add_child(_spacer(4))
	wave_value = _chip("Welle", h)
	lives_value = _chip("Leben", h, UiTheme.MISSING)
	gold_value = _chip("Gold", h, UiTheme.COIN)
	path_value = _chip("Weg", h)
	path_value.get_parent().get_parent().tooltip_text = "Länge des Laufwegs der Bodengegner in Feldern (ein Tower ist 2 Felder breit).\nIn Klammern: wie viel länger der Weg in dieser Bauphase geworden ist."
	chance_value = _chip("Chance", h)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(fill)

	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 0)
	h.add_child(speed_row)
	var group := ButtonGroup.new()
	for f in SPEEDS:
		var b := _button("%dx" % int(f), speed_row, func(): speed_selected.emit(f))
		b.toggle_mode = true
		b.button_group = group
		b.tooltip_text = "Tempo (Tasten 1, 2, 3)"
		b.custom_minimum_size.x = 44
		b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
		b.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)
		speed_buttons.append(b)

	debug_button = _button("Debug", h, func(): debug_panel.visible = not debug_panel.visible)
	debug_button.toggle_mode = true
	debug_button.tooltip_text = "Debug-Menü"
	debug_button.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN, 0, 2))
	debug_button.add_theme_color_override("font_pressed_color", UiTheme.GOLD_DARK)

	_button("Rezepte", h, toggle_recipe_book).tooltip_text = "Rezeptbuch (Taste R)"
	_button("Hilfe", h, func(): help_panel.visible = not help_panel.visible)
	_button("Menü", h, open_leave_confirm)


## Panel-Überschrift: Großbuchstaben, fett.
func _panel_title(l: Label) -> Label:
	l.uppercase = true
	l.add_theme_font_override("font", UiTheme.font(true))
	return l


func _spacer(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = w
	return c


func _build_banner() -> void:
	banner = PanelContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override("panel", UiTheme.panel(18.0, 0.92))
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_top = BANNER_TOP
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(banner)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 12)
	banner.add_child(h)
	phase_title = UiUtil.label("", h, 15)
	phase_title.uppercase = true
	phase_title.add_theme_font_override("font", UiTheme.font(true))
	phase_title.add_theme_color_override("font_color", UiTheme.CYAN)
	phase_label = UiUtil.label("", h, 15)
	oneshot_pill = PanelContainer.new()
	oneshot_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oneshot_pill.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PURPLE, Color.TRANSPARENT, 0, 0, 10))
	h.add_child(oneshot_pill)
	oneshot_label = UiUtil.label("", oneshot_pill, 13)
	oneshot_label.add_theme_color_override("font_color", Color.WHITE)


func _build_pinned() -> void:
	# Linke Spalte: nächste Wellen, darunter die angepinnten Rezepte
	var left := VBoxContainer.new()
	left_col = left
	left.offset_left = 16
	left.offset_top = LEFT_TOP
	left.custom_minimum_size.x = 280
	left.add_theme_constant_override("separation", 12)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left)
	waves_panel = PanelContainer.new()
	waves_panel.add_theme_stylebox_override("panel", UiTheme.panel(12.0, 0.94))
	left.add_child(waves_panel)
	waves_box = VBoxContainer.new()
	waves_box.add_theme_constant_override("separation", 8)
	waves_panel.add_child(waves_box)
	pinned_panel = PanelContainer.new()
	pinned_panel.add_theme_stylebox_override("panel", UiTheme.panel(12.0, 0.94))
	left.add_child(pinned_panel)
	pinned_box = VBoxContainer.new()
	pinned_box.add_theme_constant_override("separation", 10)
	pinned_panel.add_child(pinned_box)


func _build_bottom() -> void:
	bottom = PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", UiTheme.panel(14.0, 0.96))
	bottom.anchor_left = 0.5
	bottom.anchor_right = 0.5
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_bottom = -16
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(bottom)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	bottom.add_child(h)

	strip_col = VBoxContainer.new()
	h.add_child(strip_col)
	UiTheme.caption("Neue Gems dieser Runde", strip_col)
	strip_row = HBoxContainer.new()
	strip_row.add_theme_constant_override("separation", 8)
	strip_col.add_child(strip_row)
	strip_hint = UiUtil.label("", strip_col, 12)
	strip_hint.add_theme_color_override("font_color", UiTheme.PURPLE_LIGHT)
	_vsep(h)

	info_col = VBoxContainer.new()
	info_col.custom_minimum_size.x = 250
	info_col.add_theme_constant_override("separation", 4)
	h.add_child(info_col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	info_col.add_child(head)
	info_swatch = ColorRect.new()
	info_swatch.custom_minimum_size = Vector2(26, 26)
	info_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(info_swatch)
	info_title = UiUtil.label("", head, 20)
	info_body = UiUtil.wrap_label("", info_col, 250)
	info_body.add_theme_font_size_override("font_size", 13)
	info_body.add_theme_color_override("font_color", UiTheme.DIM)
	_vsep(h)

	used_col = VBoxContainer.new()
	h.add_child(used_col)
	# Kopfzeile mit Pfeilen zum Weiterklicken, darunter genau ein Rezept
	var used_head := HBoxContainer.new()
	used_head.add_theme_constant_override("separation", 6)
	used_col.add_child(used_head)
	UiTheme.caption("Wird gebraucht für", used_head).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	used_prev = UiUtil.button("‹", used_head, func(): _turn_used_page(-1))
	used_page_label = UiUtil.label("", used_head, 12)
	used_page_label.add_theme_color_override("font_color", UiTheme.MUTED)
	used_next = UiUtil.button("›", used_head, func(): _turn_used_page(1))
	for b in [used_prev, used_next]:
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(30, 24)
		b.add_theme_font_size_override("font_size", 16)
	used_row = HBoxContainer.new()
	used_row.custom_minimum_size = Vector2(320, 0)
	used_col.add_child(used_row)
	_vsep(h)

	actions_col = VBoxContainer.new()
	actions_col.custom_minimum_size.x = 260
	actions_col.add_theme_constant_override("separation", 8)
	h.add_child(actions_col)
	for c in [strip_col, info_col, used_col, actions_col]:
		c.visible = false
	_update_layout()


func _build_help() -> void:
	help_panel = PanelContainer.new()
	help_panel.anchor_left = 1.0
	help_panel.anchor_right = 1.0
	help_panel.offset_top = 64
	help_panel.offset_right = -16
	help_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(help_panel)
	UiUtil.wrap_label("Linksklick: Gem setzen / Tower oder Stein auswählen\nRechtsklick, Esc: Auswahl aufheben\nLeertaste: große Aktion (Behalten / One-Shot)\nR: Rezeptbuch\nWASD/Pfeile, Fensterrand, rechte Maustaste ziehen: Kamera bewegen\nQ/E oder mittlere Maustaste: drehen, Mausrad: zoomen\n1, 2, 3: Tempo", help_panel, 320)
	help_panel.hide()


## Debug-Menü unter dem Debug-Knopf: Gems pro Runde, Gold, Leben, nächster Gem, Unsterblich, Welle.
func _build_debug() -> void:
	debug_panel = PanelContainer.new()
	debug_panel.anchor_left = 1.0
	debug_panel.anchor_right = 1.0
	debug_panel.offset_top = 60
	debug_panel.offset_right = -16
	debug_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	debug_panel.custom_minimum_size.x = 320
	debug_panel.add_theme_stylebox_override("panel", UiTheme.panel(14.0))
	root.add_child(debug_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	debug_panel.add_child(v)
	UiTheme.title(UiUtil.label("Debug", v, 18))

	var row := _debug_row("Gems pro Runde", v)
	debug_gems = SpinBox.new()
	debug_gems.min_value = 1
	debug_gems.max_value = 20
	debug_gems.value_changed.connect(func(n): debug_gems_changed.emit(int(n)))
	row.add_child(debug_gems)

	row = _debug_row("Gold", v)
	for n in [100, 1000]:
		_button("+%d" % n, row, func(): debug_gold_requested.emit(n))
	row = _debug_row("Leben", v)
	for n in [10, 50]:
		_button("+%d" % n, row, func(): debug_lives_requested.emit(n))

	UiTheme.caption("Nächster Gem", v)
	debug_option = OptionButton.new()
	debug_option.fit_to_longest_item = false
	debug_option.clip_text = true
	debug_option.focus_mode = Control.FOCUS_NONE
	debug_option.tooltip_text = "Welcher Gem als nächstes gesetzt wird"
	v.add_child(debug_option)
	debug_option.item_selected.connect(func(i): debug_tower_changed.emit(debug_keys[i]))

	immortal_button = CheckBox.new()
	immortal_button.text = "Unsterblich (Leben dürfen ins Minus)"
	immortal_button.focus_mode = Control.FOCUS_NONE
	immortal_button.toggled.connect(func(on): debug_immortal_changed.emit(on))
	v.add_child(immortal_button)

	row = _debug_row("Welle", v)
	debug_wave = SpinBox.new()
	debug_wave.min_value = 1
	row.add_child(debug_wave)
	_button("Starten", row, func(): debug_wave_requested.emit(int(debug_wave.value)))
	var hint := UiUtil.wrap_label("Läuft gerade eine Welle, wird sie abgebrochen und die gewählte startet sofort. In der Bau- und Wahlphase kommt sie als nächste.", v, 290)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UiTheme.MUTED)
	debug_panel.hide()


func _debug_row(text: String, parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var l := UiUtil.label(text, row, 14)
	l.custom_minimum_size.x = 120
	return row


# --- Schnittstelle für game.gd -------------------------------------------------

func setup_debug_towers(preselect: String) -> void:
	debug_option.clear()
	debug_keys = [""]
	debug_option.add_item(tr("Zufälliger Gem"))
	var specials := Database.special_ids()
	var gems := Database.gem_ids()
	var groups := [["Basis-Gems", gems], ["Spezial-Tower", specials],
			["Sonstige", Database.tower_ids().filter(func(id): return not gems.has(id) and not specials.has(id))]]
	for g in groups:
		if (g[1] as Array).is_empty():
			continue
		# Trenner: OptionButton zählt sie als Einträge mit, daher Platzhalter in debug_keys
		debug_option.add_separator(tr(g[0]))
		debug_keys.append("")
		for id in g[1]:
			for t in Database.tier_count(id):
				debug_keys.append("%s:%d" % [id, t])
				debug_option.add_item(Database.tower_label(id, t))
	debug_option.select(maxi(debug_keys.find(preselect), 0) if preselect != "" else 0)


## Werte für das Debug-Menü: Gems pro Runde und Anzahl der Wellen.
func setup_debug(gems_per_round: int, wave_count: int) -> void:
	debug_gems.set_value_no_signal(gems_per_round)
	debug_wave.max_value = maxi(wave_count, 1)


func set_resources(wave: int, waves: int, lives: int, gold: int) -> void:
	wave_value.text = "%d / %d" % [wave, waves]
	lives_value.text = str(lives)
	gold_value.text = str(gold)


## level: aktuelle Chance-Stufe, next_wave: ab dieser Welle gilt die nächste (-1 = schon maximal).
func set_chance(level: int, next_wave: int) -> void:
	chance_value.text = tr("Stufe %d") % level
	chance_value.get_parent().get_parent().tooltip_text = tr("Bessere Gems: die Chance-Stufe steigt automatisch.") + "\n" + \
		(tr("Stufe %d ab Welle %d") % [level + 1, next_wave] if next_wave >= 0 else tr("Höchste Stufe erreicht"))


## oneshot: Text für die lila Markierung, leer = keine.
func set_phase(title: String, text: String, oneshot := "") -> void:
	phase_title.text = title
	phase_label.text = text
	phase_label.visible = text != ""
	oneshot_pill.visible = oneshot != ""
	oneshot_label.text = oneshot
	var border := UiTheme.PURPLE_LIGHT if oneshot != "" else UiTheme.BORDER_2
	(banner.get_theme_stylebox("panel") as StyleBoxFlat).border_color = border
	_recenter.call_deferred()


## Tower auf dem Feld plus neue Gems, als [id, stufe] – für die Rezeptanzeige.
## now: was gerade zum Bauen zählt, {"pool": [[id, stufe]], "wave": bool} (siehe Recipes.ready_now).
func set_owned(list: Array, now := {}) -> void:
	if list == owned and now == owned_now:
		return
	owned = list
	owned_now = now
	_used_key = []
	_refresh_used_in()
	_refresh_pinned()
	if recipe_book.visible:
		recipe_book.open(owned, owned_now)


## gems: [{label, color, selected, oneshot}] – die neuen Gems der Runde.
func set_round_gems(gems: Array, hint := "") -> void:
	strip_hint.text = hint
	if gems == _gems:
		return
	_gems = gems
	for c in strip_row.get_children():
		strip_row.remove_child(c)
		c.queue_free()
	for i in gems.size():
		var g: Dictionary = gems[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(50, 50)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = g.label
		var border := UiTheme.GOLD if g.selected else (UiTheme.PURPLE_LIGHT if g.oneshot else UiTheme.BORDER_2)
		var bg := Color("241a38") if g.oneshot else (Color("2a0f2e") if g.selected else UiTheme.PANEL_2)
		var st := UiTheme.box(bg, border, 6, 2, 0)
		b.add_theme_stylebox_override("normal", st)
		var hover := st.duplicate() as StyleBoxFlat
		hover.border_color = UiTheme.GOLD
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", hover)
		var sw := ColorRect.new()
		sw.color = g.color
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sw.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		sw.custom_minimum_size = Vector2(26, 26)
		sw.offset_left = -13
		sw.offset_top = -13
		sw.offset_right = 13
		sw.offset_bottom = 13
		b.add_child(sw)
		b.pressed.connect(func(): round_gem_selected.emit(i))
		strip_row.add_child(b)
	strip_col.visible = not gems.is_empty()
	_update_layout()


## info: {title, color, body, used_in (Array von Rezept-IDs, null = Abschnitt ausblenden)} oder {} für nichts.
func set_selection(info: Dictionary) -> void:
	_selection = info
	info_col.visible = not info.is_empty()
	if info.is_empty():
		_update_layout()
		return
	info_title.text = info.title
	info_title.add_theme_color_override("font_color", (info.color as Color).lerp(Color.WHITE, 0.25))
	info_swatch.color = info.color
	info_body.text = info.body
	_refresh_used_in()
	_update_layout()


## options: [{label, style}] mit style "oneshot" (lila), "primary" (gold) oder "normal".
## Der erste One-Shot, sonst die erste Hauptaktion, wird zum großen Button (Leertaste).
func set_options(options: Array) -> void:
	if options == _options:
		return
	_options = options
	_main_button = null
	for c in actions_col.get_children():
		actions_col.remove_child(c)
		c.queue_free()
	_main_index = -1
	for style in ["oneshot", "primary"]:
		if _main_index < 0:
			for i in options.size():
				if options[i].get("style", "normal") == style:
					_main_index = i
					break
	if not options.is_empty():
		UiTheme.caption("Aktionen", actions_col)
	if _main_index >= 0:
		var o: Dictionary = options[_main_index]
		var main := _main_index
		var big := _button(o.label, actions_col, func(): option_chosen.emit(main))
		_main_button = big
		big.tooltip_text = o.label + " " + tr("(Leertaste)")
		big.clip_text = true
		big.custom_minimum_size = Vector2(260, 56)
		big.add_theme_font_size_override("font_size", 18)
		if o.style == "oneshot":
			UiTheme.accent_button(big, UiTheme.PURPLE, Color.WHITE, Color(UiTheme.PURPLE_LIGHT, 0.55))
		else:
			UiTheme.accent_button(big, UiTheme.GOLD, UiTheme.GOLD_DARK, Color(UiTheme.GOLD, 0.45))
		var hint: String = tr("Leertaste") + (" · " + str(o.hint) if o.has("hint") else "")
		UiUtil.wrap_label(hint, actions_col, 260).add_theme_color_override("font_color", UiTheme.MUTED)
	for i in options.size():
		if i == _main_index:
			continue
		var o: Dictionary = options[i]
		var b := _button(o.label, actions_col, func(): option_chosen.emit(i))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.custom_minimum_size = Vector2(260, 40)
		if o.has("sub"):
			_two_line(b, o.label, o.sub)
		if o.get("style", "normal") == "oneshot":
			b.add_theme_stylebox_override("normal", UiTheme.box(Color("241a38"), UiTheme.PURPLE_LIGHT))
	actions_col.visible = not options.is_empty()
	_update_layout()


## Knopf mit Name oben und kleiner goldener Zeile darunter (z. B. Upgrade und Goldkosten).
func _two_line(b: Button, title: String, sub: String) -> void:
	b.text = ""
	b.tooltip_text = title + " · " + sub
	b.custom_minimum_size.y = 54
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_right = -12
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(v)
	var t := UiUtil.label(title, v, 15)
	t.clip_text = true
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := UiUtil.label(sub, v, 13)
	g.add_theme_color_override("font_color", UiTheme.COIN)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_options_enabled(enabled: bool) -> void:
	for b in actions_col.get_children():
		if b is Button:
			(b as Button).disabled = not enabled


## waves: [{number, type, detail, color, state}] – type: "Boden", "Flieger", "Masse", "Boss" oder "Gemischt",
## state: "läuft", "nächste" oder "".
func set_waves(waves: Array) -> void:
	if waves == _waves:
		return
	_waves = waves
	for c in waves_box.get_children():
		waves_box.remove_child(c)
		c.queue_free()
	_panel_title(UiUtil.label("Nächste Wellen", waves_box, 15))
	for w in waves:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		waves_box.add_child(row)
		var icon := WaveIcon.new()
		icon.kind = w.type
		icon.custom_minimum_size = Vector2(26, 26)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		v.add_child(head)
		UiUtil.label(tr("Welle %d") % w.number, head, 14)
		var t := UiUtil.label(tr(w.type), head, 14)
		t.add_theme_color_override("font_color", WaveIcon.COLORS.get(w.type, UiTheme.TEXT))
		if w.state != "":
			var st := UiUtil.label(w.state, head, 12)
			st.add_theme_color_override("font_color", UiTheme.GOLD)
			st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var d := UiUtil.label(w.detail, v, 12)
		d.add_theme_color_override("font_color", UiTheme.MUTED)
	waves_panel.visible = not waves.is_empty()


func show_message(text: String) -> void:
	message_label.text = text


## delta: wie viel länger der Weg seit Beginn der Bauphase ist (0 = nicht anzeigen).
func set_path_length(cells: int, delta: int) -> void:
	path_value.text = tr("%d Felder") % cells
	if delta != 0:
		path_value.text += " (%+d)" % delta
	path_value.add_theme_color_override("font_color", UiTheme.HAVE if delta > 0 else (UiTheme.MISSING if delta < 0 else UiTheme.TEXT))


func show_game_over(victory: bool, wave: int, waves: int, lives: int, kills: int, path_cells: int) -> void:
	recipe_book.hide()
	help_panel.hide()
	game_over_title.text = "Gewonnen!" if victory else "Verloren"
	game_over_title.add_theme_color_override("font_color", UiTheme.GOLD if victory else UiTheme.MISSING)
	game_over_stats.text = tr("Schwierigkeit: ") + tr(Session.difficulty_name()) + "\n" + tr("Welle %d von %d\nLeben übrig: %d\nGegner besiegt: %d\nWeglänge am Ende: %d Felder") % [wave, waves, lives, kills, path_cells]
	editor_button.visible = Session.return_scene != Session.MAIN_MENU
	editor_button.text = "Zurück zum Map-Editor" if Session.return_scene == Session.MAP_EDITOR else "Zurück zum Tower-Editor"
	game_over.show()


func _build_game_over() -> void:
	game_over = Control.new()
	game_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(game_over)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(28.0))
	panel.custom_minimum_size.x = 380
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	game_over_title = UiTheme.title(UiUtil.label("", v, 40))
	game_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_stats = UiUtil.label("", v, 15)
	game_over_stats.add_theme_color_override("font_color", UiTheme.DIM)
	game_over_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_spacer(0))
	var again := _button("Nochmal spielen", v, func(): restart_requested.emit())
	again.tooltip_text = "Dieselbe Map mit denselben Einstellungen neu starten"
	again.custom_minimum_size.y = 52
	again.add_theme_font_size_override("font_size", 18)
	UiTheme.accent_button(again, UiTheme.GOLD, UiTheme.GOLD_DARK, Color(UiTheme.GOLD, 0.35))
	editor_button = _button("", v, func(): menu_requested.emit())
	editor_button.custom_minimum_size.y = 44
	var menu := _button("Hauptmenü", v, func(): main_menu_requested.emit())
	menu.custom_minimum_size.y = 44
	game_over.hide()


## Rückfrage, bevor der Menü-Knopf die laufende Partie verlässt. Das Spiel ist solange pausiert.
func _build_leave_confirm() -> void:
	leave_confirm = Control.new()
	leave_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	leave_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(leave_confirm)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	leave_confirm.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	leave_confirm.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(28.0))
	panel.custom_minimum_size.x = 380
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var title := UiTheme.title(UiUtil.label("Spiel verlassen?", v, 26))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var text := UiUtil.label("Die laufende Partie geht dabei verloren.", v, 15)
	text.add_theme_color_override("font_color", UiTheme.DIM)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_spacer(0))
	var stay := _button("Weiterspielen", v, close_leave_confirm)
	stay.custom_minimum_size.y = 52
	stay.add_theme_font_size_override("font_size", 18)
	UiTheme.accent_button(stay, UiTheme.GOLD, UiTheme.GOLD_DARK, Color(UiTheme.GOLD, 0.35))
	var leave := _button("Verlassen", v, func():
		leave_confirm.hide()
		menu_requested.emit())
	leave.custom_minimum_size.y = 44
	leave.add_theme_color_override("font_color", UiTheme.MISSING)
	leave.add_theme_color_override("font_hover_color", UiTheme.MISSING.lightened(0.2))
	var hint := UiUtil.label("Esc: weiterspielen", v, 12)
	hint.add_theme_color_override("font_color", UiTheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leave_confirm.hide()


func open_leave_confirm() -> void:
	leave_confirm.show()
	get_tree().paused = true


func close_leave_confirm() -> void:
	leave_confirm.hide()
	get_tree().paused = false


func toggle_recipe_book() -> void:
	if recipe_book.visible:
		recipe_book.close()
	else:
		recipe_book.open(owned, owned_now)


# --- intern ------------------------------------------------------------------

func _refresh_used_in() -> void:
	var ids = _selection.get("used_in", null)
	if ids != _used_ids:
		_used_ids = ids
		used_page = 0
	var key := [ids, Session.pinned_recipes.duplicate(), owned, owned_now, used_page]
	if key == _used_key:
		return
	_used_key = key
	for c in used_row.get_children():
		used_row.remove_child(c)
		c.queue_free()
	used_col.visible = ids != null
	if ids == null:
		return
	var count := (ids as Array).size()
	used_prev.visible = count > 1
	used_next.visible = count > 1
	used_page_label.visible = count > 1
	used_page_label.text = "%d / %d" % [used_page + 1, count]
	if count == 0:
		UiUtil.label("Keine Rezepte brauchen diesen Tower.", used_row, 13).add_theme_color_override("font_color", UiTheme.MUTED)
		return
	var c := RecipeBook.card(ids[used_page], owned, _on_pins_changed, true, owned_now)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	used_row.add_child(c)
	_recenter.call_deferred()


func _turn_used_page(step: int) -> void:
	var count := (_used_ids as Array).size() if _used_ids != null else 0
	if count == 0:
		return
	used_page = posmod(used_page + step, count)
	_refresh_used_in()


func _on_pins_changed() -> void:
	_refresh_pinned.call_deferred()
	_refresh_used_in.call_deferred()


func _refresh_pinned() -> void:
	if pinned_box == null:
		return
	for c in pinned_box.get_children():
		pinned_box.remove_child(c)
		c.queue_free()
	var head := HBoxContainer.new()
	pinned_box.add_child(head)
	var t := _panel_title(UiUtil.label("Angepinnt", head, 15))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiUtil.label("%d" % Session.pinned_recipes.size(), head, 12).add_theme_color_override("font_color", UiTheme.MUTED)
	for id in Session.pinned_recipes:
		if Database.towers.has(id):
			pinned_box.add_child(RecipeBook.card(id, owned, _on_pins_changed, true, owned_now))
	pinned_panel.visible = not Session.pinned_recipes.is_empty()


func _update_layout() -> void:
	# Trennlinien nur zwischen sichtbaren Spalten
	var cols: Array[Control] = [strip_col, info_col, used_col, actions_col]
	var any_before := false
	for i in cols.size():
		if i > 0:
			separators[i - 1].visible = any_before and cols[i].visible
		any_before = any_before or cols[i].visible
	bottom.visible = any_before
	_recenter.call_deferred()


## Banner und Auswahlkarte bleiben mittig und passen sich dem Inhalt an (auch beim Schrumpfen).
func _recenter() -> void:
	for c in [banner, bottom]:
		var s: Vector2 = c.get_combined_minimum_size()
		c.offset_left = -s.x / 2.0
		c.offset_right = s.x / 2.0
		if c == bottom:
			c.offset_top = -16 - s.y
			c.offset_bottom = -16
		else:
			c.offset_bottom = c.offset_top + s.y
