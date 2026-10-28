extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func on_attack(event: YtEvent):
	var tower: YtTower = item.get_carrier()
	item.user_int = item.user_int + 1

	if item.user_int == 10:
		YtCombatLog.log_item_ability(item, event.get_target(), "Bartuc's Spirit")
		tower.do_spell_damage_aoe_unit(event.get_target(), 300, 2000 + (tower.get_level() * 80), tower.calc_spell_crit_no_bonus(), 0.0)
		var effect: int = YtEffect.create_simple_at_unit("res://src/effects/warstomp_caster.tscn", event.get_target())
		YtEffect.set_z_index(effect, YtEffect.Z_INDEX_BELOW_CREEPS)
		item.user_int = 0


func on_pickup():
	item.user_int = 0
