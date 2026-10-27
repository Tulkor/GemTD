extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var mark_bt: YtBuffType


func tower_init():
	mark_bt = YtBuffType.new("mark_bt", 10.0, 0.4, true, self)
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_MULTICRIT_COUNT, 1.0, 0.0)
	mod.add_modification(YtModificationType.enm.MOD_ATK_CRIT_CHANCE, 0.075, 0.002)
	mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 0.25, 0.006)
	mark_bt.set_buff_modifier(mod)
	mark_bt.set_buff_icon("res://resources/icons/generic_icons/biceps.tres")
	mark_bt.set_buff_tooltip(YtUtils.text("FYXT"))
