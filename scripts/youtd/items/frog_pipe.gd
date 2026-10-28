extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.

# NOTE: in original script, collision range was defined by
# calling setCollisionParameters. Removed that because it's
# not needed. Can define when set_collision_enabled() is
# called.

# NOTE: I modified the coloring of projectiles. Set initial
# color to blue and then when projectile starts homing make
# it bluer. Original script uses a green frog model which
# turns blueish later.


var frog_pt: YtProjectileType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


# NOTE: deem_FrogAttack() in original script
func daem_frog_attack(tower: YtTower, target: YtUnit, temp: int):
	var x: float = tower.get_x()
	var y: float = tower.get_y()

	var angle: float = rad_to_deg(atan2(target.get_y() - y, target.get_x() - x))

	var p: YtProjectile = YtProjectile.create(frog_pt, tower, 0, 0, Vector3(x + YtGlobals.synced_rng.randi_range(-40, 40), y + YtGlobals.synced_rng.randi_range(-40, 40), 5.0), angle + temp)
	p.set_color(Color8(100, 255, 100, 255))
	p.user_int = temp
	p.user_real = tower.get_current_attack_damage_with_bonus()
	p.user_real2 = tower.calc_attack_multicrit_no_bonus()


# NOTE: deem_FrogCollision() in original script
func frog_pt_on_hit(p: YtProjectile, target: YtUnit):
	if target == null:
		return

	var tower: YtTower = p.get_caster()
	tower.do_attack_damage(target, p.user_real, p.user_real2)


func item_init():
	frog_pt = YtProjectileType.create_ranged("path_to_projectile_sprite", 3700.0, 500.0, self)
	frog_pt.enable_collision(frog_pt_on_collision, 190, YtTargetType.new(YtTargetType.CREEPS), false)
	frog_pt.enable_homing(frog_pt_on_hit, 0)
	frog_pt.enable_periodic(frog_pt_periodic, 0.60)
	frog_pt.set_acceleration(-36)
	frog_pt.disable_explode_on_hit()


func on_attack(event: YtEvent):
	var tower: YtTower = item.get_carrier()
	var target: YtUnit = event.get_target()
	var frog_chance: float = 0.2

	if !tower.calc_chance(frog_chance):
		return

	if target.get_size() != YtCreepSize.enm.AIR:
		YtCombatLog.log_ability(tower, target, "Frog Piper")
		
		daem_frog_attack(item.get_carrier(), target, YtGlobals.synced_rng.randi_range(-40, -20))
		daem_frog_attack(item.get_carrier(), target, YtGlobals.synced_rng.randi_range(-20, -0))
		daem_frog_attack(item.get_carrier(), target, YtGlobals.synced_rng.randi_range(0, 20))
		daem_frog_attack(item.get_carrier(), target, YtGlobals.synced_rng.randi_range(20, 40))


# NOTE: deem_FrogHome() in original script
func frog_pt_on_collision(p: YtProjectile, target: YtUnit):
	if target.get_size() == YtCreepSize.enm.AIR:
		return

	p.set_speed(500)
	p.set_collision_enabled(false)
	p.set_homing_target(target)
	p.set_acceleration(8)
	p.set_color(Color8(100, 220, 150, 255))
	p.disable_periodic()
	p.set_remaining_lifetime(3.0)


# NOTE: deem_FrogPeriodic() in original script
func frog_pt_periodic(projectile: YtProjectile):
	projectile.user_int *= -1
	projectile.set_speed(500)
	projectile.set_direction(projectile.get_direction() + projectile.user_int)
