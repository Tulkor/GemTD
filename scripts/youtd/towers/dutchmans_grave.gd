extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var panic_bt: YtBuffType
var dutchman_pt: YtProjectileType
var cannonball_pt: YtProjectileType
var soul_pt: YtProjectileType
var soulstorm_pt: YtProjectileType
var multiboard: YtMultiboardValues
var soul_count: int = 0
var soulstorm_is_active: bool = false
var timer_soulstorm: float = 0.0
var timer_cannonball: float = 0.0
var timer_soul: float = 0.0
var timer_reorder: float = 0.0
var dutchman: YtProjectile
var current_target: YtUnit = null


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)
	triggers.add_event_on_damage(on_damage)
	triggers.add_event_on_kill(on_kill)


func tower_init():
	tower.hide_attack_projectiles()
	
	dutchman_pt = YtProjectileType.create("path_to_projectile_sprite", 999999, 550, self)
	dutchman_pt.enable_periodic(dutchman_pt_periodic, 0.1)
	dutchman_pt.enable_homing(dutchman_pt_on_hit, 4.0)

	cannonball_pt = YtProjectileType.create_interpolate("path_to_projectile_sprite", 900, self)
	cannonball_pt.set_event_on_interpolation_finished(cannonball_pt_on_hit)

	soul_pt = YtProjectileType.create("path_to_projectile_sprite", 6, 300, self)
	soul_pt.enable_homing(soul_pt_on_hit, 4.0)
	soul_pt.set_start_rotation(6.0)

	soulstorm_pt = YtProjectileType.create("path_to_projectile_sprite", 6, 300, self)
	soulstorm_pt.set_acceleration(10)
	soulstorm_pt.enable_collision(soulstorm_pt_on_collision, 100, YtTargetType.new(YtTargetType.CREEPS), false)

	panic_bt = YtBuffType.new("panic_bt", 5, 0, false, self)
	var panic_bt_mod: YtModifier = YtModifier.new()
	panic_bt_mod.add_modification(YtModificationType.enm.MOD_ARMOR, -25.0, -1.0)
	panic_bt_mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, 0.20, -0.002)
	panic_bt.set_buff_modifier(panic_bt_mod)
	panic_bt.set_buff_icon("res://resources/icons/generic_icons/animal_skull.tres")
	panic_bt.set_buff_tooltip(YtUtils.text("EC2N"))

	multiboard = YtMultiboardValues.new(1)
	var soul_count_label: String = YtUtils.text("X8AI")
	multiboard.set_key(0, soul_count_label)


func on_create(_preceding: YtTower):
	dutchman = YtProjectile.create_from_unit_to_unit(dutchman_pt, tower, 1.0, tower.calc_spell_crit_no_bonus(), tower, tower, true, true, false)
	dutchman.set_color(Color8(100, 100, 100, 180))
	dutchman.set_projectile_scale(1.0)


func on_destruct():
	dutchman.remove_from_game()


func on_attack(event: YtEvent):
	var target: YtUnit = event.get_target()
	dutchman.set_homing_target(target)
	current_target = target


# NOTE: set damage to 0 because actual damage is dealt via
# cannonball_pt_on_hit()
func on_damage(event: YtEvent):
	event.damage = 0


func on_kill(event: YtEvent):
	var target: YtUnit = event.get_target()
	var lvl: int = tower.get_level()
	var it: YtIterate = YtIterate.over_units_in_range_of_unit(tower, YtTargetType.new(YtTargetType.CREEPS), target, 300)

	soul_count += 1

	YtEffect.create_simple_at_unit("res://src/effects/spell_aiso.tscn", target)

	while true:
		var next: YtUnit = it.next()

		if next == null:
			return

		panic_bt.apply(tower, next, lvl)


func on_autocast(_event: YtEvent):
	soulstorm_is_active = true


func on_tower_details() -> YtMultiboardValues:
	multiboard.set_value(0, str(soul_count))

	return multiboard


# NOTEL "Periodic()" in original script
func dutchman_pt_periodic(_p: YtProjectile):
	if current_target == null || !YtUtils.unit_is_valid(current_target):
		current_target = tower
		dutchman.set_homing_target(tower)

	timer_cannonball -= 0.1
	if timer_cannonball <= 0.0:
		timer_cannonball += tower.get_current_attack_speed()
		shoot_cannonball()

	timer_soul -= 0.1
	if timer_soul <= 0.0:
		timer_soul = 5.0
		shoot_soul()

	timer_reorder -= 0.1
	if timer_reorder <= 0.0:
		timer_reorder = 2.0
		dutchman.set_homing_target(current_target)

	if soulstorm_is_active:
		timer_soulstorm -= 0.1

		if timer_soulstorm <= 0.0:
			timer_soulstorm = 0.3
			do_soulstorm()


# NOTEL "Hit()" in original script
func dutchman_pt_on_hit(p: YtProjectile, _target: YtUnit):
	p.avert_destruction()


# NOTEL "NAttackHit()" in original script
func cannonball_pt_on_hit(_p: YtProjectile, target: YtUnit):
	if target == null:
		return

	var damage: float = tower.get_current_attack_damage_with_bonus()
	tower.do_attack_damage_aoe_unit(target, 250, damage, tower.calc_attack_multicrit_no_bonus(), 0)


# NOTEL "SoulHit()" in original script
func soulstorm_pt_on_collision(p: YtProjectile, target: YtUnit):
	if target == null:
		return

	YtEffect.create_simple_at_unit("res://src/effects/death_coil.tscn", target)

	var damage: float = p.user_real
	p.do_spell_damage(target, damage)
	p.user_real *= 0.5


# NOTE: "Storm()" in original script
func do_soulstorm():
	var shoot_pos: Vector3 = dutchman.get_position_wc3()

	if soul_count >= 2:
		soul_count -= 2

		var p1: YtProjectile = YtProjectile.create(soulstorm_pt, tower, 1.0, tower.calc_spell_crit_no_bonus(), shoot_pos, 0.0)
		p1.user_real = 14000.0
		var p2: YtProjectile = YtProjectile.create(soulstorm_pt, tower, 1.0, tower.calc_spell_crit_no_bonus(), shoot_pos, 180.0)
		p2.user_real = 14000.0
	else:
		soulstorm_is_active = false


func soul_pt_on_hit(_p: YtProjectile, target: YtUnit):
	if target == null:
		return

	var damage: float = 14000 + 1400 * tower.get_level()

	tower.do_spell_damage(target, damage, tower.calc_spell_crit_no_bonus())


# NOTE: "NAttackFunc()" in original script
func shoot_cannonball():
	var it: YtIterate = YtIterate.over_units_in_range_of(tower, YtTargetType.new(YtTargetType.CREEPS), Vector2(dutchman.get_x(), dutchman.get_y()), 800)
	var next: YtUnit = it.next_random()

	if next != null:
		var shoot_pos: Vector3 = dutchman.get_position_wc3()
		YtProjectile.create_linear_interpolation_from_point_to_unit(cannonball_pt, tower, 1, 1, shoot_pos, next, 0.4, true)


# NOTE: "SAttackFunc()" in original script
# NOTE: original script uses an "acidbomb" Cast. Youtd2
# engine doesn't implement "acidbomb" cast/spelltype, so
# used a projectile instead.
func shoot_soul():
	if soul_count < 1:
		return

	var it: YtIterate = YtIterate.over_units_in_range_of(tower, YtTargetType.new(YtTargetType.CREEPS), Vector2(dutchman.get_x(), dutchman.get_y()), 1200)

	var shoot_pos: Vector3 = dutchman.get_position_wc3()

	while true:
		var next: YtUnit = it.next()

		if next == null:
			return

		if next.is_immune():
			continue

		soul_count -= 1

		YtProjectile.create_from_point_to_unit(soul_pt, tower, 1.0, 1.0, shoot_pos, next, true, false, false)
		
		break
