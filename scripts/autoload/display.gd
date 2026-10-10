extends Node
## Anzeige: Vollbild oder Fenster und die Fenstergröße. Gespeichert in user://settings.cfg.

const SETTINGS := "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1400, 900), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
]

var fullscreen := false
var resolution := Vector2i(1400, 900)


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		fullscreen = bool(cfg.get_value("display", "fullscreen", false))
		resolution = cfg.get_value("display", "resolution", resolution)
	_apply()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply()
	_save()


func set_resolution(size: Vector2i) -> void:
	resolution = size
	_apply()
	_save()


func _apply() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	# Nicht größer als der Bildschirm, dann mittig
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var size := Vector2i(mini(resolution.x, screen.size.x), mini(resolution.y, screen.size.y))
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "resolution", resolution)
	cfg.save(SETTINGS)
