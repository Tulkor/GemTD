class_name YtCreepCategory extends Node
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.

enum enm {
	UNDEAD,
	MAGIC,
	NATURE,
	ORC,
	HUMANOID,
	CHALLENGE,
}


static var _ordered_list: Array[YtCreepCategory.enm] = [
	YtCreepCategory.enm.UNDEAD,
	YtCreepCategory.enm.MAGIC,
	YtCreepCategory.enm.NATURE,
	YtCreepCategory.enm.ORC,
	YtCreepCategory.enm.HUMANOID,
	YtCreepCategory.enm.CHALLENGE,
]

static var _string_map: Dictionary = {
	YtCreepCategory.enm.UNDEAD: "undead",
	YtCreepCategory.enm.MAGIC: "magic",
	YtCreepCategory.enm.NATURE: "nature",
	YtCreepCategory.enm.ORC: "orc",
	YtCreepCategory.enm.HUMANOID: "humanoid",
	YtCreepCategory.enm.CHALLENGE: "challenge",
}

static var _color_map: Dictionary = {
	YtCreepCategory.enm.UNDEAD: Color.MEDIUM_PURPLE,
	YtCreepCategory.enm.MAGIC: Color.CORNFLOWER_BLUE,
	YtCreepCategory.enm.NATURE: Color.LIME_GREEN,
	YtCreepCategory.enm.ORC: Color.DARK_SEA_GREEN,
	YtCreepCategory.enm.HUMANOID: Color.TAN,
	YtCreepCategory.enm.CHALLENGE: Color.GOLD,
}


static func get_list() -> Array[YtCreepCategory.enm]:
	return _ordered_list


static func from_string(string: String) -> YtCreepCategory.enm:
	var key = _string_map.find_key(string)
	
	if key != null:
		return key
	else:
		push_error("Invalid string: \"%s\". Possible values: %s" % [string, _string_map.values()])

		return YtCreepCategory.enm.UNDEAD


static func convert_to_string(type: YtCreepCategory.enm) -> String:
	return _string_map[type]


static func get_display_string(type: YtCreepCategory.enm) -> String:
	return YoutdData.race_name(convert_to_string(type))
static func get_color(type: YtCreepCategory.enm) -> Color:
	var color: Color = _color_map[type]

	return color


static func convert_to_mod_dmg_type(category: YtCreepCategory.enm) -> YtModificationType.enm:
	const creep_category_to_mod_map: Dictionary = {
		YtCreepCategory.enm.UNDEAD: YtModificationType.enm.MOD_DMG_TO_UNDEAD,
		YtCreepCategory.enm.MAGIC: YtModificationType.enm.MOD_DMG_TO_MAGIC,
		YtCreepCategory.enm.NATURE: YtModificationType.enm.MOD_DMG_TO_NATURE,
		YtCreepCategory.enm.ORC: YtModificationType.enm.MOD_DMG_TO_ORC,
		YtCreepCategory.enm.HUMANOID: YtModificationType.enm.MOD_DMG_TO_HUMANOID,
		YtCreepCategory.enm.CHALLENGE: YtModificationType.enm.MOD_DMG_TO_CHALLENGE,
	}

	var mod_type: YtModificationType.enm = creep_category_to_mod_map[category]

	return mod_type
