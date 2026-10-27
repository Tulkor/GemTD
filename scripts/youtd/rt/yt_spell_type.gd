class_name YtSpellType
extends Node
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.

# YtSpellType is used to store information about spells. Used to
# create instances of YtSpellDummy.

# NOTE: this class is called "Cast" in JASS


enum Name {
	BLIZZARD,
	CHAIN_LIGHTNING,
	FORKED_LIGHTNING,
	CARRION_SWARM,
}


class BlizzardData:
	var damage: float = 0.0
	var radius: float = 0.0
	var wave_count: int = 0


class ChaingLightningData:
	var damage: float = 0.0
	var damage_reduction: float = 0.0
	var chain_count: int = 0


class ForkedLightningData:
	var damage: float = 0.0
	var target_count: int = 0


class SwarmData:
	var damage: float = 0.0
	var start_radius: float = 0.0
	var end_radius: float = 0
	var travel_distance: float = 0.0
	var effect_path: String = ""


class SpellData:
	var blizzard: BlizzardData = BlizzardData.new()
	var chain_lightning: ChaingLightningData = ChaingLightningData.new()
	var forked_lightning: ForkedLightningData = ForkedLightningData.new()
	var swarm: SwarmData = SwarmData.new()


const _spell_script_map: Dictionary = {
	YtSpellType.Name.BLIZZARD: preload("res://scripts/youtd/rt/yt_spell_blizzard.gd"),
	YtSpellType.Name.CHAIN_LIGHTNING: preload("res://scripts/youtd/rt/yt_spell_chain_lightning.gd"),
	YtSpellType.Name.FORKED_LIGHTNING: preload("res://scripts/youtd/rt/yt_spell_forked_lightning.gd"),
	YtSpellType.Name.CARRION_SWARM: preload("res://scripts/youtd/rt/yt_spell_swarm.gd"),
}


var data: SpellData = SpellData.new()

var _spell_name: YtSpellType.Name
var _lifetime: float
var _source_height: float = 0.0
var _damage_event_handler: Callable = Callable()


#########################
###     Built-in      ###
#########################

func _init(spell_name: YtSpellType.Name, lifetime: float, parent: Node):
	parent.add_child(self)
	_spell_name = spell_name
	_lifetime = lifetime


#########################
###       Public      ###
#########################

# NOTE: cast.setDamageEvent() in JASS
func set_damage_event(handler: Callable):
	_damage_event_handler = handler


func point_cast_from_unit_on_point(caster: YtUnit, origin_unit: YtUnit, target_pos: Vector2, damage_ratio: float, crit_ratio: float):
	var target: YtUnit = null
	var origin_pos: Vector3 = origin_unit.get_position_wc3()
	_cast_generic(caster, origin_pos, target, target_pos, damage_ratio, crit_ratio)


func point_cast_from_caster_on_point(caster: YtUnit, target_pos: Vector2, damage_ratio: float, crit_ratio: float):
	var origin_pos: Vector3 = caster.get_position_wc3()
	var target: YtUnit = null
	_cast_generic(caster, origin_pos, target, target_pos, damage_ratio, crit_ratio)


# NOTE: cast.targetCastFromCaster() in JASS
func target_cast_from_caster(caster: YtUnit, target: YtUnit, damage_ratio: float, crit_ratio: float):
	var origin_pos: Vector3 = caster.get_position_wc3()
	var target_pos: Vector2 = target.get_position_wc3_2d()
	_cast_generic(caster, origin_pos, target, target_pos, damage_ratio, crit_ratio)


# NOTE: cast.targetCastFromPoint() in JASS
func target_cast_from_point(caster: YtUnit, target: YtUnit, origin_pos_2d: Vector2, damage_ratio: float, crit_ratio: float):
	var origin_pos: Vector3 = Vector3(origin_pos_2d.x, origin_pos_2d.y, 0)
	var target_pos: Vector2 = target.get_position_wc3_2d()
	_cast_generic(caster, origin_pos, target, target_pos, damage_ratio, crit_ratio)


# NOTE: point_cast_from_target_on_target() and
# target_cast_from_caster() are basically the same in
# current implementation. In original game, there's more
# nuance but for practical purposes there's no point in
# implementing this nuance.
# NOTE: cast.pointCastFromCasterOnTarget() in JASS
func point_cast_from_target_on_target(caster: YtUnit, target: YtUnit, damage_ratio: float, crit_ratio: float):
	var origin_pos: Vector3 = target.get_position_wc3()
	var target_pos: Vector2 = target.get_position_wc3_2d()
	_cast_generic(caster, origin_pos, target, target_pos, damage_ratio, crit_ratio)


# NOTE: cast.setSourceHeight() in JASS
func set_source_height(value: float):
	_source_height = value


#########################
###      Private      ###
#########################

func _cast_generic(caster: YtUnit, origin_pos: Vector3, target: YtUnit, target_pos: Vector2, damage_ratio: float, crit_ratio: float):
	var instance: YtSpellDummy = _spell_script_map[_spell_name].new()
	origin_pos.z += _source_height
	instance.set_position_wc3(origin_pos)
	instance.init_spell(caster, target, _lifetime, data, _damage_event_handler, target_pos, damage_ratio, crit_ratio)
	tree_exited.connect(instance._on_cast_type_tree_exited)
	YtUtils.add_object_to_world(instance)
