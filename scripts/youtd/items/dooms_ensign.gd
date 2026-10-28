extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var ensign_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func item_init():
	ensign_bt = YtBuffType.new("ensign_bt", 5, 0, false, self)
	ensign_bt.set_buff_icon("res://resources/icons/generic_icons/open_wound.tres")
	ensign_bt.set_buff_tooltip(YtUtils.text("QCSJ"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_ARMOR_PERC, -0.10, -0.006)
	ensign_bt.set_buff_modifier(mod)


func on_damage(event: YtEvent):
	if event.is_main_target():
		ensign_bt.apply(item.get_carrier(), event.get_target(), item.get_carrier().get_level())
