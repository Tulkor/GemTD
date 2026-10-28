extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.

var conduction_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_spell_targeted(on_spell_target)


func item_init():
	conduction_bt = YtBuffType.new("conduction_bt", 0.0, 0.0, true, self)
	conduction_bt.set_buff_icon("res://resources/icons/generic_icons/rolling_energy.tres")
	conduction_bt.set_buff_tooltip(YtUtils.text("0IQV"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 0.20, 0.005)
	conduction_bt.set_buff_modifier(mod)


func on_spell_target(_event: YtEvent):
	var tower: YtTower = item.get_carrier()
	var lvl: int = tower.get_level()

	YtCombatLog.log_item_ability(item, null, "Conduct Magic")
	conduction_bt.apply_custom_timed(tower, tower, lvl, 10.0)
