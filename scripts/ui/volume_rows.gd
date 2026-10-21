class_name VolumeRows
## Zwei Regler für die Einstellungen: Lautstärke der Sounds und des Ambientes (Sfx, 0–100 %).
## Gleicher Aufbau wie die Zeile „UI-Größe“: Name links, Regler und Zahl rechts im Grid.


## Hängt beide Zeilen an grid (zwei Spalten). font/num_color: Schrift und Farbe der Prozentzahl.
static func add(grid: GridContainer, font: Font, num_color: Color) -> void:
	_row(grid, "Sounds", "Schüsse, Bauen, Wellen und Bosse.", Sfx.volume, Sfx.set_volume, font, num_color)
	_row(grid, "Ambiente", "Hintergrundgeräusche wie Wald und Nacht in eeveTD.", Sfx.ambience_volume, Sfx.set_ambience_volume, font, num_color)


static func _row(grid: GridContainer, text: String, tip: String, value: float, apply: Callable, font: Font, num_color: Color) -> HSlider:
	var l := UiUtil.label(TranslationServer.translate(text), grid, 15)
	l.custom_minimum_size.x = 150
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(h)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.value = roundf(value * 100.0)
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size.y = 24
	s.tooltip_text = TranslationServer.translate(tip)
	h.add_child(s)
	var n := UiUtil.label("%d %%" % roundi(s.value), h, 16)
	n.custom_minimum_size.x = 64
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	n.add_theme_font_override("font", font)
	n.add_theme_color_override("font_color", num_color)
	s.value_changed.connect(func(v):
		n.text = "%d %%" % roundi(v)
		apply.call(v / 100.0))
	# Beim Loslassen eine Probe hören, damit man die Lautstärke einschätzen kann
	s.drag_ended.connect(func(_changed): Sfx.play("build"))
	return s
