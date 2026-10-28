extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var bestial_bt: YtBuffType


func item_init():
	bestial_bt = YtBuffType.create_aura_effect_type("bestial_bt", true, self)
	bestial_bt.set_buff_icon("res://resources/icons/generic_icons/mighty_force.tres")
	bestial_bt.set_buff_tooltip(YtUtils.text("UEUU"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_DMG_TO_HUMANOID, 0.12, 0.0024)
	mod.add_modification(YtModificationType.enm.MOD_DMG_TO_ORC, 0.12, 0.0024)
	mod.add_modification(YtModificationType.enm.MOD_DPS_ADD, 100, 6)
	bestial_bt.set_buff_modifier(mod)
