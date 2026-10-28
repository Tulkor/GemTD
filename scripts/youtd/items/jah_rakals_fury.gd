extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var multiboard: YtMultiboardValues


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func item_init():
	multiboard = YtMultiboardValues.new(1)
	var attack_speed_increase_label: String = YtUtils.text("RWPC")
	multiboard.set_key(0, attack_speed_increase_label)


func on_attack(event: YtEvent):
	if item.user_int == event.get_target().get_uid():
# 		100% attack speed limit
		if item.user_real != 1.00 && item.user_real + 0.02 > 1.00:
#			Add the remaining bonus (99% -> 101%; limit -> 100%; add 100% - 99% = 1%)
			item.get_carrier().modify_property(YtModificationType.enm.MOD_ATTACKSPEED, 1.00 - item.user_real)
			item.user_real = 1.00
		else:
#			Add bonus
			item.get_carrier().modify_property(YtModificationType.enm.MOD_ATTACKSPEED, 0.02)
			item.user_real = item.user_real + 0.02
	else:
#		Save current target
		item.user_int = event.get_target().get_uid()
#		Temp variable to store the current bonus
		item.user_real2 = item.user_real
#		Calculate the new bonus (Current bonus * (50% + towerlevel%))
		item.user_real = item.user_real * (50.0 + item.get_carrier().get_level()) / 100
#		Change the bonus (new Bonus - current Bonus)
		item.get_carrier().modify_property(YtModificationType.enm.MOD_ATTACKSPEED, item.user_real - item.user_real2)


func on_create():
	item.user_real = 0.00
	item.user_int = 0


func on_drop():
# 	Remove bonus
	item.get_carrier().modify_property(YtModificationType.enm.MOD_ATTACKSPEED, -item.user_real)


func on_pickup():
#	Add bonus
	item.get_carrier().modify_property(YtModificationType.enm.MOD_ATTACKSPEED, item.user_real)


func on_tower_details() -> YtMultiboardValues:
	var attack_speed_bonus_text: String = YtUtils.format_percent(item.user_real, 0)
	multiboard.set_value(0, attack_speed_bonus_text)

	return multiboard
