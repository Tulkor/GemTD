class_name PlayerState
extends RefCounted
## Was jedem Spieler allein gehört (Koop: mehrere, solo: einer). Leben/Punkte, Wellen und das
## Feld sind gemeinsam und liegen in game.gd.

var id := 0
var name := ""
var gold := 0
var gold_frac := 0.0      ## Bruchteile aus Kopfgeld (Massenwellen)
var round_towers: Array = []  ## in dieser Runde gesetzte Gems
var undo_gems: Array = []     ## zurückgenommene Gems [id, tier], kommen beim nächsten Setzen wieder
var stage := 0                ## eigener Rundenstand: Game.Phase.BUILD, CHOOSE oder WAVE (fertig, wartet auf die anderen)
var away := false             ## Koop: nicht verbunden, hält die Runde nicht auf


func _init(player_id := 0, player_name := "") -> void:
	id = player_id
	name = player_name
