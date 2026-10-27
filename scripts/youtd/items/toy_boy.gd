extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var playtime_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_periodic_event(periodic, 10)


func item_init():
	playtime_bt = YtBuffType.new("playtime_bt", 2.0, 0, false, self)
	playtime_bt.set_buff_icon("res://resources/icons/generic_icons/pokecog.tres")
	playtime_bt.set_buff_tooltip(YtUtils.text("QYT7"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, -0.5, 0.0)
	playtime_bt.set_buff_modifier(mod)


func periodic(_event: YtEvent):
	YtCombatLog.log_item_ability(item, null, "Play with me!")
	playtime_bt.apply(item.get_carrier(), item.get_carrier(), 1)
