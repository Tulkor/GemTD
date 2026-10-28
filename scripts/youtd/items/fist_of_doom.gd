extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_periodic_event(periodic, 10)


func periodic(_event: YtEvent):
	YtCombatLog.log_item_ability(item, null, "Pay With Blood")
	item.get_carrier().remove_exp(2)
