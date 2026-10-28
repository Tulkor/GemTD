extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var slow_bt: YtBuffType


func item_init():
	slow_bt = YtBuffType.create_aura_effect_type("slow_bt", false, self)
	slow_bt.set_buff_icon("res://resources/icons/generic_icons/foot_trip.tres")
	slow_bt.set_buff_tooltip(YtUtils.text("BZT7"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, -0.14, 0.0)
	slow_bt.set_buff_modifier(mod)
