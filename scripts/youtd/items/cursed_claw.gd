extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var cripple_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func item_init():
	cripple_bt = YtBuffType.new("cripple_bt", 5, 0, false, self)
	cripple_bt.set_buff_icon("res://resources/icons/generic_icons/foot_trip.tres")
	cripple_bt.set_buff_tooltip(YtUtils.text("ARXM"))
	var mod: YtModifier = YtModifier.new() 
	mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, -0.10, -0.004) 
	cripple_bt.set_buff_modifier(mod) 


func on_attack(event: YtEvent):
	var tower: YtTower = item.get_carrier()
	var target: YtUnit = event.get_target()
	var level: int = tower.get_level()

	cripple_bt.apply(tower, target, level)
