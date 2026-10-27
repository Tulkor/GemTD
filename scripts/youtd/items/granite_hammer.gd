extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func on_attack(_event: YtEvent):
	var tower: YtTower = item.get_carrier()
	item.user_int = item.user_int + 1

	if item.user_int == 5:
		YtCombatLog.log_item_ability(item, null, "Heavy Weapon")
		
		tower.add_attack_crit()

		item.user_int = 0


func on_pickup():
	item.user_int = 1
