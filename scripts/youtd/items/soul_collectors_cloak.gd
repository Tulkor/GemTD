extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var multiboard: YtMultiboardValues


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_kill(on_kill)


func item_init():
	multiboard = YtMultiboardValues.new(1)
	var dps_gained_label: String = YtUtils.text("HI9K")
	multiboard.set_key(0, dps_gained_label)


func on_create():
	item.user_int = 0


func on_drop():
	item.get_carrier().modify_property(YtModificationType.enm.MOD_DPS_ADD, -item.user_int)


func on_pickup():
	item.get_carrier().modify_property(YtModificationType.enm.MOD_DPS_ADD, item.user_int)


func on_kill(_event: YtEvent):
	if item.user_int < 4000:
		item.get_carrier().modify_property(YtModificationType.enm.MOD_DPS_ADD, 10)
		item.user_int = item.user_int + 10


func on_tower_details() -> YtMultiboardValues:
	var dps_gained_text: String = YtUtils.format_float(item.user_int, 0)
	multiboard.set_value(0, dps_gained_text)

	return multiboard
