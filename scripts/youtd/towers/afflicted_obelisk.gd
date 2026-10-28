extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: it may look wrong that the parasite buff has
# "friendly" property set to true but it doesn't matter
# because this buff is only for visual purposes. Leave it as
# is and do not change this.


var parasite_bt: YtBuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {vuln_value = 0.025, vuln_value_add = 0.0005},
		2: {vuln_value = 0.030, vuln_value_add = 0.0006},
		3: {vuln_value = 0.035, vuln_value_add = 0.0007},
		4: {vuln_value = 0.040, vuln_value_add = 0.0008},
	}


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func tower_init():
	parasite_bt = YtBuffType.new("parasite_bt", 0, 0, true, self)
	parasite_bt.set_buff_icon("res://resources/icons/generic_icons/amber_mosquito.tres")
	parasite_bt.set_buff_tooltip(YtUtils.text("DCFN"))


func on_damage(event: YtEvent):
	var target: YtUnit = event.get_target()
	var level: int = tower.get_level()

#	NOTE: need to divide by tower's buff duration because
#	duration will later be multiplied by tower's buff
#	duration, when buff is applied. Final result will be
#	that duration is 3 seconds.
	parasite_bt.apply_custom_timed(tower, target, 0, 3.0 / tower.get_prop_buff_duration())
	target.modify_property(YtModificationType.enm.MOD_DMG_FROM_NATURE, _stats.vuln_value + level * _stats.vuln_value_add)

	await YtUtils.create_manual_timer(3.0, self).timeout

	if YtUtils.unit_is_valid(target):
		tower.do_custom_attack_damage(target, tower.get_current_attack_damage_with_bonus(), tower.calc_attack_multicrit(0, 0, 0), YtAttackType.enm.DECAY)
		YtEffect.create_simple_at_unit("res://src/effects/crypt_fiend_eggsack.tscn", target)
		target.modify_property(YtModificationType.enm.MOD_DMG_FROM_NATURE, -_stats.vuln_value - level * _stats.vuln_value_add)
