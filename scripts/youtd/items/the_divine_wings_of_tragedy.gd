extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var divine_wings_bt: YtBuffType


func item_init():
	divine_wings_bt = YtBuffType.create_aura_effect_type("item230_divine_wings_bt", true, self)
	divine_wings_bt.set_buff_icon("res://resources/icons/generic_icons/angel_wings.tres")
	divine_wings_bt.set_buff_tooltip(YtUtils.text("HFBQ"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 0.15, 0.0)
	mod.add_modification(YtModificationType.enm.MOD_DAMAGE_ADD_PERC, 0.15, 0.0)
	divine_wings_bt.set_buff_modifier(mod)
