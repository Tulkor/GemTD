class_name YtArmorType extends Node
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.

enum enm {
	HEL,
	MYT,
	LUA,
	SOL,
	SIF,
	ZOD,
}

static var _list: Array[YtArmorType.enm] = [
	YtArmorType.enm.HEL,
	YtArmorType.enm.MYT,
	YtArmorType.enm.LUA,
	YtArmorType.enm.SOL,
	YtArmorType.enm.SIF,
	YtArmorType.enm.ZOD,
]

static var _string_map: Dictionary = {
	YtArmorType.enm.HEL: "hel",
	YtArmorType.enm.MYT: "myt",
	YtArmorType.enm.LUA: "lua",
	YtArmorType.enm.SOL: "sol",
	YtArmorType.enm.SIF: "sif",
	YtArmorType.enm.ZOD: "zod",
}

static var _color_map: Dictionary = {
	YtArmorType.enm.HEL: Color.ORANGE_RED,
	YtArmorType.enm.MYT: Color.CORNFLOWER_BLUE,
	YtArmorType.enm.LUA: Color.LIME_GREEN,
	YtArmorType.enm.SOL: Color.GOLD,
	YtArmorType.enm.SIF: Color.MEDIUM_PURPLE,
	YtArmorType.enm.ZOD: Color.YELLOW,
}


static func from_string(string: String) -> YtArmorType.enm:
	var key = _string_map.find_key(string)
	
	if key != null:
		return key
	else:
		push_error("Invalid string: \"%s\". Possible values: %s" % [string, _string_map.values()])

		return YtArmorType.enm.ZOD


static func convert_to_string(type: YtArmorType.enm) -> String:
	return _string_map[type]


static func get_display_string(type: YtArmorType.enm) -> String:
	return YoutdData.armor_name(convert_to_string(type))
static func get_list() -> Array[YtArmorType.enm]:
	return _list.duplicate()


# Returns text which says how much damage this armor type
# takes from each attack type.
static func get_spell_damage_taken(armor_type: YtArmorType.enm) -> float:
	var value: float

	if armor_type == YtArmorType.enm.SIF:
		value = YtConstants.SPELL_DAMAGE_RATIO_FOR_SIF
	else:
		value = YtConstants.SPELL_DAMAGE_RATIO

	return value
