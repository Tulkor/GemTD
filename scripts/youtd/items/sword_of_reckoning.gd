extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var holy_wrath_bt: YtBuffType


func item_init():
	holy_wrath_bt = YtBuffType.create_aura_effect_type("holy_wrath_bt", true, self)
	holy_wrath_bt.set_buff_icon("res://resources/icons/generic_icons/mighty_force.tres")
	holy_wrath_bt.set_buff_tooltip(YtUtils.text("8CD3"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_DMG_TO_UNDEAD, 0.12, 0.0024)
	holy_wrath_bt.set_buff_modifier(mod)
