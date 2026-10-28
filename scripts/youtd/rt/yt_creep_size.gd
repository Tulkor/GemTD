class_name YtCreepSize extends Node
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.


# NOTE: order is important to be able to compare
enum enm {
	MASS,
	CHALLENGE_MASS,
	NORMAL,
	AIR,
	CHAMPION,
	BOSS,
	CHALLENGE_BOSS,
}


static var _ordered_list: Array[YtCreepSize.enm] = [
	YtCreepSize.enm.MASS,
	YtCreepSize.enm.CHALLENGE_MASS,
	YtCreepSize.enm.NORMAL,
	YtCreepSize.enm.AIR,
	YtCreepSize.enm.CHAMPION,
	YtCreepSize.enm.BOSS,
	YtCreepSize.enm.CHALLENGE_BOSS,
]


static var _string_map: Dictionary = {
	YtCreepSize.enm.MASS: "mass",
	YtCreepSize.enm.NORMAL: "normal",
	YtCreepSize.enm.AIR: "air",
	YtCreepSize.enm.CHAMPION: "champion",
	YtCreepSize.enm.BOSS: "boss",
	YtCreepSize.enm.CHALLENGE_MASS: "challenge mass",
	YtCreepSize.enm.CHALLENGE_BOSS: "challenge boss",
}


static var _color_map: Dictionary = {
	YtCreepSize.enm.MASS: Color.ORANGE,
	YtCreepSize.enm.NORMAL: Color.DARK_SEA_GREEN,
	YtCreepSize.enm.AIR: Color.CORNFLOWER_BLUE,
	YtCreepSize.enm.CHAMPION: Color.MEDIUM_PURPLE,
	YtCreepSize.enm.BOSS: Color.ORANGE_RED,
	YtCreepSize.enm.CHALLENGE_MASS: Color.GOLD,
	YtCreepSize.enm.CHALLENGE_BOSS: Color.GOLD,
}


static var _item_drop_roll_count: Dictionary = {
	YtCreepSize.enm.MASS: 1,
	YtCreepSize.enm.NORMAL: 2,
	YtCreepSize.enm.AIR: 4,
	YtCreepSize.enm.CHAMPION: 4,
	YtCreepSize.enm.BOSS: 20,
#	NOTE: these values were derived values from JASS code.
# 	for challenge mass: 4 = WU[1] * 10 / 5 = 2 * 10 / 5
# 	for challenge boss: 40 = WU[7] * 10 / 5 = 20 * 10 / 5
	YtCreepSize.enm.CHALLENGE_MASS: 4,
	YtCreepSize.enm.CHALLENGE_BOSS: 40,
}

static var _score_multiplier: Dictionary = {
	YtCreepSize.enm.MASS: 1,
	YtCreepSize.enm.NORMAL: 2,
	YtCreepSize.enm.AIR: 4,
	YtCreepSize.enm.CHAMPION: 4,
	YtCreepSize.enm.BOSS: 20,
#	NOTE: these values were derived values from JASS code.
# 	for challenge mass: 20 = WU[1] * 10 = 2 * 10
# 	for challenge boss: 200 = WU[7] * 10 = 20 * 10
	YtCreepSize.enm.CHALLENGE_MASS: 20,
	YtCreepSize.enm.CHALLENGE_BOSS: 200,
}

static var _experience_map: Dictionary = {
	YtCreepSize.enm.MASS: 1,
	YtCreepSize.enm.NORMAL: 2,
	YtCreepSize.enm.AIR: 4,
	YtCreepSize.enm.CHAMPION: 4,
	YtCreepSize.enm.BOSS: 20,
#	NOTE: these values were derived values from JASS code.
# 	for challenge mass: 4 = 2 * WU[1] = 2 * 2
# 	for challenge boss: 40 = 2 * WU[7] = 2 * 20
	YtCreepSize.enm.CHALLENGE_MASS: 4,
	YtCreepSize.enm.CHALLENGE_BOSS: 40,
}

static var _weight_map: Dictionary = {
	YtCreepSize.enm.MASS: 1,
	YtCreepSize.enm.NORMAL: 2,
	YtCreepSize.enm.AIR: 4,
	YtCreepSize.enm.CHAMPION: 4,
	YtCreepSize.enm.BOSS: 20,
	YtCreepSize.enm.CHALLENGE_MASS: 2,
	YtCreepSize.enm.CHALLENGE_BOSS: 20,
}

static var _portal_damage_multiplier_map: Dictionary = {
	YtCreepSize.enm.MASS: 1,
	YtCreepSize.enm.NORMAL: 2,
	YtCreepSize.enm.AIR: 4,
	YtCreepSize.enm.CHAMPION: 4,
	YtCreepSize.enm.BOSS: 20,
	YtCreepSize.enm.CHALLENGE_MASS: 0,
	YtCreepSize.enm.CHALLENGE_BOSS: 0,
}

static var _gold_multiplier_map: Dictionary = {
	YtCreepSize.enm.MASS: 1,
	YtCreepSize.enm.NORMAL: 2,
	YtCreepSize.enm.AIR: 2,
	YtCreepSize.enm.CHAMPION: 4,
	YtCreepSize.enm.BOSS: 4,
	YtCreepSize.enm.CHALLENGE_MASS: 0,
	YtCreepSize.enm.CHALLENGE_BOSS: 0,
}

static var health_multiplier_map: Dictionary = {
	YtCreepSize.enm.MASS: 0.3,
	YtCreepSize.enm.NORMAL: 1.0,
	YtCreepSize.enm.AIR: 1.0,
	YtCreepSize.enm.CHAMPION: 1.75,
	YtCreepSize.enm.BOSS: 6.0,
	YtCreepSize.enm.CHALLENGE_MASS: 1.6,
	YtCreepSize.enm.CHALLENGE_BOSS: 12.0,
}

static var _base_mana_map: Dictionary = {
	YtCreepSize.enm.MASS: 100,
	YtCreepSize.enm.NORMAL: 200,
	YtCreepSize.enm.AIR: 400,
	YtCreepSize.enm.CHAMPION: 300,
	YtCreepSize.enm.BOSS: 2000,
	YtCreepSize.enm.CHALLENGE_MASS: 100,
	YtCreepSize.enm.CHALLENGE_BOSS: 3000,
}


static func get_list() -> Array[YtCreepSize.enm]:
	return _ordered_list


static func from_string(string: String) -> YtCreepSize.enm:
	var key = _string_map.find_key(string)
	
	if key != null:
		return key
	else:
		push_error("Invalid string: \"%s\". Possible values: %s" % [string, _string_map.values()])

		return YtCreepSize.enm.MASS


static func convert_to_string(type: YtCreepSize.enm) -> String:
	return _string_map[type]


static func get_display_string(type: YtCreepSize.enm) -> String:
	return YoutdData.size_name(convert_to_string(type).replace(" ", "_"))
static func get_item_drop_roll_count(type: YtCreepSize.enm) -> int:
	return _item_drop_roll_count[type]


static func get_score_multiplier(type: YtCreepSize.enm) -> float:
	return _score_multiplier[type]


static func get_weight(type: YtCreepSize.enm) -> float:
	return _weight_map[type]


static func get_experience(type: YtCreepSize.enm) -> float:
	return _experience_map[type]


static func get_gold_multiplier(type: YtCreepSize.enm) -> float:
	return _gold_multiplier_map[type]


static func get_portal_damage_multiplier(type: YtCreepSize.enm) -> float:
	return _portal_damage_multiplier_map[type]


static func is_challenge(type: YtCreepSize.enm) -> bool:
	var out: bool = type == YtCreepSize.enm.CHALLENGE_MASS || type == YtCreepSize.enm.CHALLENGE_BOSS

	return out


static func get_base_mana(type: YtCreepSize.enm) -> float:
	return _base_mana_map[type]


static func convert_to_mod_dmg_type(category: YtCreepSize.enm) -> YtModificationType.enm:
	const creep_size_to_mod_map: Dictionary = {
		YtCreepSize.enm.MASS: YtModificationType.enm.MOD_DMG_TO_MASS,
		YtCreepSize.enm.NORMAL: YtModificationType.enm.MOD_DMG_TO_NORMAL,
		YtCreepSize.enm.CHAMPION: YtModificationType.enm.MOD_DMG_TO_CHAMPION,
		YtCreepSize.enm.BOSS: YtModificationType.enm.MOD_DMG_TO_BOSS,
		YtCreepSize.enm.AIR: YtModificationType.enm.MOD_DMG_TO_AIR,
#		NOTE: this code is actually redundant because
#		creep.get_size() function already converts challenge
#		sizes to "simple" sizes. Keeping it for
#		completeness.
		YtCreepSize.enm.CHALLENGE_MASS: YtModificationType.enm.MOD_DMG_TO_MASS,
		YtCreepSize.enm.CHALLENGE_BOSS: YtModificationType.enm.MOD_DMG_TO_BOSS,
	}

	var mod_type: YtModificationType.enm = creep_size_to_mod_map[category]

	return mod_type
