extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.

# NOTE: [ORIGINAL_GAME_DEVIATION] Renamed
# "Flag of the Alliance"=>"Flag of the Allegiance"

var motivation_bt: YtBuffType


func item_init():
	motivation_bt = YtBuffType.create_aura_effect_type("motivation_bt", true, self) 
	motivation_bt.set_buff_icon("res://resources/icons/generic_icons/mighty_force.tres")
	motivation_bt.set_buff_tooltip(YtUtils.text("7NOD"))
	var mod: YtModifier = YtModifier.new() 
	mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 0.05, 0.001) 
	motivation_bt.set_buff_modifier(mod)
