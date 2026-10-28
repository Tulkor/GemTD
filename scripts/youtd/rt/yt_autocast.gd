class_name YtAutocast
extends Node
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.

# YtAutocast is attached to a unit and triggers an ability.
# Can be attached using YtTower.add_autocast(),
# YtBuff.add_autocast() or YtItem.set_autocast().
#
# Note that autocast doesn't implement the gameplay effects
# of the ability like dealing damage. That needs to be
# implemented in the autocast handler. The only gameplay
# effect that some autocasts do is applying buffs on units.
#
# YtAutocast type determines the way that the autocast
# behaves. See below for descriptions of autocast types.
#
# AC_TYPE_ALWAYS_BUFF - applies a buff on targets in range
# that don't already have the buff_type. Note that if a
# handler is specified, then it will be called and buff
# should be applied by the handler.
#
# AC_TYPE_ALWAYS_IMMEDIATE - calls the defined handler.
# Ability effects should be implemented by the handler.
#
# AC_TYPE_OFFENSIVE_BUFF - same as AC_TYPE_ALWAYS_BUFF, but
# is active only while tower is attacking.
#
# AC_TYPE_OFFENSIVE_UNIT - calls handler and passes current
# attack target of caster via the event argument.
#
# AC_TYPE_OFFENSIVE_IMMEDIATE - same as
# AC_TYPE_ALWAYS_IMMEDIATE but is active only while tower is
# active.
#
# AC_TYPE_NOAC_IMMEDIATE - same as AC_TYPE_ALWAYS_IMMEDIATE
# but is always in manual mode.
#
# AC_TYPE_NOAC_CREEP - same as AC_TYPE_OFFENSIVE_UNIT but is
# always in manual mode.
# 
# AC_TYPE_NOAC_TOWER - same as AC_TYPE_NOAC_CREEP but
# accepts only tower targets.
#
# AC_TYPE_NOAC_PLAYER_TOWER - same as AC_TYPE_NOAC_TOWER but
# accepts only player tower targets.
# 
# See _types_that_can_use_auto_mode list for information
# about which autocast types can use auto mode. Types not in
# the list are always in manual mode.


enum Type {
	AC_TYPE_ALWAYS_BUFF,
	AC_TYPE_ALWAYS_IMMEDIATE,
	AC_TYPE_OFFENSIVE_BUFF,
	AC_TYPE_OFFENSIVE_UNIT,
	AC_TYPE_OFFENSIVE_IMMEDIATE,
	AC_TYPE_OFFENSIVE_POINT,
	AC_TYPE_NOAC_IMMEDIATE,
	AC_TYPE_NOAC_CREEP,
	AC_TYPE_NOAC_TOWER,
	AC_TYPE_NOAC_PLAYER_TOWER,
	AC_TYPE_NOAC_POINT,
}


const _types_that_can_use_auto_mode: Array[YtAutocast.Type] = [
	YtAutocast.Type.AC_TYPE_ALWAYS_BUFF,
	YtAutocast.Type.AC_TYPE_ALWAYS_IMMEDIATE,
	YtAutocast.Type.AC_TYPE_OFFENSIVE_BUFF,
	YtAutocast.Type.AC_TYPE_OFFENSIVE_UNIT,
	YtAutocast.Type.AC_TYPE_OFFENSIVE_IMMEDIATE,
]
const _immediate_type_list: Array[YtAutocast.Type] = [
	YtAutocast.Type.AC_TYPE_ALWAYS_IMMEDIATE,
	YtAutocast.Type.AC_TYPE_OFFENSIVE_IMMEDIATE,
	YtAutocast.Type.AC_TYPE_NOAC_IMMEDIATE,
]
const _buff_type_list: Array[YtAutocast.Type] = [
	YtAutocast.Type.AC_TYPE_ALWAYS_BUFF,
	YtAutocast.Type.AC_TYPE_OFFENSIVE_BUFF,
]
const _offensive_type_list: Array[YtAutocast.Type] = [
	YtAutocast.Type.AC_TYPE_OFFENSIVE_BUFF,
	YtAutocast.Type.AC_TYPE_OFFENSIVE_UNIT,
	YtAutocast.Type.AC_TYPE_OFFENSIVE_IMMEDIATE,
	YtAutocast.Type.AC_TYPE_OFFENSIVE_POINT,
]
const _unit_type_list: Array[YtAutocast.Type] = [
	YtAutocast.Type.AC_TYPE_OFFENSIVE_UNIT,
]
const _point_type_list: Array[YtAutocast.Type] = [
	YtAutocast.Type.AC_TYPE_OFFENSIVE_POINT,
	YtAutocast.Type.AC_TYPE_NOAC_POINT,
]

# NOTE: buff_target_type and buff_type are
# only relevant to "_BUFF" autocast types. For other
# autocast types leave these values blank.

var _autocast_id: int = -1
var _autocast_type: YtAutocast.Type = Type.AC_TYPE_OFFENSIVE_UNIT
var _buff_type: YtBuffType = null
var _buff_target_type: YtTargetType = null
var _handler: Callable = Callable()
var _target_pos: Vector2 = Vector2.ZERO
var _target_type: YtTargetType = null
var _caster: YtUnit = null
var _is_item_autocast: bool = false
var _item_owner = null

# Tracks how much time is left before ability can be used.
var _cooldown_timer: YtManualTimer
# While auto mode is enabled, this timer periodically
# triggers an attempt to cast ability if all requirements
# are met. While auto mode is disabled, this timer is
# paused.
var _auto_timer: YtManualTimer

var _uid: int = 0


#########################
###     Built-in      ###
#########################

func _ready():
	_cooldown_timer.wait_time = get_cooldown()
	_cooldown_timer.one_shot = true

	_uid = YtWorld.next_uid()

	YtGroupManager.add("autocasts", self, get_uid())

	if !can_use_auto_mode():
		_auto_timer.set_paused(true)

	_check_buff_target_type()

	_target_type = YtAutocast.calculate_target_type(_autocast_type, _buff_target_type)


#########################
###       Public      ###
#########################

func get_id() -> int:
	return _autocast_id


func get_name_english() -> String:
	var name_english: String = YtAbilityData.autocast_name_english(_autocast_id)

	return name_english


func get_autocast_name() -> String:
	var autocast_name: String = YtAbilityData.autocast_autocast_name(_autocast_id)

	return autocast_name


func get_target_self() -> bool:
	var target_self: bool = YtAbilityData.autocast_target_self(_autocast_id)

	return target_self


func get_cast_range() -> float:
	var cast_range: float = YtAbilityData.autocast_cast_range(_autocast_id)

	return cast_range


func get_auto_range() -> float:
	var auto_range: float = YtAbilityData.autocast_auto_range(_autocast_id)

	return auto_range


func get_uid() -> int:
	return _uid


func toggle_auto_mode():
	var new_paused_value: bool = !_auto_timer.is_paused()
	_auto_timer.set_paused(new_paused_value)


func auto_mode_is_enabled() -> bool:
	var is_enabled: bool = !_auto_timer.is_paused()

	return is_enabled


func do_cast_at_pos(target_pos: Vector2):
	_target_pos = target_pos
	var target: YtUnit = null
	do_cast(target)


# NOTE: target arg may be null if autocast is immediate
# NOTE: this function doesn't check conditions like "caster
# has enough mana", "not on cooldown". This has to be done
# by the user of this function before calling the do_cast().
# Use YtAutocast.can_cast() for checking.
func do_cast(target: YtUnit):
	YtCombatLog.log_autocast(_caster, target, self)

	_cooldown_timer.start()
	
	if !_handler.is_null():
		var autocast_event: YtEvent = _make_autocast_event(target)
		_handler.call(autocast_event)
	elif _buff_type != null:
		_buff_type.apply(_caster, target, _caster.get_level())
	else:
		push_error("Incorrect autocast state, _handler = %s, _buff_type= %s" % [_handler, _buff_type])

		return

#	NOTE: the ordering of calls is important here. Must
#	subtract mana AFTER calling the autocast handler
#	function. This is because autocast handlers need to
#	check mana value before it is spent.
	var mana_cost: int = get_mana_cost()
	_caster.subtract_mana(mana_cost, false)

	var spell_casted_event: YtEvent = _make_autocast_event(target)
	_caster.spell_casted.emit(spell_casted_event)

	if target != null:
		var spell_targeted_event: YtEvent = _make_autocast_event(_caster)
		target.spell_targeted.emit(spell_targeted_event)

	var caster_art: String = YtAbilityData.autocast_caster_art(_autocast_id)
	if !caster_art.is_empty():
		YtEffect.create_simple_at_unit(caster_art, _caster)

	var target_art: String = YtAbilityData.autocast_target_art(_autocast_id)
	if !target_art.is_empty() && target != null:
		YtEffect.create_simple_at_unit(target_art, target)


## Zauber von Hand auslösen (Knopf im Tower-Menü). Das Ziel sucht sich der Zauber selbst: Gegner = aktuelles
## Angriffsziel oder der nächste in Reichweite, Tower = der nächste andere Tower, Punkt = Stelle dieses Gegners.
## false, wenn er gerade nicht geht (Abklingzeit, Mana, kein Ziel).
func manual_cast() -> bool:
	if not can_cast():
		return false
	if type_is_immediate():
		do_cast(null)
		return true
	var tt: YtTargetType = YtTargetType.new(YtTargetType.CREEPS) if type_is_point() else _target_type
	var units: Array = YtUtils.get_units_in_range(_caster, tt, _caster.get_position_wc3_2d(), get_cast_range())
	if not get_target_self():
		units.erase(_caster)
	var current: YtUnit = _caster.get_current_target()
	var target: YtUnit = current if current != null and units.has(current) else null
	if target == null and not units.is_empty():
		YtUtils.sort_unit_list_by_distance(units, _caster.get_position_wc3_2d())
		target = units[0]
	if target == null:
		return false
	if type_is_point():
		do_cast_at_pos(target.get_position_wc3_2d())
	else:
		do_cast(target)
	return true


func check_target_for_unit_autocast(target: YtUnit) -> bool:
	if target == null:
		return false

	var target_is_in_range: bool = _get_target_is_in_range(target)
	var target_type_is_valid = _target_type.match(target)
	var target_is_immune: bool = target.is_immune()
	var target_is_self: bool = target == _caster
	var target_self: bool = get_target_self()
	var targetting_self_when_forbidden: bool = !target_self && target_is_self
	var target_is_ok: bool = target_is_in_range && target_type_is_valid && !target_is_immune && !targetting_self_when_forbidden

	return target_is_ok


func target_pos_is_in_range(target_pos: Vector2) -> bool:
	var in_range: float = YtVectorUtils.in_range(_caster.get_position_wc3_2d(), target_pos, get_cast_range())

	return in_range


func can_cast() -> bool:
	if _caster == null:
		return false

	var on_cooldown: bool = _cooldown_timer.get_time_left() > 0
	var mana_cost: int = get_mana_cost()
	var enough_mana: bool = _caster.get_mana() >= mana_cost
	var silenced: bool = _caster.is_silenced()
	var stunned: bool = _caster.is_stunned()
	var result: bool = !on_cooldown && enough_mana && !silenced && !stunned

	return result


# Some autocast types are always manual
func can_use_auto_mode() -> bool:
	var can_use: bool = _types_that_can_use_auto_mode.has(_autocast_type)

	return can_use


# Some autocast types are always manual
static func can_use_auto_mode_for_id(autocast_id: int) -> bool:
	var autocast_type: YtAutocast.Type = YtAbilityData.autocast_autocast_type(autocast_id)
	var can_use: bool = _types_that_can_use_auto_mode.has(autocast_type)

	return can_use


func type_is_immediate() -> bool:
	return _immediate_type_list.has(_autocast_type)


func type_is_point() -> bool:
	return _point_type_list.has(_autocast_type)


func type_is_buff() -> bool:
	return _buff_type_list.has(_autocast_type)


func type_is_offensive() -> bool:
	return _offensive_type_list.has(_autocast_type)


func type_is_unit() -> bool:
	return _unit_type_list.has(_autocast_type)


# NOTE: this is used if this autocast is "owned" by an item
# instead of a tower.
func set_item_owner(item):
	_item_owner = item
	_is_item_autocast = true


#########################
###      Private      ###
#########################

func _check_buff_target_type():
	var ac_type_is_buff: bool = type_is_buff()

	if ac_type_is_buff && _buff_target_type == null:
		push_error("Autocast %s has autocast type buff but doesn't have buff_target_type defined. You should define a non-null buff_target_type." % get_name_english())
	elif !ac_type_is_buff && _buff_target_type != null:
		push_error("Autocast %s doesn't have autocast type buff but has non-null buff_target_type. You should change buff_target_type to null." % get_name_english())


func _make_autocast_event(target: YtUnit) -> YtEvent:
	var event: YtEvent = YtEvent.new(target)
	event._autocast = self

	return event


func _get_target_is_in_range(target: YtUnit) -> bool:
	var range_extended: float = YtUtils.apply_unit_range_extension(get_auto_range(), _target_type)
	var target_is_in_range: bool = YtVectorUtils.in_range(target.get_position_wc3_2d(), _caster.get_position_wc3_2d(), range_extended)

	return target_is_in_range


static func calculate_target_type(autocast_type_arg: YtAutocast.Type, buff_target_type_arg: YtTargetType) -> YtTargetType:
	match autocast_type_arg:
		YtAutocast.Type.AC_TYPE_ALWAYS_BUFF:
			if buff_target_type_arg != null:
				return buff_target_type_arg
			else:
				return YtTargetType.new(0)
		YtAutocast.Type.AC_TYPE_ALWAYS_IMMEDIATE: return YtTargetType.new(0)
		YtAutocast.Type.AC_TYPE_OFFENSIVE_BUFF:
			if buff_target_type_arg != null:
				return buff_target_type_arg
			else:
				return YtTargetType.new(0)
		YtAutocast.Type.AC_TYPE_OFFENSIVE_UNIT: return YtTargetType.new(YtTargetType.CREEPS)
		YtAutocast.Type.AC_TYPE_OFFENSIVE_IMMEDIATE: return YtTargetType.new(0)
		YtAutocast.Type.AC_TYPE_NOAC_IMMEDIATE: return YtTargetType.new(0)
		YtAutocast.Type.AC_TYPE_NOAC_CREEP: return YtTargetType.new(YtTargetType.CREEPS)
		YtAutocast.Type.AC_TYPE_NOAC_TOWER: return YtTargetType.new(YtTargetType.TOWERS)
		YtAutocast.Type.AC_TYPE_NOAC_PLAYER_TOWER: return YtTargetType.new(YtTargetType.PLAYER_TOWERS)
		YtAutocast.Type.AC_TYPE_NOAC_POINT: return YtTargetType.new(0)

	push_error("_calculate_target_type doesn't support type: ", autocast_type_arg)

	return YtTargetType.new(0)


func _get_target_for_auto_mode() -> YtUnit:
	if type_is_buff():
		return _get_target_for_buff_autocast()
	elif type_is_unit():
		return _get_target_for_unit_autocast()
	elif type_is_immediate():
#		Immediate autocasts have no target
		return null
	else:
		return null


func _get_target_for_unit_autocast() -> YtUnit:
# 	NOTE: use tower's current attack target instead of
# 	searching for nearby units ourselves.
	var target: YtUnit = _caster.get_current_target()

	var target_is_ok: bool = check_target_for_unit_autocast(target)

	if target_is_ok:
		return target
	else:
		return null


func _get_target_for_buff_autocast() -> YtUnit:
	var unit_list: Array = YtUtils.get_units_in_range(_caster, _target_type, _caster.get_position_wc3_2d(), get_auto_range())

# 	NOTE: should not filter targets by buff groups if
# 	targets are creeps. YtBuff groups is a feature only for towers
	var autocast_targets_towers: bool = _target_type != null && _target_type.get_unit_type() == YtTargetType.UnitType.TOWERS
	if autocast_targets_towers:
		pass
	
	YtUtils.shuffle(YtGlobals.synced_rng, unit_list)

	var target_self: bool = get_target_self()
	if !target_self:
		unit_list.erase(_caster)

	for unit in unit_list:
		if !YtUtils.unit_is_valid(unit):
			continue

		if _buff_type == null:
			return unit

		var unit_is_immune: bool = unit.is_immune()
		if unit_is_immune:
			continue

		var buff: YtBuff = unit.get_buff_of_type(_buff_type)
		var unit_has_buff: bool = buff != null

		if !unit_has_buff:
			return unit

	return null


# Examples:
# 
# a) Caster has no buffgroups, target has no buffgroups =>
#    accept
# 
# b) Caster has buffgroup 1=outgoing, target has no
#    buffgroups => reject
# 
# c) Caster has buffgroup 1=outgoing, target has buffgroup
#    1=incoming => accept
# 
# d) Caster has buffgroup 1=outgoing 2=outgoing, target has
#    buffgroup 1=incoming => accept
# 
# e) Caster has no buffgroups, target has
#    buffgroup 1=incoming => accept
func _on_auto_timer_timeout():
	if !can_cast():
		return
	
# 	NOTE: need to do combat check in here instead of in
# 	can_cast() so that if auto mode is disabled, autocast
# 	can still be casted manually by player. For example,
# 	player needs to be able to start the cast to pick the
# 	target before tower starts attacking.
	var cant_cast_because_not_in_combat: bool = type_is_offensive() && !_caster.is_in_combat()

	if cant_cast_because_not_in_combat:
		return

	var cant_cast_because_zero_charges: bool = _item_owner != null && _item_owner.get_charges() == 0 && _item_owner.uses_charges()

	if cant_cast_because_zero_charges:
		return

	var target: YtUnit = _get_target_for_auto_mode()

#	NOTE: no error message here like in manual case becase
#	this is the auto case and adding an error message here
#	would cause spam
	if target == null && !type_is_immediate():
		return

	do_cast(target)


#########################
### Setters / Getters ###
#########################

func set_caster(caster: YtUnit):
	_caster = caster


func get_caster() -> YtUnit:
	return _caster


func get_autocast_index() -> int:
	var autocast_list: Array[YtAutocast] = _caster.get_autocast_list()
	var index: int = autocast_list.find(self)

	return index


# NOTE: autocast.getCooldown() in JASS
func get_cooldown() -> float:
	var cooldown: float = YtAbilityData.autocast_cooldown(_autocast_id)

	return cooldown


func get_remaining_cooldown() -> float:
	if !is_node_ready():
		push_error("Autocast cannot perform the request because it hasn't been added to the scene tree. Make sure that autocast's parent and it's ancestors have been added to the scene tree. Parent: ", get_parent())

		return 0.0

	return _cooldown_timer.time_left

# NOTE: autocast.getManacost() in JASS
func get_mana_cost() -> int:
	var mana_cost: int = YtAbilityData.autocast_mana_cost(_autocast_id)

	return mana_cost


func is_item_autocast() -> bool:
	return _is_item_autocast


func get_target_pos() -> Vector2:
	return _target_pos


static func make(autocast_id: int, creator_object: Object) -> YtAutocast:
	var buff_type_string: String = YtAbilityData.autocast_buff_type(autocast_id)
	var buff_type: YtBuffType
	if !buff_type_string.is_empty():
		buff_type = creator_object.get(buff_type_string)
		
		if buff_type == null:
			push_error("Failed to find buff type for autocast. Buff type = %s, autocast id = %s" % [buff_type_string, autocast_id])
	else:
		buff_type = null

	var handler_function_string: String = YtAbilityData.autocast_handler_function(autocast_id)
	var handler_function: Callable
	if !handler_function_string.is_empty():
		handler_function = Callable(creator_object, handler_function_string)
		
		if !handler_function.is_valid():
			push_error("Failed to find handle function for autocast. Handler function = %s, autocast id = %d" % [handler_function_string, autocast_id])
#			NOTE: Switch to empty callable to prevent
#			runtime errors
			handler_function = Callable()
	else:
		handler_function = Callable()
	
#	NOTE: need to store autocast_type and buff_target_type
#	in variables instead of getting them from
#	AutocastProperties every time because these properties
#	are a bit costly too calculate all the time. Other
#	properties are okay to get through AutocastProperties.
	var autocast := YtAutocast.new()
	autocast._cooldown_timer = YtManualTimer.new()
	autocast.add_child(autocast._cooldown_timer)
	autocast._auto_timer = YtManualTimer.new()
	autocast._auto_timer.wait_time = 0.2
	autocast._auto_timer.autostart = true
	autocast._auto_timer.timeout.connect(autocast._on_auto_timer_timeout)
	autocast.add_child(autocast._auto_timer)
	autocast._autocast_id = autocast_id
	autocast._autocast_type = YtAbilityData.autocast_autocast_type(autocast_id)
	autocast._buff_target_type = YtAbilityData.autocast_buff_target_type(autocast_id)
	autocast._buff_type = buff_type
	autocast._handler = handler_function

	return autocast


static func autocast_type_to_string(t: Type) -> String:
	match t:
		Type.AC_TYPE_ALWAYS_BUFF: return "AC_TYPE_ALWAYS_BUFF"
		Type.AC_TYPE_ALWAYS_IMMEDIATE: return "AC_TYPE_ALWAYS_IMMEDIATE"
		Type.AC_TYPE_OFFENSIVE_BUFF: return "AC_TYPE_OFFENSIVE_BUFF"
		Type.AC_TYPE_OFFENSIVE_UNIT: return "AC_TYPE_OFFENSIVE_UNIT"
		Type.AC_TYPE_OFFENSIVE_IMMEDIATE: return "AC_TYPE_OFFENSIVE_IMMEDIATE"
		Type.AC_TYPE_OFFENSIVE_POINT: return "AC_TYPE_OFFENSIVE_POINT"
		Type.AC_TYPE_NOAC_IMMEDIATE: return "AC_TYPE_NOAC_IMMEDIATE"
		Type.AC_TYPE_NOAC_CREEP: return "AC_TYPE_NOAC_CREEP"
		Type.AC_TYPE_NOAC_TOWER: return "AC_TYPE_NOAC_TOWER"
		Type.AC_TYPE_NOAC_PLAYER_TOWER: return "AC_TYPE_NOAC_PLAYER_TOWER"
		Type.AC_TYPE_NOAC_POINT: return "AC_TYPE_NOAC_POINT"

	return "UNKNOWN"


static func string_to_autocast_type(t_string: String) -> Type:
	match t_string:
		"AC_TYPE_ALWAYS_BUFF": return Type.AC_TYPE_ALWAYS_BUFF
		"AC_TYPE_ALWAYS_IMMEDIATE": return Type.AC_TYPE_ALWAYS_IMMEDIATE
		"AC_TYPE_OFFENSIVE_BUFF": return Type.AC_TYPE_OFFENSIVE_BUFF
		"AC_TYPE_OFFENSIVE_UNIT": return Type.AC_TYPE_OFFENSIVE_UNIT
		"AC_TYPE_OFFENSIVE_IMMEDIATE": return Type.AC_TYPE_OFFENSIVE_IMMEDIATE
		"AC_TYPE_OFFENSIVE_POINT": return Type.AC_TYPE_OFFENSIVE_POINT
		"AC_TYPE_NOAC_IMMEDIATE": return Type.AC_TYPE_NOAC_IMMEDIATE
		"AC_TYPE_NOAC_CREEP": return Type.AC_TYPE_NOAC_CREEP
		"AC_TYPE_NOAC_TOWER": return Type.AC_TYPE_NOAC_TOWER
		"AC_TYPE_NOAC_PLAYER_TOWER": return Type.AC_TYPE_NOAC_PLAYER_TOWER
		"AC_TYPE_NOAC_POINT": return Type.AC_TYPE_NOAC_POINT

	return Type.AC_TYPE_NOAC_POINT
