class_name YtUtils
extends RefCounted
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Statt des Autoloads Utils: nur die Hilfen, die Tower- und Gegner-Skripte brauchen.


static func tr_text(text: String) -> String:
	return text(text)


## Text aus der Übersetzungstabelle von YouTD 2 (Schlüssel wie "AFH7"): deutsch aus data/youtd/texte.json, übersetzt
## über en.json. Die Tabelle liegt nicht im Quelltext von YouTD 2; unbekannte Schlüssel (Buff-Hinweise) bleiben leer.
static func text(key: String) -> String:
	var t := str(YoutdData._file("texte").get(key, ""))
	return TranslationServer.translate(t) if t != "" else ""


## Reichweiten zählen bis zum Rand eines kleinen Kreises um das Ziel (bei Towern größer).
static func apply_unit_range_extension(range_original: float, target_type: YtTargetType) -> float:
	if target_type == null:
		return range_original
	if target_type.get_unit_type() == YtTargetType.UnitType.TOWERS:
		return range_original + YtConstants.RANGE_CHECK_BONUS_FOR_TOWERS
	return range_original + YtConstants.RANGE_CHECK_BONUS_FOR_OTHER_UNITS


## Einmaliger Timer im Spieltakt; löscht sich nach dem Ablauf selbst.
static func create_manual_timer(duration: float, parent: Node) -> YtManualTimer:
	var timer := YtManualTimer.new()
	var host: Node = YtWorld.node
	var parent_is_active: bool = parent != null and parent.is_inside_tree() and not parent.is_queued_for_deletion()
	if parent_is_active and host != null:
		host.add_child(timer)
		timer.one_shot = true
		timer.timeout.connect(timer.queue_free)
		# Verlässt der Besitzer das Feld, läuft der Timer sofort ab: die wartende Funktion endet noch, solange es sie
		# gibt (die Skripte prüfen danach unit_is_valid). Sonst bliebe sie samt Event als Speicherleck übrig.
		parent.tree_exiting.connect(timer.expire, CONNECT_ONE_SHOT)
		timer.start(duration)
	else:
		timer.queue_free()
	return timer


static func get_time() -> float:
	return YtWorld.get_time()


static func get_current_tick() -> int:
	return YtWorld.get_tick()


static func time_to_ticks(time: float) -> int:
	return roundi(time * YtWorld.TICKS_PER_SECOND)


static func ticks_to_time(ticks: int) -> float:
	return ticks * 1.0 / YtWorld.TICKS_PER_SECOND


static func get_time_of_day() -> float:
	return fmod(YtConstants.INITIAL_TIME_OF_DAY + get_time() * YtConstants.IRL_SECONDS_TO_GAME_WORLD_HOURS, 24.0)


static func add_object_to_world(object: Node) -> void:
	if YtWorld.node == null:
		object.queue_free()
		return
	YtWorld.node.add_child(object, true)


static func get_max_level() -> int:
	return YtConstants.TOWER_MAX_LEVEL_WITH_BONUS


static func get_colored_string(string: String, _color: Color) -> String:
	return string


static func divide_safe(a: float, b: float, result_when_divide_by_zero: float = 0.0) -> float:
	return a / b if b != 0.0 else result_when_divide_by_zero


static func pick_random(rng: RandomNumberGenerator, array: Array) -> Variant:
	if array.is_empty():
		return null
	return array[rng.randi() % array.size()]


static func shuffle(rng: RandomNumberGenerator, array: Array) -> void:
	for i in array.size():
		var j: int = rng.randi_range(0, array.size() - 1)
		if j != i:
			var temp = array[j]
			array[j] = array[i]
			array[i] = temp


## Zufälliges Element nach Gewichten: {"a": 10, "b": 20} → a zu 1/3, b zu 2/3.
static func random_weighted_pick(rng: RandomNumberGenerator, element_to_weight_map: Dictionary) -> Variant:
	if element_to_weight_map.is_empty():
		return null
	var keys: Array = element_to_weight_map.keys()
	keys.sort()
	var total := 0.0
	for k in keys:
		total += float(element_to_weight_map[k])
	var roll: float = rng.randf_range(0, total)
	var acc := 0.0
	for k in keys:
		acc += float(element_to_weight_map[k])
		if roll <= acc:
			return k
	return keys[0]


## Einheit noch im Spiel? Ohne Typ, weil ungültige Instanzen hier ankommen können.
static func unit_is_valid(unit) -> bool:
	return unit != null and is_instance_valid(unit) and unit.is_inside_tree() and not unit.is_queued_for_deletion()


static func rand_chance(rng: RandomNumberGenerator, chance: float) -> bool:
	return rng.randf() <= clampf(chance, 0.0, 1.0)


## Einheiten (Tower, Gegner oder Leichen) im Umkreis, nach Zieltyp gefiltert.
static func get_units_in_range(caster: YtUnit, type: YtTargetType, center: Vector2, radius: float) -> Array[YtUnit]:
	var result: Array[YtUnit] = []
	if type == null:
		return result
	var group_name: String
	match type.get_unit_type():
		YtTargetType.UnitType.TOWERS: group_name = "yt_towers"
		YtTargetType.UnitType.CREEPS: group_name = "yt_creeps"
		YtTargetType.UnitType.CORPSES: group_name = "yt_corpses"
	radius = apply_unit_range_extension(radius, type)
	var r2 := radius * radius
	var check_player: bool = type.player_towers_is_set() and caster != null
	for node in YtWorld.group(group_name):
		var unit: YtUnit = node as YtUnit
		if unit == null or unit.is_queued_for_deletion() or not unit.is_inside_tree():
			continue
		if not type.match(unit):
			continue
		if center.distance_squared_to(unit.get_position_wc3_2d()) > r2:
			continue
		if check_player and caster.get_player() != unit.get_player():
			continue
		result.append(unit)
	return result


static func sort_unit_list_by_distance(unit_list: Array, position: Vector2) -> void:
	unit_list.sort_custom(func(a, b):
		var da: float = a.get_position_wc3_2d().distance_squared_to(position)
		var db: float = b.get_position_wc3_2d().distance_squared_to(position)
		if absf(da - db) < 0.01:
			return a.get_uid() < b.get_uid()
		return da < db)


## Ziele für Tower: erst die älteste Welle in Reichweite fertig machen, darin die nächsten Gegner.
static func sort_creep_list_for_targeting(unit_list: Array, position: Vector2) -> void:
	unit_list.sort_custom(func(a, b):
		var la: int = a.get_spawn_level()
		var lb: int = b.get_spawn_level()
		if la != lb:
			return la < lb
		var da: float = a.get_position_wc3_2d().distance_to(position)
		var db: float = b.get_position_wc3_2d().distance_to(position)
		if absf(da - db) < 0.01:
			return a.get_uid() < b.get_uid()
		return da < db)


static func bit_is_set(mask: int, bit: int) -> bool:
	return (mask & bit) != 0x0


static func format_float(x: float, digits: int) -> String:
	return String.num(x, digits)


static func format_percent(x: float, digits: int) -> String:
	return "%s%%" % String.num(x * 100, digits)


static func format_percent_add_color(x: float, digits: int) -> String:
	return format_percent(x, digits)


static func get_tower_list() -> Array[YtTower]:
	var list: Array[YtTower] = []
	for n in YtWorld.group("yt_towers"):
		list.append(n as YtTower)
	return list


static func get_creep_list() -> Array[YtCreep]:
	var list: Array[YtCreep] = []
	for n in YtWorld.group("yt_creeps"):
		list.append(n as YtCreep)
	return list


## Flächenschaden: Ziele in der äußeren Hälfte bekommen (1 − sides_ratio) davon.
static func get_aoe_damage(aoe_center: Vector2, target: YtUnit, radius: float, damage: float, sides_ratio: float) -> float:
	var distance: float = aoe_center.distance_to(target.get_position_wc3_2d())
	if divide_safe(distance, radius) > 0.5:
		return damage * (1.0 - sides_ratio)
	return damage


static func get_scale_from_grows(sprite_scale_min: float, sprite_scale_max: float, current_grows: float, max_grows: float) -> float:
	var scale_max: float = sprite_scale_max / sprite_scale_min
	var grow_ratio: float = clampf(current_grows / max_grows, 0.0, 1.0)
	return 1.0 + (scale_max - 1.0) * grow_ratio


## Punkt (WC3) auf dem Gegnerweg?
static func is_point_on_creep_path(point_wc3: Vector2, _player = null) -> bool:
	var game = YtWorld.game
	if game == null:
		return false
	var p := point_wc3 / YtWorld.WC3
	var path: PackedVector2Array = game.lane_paths[0].ground
	for i in range(1, path.size()):
		if Geometry2D.get_closest_point_to_segment(p, path[i - 1], path[i]).distance_to(p) <= 0.5:
			return true
	return false


## i-ter Punkt des Gegnerwegs (Boden) in WC3-Einheiten.
static func get_path_point_wc3(move_path, index: int) -> Vector2:
	var path: PackedVector2Array = move_path if move_path is PackedVector2Array else YtWorld.game.lane_paths[0].ground
	return path[clampi(index, 0, path.size() - 1)] * YtWorld.WC3


## Große Zahl kurz mit Tausendertrennern und M/G/T (TowerDetails.int_format in YouTD 2).
static func int_format(num: float) -> String:
	var suffix := ""
	for s in [[1e15, "Q"], [1e12, "T"], [1e9, "G"], [1e6, "M"]]:
		if num >= s[0]:
			num /= s[0]
			suffix = s[1]
			break
	var num_str := str(int(num)) if num >= 1 else "0"
	var frac_str := ""
	if suffix != "":
		var f := format_float(num, 2)
		if f.contains("."):
			frac_str = "." + f.split(".")[1]
	for i in range(num_str.length() - 3, 0, -3):
		num_str = num_str.insert(i, ",")
	return num_str + frac_str + suffix
