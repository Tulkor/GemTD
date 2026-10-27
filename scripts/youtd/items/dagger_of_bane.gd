extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: in original, tower is saved in buff's user_int.
# Changed it so that tower's get_uid() is saved instead
# because we can't convert references to ints in gdscript.


var poison_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


# NOTE: dealDamage() in original script
func poison_bt_periodic(event: YtEvent):
	var b: YtBuff = event.get_buff()
	var tower: YtTower = b.get_caster()

	if tower.get_uid() == b.user_int:
		tower.do_spell_damage(b.get_buffed_unit(), tower.get_current_attack_damage_base() * 0.15, tower.get_spell_crit_damage())
	else:
		b.remove_buff()


func item_init():
#	+ 0.01 seconds is a dirty hack to make damage tick 4 times with 100% duration
	poison_bt = YtBuffType.new("poison_bt", 4.01, 0, false, self)
	poison_bt.set_buff_icon("res://resources/icons/generic_icons/poison_gas.tres")
	poison_bt.set_buff_tooltip(YtUtils.text("IF2L"))
	poison_bt.add_periodic_event(poison_bt_periodic, 1)


func on_damage(event: YtEvent):
	var P: YtBuff
	var u: YtUnit

	if event.is_main_target():
		u = event.get_target()
		P = u.get_buff_of_type(poison_bt)

		if P != null:
			poison_bt.apply(item.get_carrier(), event.get_target(), 0)
		else:
			poison_bt.apply(item.get_carrier(), event.get_target(), 0).user_int = item.get_carrier().get_uid()
