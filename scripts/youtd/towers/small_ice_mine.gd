extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var slow_bt: YtBuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {slow_value = 0.075, slow_duration = 2.0, aoe_range = 250, aoe_damage = 150, aoe_damage_add = 7.5},
		2: {slow_value = 0.090, slow_duration = 3.0, aoe_range = 300, aoe_damage = 500, aoe_damage_add = 25},
		3: {slow_value = 0.110, slow_duration = 4.0, aoe_range = 350, aoe_damage = 1250, aoe_damage_add = 62.5},
		4: {slow_value = 0.140, slow_duration = 5.0, aoe_range = 400, aoe_damage = 2500, aoe_damage_add = 125},
	}


const NOVA_CHANCE: float = 0.20
const NOVA_CHANCE_ADD: float = 0.004
const EXTRA_CRIT_CHANCE: float = 0.30


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func tower_init():
	var m: YtModifier = YtModifier.new()

	slow_bt = YtBuffType.new("slow_bt", _stats.slow_duration, 0.0, false, self)
	m.add_modification(YtModificationType.enm.MOD_MOVESPEED, -_stats.slow_value, 0.0)
	slow_bt.set_buff_modifier(m)
	slow_bt.set_buff_icon("res://resources/icons/generic_icons/foot_trip.tres")
	slow_bt.set_buff_tooltip(YtUtils.text("SW2E"))


func on_damage(event: YtEvent):
	var level: int = tower.get_level()
	var nova_chance: float = NOVA_CHANCE + NOVA_CHANCE_ADD * level

	if !tower.calc_chance(nova_chance):
		return

	var target: YtUnit = event.get_target()
	var it: YtIterate = YtIterate.over_units_in_range_of_unit(tower, YtTargetType.new(YtTargetType.CREEPS), target, _stats.aoe_range)
	var next: YtUnit

	YtCombatLog.log_ability(tower, target, "Ice Nova")

	while true:
		next = it.next()

		if next == null:
			break

		slow_bt.apply(tower, next, level)

	var damage: float = _stats.aoe_damage + _stats.aoe_damage_add * tower.get_level()
	tower.do_spell_damage_aoe_unit(target, _stats.aoe_range, damage, tower.calc_spell_crit(EXTRA_CRIT_CHANCE, 0.0), 0)
	YtEffect.create_simple_at_unit("res://src/effects/frost_bolt_missile.tscn", target)
