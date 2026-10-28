extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: changed how the "mirror image" VFX is implemented by
# a lot. Original script uses YtEffect with models and attack
# animations. Don't have access to those things so used a
# moving projectile instead with sprite of tower.


var omnislashed_bt: YtBuffType
var mirror_image_pt: YtProjectileType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func tower_init():
	omnislashed_bt = YtBuffType.new("omnislashed_bt", -1, 0, false, self)
	omnislashed_bt.set_buff_icon("res://resources/icons/generic_icons/triple_scratches.tres")
	omnislashed_bt.set_buff_tooltip(YtUtils.text("Q9VE"))
	omnislashed_bt.add_event_on_damaged(omnislashed_bt_on_damaged)

	mirror_image_pt = YtProjectileType.create_interpolate("res://src/projectiles/projectile_visuals/omnislasher_mirror_image.tscn", 1000.0, self)
	mirror_image_pt.set_event_on_interpolation_finished(mirror_image_pt_on_interpolation_finished)
	mirror_image_pt.disable_explode_on_hit()


# NOTE: implemented this slightly differently than original
# script. Using "await" instead of timer.
func on_attack(event: YtEvent):
	var target: YtUnit = event.get_target()
	var attack_count: int = 10 + 2 / 5 * tower.get_level()
	var time_between_attacks: float = tower.get_current_attack_speed() / attack_count
	var it: YtIterate = YtIterate.over_units_in_range_of_unit(tower, YtTargetType.new(YtTargetType.CREEPS), target, 1200)

	YtSFX.sfx_at_unit(YtSfxPaths.MAGIC_FIZZLE, tower)
	
	tower.set_sprite_color(Color8(255, 255, 255, 100))

# 	NOTE: original script calls PauseUnit() here and after
# 	the end of the Omnislash ability. This means that the
# 	tower never actually shoots the attack projectile.
# 	Replicate this behavior by calling order_stop().
	tower.order_stop()

	var fun_text: String
	var fun_value: float = YtGlobals.synced_rng.randf_range(0, 1.0)
	if fun_value < 0.03:
		var faster_than_light_text: String = YtUtils.text("ZWDX")
		fun_text = faster_than_light_text
	elif fun_value < 0.02:
		var einstein_lies_text: String = YtUtils.text("B0DP")
		fun_text = einstein_lies_text
	elif fun_value < 0.01:
		var relativity_text: String = YtUtils.text("M4CO")
		fun_text = relativity_text
	else:
		fun_text = ""

	if !fun_text.is_empty():
		tower.get_player().display_floating_text_x(fun_text, tower, Color8(50, 150, 255, 255), 0.05, 2, 3)

	var p: YtProjectile = YtProjectile.create_linear_interpolation_from_unit_to_unit(mirror_image_pt, tower, 0, 0, tower, target, 0.1, true)
#	NOTE: set a very high speed for first movement from tower to target so that projectile reaches the target on time
	p.set_speed(5000)

	for i in range(0, attack_count):
		await YtUtils.create_manual_timer(time_between_attacks, self).timeout

		if !YtUtils.unit_is_valid(tower):
			break

		if !YtUtils.unit_is_valid(target):
			target = it.next()
			
		if target == null:
			break

		YtEffect.create_simple_at_unit("res://src/effects/blood_splatter.tscn", target)

		var random_angle: float = deg_to_rad(YtGlobals.synced_rng.randf_range(0, 360))
		var random_offset: Vector2 = Vector2(80, 0).rotated(random_angle)
		var projectile_pos: Vector3 = Vector3(
			target.get_x() + random_offset.x,
			target.get_y() + random_offset.y,
			target.get_z())
		p.start_interpolation_to_point(projectile_pos, 0.1)
#		NOTE: reduce speed to normal value for moves after first one
		p.set_speed(1000)

		damage(target)

	p.remove_from_game()
	tower.set_sprite_color(Color8(255, 255, 255, 255))


func damage(target: YtUnit):
	var buff: YtBuff = target.get_buff_of_type(omnislashed_bt)

	tower.do_attack_damage(target, tower.get_current_attack_damage_with_bonus() / 10, tower.calc_attack_multicrit_no_bonus())

	if buff == null:
		buff = omnislashed_bt.apply(tower, target, tower.get_level())
		var damage_multiplier: float = 1.0
		buff.user_real = damage_multiplier
	else:
		var damage_multiplier: float = buff.user_real + 0.04
		buff.user_real = damage_multiplier


func omnislashed_bt_on_damaged(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var caster: YtTower = event.get_target()

	if caster.get_attack_type() != YtAttackType.enm.PHYSICAL:
		return

	if event.is_spell_damage():
		return

	var damage_multiplier: float = buff.user_real
	event.damage *= damage_multiplier


func mirror_image_pt_on_interpolation_finished(projectile: YtProjectile, _target: YtUnit):
	projectile.avert_destruction()
