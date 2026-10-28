class_name YtRarity extends Node
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.


enum enm {
	COMMON,
	UNCOMMON,
	RARE,
	UNIQUE,
}


static var _string_map: Dictionary = {
	YtRarity.enm.COMMON: "common",
	YtRarity.enm.UNCOMMON: "uncommon",
	YtRarity.enm.RARE: "rare",
	YtRarity.enm.UNIQUE: "unique",
}

static var _color_map: Dictionary = {
	YtRarity.enm.COMMON: Color.GREEN,
	YtRarity.enm.UNCOMMON: Color.ROYAL_BLUE,
	YtRarity.enm.RARE: Color.MEDIUM_PURPLE,
	YtRarity.enm.UNIQUE: Color.GOLD,
}


static func convert_from_string(string: String) -> YtRarity.enm:
	var key = _string_map.find_key(string)
	
	if key != null:
		return key
	else:
		push_error("Invalid string: \"%s\". Possible values: %s" % [string, _string_map.values()])

		return YtRarity.enm.COMMON


static func convert_to_string(rarity: YtRarity.enm) -> String:
	return _string_map[rarity]


static func get_display_string(type: YtRarity.enm) -> String:
	return YoutdData.rarity_name(convert_to_string(type))
static func get_color(rarity: YtRarity.enm) -> Color:
	return _color_map[rarity]


static func get_list() -> Array[YtRarity.enm]:
	return [
		YtRarity.enm.COMMON,
		YtRarity.enm.UNCOMMON,
		YtRarity.enm.RARE,
		YtRarity.enm.UNIQUE,
	]
