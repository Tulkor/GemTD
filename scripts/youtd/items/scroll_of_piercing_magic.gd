extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func on_damage(event: YtEvent):
	var t: YtCreep = event.get_target()

	if t.get_armor_type() == YtArmorType.enm.SIF:
		item.get_carrier().do_spell_damage(t, event.damage * 0.25, item.get_carrier().calc_spell_crit_no_bonus())
		YtEffect.create_simple_at_unit("res://src/effects/spell_breaker_target.tscn", t)
