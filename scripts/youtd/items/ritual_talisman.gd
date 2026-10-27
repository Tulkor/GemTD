extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var ritual_bt: YtBuffType


func item_init():
	ritual_bt = YtBuffType.new("ritual_bt", 10, 0, true, self)
	ritual_bt.set_buff_icon("res://resources/icons/generic_icons/moebius_trefoil.tres")
	ritual_bt.set_buff_tooltip(YtUtils.text("49QO"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_EXP_RECEIVED, 0.2, 0.008)
	mod.add_modification(YtModificationType.enm.MOD_DAMAGE_ADD_PERC, 0.1, 0.002)
	ritual_bt.set_buff_modifier(mod)
