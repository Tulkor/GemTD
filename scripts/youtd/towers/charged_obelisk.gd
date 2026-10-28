extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var stun_bt: YtBuffType
var charge_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func tower_init():
	stun_bt = YtCbStun.new("charged_obelisk_stun", 0, 0, false, self)

	charge_bt = YtBuffType.new("charge_bt", 10, 0, true, self)
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 0.25, 0.001)
	charge_bt.set_buff_modifier(mod)
	charge_bt.set_buff_icon("res://resources/icons/generic_icons/electric.tres")
	charge_bt.set_buff_tooltip(YtUtils.text("NJH8"))
	charge_bt.add_periodic_event(charge_bt_periodic, 1.0)


func on_attack(_event: YtEvent):
	var lvl: int = tower.get_level()
	var it: YtIterate = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.CREEPS), 1000)
	var random_creep: YtUnit = it.next_random()

	if random_creep == null:
		return

	tower.do_spell_damage(random_creep, 1000 + 40 * lvl, tower.calc_spell_crit(0.20 + 0.004 * lvl, 0))

	if random_creep.get_size() < YtCreepSize.enm.BOSS:
		stun_bt.apply_only_timed(tower, random_creep, 0.2)

	YtEffect.create_simple_at_unit("res://src/effects/monsoon_bolt.tscn", random_creep)


func on_autocast(event: YtEvent):
	charge_bt.apply(tower, event.get_target(), tower.get_level() * 6)


func charge_bt_periodic(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var caster: YtTower = buff.get_caster()
	var target: YtUnit = buff.get_buffed_unit()
	var new_level: int = buff.get_level() + 50 + caster.get_level()
	var duration: float = buff.get_remaining_duration()

	buff = charge_bt.apply_custom_timed(caster, target, new_level, duration)
	buff.set_remaining_duration(duration)
