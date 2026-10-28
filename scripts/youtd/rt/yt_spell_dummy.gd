class_name YtSpellDummy
extends YtDummyUnit
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.


# Instance of a spell. Should be created using YtSpellType.


# NOTE: target may be null if spell was cast on point
var _target: YtUnit = null
var _target_position: Vector2 = Vector2.ZERO
var _lifetime: float = 0.0


var _lifetime_timer: YtManualTimer


#########################
###     Built-in      ###
#########################

func _init():
	_lifetime_timer = YtManualTimer.new()
	_lifetime_timer.one_shot = true
	_lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)
	add_child(_lifetime_timer)


func _ready():
	super()

	_lifetime_timer.start(_lifetime)


#########################
###       Public      ###
#########################

func init_spell(caster: YtUnit, target: YtUnit, lifetime: float, data: YtSpellType.SpellData, damage_event_handler: Callable, target_pos: Vector2, damage_ratio: float, crit_ratio: float):
	_caster = caster
	_lifetime = lifetime
	_set_subclass_data(data)

	set_damage_event(damage_event_handler)

	_target = target
	_target_position = target_pos
	_damage_ratio = damage_ratio
	_crit_ratio = crit_ratio


func get_lifetime() -> float:
	return _lifetime


func get_remaining_lifetime() -> float:
	var remaining_lifetime: float = _lifetime_timer.get_time_left()

	return remaining_lifetime


#########################
###      Private      ###
#########################

# NOTE: subclasses override this to save data that is useful
# for them
func _set_subclass_data(_data: YtSpellType.SpellData):
	pass


#########################
###     Callbacks     ###
#########################

func _on_lifetime_timer_timeout():
	_cleanup()


func _on_cast_type_tree_exited():
	_cleanup()
