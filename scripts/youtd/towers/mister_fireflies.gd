extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.

# NOTE: changed script to hide attack projectile and deal 0
# damage.

# NOTE: removed update of moth element triggered by "unit
# comes in range". Not necessary because can update this in
# periodic callback.

# NOTE: [ORIGINAL_GAME_BUG] Added moth periodic damage.
# Original script is missing it.

# NOTE: removed weird code for moth spell crit. Not needed
# because moth damage is dealt via tower.


var TARGET_TYPE_FOR_RARE_BREED: YtTargetType = YtTargetType.new(YtTargetType.TOWERS + YtTargetType.ELEMENT_DARKNESS + YtTargetType.ELEMENT_FIRE + YtTargetType.ELEMENT_STORM)


# var example_bt: YtBuffType
var moth_pt: YtProjectileType
# var multiboard: YtMultiboardValues
var moth_list: Array[YtProjectile] = []
var element_for_moths: YtElement.enm = YtElement.enm.DARKNESS
var timer_to_return_to_tower: float = 0
var moth_target: YtUnit = null


const RARE_BREED_RADIUS: float = 110
const MOTH_DAMAGE_RADIUS: float = 375
const MOTH_DAMAGE_PERIOD: float = 0.5
const MANA_BURN_ADD: float = 0.08


func get_tier_stats() -> Dictionary:
	return {
		1: {moth_damage = 50, moth_damage_if_darkness = 75, moth_count = 6, mana_burn = 2, mana_burn_bonus_if_fire = 2},
		2: {moth_damage = 80, moth_damage_if_darkness = 120, moth_count = 6, mana_burn = 3, mana_burn_bonus_if_fire = 3},
		3: {moth_damage = 110, moth_damage_if_darkness = 165, moth_count = 7, mana_burn = 4, mana_burn_bonus_if_fire = 4},
	}


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)
	triggers.add_event_on_damage(on_damage)
	triggers.add_periodic_event(periodic, 1.0)


func tower_init():
	tower.hide_attack_projectiles()

	moth_pt = YtProjectileType.create_interpolate("path_to_projectile_sprite", 275, self)
	moth_pt.set_event_on_interpolation_finished(moth_pt_on_interpolation_finished)
	moth_pt.enable_periodic(moth_pt_periodic, MOTH_DAMAGE_PERIOD)


func on_create(_preceding_tower: YtTower):
	for i in range(0, _stats.moth_count):
		var moth_pos: Vector3 = Vector3(
			tower.get_x() + YtGlobals.synced_rng.randf_range(-100, 100),
			tower.get_y() + YtGlobals.synced_rng.randf_range(-100, 100),
			175,
			)
		var p: YtProjectile = YtProjectile.create_bezier_interpolation_from_unit_to_point(moth_pt, tower, 1.0, 1.0, tower, moth_pos, 0.4, 0.4, 0.4)

		moth_list.append(p)

	update_element_for_moths()


func on_destruct():
	for moth in moth_list:
		moth.remove_from_game()


# Send moths at current attack target
func on_attack(event: YtEvent):
	var target: YtUnit = event.get_target()
	moth_target = target
	timer_to_return_to_tower = 3.5


# NOTE: tower doesn't deal damage with normal attacks - only
# with moths
func on_damage(event: YtEvent):
	event.damage = 0


func periodic(_event: YtEvent):
#	Moths start to attempt returning to tower after a delay
	if timer_to_return_to_tower > 0:
		timer_to_return_to_tower -= 1
	else:
		moth_target = tower

	update_element_for_moths()


func moth_pt_on_interpolation_finished(p: YtProjectile, _hit_target: YtUnit):
	var spread: float = 280

#	Divides the difference between p and target; higher =
#	slower approach, below 0 = jump to opposite side
	var divider: float = 4

	var move_target: YtUnit
	if YtUtils.unit_is_valid(moth_target):
		move_target = moth_target
	else:
		move_target = tower

	var dx: float = move_target.get_x() - p.get_x()
	var dy: float = move_target.get_y() - p.get_y()

	var speed: float = 150

	if move_target is YtCreep:
		divider = 2

		var max_diff: float = max(dx, dy)

		if max_diff > 1200:
			spread = 150
			speed = 300
		elif max_diff > 400:
			spread = 175
			speed = 350
		else:
			spread = 200
			speed = 400
			divider = 0.85
	
	if element_for_moths == YtElement.enm.STORM:
		speed += 450
		spread = 150
		divider = 1

	p.set_speed(speed)

	var target_pos: Vector3 = Vector3(
		p.get_x() + YtGlobals.synced_rng.randf_range(-spread, spread) + YtUtils.divide_safe(dx, divider),
		p.get_y() + YtGlobals.synced_rng.randf_range(-spread, spread) + YtUtils.divide_safe(dy, divider),
		p.get_z() + YtGlobals.synced_rng.randf_range(-min(35, p.get_z() - 35), 65) - YtUtils.divide_safe(p.get_z() / 10, divider)
		)

	var angle: float = rad_to_deg(atan2(target_pos.y - p.get_y(), target_pos.x - p.get_x()))
	var angle_diff: float = angle - p.get_direction()

	if angle_diff > 180:
		angle_diff -= 360
	elif angle_diff < -180:
		angle_diff += 360

	var steep: float = 0.2
	if angle_diff > 120 || angle_diff < -120:
		steep = 1.0

	p.start_bezier_interpolation_to_point(target_pos, 0.1, YtGlobals.synced_rng.randf_range(-1, 1), steep)

	p.avert_destruction()


# NOTE: partially FireFly_Damage() in original script
func moth_pt_periodic(projectile: YtProjectile):
	var moth_pos: Vector2 = projectile.get_position_wc3_2d()
	var it: YtIterate = YtIterate.over_units_in_range_of(tower, YtTargetType.new(YtTargetType.CREEPS), moth_pos, MOTH_DAMAGE_RADIUS)

	var target: YtUnit = it.next_random()

	if target == null:
		return

	var mana_burn_amount: float = _stats.mana_burn + MANA_BURN_ADD * tower.get_level()
	if element_for_moths == YtElement.enm.FIRE:
		mana_burn_amount += _stats.mana_burn_bonus_if_fire

	var moth_damage: float
	if element_for_moths == YtElement.enm.DARKNESS:
		moth_damage = _stats.moth_damage_if_darkness
	else:
		moth_damage = _stats.moth_damage

	tower.do_spell_damage(target, moth_damage, tower.calc_spell_crit_no_bonus())
	target.subtract_mana(mana_burn_amount, false)


func update_element_for_moths():
	var it: YtIterate = YtIterate.over_units_in_range_of_caster(tower, TARGET_TYPE_FOR_RARE_BREED, RARE_BREED_RADIUS)

	var gold_cost_map: Dictionary = {}

	while true:
		var next: YtUnit = it.next()

		if next == null:
			break

		var element: YtElement.enm = next.get_element()
		var this_gold_cost: int = next.get_gold_cost()

		if !gold_cost_map.has(element):
			gold_cost_map[element] = 0

		gold_cost_map[element] += this_gold_cost

	var winning_element: YtElement.enm = YtElement.enm.DARKNESS
	var winning_sum: int = gold_cost_map.get(YtElement.enm.DARKNESS, 0)

#	NOTE: sort keys to ensure deterministic iteration order for multiplayer sync
	var sorted_element_keys: Array = gold_cost_map.keys()
	sorted_element_keys.sort()
	for element in sorted_element_keys:
		var this_sum: int = gold_cost_map[element]

		if this_sum > winning_sum:
			winning_element = element
			winning_sum = this_sum

	element_for_moths = winning_element

	var element_color: Color = YtElement.get_color(element_for_moths)

	for moth in moth_list:
		moth.set_color(element_color)
