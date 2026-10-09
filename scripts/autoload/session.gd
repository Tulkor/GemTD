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
## IDs der im Rezeptbuch angepinnten Spezial-Tower.
var pinned_recipes: Array = []
## Wohin "Zurück" im Spiel führt.
var return_scene := MAIN_MENU


func goto(scene: String) -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(scene)
