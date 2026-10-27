extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var magnetic_bt: YtBuffType


func item_init():
	magnetic_bt = YtBuffType.create_aura_effect_type("magnetic_bt", true, self)
	magnetic_bt.set_buff_icon("res://resources/icons/generic_icons/rss.tres")
	magnetic_bt.set_buff_tooltip(YtUtils.text("C14B"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_DEBUFF_DURATION, -0.15, 0.0)
	mod.add_modification(YtModificationType.enm.MOD_BUFF_DURATION, 0.1, 0.0)
	magnetic_bt.set_buff_modifier(mod)
	