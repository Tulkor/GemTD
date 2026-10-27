extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_periodic_event(periodic, 12)


func periodic(_event: YtEvent):
	YtCombatLog.log_item_ability(item, null, "Learn")
	
	var tower: YtUnit = item.get_carrier()
	tower.add_exp(1)
