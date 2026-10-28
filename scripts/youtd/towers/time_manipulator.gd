extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: [ORIGINAL_GAME_BUG] Fixed error in original script
# where "Time Field" buff was "unfriendly" even though it's
# applied on a tower. Changed it to "friendly".


var aura_bt: YtBuffType
var time_field_bt: YtBuffType
var multiboard: YtMultiboardValues
var exp_exchanged: int


func load_triggers(triggers: YtBuffType):
	triggers.add_periodic_event(periodic, 10)


func tower_init():
	time_field_bt = YtBuffType.new("time_field_bt", 10, 0, true, self)
	time_field_bt.set_special_effect("res://src/effects/spell_aire.tscn", 150, 1.0)
	time_field_bt.add_periodic_event(time_field_bt_periodic, 1.0)
	time_field_bt.set_buff_icon("res://resources/icons/generic_icons/rss.tres")
	time_field_bt.set_buff_tooltip(YtUtils.text("ZD87"))

	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", true, self)
	var aura_bt_mod: YtModifier = YtModifier.new()
	aura_bt_mod.add_modification(YtModificationType.enm.MOD_EXP_RECEIVED, 0.1, 0.016)
	aura_bt_mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 0.1, 0.01)
	aura_bt_mod.add_modification(YtModificationType.enm.MOD_MANA_REGEN_PERC, 0.05, 0.02)
	aura_bt_mod.add_modification(YtModificationType.enm.MOD_BUFF_DURATION, 0.125, 0.015)
	aura_bt.set_buff_modifier(aura_bt_mod)
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/electric.tres")
	aura_bt.set_buff_tooltip(YtUtils.text("WG04"))

	multiboard = YtMultiboardValues.new(1)
	var exp_exchanged_label: String = YtUtils.text("MOLD")
	multiboard.set_key(0, exp_exchanged_label)


func on_create(_preceding: YtTower):
	exp_exchanged = 0


func on_destruct():
	tower.add_exp_flat(exp_exchanged)


func on_tower_details() -> YtMultiboardValues:
	var exp_exchanged_string: String = str(exp_exchanged)
	multiboard.set_value(0, exp_exchanged_string)

	return multiboard


func periodic(_event: YtEvent):
	if tower.get_exp() >= 700:
		tower.remove_exp_flat(50)
		exp_exchanged += 50
		tower.modify_property(YtModificationType.enm.MOD_SPELL_DAMAGE_DEALT, 0.05)
		YtEffect.create_simple_at_unit("res://src/effects/charm_target.tscn", tower, YtUnit.BodyPart.OVERHEAD)
	else:
		tower.add_exp(2)
		YtEffect.create_simple_at_unit("res://src/effects/blink_target.tscn", tower, YtUnit.BodyPart.CHEST)


func on_autocast(_event: YtEvent):
	time_field_bt.apply(tower, tower, tower.get_level())


# NOTE: "MajFieldDamage()" in original script
func time_field_bt_periodic(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var caster: YtTower = buff.get_caster()
	var damage: float = 1500 + 75 * buff.get_level()

	caster.do_spell_damage_pb_aoe(950, damage, caster.calc_spell_crit_no_bonus(), 0.0)
