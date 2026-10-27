extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var multiboard: YtMultiboardValues
var blood_bt: YtBuffType
var aura_bt: YtBuffType
var wrath_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)
	triggers.add_event_on_unit_comes_in_range(on_unit_in_range, 900, YtTargetType.new(YtTargetType.CREEPS))


func tower_init():
	blood_bt = YtBuffType.new("blood_bt", 6.0, 0.08, false, self)
	var iaman_ymir_blood_mod: YtModifier = YtModifier.new()
	iaman_ymir_blood_mod.add_modification(YtModificationType.enm.MOD_DMG_FROM_ICE, 0.25, 0.004)
	blood_bt.set_buff_modifier(iaman_ymir_blood_mod)
	blood_bt.set_buff_icon("res://resources/icons/generic_icons/round_potion.tres")
	blood_bt.set_buff_tooltip(YtUtils.text("MR2Y"))

	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", true, self)
	var iaman_ymir_flesh_mod: YtModifier = YtModifier.new()
	iaman_ymir_flesh_mod.add_modification(YtModificationType.enm.MOD_DEBUFF_DURATION, -0.25, -0.006)
	aura_bt.set_buff_modifier(iaman_ymir_flesh_mod)
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/meat.tres")
	aura_bt.set_buff_tooltip(YtUtils.text("LJ28"))

	wrath_bt = YtBuffType.new("wrath_bt", 0, 0, false, self)
	var iaman_ymir_wrath_mod: YtModifier = YtModifier.new()
	iaman_ymir_wrath_mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, -1.0, 0.001)
	wrath_bt.set_buff_modifier(iaman_ymir_wrath_mod)
	wrath_bt.set_buff_icon("res://resources/icons/generic_icons/foot_trip.tres")
	wrath_bt.set_buff_tooltip(YtUtils.text("SCJ8"))

	multiboard = YtMultiboardValues.new(1)
	var wrath_damage_label: String = YtUtils.text("OEII")
	multiboard.set_key(0, wrath_damage_label)


func on_damage(event: YtEvent):
	var target: YtCreep = event.get_target()
	var wrath_chance: float = 0.20 + 0.004 * tower.get_level()

	if !tower.calc_chance(wrath_chance):
		return

	YtCombatLog.log_ability(tower, target, "Wrath of Ymir")

#	slow becomes less powerful with every cast
	var slow_power: int = 1000 - int(target.get_health_ratio() * 1000)
	var wrath_damage: float = get_wrath_damage()

	tower.do_spell_damage(target, wrath_damage, tower.calc_spell_crit_no_bonus())
	wrath_bt.apply_custom_timed(tower, target, slow_power, 2.0)
	YtEffect.create_simple_at_unit("res://src/effects/ziggurat_frost_missile.tscn", target)


func on_tower_details() -> YtMultiboardValues:
	var wrath_damage: float = get_wrath_damage()
	var wrath_damage_string: String = YtUtils.format_float(wrath_damage, 0)
	multiboard.set_value(0, wrath_damage_string)

	return multiboard


func on_unit_in_range(event: YtEvent):
	var target: YtUnit = event.get_target()
	blood_bt.apply(tower, target, tower.get_level())


func get_wrath_damage() -> float:
	var wrath_damage: float = tower.get_current_attack_damage_with_bonus() * (0.10 + 0.006 * tower.get_level())

	return wrath_damage
