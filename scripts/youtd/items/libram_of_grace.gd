extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var grace_bt: YtBuffType


func item_init():
	grace_bt = YtBuffType.create_aura_effect_type("grace_bt", true, self)
	grace_bt.set_buff_icon("res://resources/icons/generic_icons/angel_wings.tres")
	grace_bt.set_buff_tooltip(YtUtils.text("I4A3"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_EXP_RECEIVED, 0.1, 0.004)
	grace_bt.set_buff_modifier(mod)
