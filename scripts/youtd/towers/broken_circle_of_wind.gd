extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var wind_bt: YtBuffType

func get_tier_stats() -> Dictionary:
	return {
		1: {catch_chance = 0.20, catch_chance_add = 0.003, cyclone_duration = 0.5, cyclone_damage = 20, cyclone_damage_add = 2},
		2: {catch_chance = 0.22, catch_chance_add = 0.004, cyclone_duration = 0.6, cyclone_damage = 68, cyclone_damage_add = 7},
		3: {catch_chance = 0.24, catch_chance_add = 0.005, cyclone_duration = 0.7, cyclone_damage = 196, cyclone_damage_add = 20},
		4: {catch_chance = 0.26, catch_chance_add = 0.006, cyclone_duration = 0.8, cyclone_damage = 600, cyclone_damage_add = 60},
		5: {catch_chance = 0.28, catch_chance_add = 0.007, cyclone_duration = 1.0, cyclone_damage = 1120, cyclone_damage_add = 112},
	}


func load_triggers(triggers_buff_type: YtBuffType):
	triggers_buff_type.add_event_on_attack(on_attack)


func tower_init():
	wind_bt = YtCbStun.new("wind_bt", 1.0, 0, false, self)
	wind_bt.set_buff_icon("res://resources/icons/generic_icons/rolling_energy.tres")
	wind_bt.add_event_on_create(wind_bt_on_create)
	wind_bt.add_periodic_event(wind_bt_periodic, 0.1)
	wind_bt.add_event_on_cleanup(wind_bt_on_cleanup)


func on_attack(event: YtEvent):
	var target: YtUnit = event.get_target()
	var damage: float = _stats.cyclone_damage + _stats.cyclone_damage_add * tower.get_level()
	var b: YtBuff

	if (target.get_size() == YtCreepSize.enm.MASS || target.get_size() == YtCreepSize.enm.NORMAL || target.get_size() == YtCreepSize.enm.CHAMPION):
		if (tower.calc_chance(_stats.catch_chance + (_stats.catch_chance_add * tower.get_level()))):
			YtCombatLog.log_ability(tower, target, "Wind of Death")

			b = target.get_buff_of_type(wind_bt)
			
			if b != null:
				damage = max(b.user_real3, damage)

			b = wind_bt.apply_custom_timed(tower, target, tower.get_level(), _stats.cyclone_duration)

			if b != null:
				b.user_real3 = damage


# NOTE: cyclone_creep_up() in original script
func wind_bt_on_create(event: YtEvent):
	var b: YtBuff = event.get_buff()

	var c: YtUnit = b.get_buffed_unit()
#	(start) cyclone animation
	b.user_int = YtEffect.create_simple_at_unit_attached("res://src/effects/cyclone_target.tscn", c)
	YtEffect.set_auto_destroy_enabled(b.user_int, false)
	YtEffect.set_z_index(b.user_int, -1)
#   move creep up
	c.adjust_height(300, 1000)


# NOTE: cyclone_creep_turn() in original script
func wind_bt_periodic(event: YtEvent):
	var b: YtBuff = event.get_buff()

	var real_unit: YtUnit = b.get_buffed_unit()
	real_unit.set_unit_facing(real_unit.get_unit_facing() + 150.0)
	real_unit = null


# NOTE: cyclone_creep_down() in original script
func wind_bt_on_cleanup(event: YtEvent):
	var b: YtBuff = event.get_buff()

	var t: YtUnit = b.get_caster()
	var c: YtUnit = b.get_buffed_unit()
	var ratio: float = 1

	YtCombatLog.log_ability(t, c, "Wind of Death End")

#	set units back (down)
	c.adjust_height(-300, 2500)
#	remove the cyclone
	YtEffect.destroy_effect(b.user_int)
# 	effects
	YtSFX.sfx_at_unit(YtSfxPaths.CLOUD_POOF, c)
	var creep_pos: Vector2 = c.get_position_wc3_2d()
	var thunder_clap_effect: int = YtEffect.create_simple("res://src/effects/thunder_clap.tscn", creep_pos)
	YtEffect.set_z_index(thunder_clap_effect, YtEffect.Z_INDEX_BELOW_CREEPS)
	YtEffect.create_simple("res://src/effects/monsoon_bolt.tscn", creep_pos)
#   do damage
	if c.get_size() == YtCreepSize.enm.CHAMPION:
		ratio = 1.25

	t.do_attack_damage_aoe_unit(c, ratio * 300.0, b.user_real3, t.calc_attack_multicrit(0, 0, 0), 0.0)
