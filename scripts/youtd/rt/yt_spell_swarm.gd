extends YtSpellDummy
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.


# This spell implements the "Carrion Swarm" spell from WC3.
# Deals damage in a cone from caster to target. Works as a
# moving AoE which expands as it gets closer to target.
# 
# The swarm moves in the direction of defined target
# position but keeps going past the target position. It only
# stops once the defined lifetime is over.


const MOVE_PERIOD: float = 0.2

var _current_swarm_pos: Vector2
var _already_damaged_list: Array[YtUnit] = []

# Spell data
var _damage: float
var _start_pos: Vector2
var _start_radius: float
var _end_radius: float
var _travel_distance: float
var _effect_path: String
var _move_vector: Vector2

var _move_timer: YtManualTimer


func _ready():
	super()

	_move_timer = YtManualTimer.new()
	_move_timer.wait_time = MOVE_PERIOD
	_move_timer.timeout.connect(_on_move_timer_timeout)
	add_child(_move_timer)
	_move_timer.start()

	_start_pos = get_position_wc3_2d()

	_current_swarm_pos = _start_pos

#	NOTE: need to subtract MOVE_PERIOD here so that the last
#	move step is done before the spell expires due to
#	lifetime expiring. If this subtraction is not done, then
#	the spell will not reach the max distance as it's
#	supposed to.
	var lifetime: float = get_lifetime()
	var move_speed: float = _travel_distance / (lifetime - MOVE_PERIOD)
	_move_vector = (_target_position - _start_pos).normalized() * move_speed


func _on_move_timer_timeout():
#	Move current position of spell
	_current_swarm_pos = _current_swarm_pos + _move_vector * MOVE_PERIOD

# 	Add visual effect
	var effect: int = YtEffect.create_animated(_effect_path, Vector3(_current_swarm_pos.x, _current_swarm_pos.y, 0.0), 0.0)
	var effect_scale: float = _get_effect_scale()
	YtEffect.set_scale(effect, effect_scale)

# 	Deal damage
	var current_radius: float = _get_current_radius()
	var creep_list: Array = YtUtils.get_units_in_range(_caster, YtTargetType.new(YtTargetType.CREEPS), _current_swarm_pos, current_radius)

#	Deal damage once to each creep in path
	for already_damaged_creep in _already_damaged_list:
		if !YtUtils.unit_is_valid(already_damaged_creep):
			continue

		creep_list.erase(already_damaged_creep)

	for creep in creep_list:
		do_spell_damage(creep, _damage)
		_already_damaged_list.append(creep)

	var _travel_distance_current: float = _start_pos.distance_to(_current_swarm_pos)
	var reached_target: bool = round(_travel_distance_current) >= round(_travel_distance)

	if reached_target:
		_move_timer.stop()


func _get_move_progress() -> float:
	var start_pos: Vector2 = get_position_wc3_2d()
	var distance_travelled: float = _current_swarm_pos.distance_to(start_pos)
	var total_distance: float = start_pos.distance_to(_target_position)
	var move_progress: float = YtUtils.divide_safe(distance_travelled, total_distance, 1.0)

	return move_progress


func _get_effect_scale() -> float:
	var lifetime: float = get_lifetime()
	var remaining_lifetime: float = get_remaining_lifetime()
	var move_progress: float = 1.0 - YtUtils.divide_safe(remaining_lifetime, lifetime, 0.0)
	var effect_scale: float = lerp(0.5, 2.0, move_progress)

	return effect_scale


func _get_current_radius() -> float:
	var move_progress: float = _get_move_progress()
	var current_radius: float = lerp(_start_radius, _end_radius, move_progress)

	return current_radius


# NOTE: subclasses override this to save data that is useful
# for them
func _set_subclass_data(data: YtSpellType.SpellData):
	_damage = data.swarm.damage
	_start_radius = data.swarm.start_radius
	_end_radius = data.swarm.end_radius
	_travel_distance = data.swarm.travel_distance
	_effect_path = data.swarm.effect_path
