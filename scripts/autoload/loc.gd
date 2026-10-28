extends Node
## Sprache: Deutsch ist die Quellsprache, Englisch kommt aus data/i18n/en.json ({"Deutsch": "English"}).
## Controls übersetzen ihren Text automatisch; zusammengesetzte Texte gehen über tr("... %d") % wert.
## Die Wahl wird in user://settings.cfg gespeichert. Ohne gespeicherte Wahl startet das Spiel auf Englisch.

signal changed

const LANGUAGES := [["de", "Deutsch"], ["en", "English"]]
const SETTINGS := "user://settings.cfg"
const SOURCE := "res://data/i18n/en.json"

const DEFAULT := "en"

var language := DEFAULT
var _english: Translation


func _ready() -> void:
	reload()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		language = str(cfg.get_value("general", "language", DEFAULT))
	# Tests setzen die Sprache fest (tools/run_tests.sh), ohne die Einstellung zu speichern
	if OS.get_environment("GEMTD_SPRACHE") != "":
		language = OS.get_environment("GEMTD_SPRACHE")
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
