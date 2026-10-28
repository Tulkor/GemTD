extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var dps_boost_bt: YtBuffType
var slow_bt: YtBuffType
var multiboard: YtMultiboardValues

var current_attack_target: int = -1
var current_attack_count: int = -1
var strangle_count: int = 0


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)
	triggers.add_event_on_damage(on_damage)


func tower_init():
	dps_boost_bt = YtBuffType.new("dps_boost_bt", 0, 0, true, self)
	var fisherman_dps_boost_mod: YtModifier = YtModifier.new()
	fisherman_dps_boost_mod.add_modification(YtModificationType.enm.MOD_DPS_ADD, 0.0, 0.001)
	dps_boost_bt.set_buff_modifier(fisherman_dps_boost_mod)
	dps_boost_bt.set_buff_icon("res://resources/icons/generic_icons/meat.tres")
	dps_boost_bt.set_buff_tooltip(YtUtils.text("ZRPB"))

	slow_bt = YtBuffType.new("slow_bt", 3, 0, false, self)
	var fisherman_slow_mod: YtModifier = YtModifier.new()
	fisherman_slow_mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, -0.25, -0.01)
	slow_bt.set_buff_modifier(fisherman_slow_mod)
	slow_bt.set_buff_icon("res://resources/icons/generic_icons/foot_trip.tres")
	slow_bt.add_event_on_create(slow_bt_on_create)
	slow_bt.add_event_on_expire(slow_bt_on_expire)
	slow_bt.set_buff_tooltip(YtUtils.text("AEHQ"))

	multiboard = YtMultiboardValues.new(1)
	var strangled_count_label: String = YtUtils.text("AFH7")
	multiboard.set_key(0, strangled_count_label)


func on_attack(event: YtEvent):
	var target: YtUnit = event.get_target()

	if current_attack_target != target.get_uid():
		current_attack_target = target.get_uid()
		current_attack_count = 0

	current_attack_count += 1

	var impatient_procced: bool = current_attack_count > 4 && target.get_size() < YtCreepSize.enm.BOSS

	if !impatient_procced:
		return

	var it: YtIterate = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.CREEPS), tower.get_range())

	while true:
		var next: YtUnit = it.next()

		if next == null:
			break

		if next != target && next.get_buff_of_type(slow_bt) == null:
			YtCombatLog.log_ability(tower, next, "Impatient")
			tower.issue_target_order(next)

			return

	current_attack_count = 0


func on_damage(event: YtEvent):
	var target: YtUnit = event.get_target()
	var level: int = tower.get_level()
	slow_bt.apply(tower, target, level)


func on_tower_details() -> YtMultiboardValues:
	var strangle_count_string: String = str(strangle_count)
	multiboard.set_value(0, strangle_count_string)

	return multiboard


func slow_bt_on_create(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var net_start_tick: int = YtUtils.get_current_tick()
	buff.user_int2 = net_start_tick


func slow_bt_on_expire(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var target: YtUnit = buff.get_buffed_unit()
	var lvl: int = tower.get_level()
	var movespeed_for_strangle: float = 120 + 2.4 * lvl
	var net_start_tick: int = buff.user_int2
	var current_tick: int = YtUtils.get_current_tick()
	var net_duration_ticks: int = current_tick - net_start_tick
	var net_duration: float = YtUtils.ticks_to_time(net_duration_ticks)
	var target_can_be_strangled: bool = target.get_current_movespeed() <= movespeed_for_strangle || target.is_stunned()
	var strangle_chance: float = (0.03 + 0.002 * lvl) * (net_duration / 3.0)
	var damage_for_boss: float = tower.get_current_attack_damage_with_bonus() * (4 + 0.16 * lvl)
	var strangle_procced: bool = target_can_be_strangled && tower.calc_chance(strangle_chance)

	if !strangle_procced:
		return

	if target.get_size() >= YtCreepSize.enm.BOSS || target.is_immune():
		YtCombatLog.log_ability(tower, target, "Strangle boss damage")
		tower.do_attack_damage(target, damage_for_boss, tower.calc_attack_multicrit_no_bonus())
	else:
		YtCombatLog.log_ability(tower, target, "Strangle non-boss instant kill")
		tower.kill_instantly(target)

	fresh_fish()
	YtEffect.create_simple_at_unit("res://src/effects/blood_splatter.tscn", target, YtUnit.BodyPart.ORIGIN)
	strangle_count += 1


func fresh_fish():
	var buff_level: int = int(1000 * tower.get_current_attack_damage_with_bonus() / tower.get_current_attack_speed() * (0.15 + 0.004 * tower.get_level()))
	var duration: float = 5.0 + 0.1 * tower.get_level()
	var it: YtIterate = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.TOWERS), 500)

	while true:
		var next: YtUnit = it.next()

		if next == null:
			break

		dps_boost_bt.apply_custom_timed(tower, next, buff_level, duration)
