extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var rage_bt: YtBuffType
var feral_bt: YtBuffType
var multiboard: YtMultiboardValues


func get_tier_stats() -> Dictionary:
	return {
		1: {feral_dmg_gain = 0.002, feral_dmg_max = 2.00, bloodthirst_attack_speed = 1.00, bloodthirst_duration = 3, rage_buff_level_base = 0},
		2: {feral_dmg_gain = 0.003, feral_dmg_max = 2.25, bloodthirst_attack_speed = 1.25, bloodthirst_duration = 4, rage_buff_level_base = 25},
		3: {feral_dmg_gain = 0.004, feral_dmg_max = 2.50, bloodthirst_attack_speed = 1.50, bloodthirst_duration = 5, rage_buff_level_base = 50},
	}


const BLOODTHIRST_ATTACKSPEED_ADD: float = 0.01
const BLOODTHIRST_DURATION_ADD: float = 0.05


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)
	triggers.add_event_on_kill(on_kill)


func tower_init():
	rage_bt = YtBuffType.new("rage_bt", 0, 0, true, self)
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 1.0, BLOODTHIRST_ATTACKSPEED_ADD)
	rage_bt.set_buff_modifier(mod)
	rage_bt.set_buff_icon("res://resources/icons/generic_icons/mighty_force.tres")
	rage_bt.set_buff_tooltip(YtUtils.text("BLU0"))

	feral_bt = YtBuffType.new("feral_bt", -1, 0, true, self)
	feral_bt.set_buff_icon("res://resources/icons/generic_icons/orc_head.tres")
	feral_bt.set_buff_tooltip(YtUtils.text("XZ11"))

	multiboard = YtMultiboardValues.new(1)
	var damage_bonus_label: String = YtUtils.text("DS1C")
	multiboard.set_key(0, damage_bonus_label)


func on_damage(event: YtEvent):
	if event.is_attack_damage_critical() && tower.user_real <= _stats.feral_dmg_max:
		tower.user_real += _stats.feral_dmg_gain
		tower.modify_property(YtModificationType.enm.MOD_DAMAGE_ADD_PERC, _stats.feral_dmg_gain)

		var feral_buff: YtBuff = tower.get_buff_of_type(feral_bt)
		var feral_stack_count: int = floori(tower.user_real * 100)
		feral_buff.set_displayed_stacks(feral_stack_count)


func on_kill(_event: YtEvent):
	var lvl: int = tower.get_level()
	var buff_level: int = lvl + _stats.rage_buff_level_base
	var buff_duration: float = _stats.bloodthirst_duration + BLOODTHIRST_DURATION_ADD * lvl

	if tower.get_buff_of_type(rage_bt) == null:
		YtCombatLog.log_ability(tower, null, "Bloodthirst")

		rage_bt.apply_custom_timed(tower, tower, buff_level, buff_duration)


func on_create(preceding: YtTower):
	if preceding != null && preceding.get_family() == tower.get_family():
		var damage_bonus: float = preceding.user_real
		tower.user_real = damage_bonus
		tower.modify_property(YtModificationType.enm.MOD_DAMAGE_ADD_PERC, damage_bonus)
	else:
		tower.user_real = 0.0

	var feral_buff: YtBuff = feral_bt.apply_to_unit_permanent(tower, tower, 0)
	var feral_stack_count: int = floori(tower.user_real * 100)
	feral_buff.set_displayed_stacks(feral_stack_count)


func on_tower_details() -> YtMultiboardValues:
	var damage_bonus: String = YtUtils.format_percent(tower.user_real, 1)

	multiboard.set_value(0, damage_bonus)

	return multiboard
