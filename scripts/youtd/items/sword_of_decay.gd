extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var rot_bt: YtBuffType


func item_init():
	rot_bt = YtBuffType.create_aura_effect_type("rot_bt", true, self)
	rot_bt.set_buff_icon("res://resources/icons/generic_icons/poison_gas.tres")
	rot_bt.set_buff_tooltip(YtUtils.text("RI8B"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_DMG_TO_NATURE, 0.12, 0.0024)
	rot_bt.set_buff_modifier(mod)
