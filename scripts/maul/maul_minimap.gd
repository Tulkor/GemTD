class_name MaulMinimap
extends Control
## Übersichtskarte von Shopping Maul: Gelände (ein Pixel pro Feld), eigene Zone, Tower, Gegner
## und der Kamerapunkt. Klick oder Ziehen setzt die Kamera dorthin.

var game: MaulGame
var _tex: ImageTexture


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Übersichtskarte: Klick springt hin"


func _texture() -> ImageTexture:
	if _tex != null or game == null or game.map == null:
		return _tex
	var m := game.map
	var img := Image.create(m.width, m.height, false, Image.FORMAT_RGBA8)
	var zone: int = game.players[game.local_player].zone
	var own: Rect2i = m.zones[zone].rect if zone < m.zones.size() else Rect2i()
	for y in m.height:
		for x in m.width:
			var c := Vector2i(x, y)
			var t := m.get_tile(c)
			var col := UiTheme.BG
			if t == MapData.WALK_ONLY:
				col = UiTheme.BORDER
			elif t == MapData.FLOOR:
				col = UiTheme.PANEL_2.lerp(UiTheme.CYAN, 0.25) if own.has_point(c) else UiTheme.PANEL_2.lerp(UiTheme.PURPLE, 0.25)
			img.set_pixel(x, y, col)
	_tex = ImageTexture.create_from_image(img)
	return _tex


func _scale() -> Vector2:
	return size / Vector2(game.map.width, game.map.height)


func _draw() -> void:
	if game == null:
		return
	var tex := _texture()
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	var k := _scale()
	var per_unit := k / Board3D.CELL
	for t in game.towers.values():
		draw_rect(Rect2(Vector2(t.cell) * k, k * 2.0), t.color)
	for u in game.units:
		draw_circle(u.pos * per_unit, 2.5, UiTheme.HAVE if not u.drone else UiTheme.CYAN)
	for e in game.enemies:
		var col := UiTheme.MISSING if not e.boss else UiTheme.GOLD
		draw_rect(Rect2(e.pos * per_unit - Vector2(1.5, 1.5), Vector2(3, 3)), col)
	var cam: Vector3 = game.camera_rig.target
	var p := Vector2(cam.x, cam.z) * per_unit
	var half := Vector2(game.camera_rig.distance, game.camera_rig.distance * 0.6) * 0.5 * per_unit
	draw_rect(Rect2(p - half, half * 2.0), UiTheme.TEXT, false, 1.0)


func _gui_input(event: InputEvent) -> void:
	var jump := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		jump = true
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		jump = true
	if jump and game != null:
		var p: Vector2 = event.position / (_scale() / Board3D.CELL)
		game.camera_rig.look_at_point(p)
		queue_redraw()
		accept_event()
