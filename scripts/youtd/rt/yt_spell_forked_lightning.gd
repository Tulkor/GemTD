extends YtSpellDummy
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.


const AOE_DISTANCE: float = 400.0
const VISUAL_LIFETIME: float = 0.4
const VISUAL_COLOR: Color = Color.SKY_BLUE

var _damage: float = 0.0
var _target_count: int = 0


func _ready():
	super()

	if _target == null:
		push_error("Forked lightning must be cast on target. Casting on point is not supported.")
		
		return

	var hit_list: Array[YtUnit] = _get_hit_list()

#	Add visual for chain lightning
	var unit_list_for_visual: Array[YtUnit] = hit_list.duplicate()
	var caster: YtUnit = get_caster()
	unit_list_for_visual.insert(0, caster)
	
	for creep in hit_list:
		var start_unit: YtUnit = get_caster()
		var end_unit: YtUnit = creep
		_create_lightning_section(start_unit, end_unit)
	
# 	Apply damage
	for creep in hit_list:
		do_spell_damage(creep, _damage)


func _get_hit_list() -> Array[YtUnit]:
	var hit_unit_list: Array[YtUnit] = []
	hit_unit_list.append(_target)

	var it: YtIterate = YtIterate.over_units_in_range_of_caster(_target, YtTargetType.new(YtTargetType.CREEPS), AOE_DISTANCE)

	while true:
		var next: YtUnit = it.next_random()

		if next == null:
			break

		if next == _target:
			continue

		if hit_unit_list.size() == _target_count:
			break

		hit_unit_list.append(next)
	
	return hit_unit_list


func _create_lightning_section(start_unit: YtUnit, end_unit: YtUnit):
	var interpolated_sprite: YtInterpolatedSprite = YtInterpolatedSprite.create_from_unit_to_unit(YtInterpolatedSprite.LIGHTNING, start_unit, end_unit)
	interpolated_sprite.set_lifetime(VISUAL_LIFETIME)

	interpolated_sprite.modulate = VISUAL_COLOR



# NOTE: subclasses override this to save data that is useful
# for them
func _set_subclass_data(data: YtSpellType.SpellData):
	_damage = data.forked_lightning.damage
	_target_count = data.forked_lightning.target_count
