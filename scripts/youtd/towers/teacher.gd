extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var multiboard: YtMultiboardValues
var green_pt: YtProjectileType
var blue_pt: YtProjectileType
var red_pt: YtProjectileType


func get_tier_stats() -> Dictionary:
	return {
		1: {exp_teach = 1.0},
		2: {exp_teach = 1.3},
		3: {exp_teach = 1.5},
		4: {exp_teach = 1.8},
		5: {exp_teach = 2.0},
		6: {exp_teach = 2.2},
	}


func hit(p: YtProjectile, result: YtUnit):
	if result == null:
		return

	var t: YtTower = p.get_caster()

	if result.get_uid() == p.user_int:
		result.add_exp(p.user_real)

		if p.user_int2 == t.get_uid():
			t.user_real2 = t.user_real2 + p.user_real * result.get_prop_exp_received()


func teacher_attack(xp: float):
	var in_range: YtIterate
	var result: YtUnit
	var pt: YtProjectileType
	var p: YtProjectile
	var i: int

	if tower.calc_chance(0.10 + 0.006 * tower.get_level()):
		in_range = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.TOWERS), 600)

		result = in_range.next_random()

		if result == tower:
			result = in_range.next_random()

		if result != null:
			i = YtGlobals.synced_rng.randi_range(1, 3)

			if i == 1:
				pt = green_pt
			elif i == 2:
				pt = red_pt
			elif i == 3:
				pt = blue_pt

			YtCombatLog.log_ability(tower, result, "Knowledge")

			p = YtProjectile.create_from_unit_to_unit(pt, tower, 1.0, 1.0, tower, result, true, false, true)
			p.set_projectile_scale(0.7)
			p.user_real = xp
			p.user_int = result.get_uid()
			p.user_int2 = tower.get_uid()


func load_triggers(triggers_buff_type: YtBuffType):
	triggers_buff_type.add_event_on_attack(on_attack)


func tower_init():
	multiboard = YtMultiboardValues.new(1)
	var xp_granted_label: String = YtUtils.text("WXGT")
	multiboard.set_key(0, xp_granted_label)

	green_pt = YtProjectileType.create("path_to_projectile_sprite", 20.0, 450.00, self)
	green_pt.disable_explode_on_hit()
	green_pt.enable_homing(hit, 0)
	blue_pt = YtProjectileType.create("path_to_projectile_sprite", 20.0, 450.00, self)
	blue_pt.disable_explode_on_hit()
	blue_pt.enable_homing(hit, 0)
	red_pt = YtProjectileType.create("path_to_projectile_sprite", 20.0, 450.00, self)
	red_pt.disable_explode_on_hit()
	red_pt.enable_homing(hit, 0)


func on_attack(_event: YtEvent):
	teacher_attack(_stats.exp_teach)
	tower.set_animation_by_index(tower, 3)


func on_create(preceding_tower: YtTower):
	var preceding: YtTower = preceding_tower

	if preceding != null && preceding.get_family() == tower.get_family():
		tower.user_real2 = preceding.user_real2
	else:
		tower.user_real2 = 0


func on_tower_details() -> YtMultiboardValues:
	multiboard.set_value(0, YtUtils.format_float(tower.user_real2, 1))
	return multiboard
