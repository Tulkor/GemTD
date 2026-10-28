extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.



func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func on_damage(event: YtEvent):
	var creep: YtUnit = event.get_target()
	var twr: YtUnit = item.get_carrier()
	var target_effect: int

	if creep.is_stunned():
		YtCombatLog.log_item_ability(item, creep, "Crush")
		twr.do_spell_damage_aoe_unit(creep, 250, twr.get_current_attack_damage_with_bonus() * 0.2, twr.calc_spell_crit_no_bonus(), 0)
		target_effect = YtEffect.create_animated("res://src/effects/impale_target_dust.tscn", Vector3(creep.get_x(), creep.get_y(), 0.0), 0)
		YtEffect.set_scale(target_effect, 0.5)
