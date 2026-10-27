class_name YtTargetType
extends RefCounted
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.

# Filters units by various properties. Create a YtTargetType
# like this:
# 
# YtTargetType.new(YtTargetType.CREEPS + YtTargetType.RACE_UNDEAD)

const CREEPS: int 			= 0x1
const TOWERS: int 			= 0x2
const PLAYER_TOWERS: int 	= 0x4
const CORPSES: int 			= 0x8

const RACE_UNDEAD: int 		= 0x10
const RACE_MAGIC: int 		= 0x20
const RACE_NATURE: int 		= 0x40
const RACE_ORC: int 		= 0x80
const RACE_HUMANOID: int 	= 0x100
const RACE_CHALLENGE: int 	= 0x200
const RACE_ALL: int 		= RACE_UNDEAD | RACE_MAGIC | RACE_NATURE | RACE_ORC | RACE_HUMANOID | RACE_CHALLENGE

const SIZE_MASS: int 		= 0x400
const SIZE_NORMAL: int 		= 0x800
const SIZE_CHAMPION: int 	= 0x1000
const SIZE_BOSS: int 		= 0x2000
const SIZE_AIR: int 		= 0x4000
const SIZE_ALL: int 		= SIZE_MASS | SIZE_NORMAL | SIZE_CHAMPION | SIZE_BOSS | SIZE_AIR

const ELEMENT_ASTRAL: int 	= 0x8000
const ELEMENT_DARKNESS: int = 0x10000
const ELEMENT_NATURE: int 	= 0x20000
const ELEMENT_FIRE: int 	= 0x40000
const ELEMENT_ICE: int 		= 0x80000
const ELEMENT_STORM: int 	= 0x100000
const ELEMENT_IRON: int 	= 0x200000
const ELEMENT_ALL: int 		= ELEMENT_ASTRAL | ELEMENT_DARKNESS | ELEMENT_NATURE | ELEMENT_FIRE | ELEMENT_ICE | ELEMENT_STORM | ELEMENT_IRON

const RARITY_COMMON: int 	= 0x400000
const RARITY_UNCOMMON: int 	= 0x800000
const RARITY_RARE: int 		= 0x1000000
const RARITY_UNIQUE: int 	= 0x2000000
const RARITY_ALL: int 		= RARITY_COMMON | RARITY_UNCOMMON | RARITY_RARE | RARITY_UNIQUE

const string_to_bit_map: Dictionary = {
	"CREEPS": CREEPS,
	"TOWERS": TOWERS,
	"PLAYER_TOWERS": PLAYER_TOWERS,
	"CORPSES": CORPSES,

	"RACE_UNDEAD": RACE_UNDEAD,
	"RACE_MAGIC": RACE_MAGIC,
	"RACE_NATURE": RACE_NATURE,
	"RACE_ORC": RACE_ORC,
	"RACE_HUMANOID": RACE_HUMANOID,
	"RACE_CHALLENGE": RACE_CHALLENGE,

	"SIZE_MASS": SIZE_MASS,
	"SIZE_NORMAL": SIZE_NORMAL,
	"SIZE_CHAMPION": SIZE_CHAMPION,
	"SIZE_BOSS": SIZE_BOSS,
	"SIZE_AIR": SIZE_AIR,

	"ELEMENT_ASTRAL": ELEMENT_ASTRAL,
	"ELEMENT_DARKNESS": ELEMENT_DARKNESS,
	"ELEMENT_NATURE": ELEMENT_NATURE,
	"ELEMENT_FIRE": ELEMENT_FIRE,
	"ELEMENT_ICE": ELEMENT_ICE,
	"ELEMENT_STORM": ELEMENT_STORM,
	"ELEMENT_IRON": ELEMENT_IRON,

	"RARITY_COMMON": RARITY_COMMON,
	"RARITY_UNCOMMON": RARITY_UNCOMMON,
	"RARITY_RARE": RARITY_RARE,
	"RARITY_UNIQUE": RARITY_UNIQUE,
}

const bit_to_string_map: Dictionary = {
	CREEPS: "CREEPS",
	TOWERS: "TOWERS",
	PLAYER_TOWERS: "PLAYER_TOWERS",
	CORPSES: "CORPSES",

	RACE_UNDEAD: "RACE_UNDEAD",
	RACE_MAGIC: "RACE_MAGIC",
	RACE_NATURE: "RACE_NATURE",
	RACE_ORC: "RACE_ORC",
	RACE_HUMANOID: "RACE_HUMANOID",
	RACE_CHALLENGE: "RACE_CHALLENGE",

	SIZE_MASS: "SIZE_MASS",
	SIZE_NORMAL: "SIZE_NORMAL",
	SIZE_CHAMPION: "SIZE_CHAMPION",
	SIZE_BOSS: "SIZE_BOSS",
	SIZE_AIR: "SIZE_AIR",

	ELEMENT_ASTRAL: "ELEMENT_ASTRAL",
	ELEMENT_DARKNESS: "ELEMENT_DARKNESS",
	ELEMENT_NATURE: "ELEMENT_NATURE",
	ELEMENT_FIRE: "ELEMENT_FIRE",
	ELEMENT_ICE: "ELEMENT_ICE",
	ELEMENT_STORM: "ELEMENT_STORM",
	ELEMENT_IRON: "ELEMENT_IRON",

	RARITY_COMMON: "RARITY_COMMON",
	RARITY_UNCOMMON: "RARITY_UNCOMMON",
	RARITY_RARE: "RARITY_RARE",
	RARITY_UNIQUE: "RARITY_UNIQUE",
}

static var _tower_element_to_bit: Dictionary = {
	YtElement.enm.ASTRAL: YtTargetType.ELEMENT_ASTRAL,
	YtElement.enm.DARKNESS: YtTargetType.ELEMENT_DARKNESS,
	YtElement.enm.NATURE: YtTargetType.ELEMENT_NATURE,
	YtElement.enm.FIRE: YtTargetType.ELEMENT_FIRE,
	YtElement.enm.ICE: YtTargetType.ELEMENT_ICE,
	YtElement.enm.STORM: YtTargetType.ELEMENT_STORM,
	YtElement.enm.IRON: YtTargetType.ELEMENT_IRON,
}

static var _creep_category_to_bit: Dictionary = {
	YtCreepCategory.enm.UNDEAD: RACE_UNDEAD,
	YtCreepCategory.enm.MAGIC: RACE_MAGIC,
	YtCreepCategory.enm.NATURE: RACE_NATURE,
	YtCreepCategory.enm.ORC: RACE_ORC,
	YtCreepCategory.enm.HUMANOID: RACE_HUMANOID,
	YtCreepCategory.enm.CHALLENGE: RACE_CHALLENGE,
}

static var _creep_size_to_bit: Dictionary = {
	YtCreepSize.enm.MASS: SIZE_MASS,
	YtCreepSize.enm.NORMAL: SIZE_NORMAL,
	YtCreepSize.enm.CHAMPION: SIZE_CHAMPION,
	YtCreepSize.enm.BOSS: SIZE_BOSS,
	YtCreepSize.enm.AIR: SIZE_AIR,
	YtCreepSize.enm.CHALLENGE_BOSS: SIZE_BOSS,
	YtCreepSize.enm.CHALLENGE_MASS: SIZE_MASS,
}

static var _tower_rarity_to_bit: Dictionary = {
	YtRarity.enm.COMMON: YtTargetType.RARITY_COMMON,
	YtRarity.enm.UNCOMMON: YtTargetType.RARITY_UNCOMMON,
	YtRarity.enm.RARE: YtTargetType.RARITY_RARE,
	YtRarity.enm.UNIQUE: YtTargetType.RARITY_UNIQUE,
}

enum UnitType {
	TOWERS,
	CREEPS,
	CORPSES
}

var _unit_type: UnitType
var _original_bitmask: int = 0
var _bitmask: int = 0
var _player_towers_is_set: bool


#########################
###     Built-in      ###
#########################

func _init(bitmask: int):
	_original_bitmask = bitmask
	_bitmask = bitmask
	_unit_type = YtTargetType._get_unit_type(bitmask)

	var group_bitmask_list: Array[int] = [
		ELEMENT_ALL,
		RACE_ALL,
		SIZE_ALL,
		RARITY_ALL,
	]
	
#	NOTE: if target type was created with no bit specified
#	for group (element, race or size) then it is assumed
#	that we should accept all variations for that group.
#	Therefore we set all bits from those group bitmasks.
	for all_bitmask in group_bitmask_list:
		var no_filter_for_section: bool = _bitmask & all_bitmask == 0
		if no_filter_for_section:
			_bitmask |= all_bitmask

	_player_towers_is_set = _bitmask & PLAYER_TOWERS == PLAYER_TOWERS

#	NOTE: treat PLAYER_TOWERS as TOWERS and vice versa. The
#	actual filtering for PLAYER_TOWERS cannot be implemented
#	in YtTargetType itself because caster's player is not
#	accessible here. This filtering is implemented in
#	YtUtils.get_units_in_range().
	if _bitmask & PLAYER_TOWERS == PLAYER_TOWERS:
		_bitmask |= TOWERS
	if _bitmask & TOWERS == TOWERS:
		_bitmask |= PLAYER_TOWERS


#########################
###       Public      ###
#########################

func equals_to(target_type: YtTargetType) -> bool:
	var result: bool = _bitmask == target_type._bitmask

	return result


# NOTE: need to use bitmask to get optimal performance.
# YtTargetType.match() will get called very frequently via
# YtUtils.get_units_in_range().
func match(unit: YtUnit) -> bool:
	var is_match: bool = _bitmask & unit.get_target_bitmask() == unit.get_target_bitmask()

	return is_match


func get_unit_type() -> YtTargetType.UnitType:
	return _unit_type


func player_towers_is_set() -> bool:
	return _player_towers_is_set


#########################
###       Static      ###
#########################

static func _get_unit_type(bitmask: int) -> UnitType:
	var creeps_set: bool = YtUtils.bit_is_set(bitmask, CREEPS)
	var towers_set: bool = YtUtils.bit_is_set(bitmask, TOWERS)
	var player_towers_set: bool = YtUtils.bit_is_set(bitmask, PLAYER_TOWERS)
	var corpses_set: bool = YtUtils.bit_is_set(bitmask, CORPSES)

	if creeps_set:
		return UnitType.CREEPS
	elif towers_set:
		return UnitType.TOWERS
	elif player_towers_set:
		return UnitType.TOWERS
	elif corpses_set:
		return UnitType.CORPSES
	else:
		return UnitType.CREEPS


static func make_unit_bitmask(unit: YtUnit) -> int:
	var bitmask: int = 0

	if unit is YtTower:
		var tower: YtTower = unit as YtTower

		var element: YtElement.enm = tower.get_element()
		var element_bit: int = _tower_element_to_bit[element]
		var rarity: YtRarity.enm = tower.get_rarity()
		var rarity_bit: int = _tower_rarity_to_bit[rarity]
		
#		NOTE: need to set both TOWERS and PLAYER_TOWERS so
#		that both type of bitmasks match with this unit
		bitmask |= YtTargetType.TOWERS
		bitmask |= YtTargetType.PLAYER_TOWERS
		bitmask |= element_bit
		bitmask |= rarity_bit
	elif unit is YtCreep:
		var creep: YtCreep = unit as YtCreep

		var category: YtCreepCategory.enm = creep.get_category()
		var category_bit: int = _creep_category_to_bit[category]
		var size: YtCreepSize.enm = creep.get_size()
		var size_bit: int = _creep_size_to_bit[size]

		bitmask |= YtTargetType.CREEPS
		bitmask |= category_bit
		bitmask |= size_bit
	elif unit is YtCreepCorpse:
		bitmask |= YtTargetType.CORPSES

	return bitmask


static func convert_from_string(string: String) -> YtTargetType:
	var set_bit_string_list: Array = string.split(",")
	set_bit_string_list.erase("")
	var set_bit_list: Array[int] = []

	for set_bit_string in set_bit_string_list:
		var set_bit: int = string_to_bit_map[set_bit_string]

		set_bit_list.append(set_bit)

	var bitmask: int = 0
	for set_bit in set_bit_list:
		bitmask += set_bit

	var target_type: YtTargetType
	if bitmask != 0:
		target_type = YtTargetType.new(bitmask)
	else:
		target_type = null

	return target_type


static func convert_to_string(target_type: YtTargetType) -> String:
	if target_type == null:
		return ""

	var bit_list: Array = bit_to_string_map.keys()
	bit_list.sort()

#	NOTE: using original bitmask because the full "bitmask"
#	contains redundant bits
	var bitmask: int = target_type._original_bitmask

	var set_bit_list: Array[int] = []
	for bit in bit_list:
		var bit_is_set: int = YtUtils.bit_is_set(bitmask, bit)

		if bit_is_set:
			set_bit_list.append(bit)

	var set_bit_string_list: Array = []

	for bit in set_bit_list:
		var set_bit_string: String = bit_to_string_map[bit]

		set_bit_string_list.append(set_bit_string)

	var result: String = ",".join(set_bit_string_list)

	return result
