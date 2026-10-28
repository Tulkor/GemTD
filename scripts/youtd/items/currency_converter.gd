extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_periodic_event(on_periodic, 1.0)


func on_periodic(event: YtEvent):
	var tower: YtTower = item.get_carrier()
	var lvl: int = tower.get_level()
	event.enable_advanced(15 - lvl * 0.3, false)
	if tower.get_exp() >= 2.0:
		YtCombatLog.log_item_ability(item, null, "Exchange")
		tower.remove_exp_flat(2)
		tower.get_player().give_gold(7, tower, true, true)
	else:
		var not_enough_credits_text: String = YtUtils.text("LOO6")
		tower.get_player().display_floating_text(not_enough_credits_text, tower, Color8(255, 0, 0))
