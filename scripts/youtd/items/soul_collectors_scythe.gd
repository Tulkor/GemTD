extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var multiboard: YtMultiboardValues


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_kill(on_kill)


func item_init():
	multiboard = YtMultiboardValues.new(1)
	var crit_bonus_label: String = YtUtils.text("YA2C")
	multiboard.set_key(0, crit_bonus_label)


func on_create():
	item.user_real = 0


func on_drop():
	item.get_carrier().modify_property(YtModificationType.enm.MOD_ATK_CRIT_DAMAGE, -item.user_real)


func on_pickup():
	item.get_carrier().modify_property(YtModificationType.enm.MOD_ATK_CRIT_DAMAGE, item.user_real)


func on_kill(_event: YtEvent):
	if item.user_real < 3:
		item.get_carrier().modify_property(YtModificationType.enm.MOD_ATK_CRIT_DAMAGE, 0.005)
		item.user_real = item.user_real + 0.005


func on_tower_details() -> YtMultiboardValues:
	var crit_damage_bonus_text: String = "x" + YtUtils.format_float(item.user_real, 3)
	multiboard.set_value(0, crit_damage_bonus_text)

	return multiboard
