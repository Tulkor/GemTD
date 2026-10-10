extends Node
## Sprache: Deutsch ist die Quellsprache, Englisch kommt aus data/i18n/en.json ({"Deutsch": "English"}).
## Controls übersetzen ihren Text automatisch; zusammengesetzte Texte gehen über tr("... %d") % wert.
## Die Wahl wird in user://settings.cfg gespeichert.

signal changed

const LANGUAGES := [["de", "Deutsch"], ["en", "English"]]
const SETTINGS := "user://settings.cfg"
const SOURCE := "res://data/i18n/en.json"

var language := "de"
var _english: Translation


func _ready() -> void:
	reload()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		language = str(cfg.get_value("general", "language", "de"))
	_apply()


## Englische Texte (neu) laden.
func reload() -> void:
	if _english != null:
		TranslationServer.remove_translation(_english)
	_english = Translation.new()
	_english.locale = "en"
	var f := FileAccess.open(SOURCE, FileAccess.READ)
	if f != null:
		var data = JSON.parse_string(f.get_as_text())
		if data is Dictionary:
			for k in data:
				if str(data[k]) != "":
					_english.add_message(str(k), str(data[k]))
	TranslationServer.add_translation(_english)


func set_language(code: String) -> void:
	if code == language:
		return
	language = code
	_apply()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("general", "language", code)
	cfg.save(SETTINGS)
	changed.emit()


func _apply() -> void:
	# Deutsch: Locale ohne Übersetzung, damit die Quelltexte stehen bleiben
	TranslationServer.set_locale(language)
