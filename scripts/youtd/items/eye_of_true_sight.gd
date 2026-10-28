extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# var true_sight_bt: YtBuffType


# func item_init():
# 	true_sight_bt = MagicalSightBuff.new("true_sight_bt", 900, self)
# 	true_sight_bt.set_buff_tooltip(YtUtils.text("SH63"))


# func load_triggers(triggers: YtBuffType):
# 	triggers.add_event_on_damage(on_damage)


# func on_damage(event: YtEvent):
# 	if event.get_target().is_invisible():
# 		event.damage = event.damage * (1.2 + 0.008 * item.get_carrier().get_level())


# func on_pickup():
# 	var carrier: YtUnit = item.get_carrier()
# 	true_sight_bt.apply_to_unit_permanent(carrier, carrier, 0)	
