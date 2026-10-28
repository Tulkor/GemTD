extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var speed_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_periodic_event(periodic, 40)


func item_init():
	speed_bt = YtBuffType.new("speed_bt", 0.0, 0.0, true, self)
	speed_bt.set_buff_icon("res://resources/icons/generic_icons/hammer_drop.tres")
	speed_bt.set_buff_tooltip(YtUtils.text("P7Z5"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 0.1, 0)
	speed_bt.set_buff_modifier(mod)


func on_autocast(_event: YtEvent):
	var tower: YtTower = item.get_carrier()
	var lvl: int = tower.get_level()
	var it: YtIterate
	var next: YtUnit

	if item.user_int > 0:
		it = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.TOWERS), 350)

		while true:
			next = it.next()

			if next == null:
				break

			speed_bt.apply_custom_timed(tower, next, lvl * 2, 4.0)

		item.user_int = item.user_int - 1

	item.set_charges(item.user_int)
	await YtUtils.create_manual_timer(0.1, self).timeout
	item.set_charges(item.user_int)


func on_create():
	item.set_charges(10)
#	The item will use the userInt for charges, cause charges are bugged.
	item.user_int = 10


func periodic(_event: YtEvent):
	item.user_int = item.user_int + 3

	if item.user_int >= 11:
		item.user_int = 10

	item.set_charges(item.user_int)
	await YtUtils.create_manual_timer(0.1, self).timeout
	item.set_charges(item.user_int)
