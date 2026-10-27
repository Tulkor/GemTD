extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: changed how storm is enabled/disabled. In original
# script it's done using PeriodicEvent. In this script it's
# done using "storm_is_enabled" flag.

# NOTE: [ORIGINAL_GAME_BUG] original script has a bug where
# it defines special values for challenge sizes in
# storm_mana_reduction_values map but fails to use them
# because it uses creep.get_size() which returns BOSS
# instead of CHALLENGE_BOSS. Fixed this bug by calling
# creep.get_size_including_challenge_sizes().


var aura_bt: YtBuffType
var storm_bt: YtBuffType
var missile_pt: YtProjectileType
var multiboard: YtMultiboardValues

var storm_is_enabled: bool = false
var threshold_for_cloudy_thunderstorm_autocast: float = 1.0
var storm_effect: int = 0
var storm_timeout_counter: int = 0

const AURA_RANGE: int = 1000

const storm_mana_reduction_values: Dictionary = {
	YtCreepSize.enm.MASS: 5,
	YtCreepSize.enm.NORMAL: 10,
	YtCreepSize.enm.AIR: 20,
	YtCreepSize.enm.CHAMPION: 20,
	YtCreepSize.enm.CHALLENGE_MASS: 13,
	YtCreepSize.enm.BOSS: 20,
	YtCreepSize.enm.CHALLENGE_BOSS: 130,
}


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_unit_comes_in_range(on_unit_in_range, 1000, YtTargetType.new(YtTargetType.CREEPS))
	triggers.add_periodic_event(periodic, 0.4)


func tower_init():
	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", false, self)
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/semi_closed_eye.tres")
	aura_bt.add_event_on_damaged(aura_bt_on_damaged)
	aura_bt.set_buff_tooltip(YtUtils.text("JTSQ"))

	storm_bt = YtBuffType.new("storm_bt", -1.0, 0.0, false, self)
	storm_bt.add_event_on_damaged(storm_bt_on_damaged)
	storm_bt.set_buff_tooltip(YtUtils.text("RO3D"))

	missile_pt = YtProjectileType.create_ranged("path_to_projectile_sprite", 1000 + 100, 500, self)
	missile_pt.enable_homing(missile_pt_on_hit, 0.0)

	multiboard = YtMultiboardValues.new(1)
	var mana_required_label: String = YtUtils.text("NL9R")
	multiboard.set_key(0, mana_required_label)


func on_autocast_cloud_thunderstorm(_event: YtEvent):
	if !storm_is_enabled:
		enable_storm()


func on_autocast_adjust_threshold(_event: YtEvent):
	threshold_for_cloudy_thunderstorm_autocast += 0.1
	if threshold_for_cloudy_thunderstorm_autocast > 1.0:
		threshold_for_cloudy_thunderstorm_autocast = 0.0

	var floating_text: String = YtUtils.format_percent(threshold_for_cloudy_thunderstorm_autocast, 0)
	tower.get_player().display_small_floating_text(floating_text, tower, Color8(155, 155, 255), 40.0)


func on_tower_details() -> YtMultiboardValues:
	var mana_required: String = YtUtils.format_percent(threshold_for_cloudy_thunderstorm_autocast, 0)
	multiboard.set_value(0, mana_required)

	return multiboard


func on_destruct():
	if storm_effect != 0:
		YtEffect.destroy_effect(storm_effect)


func on_unit_in_range(event: YtEvent):
	var target: YtUnit = event.get_target()

	if !storm_is_enabled && !target.is_immune():
		var threshold_reached: bool = tower.get_mana_ratio() > threshold_for_cloudy_thunderstorm_autocast

		if threshold_reached:
			enable_storm()


func periodic(_event: YtEvent):
	var mana: float = tower.get_mana()

#	The next strike will be realeased, if
#	a) The storm is enabled AND
#	b) The tower has still some mana AND
#	c) No timeout is reached
	if storm_is_enabled && mana > 1000 && storm_timeout_counter < 10:
#		Release next strike
		var it: YtIterate = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.CREEPS), 1000)
		var target: YtUnit = it.next_random()

		if target != null:
			storm_timeout_counter = 0
			storm_bt.apply(tower, target, 1)
			var damage: float = tower.get_mana() * (0.5 + 0.02 * tower.get_level())
			tower.do_spell_damage(target, damage, tower.calc_spell_crit_no_bonus())
			YtEffect.create_simple_at_unit("res://src/effects/monsoon_bolt.tscn", target)
		else:
			storm_timeout_counter += 1
	else:
		storm_is_enabled = false

		if storm_effect != 0:
			YtEffect.destroy_effect(storm_effect)
			storm_effect = 0

		storm_timeout_counter = 0


# --- Storm YtBuff Handling ---
func storm_bt_on_damaged(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var caster: YtTower = buff.get_caster()
	var target: YtCreep = buff.get_buffed_unit()
#	Calculate how much damage is really dealt
	var target_health: float = target.get_health()
	var dmg_taken: float = min(event.damage, target_health)
	var target_size: YtCreepSize.enm = target.get_size_including_challenge_sizes()
	var mana_loss: float = dmg_taken * 0.1 * storm_mana_reduction_values[target_size] * YtUtils.divide_safe(dmg_taken, target_health)

#	Remove mana from the tower according to the damage taken
#	and the size of the creep
	caster.subtract_mana(mana_loss, true)
	buff.remove_buff()


func enable_storm():
	if storm_is_enabled:
		return

	storm_is_enabled = true
	storm_effect = YtEffect.create_animated("res://src/effects/cloud_of_fog_cycle.tscn", Vector3(tower.get_x(), tower.get_y(), tower.get_z() + YtConstants.TILE_SIZE_WC3), 0.0)
	YtEffect.set_auto_destroy_enabled(storm_effect, false)


# --- YtAura YtBuff + YtProjectile Handling ---
# If a creep with the auras buff is killed, a projectile spawns
# Reaction of a natac_obsorption_AuraBuffType on Damage
func aura_bt_on_damaged(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var target: YtUnit = buff.get_buffed_unit()
	var caster: YtUnit = buff.get_caster()
	var damage: float = event.damage
	var life: float = target.get_health()

	var target_will_die: bool = damage > life
	var target_is_affected_by_storm: bool = target.get_buff_of_type(storm_bt) != null

	if target_will_die && !target_is_affected_by_storm:
		var mana_ball: YtProjectile = YtProjectile.create_from_unit_to_unit(missile_pt, caster, 0.0, 0.0, target, caster, true, false, false)
		var redundant_damage: float = damage - life
		mana_ball.user_real = redundant_damage


func missile_pt_on_hit(projectile: YtProjectile, target: YtUnit):
	if target == null || !YtUtils.unit_is_valid(target):
		return

	var max_mana: float = target.get_overall_mana()
	var current_mana: float = target.get_mana()
	var redundant_damage: float = projectile.user_real
	var granted_mana: float = redundant_damage * (1.0 + 0.05 * target.get_level())

	if granted_mana > 0:
		target.add_mana(granted_mana)

	var actual_granted_mana: float = min(max_mana - current_mana, granted_mana)
	var floating_text: String = "+%s" % str(int(actual_granted_mana))
	target.get_player().display_small_floating_text(floating_text, target, Color8(0, 0, 255), 40)

	var mana_is_full: bool = current_mana + granted_mana >= max_mana

	if !storm_is_enabled && mana_is_full:
		enable_storm()
