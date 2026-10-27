extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var multiboard: YtMultiboardValues


func item_init():
	multiboard = YtMultiboardValues.new(1)
	var interest_bonus_label: String = YtUtils.text("Q7IE")
	multiboard.set_key(0, interest_bonus_label)


func on_create():
	item.user_real = 0


func on_drop():
	item.get_player().modify_interest_rate(-item.user_real)


func on_pickup():
	var tower: YtTower = item.get_carrier()
	item.user_real = 0.004 * (tower.get_gold_cost() / 2500.0)
	item.get_player().modify_interest_rate(item.user_real)


func on_tower_details() -> YtMultiboardValues:
	multiboard.set_value(0, YtUtils.format_percent(item.user_real, 3))
	return multiboard
