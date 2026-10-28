extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: The original script uses time_level_add value to
# change duration of entangle based on tower tier. Don't
# need to do this in youtd2, can directly define different
# durations.


var entangle_bt: YtBuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {entangle_duration = 1.50, base_entangle_dps = 120},
		2: {entangle_duration = 2.25, base_entangle_dps = 660},
		3: {entangle_duration = 3.00, base_entangle_dps = 1800},
		4: {entangle_duration = 3.75, base_entangle_dps = 4300},
	}


func load_triggers(triggers_buff_type: YtBuffType):
	triggers_buff_type.add_event_on_damage(on_damage)


func tower_init():
	entangle_bt = YtCbStun.new("entangle_bt", _stats.entangle_duration, 0.75, false, self)
	entangle_bt.set_buff_icon("res://resources/icons/generic_icons/atomic_slashes.tres")
	entangle_bt.add_periodic_event(entangle_bt_damage, 1.0)


func on_create(_preceding_tower: YtTower):
	#	base entangle dps
	tower.user_int = _stats.base_entangle_dps


func on_damage(event: YtEvent):
	if !tower.calc_chance(0.125 + tower.get_level() * 0.002):
		return

	var target: YtCreep = event.get_target()

	if target.get_size() < YtCreepSize.enm.BOSS && target.get_size() != YtCreepSize.enm.AIR:
		YtCombatLog.log_ability(tower, target, "Entangle")
		
		entangle_bt.apply(tower, target, 0)

#		NOTE: not sure what reorder() does. YtTower script
#		works correctly without this.
#		target.reorder()


func entangle_bt_damage(event: YtEvent):
	var buff: YtBuff = event.get_buff()

	var t = buff.get_caster()
	var c: YtCreep = buff.get_buffed_unit()
	t.do_spell_damage(c, t.user_int + t.user_int * t.get_level() / 20, t.calc_spell_crit_no_bonus())
