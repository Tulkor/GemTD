extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var strong_wind_bt: YtBuffType
var multiboard: YtMultiboardValues
var storm_power: int = 0


const AURA_RANGE: int = 900


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func tower_init():
	strong_wind_bt = YtBuffType.create_aura_effect_type("strong_wind_bt", false, self)
	strong_wind_bt.set_buff_icon("res://resources/icons/generic_icons/energy_breath.tres")
	strong_wind_bt.add_event_on_create(strong_wind_bt_on_create)
	strong_wind_bt.add_periodic_event(strong_wind_bt_periodic, 1.0)
	strong_wind_bt.add_event_on_cleanup(strong_wind_bt_on_cleanup)
	strong_wind_bt.set_buff_tooltip(YtUtils.text("M1X0"))

	multiboard = YtMultiboardValues.new(1)
	var storm_power_label: String = YtUtils.text("KPSU")
	multiboard.set_key(0, storm_power_label)



func on_attack(event: YtEvent):
	var target: YtUnit = event.get_target()
	var lvl: int = tower.get_level()
	var x: float = target.get_x()
	var y: float = target.get_y()
	var bonus_spell_crit: float = 0.0
	var air_bonus: float = 1.0

	var chaining_storm_chance: float = 0.25 + 0.0125 * lvl + 0.0002 * storm_power

	if !tower.calc_chance(chaining_storm_chance):
		return

	if tower.get_mana() < 100:
		return

	tower.subtract_mana(100, false)

#	remove Mana
#	First Iteration
#	for damage -> count creeps (save in: numCreeps)

	YtCombatLog.log_ability(tower, target, "Chaining Storm")

	var it_for_count: YtIterate = YtIterate.over_units_in_range_of_unit(tower, YtTargetType.new(YtTargetType.CREEPS), target, 350)
	var creep_count: int = it_for_count.count()

#	do effects
	YtEffect.create_simple("res://src/effects/thunder_clap.tscn", Vector2(x, y))
	YtEffect.create_simple("res://src/effects/cyclone_target.tscn", Vector2(x, y))
	var effect3: int = YtEffect.create_simple("res://src/effects/voodoo_aura.tscn", Vector2(x, y))
	YtEffect.set_z_index(effect3, YtEffect.Z_INDEX_BELOW_CREEPS)
	YtEffect.set_lifetime(effect3, 1.0)

# 	Adjust ratios against air
	if target.get_size() == YtCreepSize.enm.AIR:
		bonus_spell_crit = 0.25
		air_bonus = 2.0

	var damage: float = creep_count * air_bonus * (200 + 65 * lvl)
	tower.do_spell_damage_aoe_unit(target, 350, damage, tower.calc_spell_crit_no_bonus() + bonus_spell_crit, 0)

#	weaken creeps (weakening is divided by the number of creeps hit)
	var it: YtIterate = YtIterate.over_units_in_range_of_unit(tower, YtTargetType.new(YtTargetType.CREEPS), target, 350)
	var mod: float = (0.02 * 0.0012 * lvl) * creep_count
	
	while true:
		var next: YtUnit = it.next()

		if next == null:
			break

		next.modify_property(YtModificationType.enm.MOD_DMG_FROM_STORM, mod)
		next.modify_property(YtModificationType.enm.MOD_DMG_FROM_ICE, mod)
		next.modify_property(YtModificationType.enm.MOD_DMG_FROM_ASTRAL, mod)


func on_tower_details() -> YtMultiboardValues:
	multiboard.set_value(0, str(storm_power))

	return multiboard


# NOTE: "strongWindOnCreate()" in original script
func strong_wind_bt_on_create(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	buff.user_int = 0 # will be used to store buff level
	buff.user_int2 = 0 # counts number of stacks
	buff.user_real = 0.0 # records movespeed stolen (in case aura has levelled)
	buff.user_real2 = 0.03 # stores slow factor, so that we don't need to recalculate it every second


# NOTE: "strongWindPeriodic()" in original script
func strong_wind_bt_periodic(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var caster: YtTower = buff.get_caster()
	var creep: YtUnit = buff.get_buffed_unit()
	var buff_level: int = buff.get_level()

#	Check if aura level hasn't changed
	if buff_level != buff.user_int:
		buff.user_int = buff_level

#		Give creep back its old movespeed and calculate new slow factor
		buff.user_real2 = 0.03 + 0.0008 * buff_level

		if creep.get_size() == YtCreepSize.enm.AIR:
			buff.user_real2 *= 2

#		Adjust movespeed accordingly
		creep.modify_property(YtModificationType.enm.MOD_MOVESPEED, buff.user_real - buff.user_real2 * buff.user_int2)
		buff.user_real = buff.user_real2 * buff.user_int2

#	Apply slow
	if buff.user_int2 < 15:	# Max 15 stacks
		buff.user_int2 += 1
		creep.modify_property(YtModificationType.enm.MOD_MOVESPEED, -buff.user_real2)
		buff.user_real = buff.user_real + buff.user_real2

	buff.set_displayed_stacks(buff.user_int2)

#	Deal damage
	var damage_multiplier: float = 1.0 + 0.05 * buff_level + 0.0005 * storm_power
	var damage: float = buff.user_real * 10 * caster.get_current_attack_damage_with_bonus() * damage_multiplier
	caster.do_attack_damage(creep, damage, caster.calc_attack_multicrit_no_bonus())


# NOTE: "strongWindOnCleanup()" in original script
func strong_wind_bt_on_cleanup(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var caster: YtTower = buff.get_caster()
	var creep: YtUnit = buff.get_buffed_unit()

	if creep.get_health() > 0:
#		Give creep its movespeed back
		creep.modify_property(YtModificationType.enm.MOD_MOVESPEED, buff.user_real)
	else:
#		creep died under the effect? Increse storm power!
		storm_power += 1
#		+ mana
		caster.add_mana(35)
