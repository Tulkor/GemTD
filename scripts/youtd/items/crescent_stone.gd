extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var earth_and_moon_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_periodic_event(periodic, 15)


func item_init():
	earth_and_moon_bt = YtBuffType.new("earth_and_moon_bt", 5, 0, true, self)
	earth_and_moon_bt.set_buff_icon("res://resources/icons/generic_icons/polar_star.tres")
	earth_and_moon_bt.set_buff_tooltip(YtUtils.text("O4EP"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_TRIGGER_CHANCES, 0.25, 0.01)
	earth_and_moon_bt.set_buff_modifier(mod)


func periodic(_event: YtEvent):
	var tower: YtTower = item.get_carrier()
	YtCombatLog.log_item_ability(item, null, "Earth and Moon")
	earth_and_moon_bt.apply(tower, tower, tower.get_level())
