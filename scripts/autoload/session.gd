extends Node
## Hält Werte, die beim Szenenwechsel weitergegeben werden.

const MAIN_MENU := "res://scenes/main_menu.tscn"
const GAME := "res://scenes/game.tscn"
const MAP_EDITOR := "res://scenes/map_editor.tscn"
const TOWER_EDITOR := "res://scenes/tower_editor.tscn"
const EEVE_GAME := "res://scenes/eeve_game.tscn"

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
	{"name": "Einfach", "factor": 0.8, "score": 0.8},
	{"name": "Normal", "factor": 0.9, "score": 1.0},
	{"name": "Schwer", "factor": 1.15, "score": 1.25},
]
## Spiele im Hauptmenü. ready: schon spielbar (eeveTD und Shopping Maul entstehen gerade).
const GAMES := [
	{"id": "gemtd", "name": "GemTD", "ready": true, "hint": "Gems setzen, kombinieren, Labyrinth bauen"},
	{"id": "eevetd", "name": "eeveTD", "ready": true, "hint": "Barrikaden bauen, zu Element-Towern aufwerten, 57 Level (noch solo)", "scene": EEVE_GAME},
	{"id": "shoppingmaul", "name": "Shopping Maul", "ready": false, "hint": "Kommt noch: Tower aus Shops kaufen und aufwerten"},
]
var game_kind := "gemtd"
## Gewählte Stufe (Index in DIFFICULTIES), Standard „Normal“.
var difficulty := 1
## Wertung: false = Leben (Spiel endet bei 0), true = Punkte (Kills geben Punkte, Durchbrüche kosten welche).
var score_mode := false
## IDs der im Rezeptbuch angepinnten Spezial-Tower.
var pinned_recipes: Array = []
## Hauptmenü nach dem Sprachwechsel mit offenen Einstellungen neu aufbauen.
var reopen_settings := false
## Spielstand, mit dem das nächste Spiel startet (leer = neues Spiel), siehe save_game.gd.
var load_state: Dictionary = {}
## Datei des laufenden Einzelspiels (leer = noch nie gespeichert); erneutes Speichern überschreibt sie.
var save_id := ""
## Tests: Einstellungen vor Runde 1 überspringen (Schwierigkeit und Wertung wie gerade in Session).
var skip_setup := false
## Koop (gemeinsames Feld), nur fürs nächste Spiel: {role: "host"/"client", player: Spielernummer, names: [..]}.
var coop: Dictionary = {}
## Wohin "Zurück" im Spiel führt.
var return_scene := MAIN_MENU


## Spielszene des gewählten Spiels (game_kind), Standard ist GemTD.
func game_scene() -> String:
	for g in GAMES:
		if g.id == game_kind:
			return str(g.get("scene", GAME))
	return GAME


func goto(scene: String) -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(scene)


func difficulty_factor() -> float:
	return float(DIFFICULTIES[clampi(difficulty, 0, DIFFICULTIES.size() - 1)].factor)


## Punkte-Faktor der gewählten Schwierigkeit.
func score_factor() -> float:
	return float(DIFFICULTIES[clampi(difficulty, 0, DIFFICULTIES.size() - 1)].get("score", 1.0))


func difficulty_name() -> String:
	return str(DIFFICULTIES[clampi(difficulty, 0, DIFFICULTIES.size() - 1)].name)
