extends Control
## Hauptmenü: Map wählen, spielen, Editoren öffnen.

var map_option: OptionButton
var maps: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("14161c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 380
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	UiUtil.label("GemTD Nachbau", box, 40).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiUtil.label("Map", box)
	map_option = OptionButton.new()
	box.add_child(map_option)
	UiUtil.button("Spielen", box, _play)
	box.add_child(HSeparator.new())
	UiUtil.button("Map-Editor", box, _open_map_editor)
	UiUtil.button("Tower-Editor", box, _open_tower_editor)
	UiUtil.button("Daten neu laden", box, _reload)
	UiUtil.button("Beenden", box, func(): get_tree().quit())
	_reload()


func _reload() -> void:
	Database.reload()
	maps = Database.list_maps()
	map_option.clear()
	for m in maps:
		map_option.add_item(m.name)
	var idx := maps.map(func(m): return m.path).find(Session.map_path)
	if idx >= 0:
		map_option.select(idx)


func _play() -> void:
	if maps.is_empty():
		return
	Session.map_path = maps[map_option.selected].path
	Session.map_override = null
	Session.test_tower = ""
	Session.return_scene = Session.MAIN_MENU
	Session.goto(Session.GAME)


func _open_map_editor() -> void:
	Session.editor_map = null
	if not maps.is_empty():
		Session.editor_map = MapData.load_file(maps[map_option.selected].path)
	Session.goto(Session.MAP_EDITOR)


func _open_tower_editor() -> void:
	Session.goto(Session.TOWER_EDITOR)
