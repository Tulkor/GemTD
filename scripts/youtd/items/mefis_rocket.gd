extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: [ORIGINAL_GAME_DEVIATION] changed the 2nd "one_shot"
# arg passed to enable_advanced(). Original script passes
# "true" but this causes the tower to not fire projectiles
# in youtd2 engine. Not sure if the JASS engine processes
# the "one_shot" arg in some weird way.


var rocket_pt: YtProjectileType
var multiboard: YtMultiboardValues


func load_triggers(triggers: YtBuffType):
	triggers.add_periodic_event(periodic, 0.1)


# NOTE: hitPT() in original script
func rocket_pt_on_hit(P: YtProjectile, U: YtUnit):
	if U == null:
		return

	var T: YtTower = P.get_caster()
	T.do_custom_attack_damage(U, P.user_real, T.calc_attack_multicrit(0, 0, 0), P.user_int)


func item_init():
	rocket_pt = YtProjectileType.create_interpolate("path_to_projectile_sprite", 1000, self)
	rocket_pt.set_event_on_interpolation_finished(rocket_pt_on_hit)

	multiboard = YtMultiboardValues.new(1)
	var damage_label: String = YtUtils.text("VLPO")
	multiboard.set_key(0, damage_label)


func on_pickup():
	var T: YtTower = item.get_carrier()

	if T.get_attack_type() != YtAttackType.enm.ARCANE:
		item.user_int = T.get_attack_type()
	else:
		item.user_int = YtAttackType.enm.ESSENCE


func on_tower_details() -> YtMultiboardValues:
	var tower: YtTower = item.get_carrier()
	var dmg: float = tower.get_current_attack_damage_with_bonus() * ( tower.get_prop_spell_damage_dealt() * (0.2 + 0.008 * tower.get_level()))
	multiboard.set_value(0, YtUtils.format_float(dmg, 0))

	return multiboard


func periodic(event: YtEvent):
	var T: YtTower = item.get_carrier()
	var I: YtIterate = YtIterate.over_units_in_range_of_caster(T, YtTargetType.new(YtTargetType.CREEPS), T.get_range())
	var U: YtUnit
	var dmg: float
	var P: YtProjectile

	event.enable_advanced(T.get_current_attack_speed(), false)

	while true:
		U = I.next()

		if U == null:
			return

		if U.is_immune():
			break

	dmg = T.get_current_attack_damage_with_bonus() * (T.get_prop_spell_damage_dealt() * (0.2 + 0.008 * T.get_level()))
	P = YtProjectile.create_linear_interpolation_from_unit_to_unit(rocket_pt, T, 1.0, 1.0, T, U, 0.35, true)
	P.user_real = dmg
	P.user_int = item.user_int
