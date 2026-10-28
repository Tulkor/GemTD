class_name YtElement extends Node
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.

enum enm {
	ICE ,
	NATURE,
	FIRE,
	ASTRAL,
	DARKNESS,
	IRON,
	STORM,
	NONE,
}


static var _string_map: Dictionary = {
	YtElement.enm.ICE: "ice",
	YtElement.enm.NATURE: "nature",
	YtElement.enm.FIRE: "fire",
	YtElement.enm.ASTRAL: "astral",
	YtElement.enm.DARKNESS: "darkness",
	YtElement.enm.IRON: "iron",
	YtElement.enm.STORM: "storm",
	YtElement.enm.NONE: "none",
}

static var _main_attack_types_map: Dictionary = {
	YtElement.enm.ICE: [YtAttackType.enm.ELEMENTAL, YtAttackType.enm.ENERGY],
	YtElement.enm.NATURE: [YtAttackType.enm.PHYSICAL, YtAttackType.enm.DECAY, YtAttackType.enm.ESSENCE],
	YtElement.enm.FIRE: [YtAttackType.enm.ELEMENTAL, YtAttackType.enm.DECAY],
	YtElement.enm.ASTRAL: [YtAttackType.enm.ENERGY, YtAttackType.enm.ELEMENTAL, YtAttackType.enm.ARCANE],
	YtElement.enm.DARKNESS: [YtAttackType.enm.DECAY, YtAttackType.enm.PHYSICAL],
	YtElement.enm.IRON: [YtAttackType.enm.PHYSICAL, YtAttackType.enm.DECAY],
	YtElement.enm.STORM: [YtAttackType.enm.ENERGY, YtAttackType.enm.PHYSICAL],
	YtElement.enm.NONE: [YtAttackType.enm.PHYSICAL, YtAttackType.enm.PHYSICAL],
}


static var _dmg_from_element_map: Dictionary = {
	YtElement.enm.ICE: YtModificationType.enm.MOD_DMG_FROM_ICE,
	YtElement.enm.NATURE: YtModificationType.enm.MOD_DMG_FROM_NATURE,
	YtElement.enm.FIRE: YtModificationType.enm.MOD_DMG_FROM_FIRE,
	YtElement.enm.ASTRAL: YtModificationType.enm.MOD_DMG_FROM_ASTRAL,
	YtElement.enm.DARKNESS: YtModificationType.enm.MOD_DMG_FROM_DARKNESS,
	YtElement.enm.IRON: YtModificationType.enm.MOD_DMG_FROM_IRON,
	YtElement.enm.STORM: YtModificationType.enm.MOD_DMG_FROM_STORM,
	YtElement.enm.NONE: YtModificationType.enm.MOD_DMG_FROM_ICE,
}

static var _color_map: Dictionary = {
	YtElement.enm.ICE: Color.CORNFLOWER_BLUE,
	YtElement.enm.NATURE: Color.LIME_GREEN,
	YtElement.enm.FIRE: Color.ORANGE_RED,
	YtElement.enm.ASTRAL: Color.MEDIUM_AQUAMARINE,
	YtElement.enm.DARKNESS: Color.MEDIUM_PURPLE,
	YtElement.enm.IRON: Color.TAN,
	YtElement.enm.STORM: Color.LIGHT_YELLOW,
	YtElement.enm.NONE: Color.WHITE,
}


static func is_valid_string(string: String) -> bool:
	var key = _string_map.find_key(string)
	var is_valid: bool = key != null

	return is_valid


static func from_string(string: String) -> YtElement.enm:
	var key = _string_map.find_key(string)
	
	if key != null:
		return key
	else:
		push_error("Invalid string: \"%s\". Possible values: %s" % [string, _string_map.values()])

		return YtElement.enm.ICE


static func convert_to_string(element: YtElement.enm) -> String:
	return _string_map[element]


static func get_display_string(element: YtElement.enm) -> String:
	return YoutdData.element_name(convert_to_string(element))
static func convert_to_dmg_from_element_mod(element: YtElement.enm) -> YtModificationType.enm:
	return _dmg_from_element_map[element]


static func get_list() -> Array[YtElement.enm]:
	return [
		YtElement.enm.ICE,
		YtElement.enm.NATURE,
		YtElement.enm.FIRE,
		YtElement.enm.ASTRAL,
		YtElement.enm.DARKNESS,
		YtElement.enm.IRON,
		YtElement.enm.STORM,
	]


static func get_color(element: YtElement.enm) -> Color:
	var color: Color = _color_map[element]

	return color

