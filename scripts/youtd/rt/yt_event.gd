class_name YtEvent
extends RefCounted
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.


enum Type {
	CLEANUP,
	CREATE,
	UPGRADE,
	REFRESH,
	DEATH,
	KILL,
	LEVEL_CHANGED,
	ATTACK,
	ATTACKED,
	DAMAGE,
	DAMAGED,
	EXPIRE,
	SPELL_CAST,
	SPELL_TARGET,
	PURGE,
}


var _buff: YtBuff
# NOTE: damage may be modified in event handlers to change
# the final effect of the event
var damage: float
var _number_of_crits: int = 0
# target is of type YtUnit, can't use typing because of cyclic dependency...
var _target: YtUnit
var _is_main_target: bool = false
var _is_spell_damage: bool = false
# Timer belonging to a buff that triggered this event. Used
# for cases where periodic event handler needs to modify
# duration of periodic event.
var _timer: YtManualTimer = null
var _autocast: YtAutocast = null
var _level_increased_during_event: bool = false


#########################
### Code starts here  ###
#########################

func _init(target: YtUnit):
	_target = target


#########################
### Setters / Getters ###
#########################

func get_buff() -> YtBuff:
	return _buff

# YtEvent.getAutocastType() in JASS
func get_autocast_type() -> YtAutocast:
	return _autocast

# YtEvent.getTarget() in JASS
func get_target() -> YtUnit:
	return _target

# Only relevant for "damage" event. True for damage
# from normal tower attacks, for main target of splash tower
# attacks and for first target of tower bounce attack.
# 
# YtEvent.isMainTarget() in JASS
func is_main_target() -> bool:
	return _is_main_target

# Only relevant for damaged events. True if damaged event is
# caused by spell damage.
# YtEvent.isSpellDamage() in JASS
func is_spell_damage() -> bool:
	return _is_spell_damage

# Changes the properties of the current PERIODIC event. Does
# nothing when called for other types of events. Note that
# if "one shot" is set to true, then the periodic event will
# trigger one more time and then stop forever.
# YtEvent.enableAdvanced() in JASS
func enable_advanced(wait_time: float, one_shot: bool):
	if _timer == null:
		return

	_timer.stop()
	_timer.wait_time = wait_time
	_timer.one_shot = one_shot
	_timer.start()


# This returns the number of crits for current attack or
# damage instance. This contains a valid value only inside
# the following events: attack, attacked, damage, damaged.
# 
# NOTE: tower.getNumberOfCrits() in JASS
# This function belongs to YtTower in JASS engine but I moved
# to YtEvent because it makes more sense.
func get_number_of_crits() -> int:
	return _number_of_crits


# Valid only for the following events: attack, attacked,
# damage, damaged.
# NOTE: YtEvent.isAttackDamageCritical() in JASS
func is_attack_damage_critical() -> int:
	var is_critical: bool = _number_of_crits > 0

	return is_critical


# Returns true if current LEVEL_CHANGED event was triggered when
# tower level increased. False if tower level decreased.
# NOTE: "Event.isLevelUp()" in JASS
func level_increased() -> bool:
	return _level_increased_during_event
