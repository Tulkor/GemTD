extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_spell_casted(on_spell_cast)


func on_spell_cast(event: YtEvent):
	var tower: YtUnit = item.get_carrier()
	var target_unit: YtUnit = event.get_target()

	if target_unit is YtTower:
		YtCombatLog.log_item_ability(item, null, "Reward the Faithful")
		
		target_unit.add_exp(1)
		tower.add_exp(1)
