extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: [ORIGINAL_GAME_BUG] Fixed bug where slow debuff
# wasn't attached to aura. This caused the item to not slow
# the creeps.


var fright_bt: YtBuffType


func item_init():
	fright_bt = YtBuffType.create_aura_effect_type("fright_bt", true, self)
	fright_bt.set_buff_icon("res://resources/icons/generic_icons/ghost.tres")
	fright_bt.set_buff_tooltip(YtUtils.text("ND86"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, -0.10, -0.0020)
	mod.add_modification(YtModificationType.enm.MOD_ARMOR, -4.00, -0.2)
	fright_bt.set_buff_modifier(mod)
