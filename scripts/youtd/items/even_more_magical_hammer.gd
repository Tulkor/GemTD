extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var mark_bt: YtBuffType
var aura_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_unit_comes_in_range(on_unit_in_range, 2000, YtTargetType.new(YtTargetType.CREEPS))


# NOTE: Mark_Setup() in original script
func mark_bt_on_create(event: YtEvent):
	var buff: YtBuff = event.get_buff()

	buff.user_int = 5
	buff.user_int2 = 5
	buff.user_int3 = 5

	buff.user_real = 50
	buff.user_real2 = 50
	buff.user_real3 = 50


# NOTE: Hammer_Aura_Trig() in original script
func aura_bt_on_damaged(event: YtEvent):
	if !event.is_spell_damage():
		return

#	Has attacker the mark buff?
	var tower: YtTower = event.get_target()
	var buff: YtBuff = tower.get_buff_of_type(mark_bt)

	if buff == null:
		return

	var lvl: int = buff.get_level()

#	Attacking tower carries a hammer
#	Hammer 1
	buff.user_int = buff.user_int - 1
	if buff.user_int <= 0:
		buff.user_int = 5
		tower.add_spell_crit()

#	Hammer 2
	if lvl >= 2:
		buff.user_int2 = buff.user_int2 - 1
		if buff.user_int2 <= 0:
			buff.user_int2 = 5
			tower.add_spell_crit()
	else:
#		Only 1 hammer
		return

#	Hammer 3
	if lvl >= 3:
		buff.user_int3 = buff.user_int3 - 1
		if buff.user_int3 <= 0:
			buff.user_int3 = 5
			tower.add_spell_crit()
	else:
#		Only 2 hammer
		return

#	Hammer 4
	if lvl >= 4:
		buff.user_real = buff.user_real - 10
#		Because real are realy not accurate at all.
		if buff.user_real < 5:
			buff.user_real = 50
			tower.add_spell_crit()
	else:
#		Only 3 hammer
		return

#	Hammer 5
	if lvl >= 5:
		buff.user_real2 = buff.user_real2 - 10
#		Because real are realy not accurate at all.
		if buff.user_real2 < 5:
			buff.user_real2 = 50
			tower.add_spell_crit()
	else:
#		Only 4 hammer
		return

#	Hammer 6
	if lvl >= 6:
		buff.user_real3 = buff.user_real3 - 10
#		Because real are realy not accurate at all.
		if buff.user_real3 < 5:
			buff.user_real3 = 50
			tower.add_spell_crit()


func item_init():
	mark_bt = YtBuffType.new("mark_bt", -1, 0, true, self)
	mark_bt.set_buff_icon("res://resources/icons/generic_icons/hammer_drop.tres")
	mark_bt.add_event_on_create(mark_bt_on_create)
	mark_bt.set_hidden()

	aura_bt = YtBuffType.new("aura_bt", -1, 0, true, self)
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/hammer_drop.tres")
	aura_bt.add_event_on_damaged(aura_bt_on_damaged)
	aura_bt.set_hidden()


func on_drop():
	var tower: YtTower = item.get_carrier()
	var buff: YtBuff = tower.get_buff_of_type(mark_bt)

	if buff != null:
#		First hammer on tower
		if buff.get_level() == 1:
#			Only one hammer was on tower
			buff.remove_buff()
		else:
			buff.set_level(buff.get_level() - 1)
	else:
#		No buff, although there is still a hammer on the tower! Shit happened!
		return


func on_pickup():
	var tower: YtTower = item.get_carrier()
	var buff: YtBuff = tower.get_buff_of_type(mark_bt)

	if buff == null:
#		First hammer on tower
		mark_bt.apply(tower, tower, 1)
	else:
#		Already a hammer on the tower
		buff.set_level(buff.get_level() + 1)


func on_unit_in_range(event: YtEvent):
	var target: YtUnit = event.get_target()

	if target.get_buff_of_type(aura_bt) == null:
		aura_bt.apply(item.get_carrier(), target, 0)
