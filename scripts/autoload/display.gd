extends Node
## Anzeige: Vollbild oder Fenster, die Fenstergröße und die UI-Größe. Gespeichert in user://settings.cfg.

const SETTINGS := "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1400, 900), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
]

var fullscreen := false
var resolution := Vector2i(1400, 900)
const UI_SCALE_MIN := 0.5
const UI_SCALE_MAX := 1.0
var ui_scale := 1.0  ## Größe der ganzen Oberfläche, 0,5 bis 1,0 (3D-Ansicht bleibt gleich)
var path_lights := false  ## Lichtpfad: Lichter fliegen den Gegnerweg entlang (PathLights, Knopf im HUD)
var style_filter := true  ## Stil-Filter je Modus über dem 3D-Bild (StyleFilter), in den Einstellungen abschaltbar
signal style_filter_changed(on: bool)
var _fonts: Array[FontFile] = []  ## hält die Schriften im Cache, damit die Einstellungen aus _sharpen_fonts bleiben


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		fullscreen = bool(cfg.get_value("display", "fullscreen", false))
		resolution = cfg.get_value("display", "resolution", resolution)
		ui_scale = clampf(float(cfg.get_value("display", "ui_scale", 1.0)), UI_SCALE_MIN, UI_SCALE_MAX)
		path_lights = bool(cfg.get_value("display", "path_lights", false))
		style_filter = bool(cfg.get_value("display", "style_filter", true))
	_sharpen_fonts()
	_apply()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply()
	_save()


func set_resolution(size: Vector2i) -> void:
	resolution = size
	_apply()
	_save()


func set_ui_scale(v: float) -> void:
	ui_scale = clampf(v, UI_SCALE_MIN, UI_SCALE_MAX)
	_apply()
	_save()


func set_path_lights(on: bool) -> void:
	path_lights = on
	_save()


func set_style_filter(on: bool) -> void:
	style_filter = on
	style_filter_changed.emit(on)
	_save()


func _apply() -> void:
	# Bei Stretch "canvas_items" skaliert das nur die 2D-Oberfläche, die 3D-Ansicht bleibt scharf
	get_tree().root.content_scale_factor = ui_scale
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


## Alle Schriften mit voller Hinting-Stufe und auf ganze Pixel gesetzt: kleine Schrift bleibt scharf, auch wenn
## die Oberfläche krumm skaliert ist (Fenstergröße, UI-Größe). Die Import-Standardwerte (leichtes Hinting,
## Teilpixel-Positionen) lassen dünne Schriften wie Federo unter etwa 14 px verschwommen aussehen.
func _sharpen_fonts() -> void:
	for f in DirAccess.get_files_at("res://assets/fonts"):
		var path := "res://assets/fonts/" + f.trim_suffix(".import").trim_suffix(".remap")
		if not path.ends_with(".ttf") or not ResourceLoader.exists(path):
			continue
		var font := load(path) as FontFile
		if font:
			_fonts.append(font)
			font.hinting = TextServer.HINTING_NORMAL
			font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "resolution", resolution)
	cfg.set_value("display", "ui_scale", ui_scale)
	cfg.set_value("display", "path_lights", path_lights)
	cfg.set_value("display", "style_filter", style_filter)
	cfg.save(SETTINGS)
