extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func on_damage(event: YtEvent):
	var tower: YtTower = item.get_carrier() 
	var speed: float = tower.get_base_attack_speed()  

	if event.is_main_target() && tower.calc_chance(0.2 * speed) == true:
		YtCombatLog.log_item_ability(item, event.get_target(), "Enlighten")
		event.get_target().modify_property(YtModificationType.enm.MOD_EXP_GRANTED, 0.05)
