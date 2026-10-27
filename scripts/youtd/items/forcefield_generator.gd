extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var forcefield_bt: YtBuffType


func item_init():
	forcefield_bt = YtBuffType.create_aura_effect_type("forcefield_bt", true, self)
	forcefield_bt.set_buff_icon("res://resources/icons/generic_icons/rss.tres")
	forcefield_bt.set_buff_tooltip(YtUtils.text("X440"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_DEBUFF_DURATION, -0.15, -0.01)
	forcefield_bt.set_buff_modifier(mod)
