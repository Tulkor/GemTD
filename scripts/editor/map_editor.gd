extends Node3D
## Einfacher Map-Editor: Kacheln malen, Spawn/Ziel/Checkpoints setzen, speichern, testen.

const PANEL_WIDTH := 340.0

enum Tool { BLOCKED, WALK_ONLY, FLOOR, SPAWN, GOAL, CHECKPOINT }
const TOOL_NAMES := {
	Tool.BLOCKED: "Blockiert (#)",
	Tool.WALK_ONLY: "Nur Weg (_)",
	Tool.FLOOR: "Boden (.)",
	Tool.SPAWN: "Spawn setzen",
	Tool.GOAL: "Ziel setzen",
	Tool.CHECKPOINT: "Checkpoint +/−",
}

var map: MapData
var board: Board3D
var camera_rig: CameraRig
var tool := Tool.BLOCKED
var painting := 0  ## 0 = nein, 1 = links (Werkzeug), 2 = rechts (Radierer)
var brush := 2     ## Pinselgröße in Feldern (2 = eine Towerbreite)

var tool_buttons := {}
var id_edit: LineEdit
var name_edit: LineEdit
var w_spin: SpinBox
var h_spin: SpinBox
var wave_option: OptionButton
var wave_ids: Array = []
var lives_spin: SpinBox
var gold_spin: SpinBox
var radius_spin: SpinBox
var rocks_spin: SpinBox
var seed_spin: SpinBox
var load_option: OptionButton
var map_entries: Array = []
var status_label: Label


func _ready() -> void:
	map = Session.editor_map.duplicate_map() if Session.editor_map != null else MapData.create_empty(60, 60)
	CameraRig.add_environment(self)
	board = Board3D.new()
	board.map = map
	add_child(board)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	_build_ui()
	_sync_fields()
	_layout()
	_on_map_changed()


func _layout() -> void:
	camera_rig.frame_map(map.width * Board3D.CELL, map.height * Board3D.CELL)


# --- Oberfläche --------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := UiUtil.side_panel(layer, PANEL_WIDTH)
	UiUtil.label("Map-Editor", box, 24)

	UiUtil.label("Werkzeug (Rechtsklick radiert)", box)
	UiUtil.wrap_label("Kamera: WASD/Pfeile, Q/E, Mausrad, mittlere Maustaste", box, PANEL_WIDTH - 40).modulate = Color(1, 1, 1, 0.6)
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	var group := ButtonGroup.new()
	for t in TOOL_NAMES:
		var b := UiUtil.button(TOOL_NAMES[t], grid, func(): tool = t)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = t == tool
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tool_buttons[t] = b
	UiUtil.spin(UiUtil.row("Pinsel (Felder)", box, 120), brush, 1, 8, 1, func(v): brush = int(v))
	UiUtil.button("Checkpoints löschen", box, func():
		map.checkpoints.clear()
		_on_map_changed())

	box.add_child(HSeparator.new())
	id_edit = LineEdit.new()
	id_edit.text_changed.connect(func(s): map.id = s)
	UiUtil.row("ID (Dateiname)", box, 120).add_child(id_edit)
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit = LineEdit.new()
	name_edit.text_changed.connect(func(s): map.name = s)
	UiUtil.row("Name", box, 120).add_child(name_edit)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var size_row := UiUtil.row("Größe B×H", box, 120)
	w_spin = UiUtil.spin(size_row, 60, 10, 400, 1, func(_v): pass)
	h_spin = UiUtil.spin(size_row, 60, 10, 400, 1, func(_v): pass)
	UiUtil.button("Größe übernehmen", box, func():
		map.resize(int(w_spin.value), int(h_spin.value))
		_layout()
		_on_map_changed())

	wave_option = OptionButton.new()
	wave_ids = Database.wave_sets.keys()
	for wid in wave_ids:
		wave_option.add_item(str(Database.wave_sets[wid].get("name", wid)))
	wave_option.item_selected.connect(func(i): map.wave_set = wave_ids[i])
	UiUtil.row("Wellen", box, 120).add_child(wave_option)
	lives_spin = UiUtil.spin(UiUtil.row("Leben", box, 120), 50, 1, 1000, 1, func(v): map.lives = int(v))
	gold_spin = UiUtil.spin(UiUtil.row("Startgold", box, 120), 0, 0, 100000, 1, func(v): map.start_gold = int(v))
	radius_spin = UiUtil.spin(UiUtil.row("Sperrzone um Punkte", box, 120), 3, 0, 10, 1, func(v):
		map.marker_radius = int(v)
		_on_map_changed())

	UiUtil.label("Varianz", box)
	rocks_spin = UiUtil.spin(UiUtil.row("Zufällige Steine", box, 120), 0, 0, 500, 1, func(v): map.variance["random_rocks"] = int(v))
	seed_spin = UiUtil.spin(UiUtil.row("Seed (−1 = zufällig)", box, 120), -1, -1, 999999, 1, func(v): map.variance["seed"] = int(v))

	box.add_child(HSeparator.new())
	status_label = UiUtil.wrap_label("", box, PANEL_WIDTH - 40)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	UiUtil.button("Speichern", actions, _save)
	UiUtil.button("Testen", actions, _test)
	UiUtil.button("Neu", actions, func(): _set_map(MapData.create_empty(int(w_spin.value), int(h_spin.value))))

	var load_row := HBoxContainer.new()
	box.add_child(load_row)
	load_option = OptionButton.new()
	load_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_row.add_child(load_option)
	UiUtil.button("Laden", load_row, _load_selected)
	_refresh_load_list()

	UiUtil.button("Zurück zum Menü", box, func(): Session.goto(Session.MAIN_MENU))


func _sync_fields() -> void:
	id_edit.text = map.id
	name_edit.text = map.name
	w_spin.set_value_no_signal(map.width)
	h_spin.set_value_no_signal(map.height)
	wave_option.select(maxi(wave_ids.find(map.wave_set), 0))
	lives_spin.set_value_no_signal(map.lives)
	gold_spin.set_value_no_signal(map.start_gold)
	radius_spin.set_value_no_signal(map.marker_radius)
	rocks_spin.set_value_no_signal(int(map.variance.get("random_rocks", 0)))
	seed_spin.set_value_no_signal(int(map.variance.get("seed", -1)))


func _set_map(m: MapData) -> void:
	map = m
	board.map = m
	_sync_fields()
	_layout()
	_on_map_changed()


func _refresh_load_list() -> void:
	map_entries = Database.list_maps()
	load_option.clear()
	for e in map_entries:
		load_option.add_item(e.name)


func _load_selected() -> void:
	if map_entries.is_empty():
		return
	var m := MapData.load_file(map_entries[load_option.selected].path)
	if m != null:
		_set_map(m)


func _save() -> void:
	if not _valid_id(map.id):
		status_label.text = "Ungültige ID: nur Kleinbuchstaben, Ziffern und _ erlaubt."
		return
	var path := Database.writable_path("maps", map.id)
	if map.save_file(path):
		status_label.text = "Gespeichert: " + path
		_refresh_load_list()


func _test() -> void:
	if pathfinder_path().is_empty():
		status_label.text = "Kein gültiger Weg – so kann nicht getestet werden."
		return
	Session.editor_map = map.duplicate_map()
	Session.map_override = map.duplicate_map()
	Session.test_tower = ""
	Session.return_scene = Session.MAP_EDITOR
	Session.goto(Session.GAME)


static func _valid_id(s: String) -> bool:
	var re := RegEx.create_from_string("^[a-z0-9_]+$")
	return re.search(s) != null


# --- Malen -------------------------------------------------------------------

func _is_point_tool() -> bool:
	return tool == Tool.SPAWN or tool == Tool.GOAL or tool == Tool.CHECKPOINT


func _process(_delta: float) -> void:
	var size := 1 if _is_point_tool() else brush
	var a := board.mouse_cell(camera_rig.camera) if size == 1 else board.mouse_anchor(camera_rig.camera, size)
	if a != board.hover_cell or size != board.hover_size:
		board.hover_cell = a
		board.hover_size = size
		board.refresh_hover()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				painting = 1 if event.button_index == MOUSE_BUTTON_LEFT else 2
				_apply(true)
			else:
				painting = 0
	elif event is InputEventMouseMotion and painting != 0:
		_apply(false)


func _apply(is_click: bool) -> void:
	var c := board.mouse_cell(camera_rig.camera)
	if painting == 2:
		var idx := map.checkpoints.find(c)
		if idx >= 0 and is_click:
			map.checkpoints.remove_at(idx)
		elif not _paint(MapData.FLOOR):
			return
		_on_map_changed()
		return
	match tool:
		Tool.BLOCKED, Tool.WALK_ONLY, Tool.FLOOR:
			var t: String = [MapData.BLOCKED, MapData.WALK_ONLY, MapData.FLOOR][tool]
			if not _paint(t):
				return
		Tool.SPAWN, Tool.GOAL, Tool.CHECKPOINT:
			if not map.in_bounds(c):
				return
			if not is_click:
				return
			if map.get_tile(c) == MapData.BLOCKED:
				map.set_tile(c, MapData.FLOOR)
			if tool == Tool.SPAWN:
				map.spawn = c
			elif tool == Tool.GOAL:
				map.goal = c
			else:
				var idx := map.checkpoints.find(c)
				if idx >= 0:
					map.checkpoints.remove_at(idx)
				else:
					map.checkpoints.append(c)
	_on_map_changed()


## Malt die Kachel t mit dem Pinsel unter der Maus. Gibt zurück, ob sich etwas geändert hat.
func _paint(t: String) -> bool:
	var a := board.mouse_cell(camera_rig.camera) if brush == 1 else board.mouse_anchor(camera_rig.camera, brush)
	var changed := false
	for c in Board3D.footprint(a, brush):
		if not map.in_bounds(c) or map.get_tile(c) == t:
			continue
		if t == MapData.BLOCKED and c in map.waypoints():
			continue
		map.set_tile(c, t)
		changed = true
	return changed


func pathfinder_path() -> Array[Vector2i]:
	return Pathfinder.new(map).compute_path()


func _on_map_changed() -> void:
	var cells := pathfinder_path()
	var pts := PackedVector2Array()
	for c in cells:
		pts.append(Board3D.cell_center(c))
	board.path_points = pts
	board.path_color = Color(0.3, 1, 0.3, 0.8)
	if cells.is_empty():
		status_label.text = "Kein gültiger Weg! Spawn, Checkpoints und Ziel müssen verbunden sein."
	else:
		status_label.text = "Weglänge ohne Labyrinth: %d Felder, %d Checkpoints" % [cells.size(), map.checkpoints.size()]
	board.rebuild()
