class_name YtAbilityData
extends RefCounted
## Auren, Autocasts und Fähigkeiten der Tower aus data/youtd/abilities.json (erzeugt tools/youtd/youtd_daten.py
## aus den Tabellen von YouTD 2, MIT). Ersetzt AuraProperties und AutocastProperties des Originals.


static func _entry(kind: String, id: int) -> Dictionary:
	var d: Dictionary = YoutdData._file("abilities")
	return d.get(kind, {}).get(str(id), {})


static func ability(id: int) -> Dictionary:
	return _entry("abilities", id)


static func aura(id: int) -> Dictionary:
	return _entry("auras", id)


static func autocast(id: int) -> Dictionary:
	return _entry("autocasts", id)


# --- Auren (AuraProperties) ---------------------------------------------------------------

static func aura_range(id: int) -> float:
	return float(aura(id).get("range", 0))


static func aura_target_type(id: int) -> YtTargetType:
	return YtTargetType.convert_from_string(str(aura(id).get("target_type", "")))


static func aura_target_self(id: int) -> bool:
	return bool(aura(id).get("target_self", false))


static func aura_level(id: int) -> int:
	return int(aura(id).get("level", 0))


static func aura_level_add(id: int) -> int:
	return int(aura(id).get("level_add", 0))


static func aura_buff_type(id: int) -> String:
	return str(aura(id).get("buff", ""))


# --- Autocasts (AutocastProperties) ----------------------------------------------------------

static func autocast_name_english(id: int) -> String:
	return str(autocast(id).get("name", ""))


static func autocast_autocast_name(id: int) -> String:
	return autocast_name_english(id)


static func autocast_target_self(id: int) -> bool:
	return bool(autocast(id).get("target_self", false))


static func autocast_cast_range(id: int) -> float:
	return float(autocast(id).get("cast_range", 0))


static func autocast_auto_range(id: int) -> float:
	return float(autocast(id).get("auto_range", 0))


static func autocast_caster_art(id: int) -> String:
	return str(autocast(id).get("caster_art", ""))


static func autocast_target_art(id: int) -> String:
	return str(autocast(id).get("target_art", ""))


static func autocast_autocast_type(id: int) -> YtAutocast.Type:
	return YtAutocast.string_to_autocast_type(str(autocast(id).get("type", "")))


static func autocast_cooldown(id: int) -> float:
	return float(autocast(id).get("cooldown", 1.0))


static func autocast_mana_cost(id: int) -> int:
	return int(autocast(id).get("mana", 0))


static func autocast_buff_type(id: int) -> String:
	return str(autocast(id).get("buff", ""))


static func autocast_handler_function(id: int) -> String:
	return str(autocast(id).get("handler", ""))


static func autocast_buff_target_type(id: int) -> YtTargetType:
	return YtTargetType.convert_from_string(str(autocast(id).get("buff_target_type", "")))
