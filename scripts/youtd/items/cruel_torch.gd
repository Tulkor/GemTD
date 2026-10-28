extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var flames_bt: YtBuffType


func item_init():
	flames_bt = YtBuffType.create_aura_effect_type("flames_bt", true, self)
	flames_bt.set_buff_icon("res://resources/icons/generic_icons/mighty_force.tres")
	flames_bt.set_buff_tooltip(YtUtils.text("KT5P"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_ATK_CRIT_CHANCE, 0.035, 0.0008)
	flames_bt.set_buff_modifier(mod)
