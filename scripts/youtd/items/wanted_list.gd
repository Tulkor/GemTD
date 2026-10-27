extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_kill(on_kill)


func on_kill(_event: YtEvent):
	var tower: YtTower = item.get_carrier()
	YtCombatLog.log_item_ability(item, null, "Headhunt")
	item.get_carrier().get_player().give_gold(2, tower, true, true)
