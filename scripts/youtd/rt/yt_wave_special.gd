class_name YtWaveSpecial
extends Node
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Wellen-Eigenschaften (Schnell, Gepanzert, Brut …) als Buffs aus scripts/youtd/specials/<script>.gd. Welche
## Eigenschaften eine Welle hat und wie viel Leben sie kosten, würfelt youtd_waves.gd; hier werden sie auf jeden
## Gegner gelegt (WaveSpecial.apply_to_creep). YtWorld hält genau einen Knoten davon.

static var node: YtWaveSpecial = null

var _buff_map: Dictionary = {}   ## Eigenschaft (int) -> YtBuffType


func _enter_tree() -> void:
	node = self


func _exit_tree() -> void:
	if node == self:
		node = null


func get_buff(special: int) -> YtBuffType:
	if _buff_map.has(special):
		return _buff_map[special]
	var bt: YtBuffType = null
	var script_name := str(YoutdData.specials().get(str(special), {}).get("script", ""))
	var path := "res://scripts/youtd/specials/%s.gd" % script_name
	if script_name != "" and ResourceLoader.exists(path):
		bt = load(path).new(self)
		bt.set_buff_tooltip(YoutdData.special_name(str(special)))
	_buff_map[special] = bt
	return bt


## Eigenschaften auf einen Gegner legen; specials gelten schon für ihn (youtd_waves.gd → special_applies).
## Leben: Faktor aus YoutdWaves.hp_modifier ist schon im Grundwert, hier nur Mana und die Buffs.
static func apply_to_creep(special_list: Array, creep: YtCreep) -> void:
	var list: Array[int] = []
	var uses_mana := false
	for s in special_list:
		list.append(int(s))
		uses_mana = uses_mana or bool(YoutdData.specials().get(str(s), {}).get("mana", false))
	creep.set_special_list(list)
	var mana: float = YtCreepSize.get_base_mana(creep.get_size()) if uses_mana else 0.0
	creep.set_base_mana(mana)
	creep.set_mana(mana)
	if node == null:
		return
	for s in list:
		var bt: YtBuffType = node.get_buff(s)
		if bt != null:
			bt.apply_to_unit_permanent(creep, creep, 0)
