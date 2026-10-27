extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers_buff_type: YtBuffType):
	triggers_buff_type.add_event_on_attack(on_attack)


func on_attack(_event: YtEvent):
	var mana: float = tower.get_mana()

	if mana < 1:
		tower.order_stop()
	else:
		tower.set_mana(mana - 1)
