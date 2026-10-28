class_name YtBuilder
extends Node
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Baumeister: Grundklasse der Skripte unter scripts/youtd/builders/ (Feld "script" in builders.json). Ein Teil
## wirkt einmal bei der Wahl (apply_to_player), ein Teil auf jeden Tower und Gegner (apply_effects), ein Teil nach
## jeder Welle (apply_wave_finished_effect).


var _id: String = ""
var _tower_buff: YtBuffType
var _creep_buff: YtBuffType
var _tower_modifier: YtModifier
var _creep_modifier: YtModifier

var _allow_adjacent_towers: bool = true
var _tower_lvl_bonus: int = 0
var _range_bonus: float = 0.0
var _item_slots_bonus: int = 0
var _adds_extra_recipes: bool = false


#########################
###     Built-in      ###
#########################

func _ready():
	_tower_buff = _get_tower_buff()
	_creep_buff = _get_creep_buff()
	_tower_modifier = _get_tower_modifier()
	_creep_modifier = _get_creep_modifier()

	if _tower_buff != null:
		_tower_buff.set_buff_tooltip("DEBUG Buff from builder %s" % _id)
		_tower_buff.set_hidden()

	if _creep_buff != null:
		_creep_buff.set_buff_tooltip("DEBUG Buff from builder %s" % _id)
		_creep_buff.set_hidden()


#########################
###       Public      ###
#########################

func get_id() -> String:
	return _id


func get_display_name() -> String:
	for b in YoutdData.builders():
		if str(b.id) == _id:
			return str(b.name)
	return ""


func get_allow_adjacent_towers() -> bool:
	return _allow_adjacent_towers


func get_tower_lvl_bonus() -> int:
	return _tower_lvl_bonus


func get_range_bonus() -> float:
	return _range_bonus


func get_item_slots_bonus() -> int:
	return _item_slots_bonus


func get_adds_extra_recipes() -> bool:
	return _adds_extra_recipes


func apply_effects(unit: YtUnit):
	var buff: YtBuffType
	var modifier: YtModifier

	if unit is YtTower:
		buff = _tower_buff
		modifier = _tower_modifier
	elif unit is YtCreep:
		buff = _creep_buff
		modifier = _creep_modifier
	else:
		buff = null
		modifier = null

	if buff != null:
		buff.apply_to_unit_permanent(unit, unit, unit.get_level())

	if modifier != null:
		unit.add_modifier(modifier)


#########################
###  Override methods ###
#########################

func apply_to_player(_player: YtPlayer):
	pass


func apply_wave_finished_effect(_player: YtPlayer):
	pass


func _get_tower_buff() -> YtBuffType:
	return null


func _get_creep_buff() -> YtBuffType:
	return null


# NOTE: if your builder needs to modify unit stats, use
# modifiers instead of buffs. This way, modifiers will be
# affected by unit leveling up.
func _get_tower_modifier() -> YtModifier:
	return null


func _get_creep_modifier() -> YtModifier:
	return null


#########################
###       Static      ###
#########################

## Baumeister id aus builders.json ("" = keiner).
static func create_instance(id: String) -> YtBuilder:
	var script_name := ""
	for b in YoutdData.builders():
		if str(b.id) == id:
			script_name = str(b.get("script", ""))
	var path := "res://scripts/youtd/builders/%s.gd" % script_name
	var builder: YtBuilder = load(path).new() if script_name != "" and ResourceLoader.exists(path) else YtBuilder.new()
	builder._id = id
	return builder
