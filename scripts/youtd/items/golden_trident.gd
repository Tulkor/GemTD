extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var multiboard: YtMultiboardValues


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func item_init():
	multiboard = YtMultiboardValues.new(1)
	var gold_bonus_label: String = YtUtils.text("VA0V")
	multiboard.set_key(1, gold_bonus_label)


func on_attack(event: YtEvent):
	var tower: YtTower = item.get_carrier()
	var gold_bonus: float = 2.0

	if event.get_number_of_crits() > 0:
		gold_bonus = gold_bonus * event.get_number_of_crits() * tower.get_base_attack_speed() * tower.get_prop_bounty_received()

		tower.get_player().give_gold(int(gold_bonus), tower, true, true)
		item.user_real += gold_bonus


func on_create():
	item.user_real = 0.00


func on_tower_details() -> YtMultiboardValues:
	multiboard.set_value(0, YtUtils.format_float(item.user_real, 1))

	return multiboard
