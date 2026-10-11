extends Node
## Hält Werte, die beim Szenenwechsel weitergegeben werden.

const MAIN_MENU := "res://scenes/main_menu.tscn"
const GAME := "res://scenes/game.tscn"
const MAP_EDITOR := "res://scenes/map_editor.tscn"
const TOWER_EDITOR := "res://scenes/tower_editor.tscn"

## Pfad der Map, die das Spiel laden soll.
var map_path := ""
## Map direkt aus dem Editor testen (hat Vorrang vor map_path).
var map_override: MapData = null
## Map, die der Map-Editor beim Öffnen wieder anzeigt (nach einem Test).
var editor_map: MapData = null
## "tower_id:stufe" – im Debug-Menü des Spiels vorausgewählt.
var test_tower := ""
## Debug: Leben dürfen ins Minus gehen, das Spiel endet nicht.
var debug_immortal := false
var debug_gems_per_round := 0   ## Debug: Gems pro Runde, 0 = Wert aus balance.json
## Schwierigkeitsstufen: Faktor auf Leben und Rüstung der Gegner.
const DIFFICULTIES := [
	{"name": "Einfach", "factor": 0.8},
	{"name": "Normal", "factor": 0.9},
	{"name": "Schwer", "factor": 1.15},
]
## Gewählte Stufe (Index in DIFFICULTIES), Standard „Normal“.
var difficulty := 1
## IDs der im Rezeptbuch angepinnten Spezial-Tower.
var pinned_recipes: Array = []
## Hauptmenü nach dem Sprachwechsel mit offenen Einstellungen neu aufbauen.
var reopen_settings := false
## Spielstand, mit dem das nächste Spiel startet (leer = neues Spiel), siehe save_game.gd.
var load_state: Dictionary = {}
## Datei des laufenden Einzelspiels (leer = noch nie gespeichert); erneutes Speichern überschreibt sie.
var save_id := ""
## Wohin "Zurück" im Spiel führt.
var return_scene := MAIN_MENU


func goto(scene: String) -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(scene)


func difficulty_factor() -> float:
	return float(DIFFICULTIES[clampi(difficulty, 0, DIFFICULTIES.size() - 1)].factor)


func difficulty_name() -> String:
	return str(DIFFICULTIES[clampi(difficulty, 0, DIFFICULTIES.size() - 1)].name)
