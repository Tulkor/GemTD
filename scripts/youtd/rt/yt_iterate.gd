class_name YtIterate
extends RefCounted
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.


# YtIterate is a wrapper over get_units_in_range() f-n which
# stores the resulting unit list and allows iterating over
# units.


var _next_list: Array[YtUnit] = []


func _init(caster: YtUnit, center_pos: Vector2, target_type: YtTargetType, radius: float):
	_next_list = YtUtils.get_units_in_range(caster, target_type, center_pos, radius)


# NOTE: YtIterate.overUnitsInRangeOf() in JASS
static func over_units_in_range_of(caster: YtUnit, target_type: YtTargetType, center_pos: Vector2, radius: float) -> YtIterate:
	var it: YtIterate = YtIterate.new(caster, center_pos, target_type, radius)

	return it


# NOTE: YtIterate.overUnitsInRangeOfCaster() in JASS
static func over_units_in_range_of_caster(caster: YtUnit, target_type: YtTargetType, radius: float) -> YtIterate:
	var center_pos: Vector2 = caster.get_position_wc3_2d()
	var it: YtIterate = YtIterate.new(caster, center_pos, target_type, radius)

	return it


# NOTE: YtIterate.overUnitsInRangeOfUnit() in JASS
static func over_units_in_range_of_unit(caster: YtUnit, target_type: YtTargetType, center: YtUnit, radius: float) -> YtIterate:
	var center_pos: Vector2 = center.get_position_wc3_2d()
	var it: YtIterate = YtIterate.new(caster, center_pos, target_type, radius)

	return it


static func over_corpses_in_range(caster: YtUnit, center_pos: Vector2, radius: float) -> YtIterate:
	var it: YtIterate = YtIterate.new(caster, center_pos, YtTargetType.new(YtTargetType.CORPSES), radius)

	return it


# NOTE: iterate.next() in JASS
func next() -> YtUnit:
	_remove_invalid_units()

	var next_unit: YtUnit

	if !_next_list.is_empty():
		next_unit = _next_list.pop_front()
	else:
		next_unit = null

	return next_unit


# NOTE: iterate.nextRandom() in JASS
func next_random() -> YtUnit:
	_remove_invalid_units()
	
	var next_unit: YtUnit

	if !_next_list.is_empty():
		next_unit = YtUtils.pick_random(YtGlobals.synced_rng, _next_list)
		_next_list.erase(next_unit)
	else:
		next_unit = null

	return next_unit


# NOTE: iterate.nextCorpse() in JASS
func next_corpse() -> YtUnit:
	var corpse: YtUnit = next()

	return corpse


# NOTE: iterate.destroy() in JASS
# JASS engine had this f-n but it's not needed in Godot
# engine - do not call it.
# func destroy():
	# pass


# NOTE: iterate.count() in JASS
func count() -> int:
	_remove_invalid_units()

	return _next_list.size()


# NOTE: need to remove invalid units before each call to
# next() or count() because units may be killed or removed
# from the game while YtIterate is used.
func _remove_invalid_units():
	_next_list = _next_list.filter(
		func(unit) -> bool:
			var unit_is_valid: bool = YtUtils.unit_is_valid(unit)

			return unit_is_valid
	)
