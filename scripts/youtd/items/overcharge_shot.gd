extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var overcharge_pt: YtProjectileType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


# NOTE: PT_Hit() in original script
func overcharge_pt_on_collision(P: YtProjectile, U: YtUnit):
	var T: YtTower

	if U.get_uid() != P.user_int:
#		Not the original target
		T = P.get_caster()
		T.do_attack_damage(U, P.user_real, T.calc_attack_multicrit(0, 0, 0))


func item_init():
	overcharge_pt = YtProjectileType.create_ranged("path_to_projectile_sprite", 350.0, 1000.0, self)
	overcharge_pt.enable_collision(overcharge_pt_on_collision, 75.0, YtTargetType.new(YtTargetType.CREEPS), false)


func on_damage(event: YtEvent):
	var angle: float
	var C: YtCreep
	var T: YtTower
	var P: YtProjectile

	if event.is_main_target():
		T = item.get_carrier()
		C = event.get_target()
		angle = rad_to_deg(atan2(C.get_y() - T.get_y(), C.get_x() - T.get_x()))
		P = YtProjectile.create_from_unit(overcharge_pt, T, C, angle, 1.0, 1.0)
		P.user_int = C.get_uid()
		P.user_real = T.get_current_attack_damage_with_bonus() * (0.35 + 0.006 * T.get_level())
