extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var multiboard: YtMultiboardValues


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_kill(on_kill)


func item_init():
	multiboard = YtMultiboardValues.new(1)
	var item_quality_label: String = YtUtils.text("ZF07")
	multiboard.set_key(0, item_quality_label)


func on_create():
	item.user_real = 0.00


func on_drop():
	item.get_carrier().modify_property(YtModificationType.enm.MOD_ITEM_QUALITY_ON_KILL, -item.user_real)


func on_pickup():
	item.get_carrier().modify_property(YtModificationType.enm.MOD_ITEM_QUALITY_ON_KILL, item.user_real)


func on_kill(_event: YtEvent):
	item.get_carrier().modify_property(YtModificationType.enm.MOD_ITEM_QUALITY_ON_KILL, -item.user_real)
	item.user_real = item.user_real + 0.0015
	item.get_carrier().modify_property(YtModificationType.enm.MOD_ITEM_QUALITY_ON_KILL, item.user_real)


func on_tower_details() -> YtMultiboardValues:
	multiboard.set_value(0, YtUtils.format_percent(item.user_real, 2))
	return multiboard
