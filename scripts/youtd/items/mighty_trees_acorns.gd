extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var charitable_bt: YtBuffType


func item_init():
	charitable_bt = YtBuffType.create_aura_effect_type("charitable_bt", true, self)
	charitable_bt.set_buff_icon("res://resources/icons/generic_icons/shiny_omega.tres")
	charitable_bt.set_buff_tooltip(YtUtils.text("FCP1"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_TRIGGER_CHANCES, 0.02, 0.004)
	mod.add_modification(YtModificationType.enm.MOD_MANA_PERC, 0.02, 0.004)
	mod.add_modification(YtModificationType.enm.MOD_SPELL_DAMAGE_DEALT, 0.02, 0.004)
	charitable_bt.set_buff_modifier(mod)
