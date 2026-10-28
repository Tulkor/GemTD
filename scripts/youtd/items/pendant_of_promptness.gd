extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func on_attack(_event: YtEvent):
	var tower: YtTower = item.get_carrier()

	if tower.subtract_mana(0.05 * tower.get_overall_mana(), false) == 0:
		tower.order_stop()
