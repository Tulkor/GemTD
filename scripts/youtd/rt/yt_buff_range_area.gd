class_name YtBuffRangeArea
extends Node
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.

# YtBuffRangeArea emits a signal when a unit that matches the
# defined target type comes in range. Used by buffs to
# implement the "unit comes in range" event.

signal unit_came_in_range(handler: Callable, unit: YtUnit)


var _target_type: YtTargetType
var _handler: Callable
var _radius: float
var _buff: YtBuff
var _prev_units_in_range: Array = []


#########################
###     Callbacks     ###
#########################

func _on_manual_timer_timeout():
	var buffed_unit: YtUnit = _buff.get_buffed_unit()

	if buffed_unit == null:
		return

	var caster: YtUnit = _buff.get_caster()
	var buffed_unit_pos: Vector2 = buffed_unit.get_position_wc3_2d()
	var all_units_in_range: Array = YtUtils.get_units_in_range(caster, _target_type, buffed_unit_pos, _radius)

	var matching_units: Array = []

	for unit in all_units_in_range:
		var target_match: bool = _target_type.match(unit)

		if target_match:
			matching_units.append(unit)

	for unit in matching_units:
		var unit_just_came_in_range: bool = !_prev_units_in_range.has(unit)

		if unit_just_came_in_range:
			unit_came_in_range.emit(_handler, unit)

	_prev_units_in_range = matching_units


#########################
###       Static      ###
#########################

static func make(radius: float, target_type: YtTargetType, handler: Callable, buff: YtBuff) -> YtBuffRangeArea:
	var buff_range_area := YtBuffRangeArea.new()
	var timer := YtManualTimer.new()
	timer.wait_time = 0.2
	timer.autostart = true
	timer.timeout.connect(buff_range_area._on_manual_timer_timeout)
	buff_range_area.add_child(timer)
	buff_range_area._radius = radius
	buff_range_area._target_type = target_type
	buff_range_area._handler = handler
	buff_range_area._buff = buff

	return buff_range_area
