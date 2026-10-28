extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.

# NOTE: [ORIGINAL_GAME_DEVIATION] Renamed
# "Warsong Double Bass"=>"War Drum"


var drum_bt: YtBuffType


func item_init():
	drum_bt = YtBuffType.create_aura_effect_type("drum_bt", true, self)
	drum_bt.set_buff_icon("res://resources/icons/generic_icons/rss.tres")
	drum_bt.set_buff_tooltip(YtUtils.text("LBDS"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 0.075, 0.001)
	drum_bt.set_buff_modifier(mod)
