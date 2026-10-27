extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.

# NOTE: too many differences between tiers. Had to make
# separate code paths for each tier.

# NOTE: [ORIGINAL_GAME_BUG] Original script has typos. Fixed
# them.
# 
# 1. 50 dmg for Frost Nova of 2nd tier. Fixed it to 250.
# 
# 2. Used aoe damage for "Aftershork" tier 3. Fixed to
#    single target damage.


var stun_bt: YtBuffType
var slow_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func tower_init():
	stun_bt = YtCbStun.new("stun_bt", 0, 0, false, self)

	var slow_bt_mod: YtModifier = YtModifier.new()
	slow_bt_mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, 0.0, -0.001)
	slow_bt = YtBuffType.new("slow_bt", 0, 0, false, self)
	slow_bt.set_buff_icon("res://resources/icons/generic_icons/foot_trip.tres")
	slow_bt.set_buff_modifier(slow_bt_mod)
	slow_bt.set_buff_tooltip(YtUtils.text("SZF9"))


func on_attack(event: YtEvent):
	match tower.get_tier():
		1: return on_attack_1(event)
		2: return on_attack_2(event)
		3: return on_attack_3(event)
		4: return on_attack_4(event)

	return ""


func on_attack_1(event: YtEvent):
	var random_spell_id = YtGlobals.synced_rng.randi_range(1, 3)
	var c: YtCreep = event.get_target()
	var u: YtUnit
	var it: YtIterate

	if random_spell_id < 3:
		YtCombatLog.log_ability(tower, c, "Fire Blast")

		YtEffect.create_simple_at_unit("res://src/effects/firelord_death_explode.tscn", c)
		tower.do_spell_damage_aoe_unit(c, 200, 190 + tower.get_level() * 7.6, tower.calc_spell_crit_no_bonus(), 0)
	else:
		YtCombatLog.log_ability(tower, c, "Frost Nova")
		
		it = YtIterate.over_units_in_range_of_unit(tower, YtTargetType.new(YtTargetType.CREEPS), c, 250)

		while true:
			u = it.next()

			if u == null:
				break

			slow_bt.apply_custom_timed(tower, u, 100, 3)

		YtEffect.create_simple_at_unit("res://src/effects/frost_bolt_missile.tscn", c)
		tower.do_spell_damage_aoe_unit(c, 250, 125 + tower.get_level() * 5, tower.calc_spell_crit_no_bonus(), 0)
			

func on_attack_2(event: YtEvent):
	var random_spell_id = YtGlobals.synced_rng.randi_range(1, 5)
	var c: YtCreep = event.get_target()
	var u: YtUnit
	var it: YtIterate

	if random_spell_id < 3:
		YtCombatLog.log_ability(tower, c, "Fire Blast")
		
		YtEffect.create_simple_at_unit("res://src/effects/firelord_death_explode.tscn", c)
		tower.do_spell_damage_aoe_unit(c, 250, 500 + tower.get_level() * 10, tower.calc_spell_crit_no_bonus(), 0)
	elif random_spell_id < 5:
		YtCombatLog.log_ability(tower, c, "Aftershock")
		
		YtEffect.create_simple_at_unit("res://src/effects/ancient_protector_missile.tscn", c)
		stun_bt.apply_only_timed(tower, c, 0.5 + tower.get_level() * 0.01)
		tower.do_spell_damage(c, 750, tower.calc_spell_crit_no_bonus())
	else:
		YtCombatLog.log_ability(tower, c, "Frost Nova")
		
		it = YtIterate.over_units_in_range_of_unit(tower, YtTargetType.new(YtTargetType.CREEPS), c, 250)

		while true:
			u = it.next()

			if u == null:
				break

			slow_bt.apply_custom_timed(tower, u, 120, 3)

		YtEffect.create_simple_at_unit("res://src/effects/frost_bolt_missile.tscn", c)
		tower.do_spell_damage_aoe_unit(c, 250, 250 + tower.get_level() * 8, tower.calc_spell_crit_no_bonus(), 0)

func on_attack_3(event: YtEvent):
	var random_spell_id = YtGlobals.synced_rng.randi_range(1, 10)
	var c: YtCreep = event.get_target()
	var u: YtUnit
	var it: YtIterate
	var count: int

	if random_spell_id < 4:
		YtCombatLog.log_ability(tower, c, "Fire Blast")
		
		YtEffect.create_simple_at_unit("res://src/effects/firelord_death_explode.tscn", c)
		tower.do_spell_damage_aoe_unit(c, 250, 1650 + tower.get_level() * 18, tower.calc_spell_crit_no_bonus(), 0)
	elif random_spell_id < 7:
		YtCombatLog.log_ability(tower, c, "Aftershock")
		
		YtEffect.create_simple_at_unit("res://src/effects/ancient_protector_missile.tscn", c)
		stun_bt.apply_only_timed(tower, c, 0.5 + tower.get_level() * 0.01)
		tower.do_spell_damage(c, 2000, tower.calc_spell_crit_no_bonus())
	elif random_spell_id < 9:
		YtCombatLog.log_ability(tower, c, "Frost Nova")
		
		it = YtIterate.over_units_in_range_of_unit(tower, YtTargetType.new(YtTargetType.CREEPS), c, 250)

		while true:
			u = it.next()

			if u == null:
				break

			slow_bt.apply_custom_timed(tower, u, 140, 4)

		YtEffect.create_simple_at_unit("res://src/effects/frost_bolt_missile.tscn", c)
		tower.do_spell_damage_aoe_unit(c, 250, 800 + tower.get_level() * 10, tower.calc_spell_crit_no_bonus(), 0)
	else:
		YtCombatLog.log_ability(tower, c, "Lightning Burst")
		
		it = YtIterate.over_units_in_range_of_unit(tower, YtTargetType.new(YtTargetType.CREEPS), c, 900)

		while true:
			u = it.next()
			count = count + 1

			if count == 6 || u == null:
				break

			YtEffect.create_simple_at_unit("res://src/effects/monsoon_bolt.tscn", u)
			tower.do_spell_damage(u, 1650 + (tower.get_level() * 30), tower.calc_spell_crit_no_bonus())
			var lightning: YtInterpolatedSprite = YtInterpolatedSprite.create_from_unit_to_unit(YtInterpolatedSprite.LIGHTNING, tower, u)
			lightning.modulate = Color.LIGHT_BLUE
			lightning.set_lifetime(0.15)


func on_attack_4(event: YtEvent):
	var random_spell_id = YtGlobals.synced_rng.randi_range(1, 10)
	var c: YtCreep = event.get_target()
	var u: YtUnit
	var it: YtIterate
	var count: int

	if random_spell_id < 4:
# 		FireBlast
		YtCombatLog.log_ability(tower, c, "Fire Blast")
		
		if tower.user_int2 == 1:
			tower.user_int = tower.user_int + 1
		else:
			tower.user_int = 1
			tower.user_int2 = 1

		YtEffect.create_simple_at_unit("res://src/effects/firelord_death_explode.tscn", c)
		tower.do_spell_damage_aoe_unit(c, 300, (3000 + tower.get_level() * 60) * (1 + ((0.5 + tower.get_level() * 0.01) * (tower.user_int - 1))), tower.calc_spell_crit_no_bonus(), 0)
	elif random_spell_id < 7:
#		Aftershock
		YtCombatLog.log_ability(tower, c, "Aftershock")
		
		if tower.user_int2 == 2:
			tower.user_int = tower.user_int + 1
		else:
			tower.user_int = 1
			tower.user_int2 = 2

		YtEffect.create_simple_at_unit("res://src/effects/ancient_protector_missile.tscn", c)
		stun_bt.apply_only_timed(tower, c, 0.7 + tower.get_level() * 0.02)
		tower.do_spell_damage(c, 6000 * (1 + ((0.5 + tower.get_level() * 0.01) * (tower.user_int - 1))), tower.calc_spell_crit_no_bonus())
	elif random_spell_id < 9:
#		FrostNova
		YtCombatLog.log_ability(tower, c, "Frost Nova")
		
		if tower.user_int2 == 3:
			tower.user_int = tower.user_int + 1
		else:
			tower.user_int = 1
			tower.user_int2 = 3

		it = YtIterate.over_units_in_range_of_unit(tower, YtTargetType.new(YtTargetType.CREEPS), c, 300)

		while true:
			u = it.next()

			if u == null:
				break

			slow_bt.apply_custom_timed(tower, u, 150, 4)

		YtEffect.create_simple_at_unit("res://src/effects/frost_bolt_missile.tscn", c)
		YtEffect.create_simple_at_unit("res://src/effects/freezing_breath.tscn", c)
		tower.do_spell_damage_aoe_unit(c, 300, (2000 + tower.get_level() * 80) * (1 + ((0.5 + tower.get_level() * 0.01) * (tower.user_int - 1))), tower.calc_spell_crit_no_bonus(), 0)
	else:
#		Lightning Burst
		YtCombatLog.log_ability(tower, c, "Lightning Burst")
		
		if tower.user_int2 == 4:
			tower.user_int = tower.user_int + 1
		else:
			tower.user_int = 1
			tower.user_int2 = 4

		it = YtIterate.over_units_in_range_of_unit(tower, YtTargetType.new(YtTargetType.CREEPS), c, 900)

		while true:
			u = it.next()
			count = count + 1

			if count == 7 || u == null:
				break

			YtEffect.create_simple_at_unit("res://src/effects/monsoon_bolt.tscn", u)
			tower.do_spell_damage(u, (3000 + tower.get_level() * 60) * (1 + ((0.5 + tower.get_level() * 0.01) * (tower.user_int - 1))), tower.calc_spell_crit_no_bonus())
			var lightning: YtInterpolatedSprite = YtInterpolatedSprite.create_from_unit_to_unit(YtInterpolatedSprite.LIGHTNING, tower, u)
			lightning.modulate = Color.LIGHT_BLUE
			lightning.set_lifetime(0.15)


func on_create(_preceding: YtTower):
#	Stores how many consecutive times last spell was cast
	tower.user_int = 0
#	Stores which spell was last cast
	tower.user_int2 = 0
