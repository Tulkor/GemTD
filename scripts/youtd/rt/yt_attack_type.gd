class_name YtAttackType extends Node
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.


# NOTE: [ORIGINAL_GAME_DEVIATION] renamed "Magic"
# attack type from original game to "Arcane". Original
# "Magic" name for attack type was confusing because it
# sounded like it was related to "spell damage".

enum enm {
	PHYSICAL,
	DECAY,
	ENERGY,
	ESSENCE,
	ELEMENTAL,
	ARCANE,
}

static var _list: Array[YtAttackType.enm] = [
	YtAttackType.enm.PHYSICAL,
	YtAttackType.enm.DECAY,
	YtAttackType.enm.ENERGY,
	YtAttackType.enm.ESSENCE,
	YtAttackType.enm.ELEMENTAL,
	YtAttackType.enm.ARCANE,
]

static var _string_map: Dictionary = {
	YtAttackType.enm.PHYSICAL: "physical",
	YtAttackType.enm.DECAY: "decay",
	YtAttackType.enm.ENERGY: "energy",
	YtAttackType.enm.ESSENCE: "essence",
	YtAttackType.enm.ELEMENTAL: "elemental",
	YtAttackType.enm.ARCANE: "arcane",
}

static var _color_map: Dictionary = {
	YtAttackType.enm.PHYSICAL: Color.TAN,
	YtAttackType.enm.DECAY: Color.MEDIUM_PURPLE,
	YtAttackType.enm.ENERGY: Color.DODGER_BLUE,
	YtAttackType.enm.ESSENCE: Color.AQUAMARINE,
	YtAttackType.enm.ELEMENTAL: Color.CORNFLOWER_BLUE,
	YtAttackType.enm.ARCANE: Color.DEEP_SKY_BLUE,
}

static var _no_damage_to_immune_map: Dictionary = {
	YtAttackType.enm.PHYSICAL: false,
	YtAttackType.enm.DECAY: false,
	YtAttackType.enm.ENERGY: false,
	YtAttackType.enm.ESSENCE: false,
	YtAttackType.enm.ELEMENTAL: false,
	YtAttackType.enm.ARCANE: true,
}

static var _damage_to_armor_map: Dictionary = {
	YtAttackType.enm.PHYSICAL: {
		YtArmorType.enm.LUA: 1.8,
		YtArmorType.enm.SOL: 1.2,
		YtArmorType.enm.HEL: 0.9,
		YtArmorType.enm.MYT: 0.6,
		YtArmorType.enm.SIF: 0.4,
		YtArmorType.enm.ZOD: 1.0,
	},
	YtAttackType.enm.DECAY: {
		YtArmorType.enm.SOL: 1.8,
		YtArmorType.enm.HEL: 1.2,
		YtArmorType.enm.MYT: 0.9,
		YtArmorType.enm.LUA: 0.6,
		YtArmorType.enm.SIF: 0.4,
		YtArmorType.enm.ZOD: 1.0,
	},
	YtAttackType.enm.ENERGY: {
		YtArmorType.enm.HEL: 1.8,
		YtArmorType.enm.MYT: 1.2,
		YtArmorType.enm.LUA: 0.9,
		YtArmorType.enm.SOL: 0.6,
		YtArmorType.enm.SIF: 0.4,
		YtArmorType.enm.ZOD: 1.0,
	},
	YtAttackType.enm.ESSENCE: {
		YtArmorType.enm.HEL: 1.0,
		YtArmorType.enm.MYT: 1.0,
		YtArmorType.enm.LUA: 1.0,
		YtArmorType.enm.SOL: 1.0,
		YtArmorType.enm.SIF: 1.0,
		YtArmorType.enm.ZOD: 1.0,
	},
	YtAttackType.enm.ELEMENTAL: {
		YtArmorType.enm.MYT: 1.8,
		YtArmorType.enm.LUA: 1.2,
		YtArmorType.enm.SOL: 0.9,
		YtArmorType.enm.HEL: 0.6,
		YtArmorType.enm.SIF: 0.4,
		YtArmorType.enm.ZOD: 1.0,
	},
	YtAttackType.enm.ARCANE: {
		YtArmorType.enm.MYT: 1.5,
		YtArmorType.enm.LUA: 1.5,
		YtArmorType.enm.SOL: 1.5,
		YtArmorType.enm.HEL: 1.5,
		YtArmorType.enm.SIF: 0.4,
		YtArmorType.enm.ZOD: 1.0,
	},
}


static func convert_to_string(type: YtAttackType.enm):
	return _string_map[type]


static func from_string(string: String) -> YtAttackType.enm:
	var key = _string_map.find_key(string)
	
	if key != null:
		return key
	else:
		push_error("Invalid attack type string: \"%s\"" % string)

		return YtAttackType.enm.PHYSICAL


static func get_display_string(type: YtAttackType.enm) -> String:
	return YoutdData.attack_name(convert_to_string(type))
static func get_damage_against(attack_type: YtAttackType.enm, armor_type: YtArmorType.enm) -> float:
	var damage: float = _damage_to_armor_map[attack_type][armor_type]

	return damage


static func deals_no_damage_to_immune(attack_type: YtAttackType.enm) -> bool:
	return _no_damage_to_immune_map[attack_type]


static func get_list() -> Array[YtAttackType.enm]:
	return _list.duplicate()


# Returns text which says how much damage this attack type
# deals against each armor type.
# NOTE: this is rich text