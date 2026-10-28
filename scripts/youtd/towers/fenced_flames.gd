extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: [ORIGINAL_GAME_BUG] Fixed bug in original script
# where periodic() didn't multiply dmg_ratio_add value by
# tower level.


const EMBER_RADIUS: float = 300

var TARGET_TYPE_COMMON_TOWERS: YtTargetType = YtTargetType.new(YtTargetType.TOWERS + YtTargetType.RARITY_COMMON)
var ember_pt: YtProjectileType


func get_tier_stats() -> Dictionary:
	return {
		1: {dmg_ratio = 0.08, dmg_ratio_add = 0.0016},
		2: {dmg_ratio = 0.10, dmg_ratio_add = 0.0020},
		3: {dmg_ratio = 0.12, dmg_ratio_add = 0.0048},
		4: {dmg_ratio = 0.16, dmg_ratio_add = 0.0064},
	}


func load_triggers(triggers: YtBuffType):
	triggers.add_periodic_event(periodic, 1.0)


func tower_init():
	ember_pt = YtProjectileType.create_interpolate("res://src/projectiles/projectile_visuals/HeadhunterWEAPONSLeft.tscn", 650, self)
	ember_pt.set_event_on_interpolation_finished(ember_pt_on_hit)


func periodic(_event: YtEvent):
	var towers_in_range: YtIterate = YtIterate.over_units_in_range_of_caster(tower, TARGET_TYPE_COMMON_TOWERS, EMBER_RADIUS)

	var common_tower: YtUnit = towers_in_range.next()

	if common_tower == null:
		return

#	NOTE: need to add RANGE_CHECK_BONUS_FOR_TOWERS to
#	account for tower radius, bit of a hack to get real
#	attack range. YtIterate class only takes target radius into
#	consideration.
	var creeps_in_range: YtIterate = YtIterate.over_units_in_range_of_caster(common_tower, YtTargetType.new(YtTargetType.CREEPS), tower.get_range() + YtConstants.RANGE_CHECK_BONUS_FOR_TOWERS)

	var dmg_ratio: float = _stats.dmg_ratio + _stats.dmg_ratio_add * tower.get_level()

	while true:
		var target: YtUnit = creeps_in_range.next_random()

		if target == null:
			break

		# Need to change speed of YtProjectileType before
		# creating projectile because cannot change
		# interpolated YtProjectile's speed after creation
		var ember_speed: float = YtGlobals.synced_rng.randf_range(500, 750)
		ember_pt.set_speed(ember_speed)
		var p: YtProjectile = YtProjectile.create_bezier_interpolation_from_unit_to_unit(ember_pt, common_tower, 1, 1, common_tower, target, YtGlobals.synced_rng.randf_range(0.0, 0.3), YtGlobals.synced_rng.randf_range(-0.8, 0.8), YtGlobals.synced_rng.randf_range(0.1, 0.4), true)
		p.set_color(Color.DARK_RED)

		var damage: float = common_tower.get_current_attack_damage_with_bonus() * dmg_ratio
		var crit: float = common_tower.calc_attack_multicrit_no_bonus()
		p.user_real = damage
		p.user_real2 = crit


# NOTE: interpolateFinished() in original script
func ember_pt_on_hit(p: YtProjectile, target: YtUnit):
	if target == null:
		return
	
	var damage: float = p.user_real
	var crit: float = p.user_real2

	tower.do_custom_attack_damage(target, damage, crit, YtAttackType.enm.ELEMENTAL)
