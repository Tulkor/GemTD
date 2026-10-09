class_name Hud
extends CanvasLayer
## Seitenpanel im Spiel.

signal option_chosen(index: int)
signal chance_upgrade_requested
signal speed_selected(factor: float)
signal menu_requested
signal debug_tower_changed(key: String)

const WIDTH := 330.0

var stats_label: Label
var phase_label: Label
var chance_button: Button
var options_box: VBoxContainer
var tower_label: Label
var debug_option: OptionButton
var debug_keys: Array[String] = []
var message_label: Label


func _ready() -> void:
	var box := UiUtil.side_panel(self, WIDTH)
	var inner := WIDTH - 40
	UiUtil.label("GemTD", box, 24)
	stats_label = UiUtil.label("", box)
	phase_label = UiUtil.wrap_label("", box, inner)
	phase_label.add_theme_color_override("font_color", Color("f1c40f"))
	chance_button = UiUtil.button("", box, func(): chance_upgrade_requested.emit())
	box.add_child(HSeparator.new())
	options_box = VBoxContainer.new()
	box.add_child(options_box)
	tower_label = UiUtil.wrap_label("", box, inner)
	box.add_child(HSeparator.new())

	UiUtil.label("Tempo", box)
	var speed_row := HBoxContainer.new()
	box.add_child(speed_row)
	for f in [1.0, 2.0, 4.0]:
		UiUtil.button("%dx" % int(f), speed_row, func(): speed_selected.emit(f))

	UiUtil.label("Debug: nächster Gem", box)
	debug_option = OptionButton.new()
	debug_option.fit_to_longest_item = false
	debug_option.custom_minimum_size.x = inner
	box.add_child(debug_option)
	debug_option.item_selected.connect(func(i): debug_tower_changed.emit(debug_keys[i]))

	box.add_child(HSeparator.new())
	UiUtil.button("Zurück", box, func(): menu_requested.emit())
	UiUtil.wrap_label("Linksklick: Gem setzen / Tower auswählen\nRechtsklick, Esc: Auswahl aufheben\nTasten 1, 2, 3: Tempo", box, inner).modulate = Color(1, 1, 1, 0.6)

	message_label = Label.new()
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message_label.add_theme_font_size_override("font_size", 48)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 8)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(message_label)


func setup_debug_towers(preselect: String) -> void:
	debug_option.clear()
	debug_keys = [""]
	debug_option.add_item("Zufällig (normal)")
	for id in Database.tower_ids():
		for t in Database.tier_count(id):
			debug_keys.append("%s:%d" % [id, t])
			debug_option.add_item(Database.tower_label(id, t))
	debug_option.select(maxi(debug_keys.find(preselect), 0))


func set_stats(text: String) -> void:
	stats_label.text = text


func set_phase(text: String) -> void:
	phase_label.text = text


func set_tower_info(text: String) -> void:
	tower_label.text = text


func set_chance(text: String, enabled: bool) -> void:
	chance_button.text = text
	chance_button.disabled = not enabled


func set_options(labels: Array) -> void:
	for c in options_box.get_children():
		options_box.remove_child(c)
		c.queue_free()
	for i in labels.size():
		var b := UiUtil.button(labels[i], options_box, func(): option_chosen.emit(i))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true


func show_message(text: String) -> void:
	message_label.text = text
