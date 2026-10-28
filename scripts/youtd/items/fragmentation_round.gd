extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var frag_pt: YtProjectileType
var frag_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


# NOTE: PT_Hit() in original script
func frag_pt_on_hit(P: YtProjectile, U: YtUnit):
	if U == null:
		return

	var T: YtTower = P.get_caster()
	var B: YtBuff = U.get_buff_of_type(frag_bt)

	if B != null:
		P.user_real = P.user_real * 1.40

	var buff_level: int
	if B != null:
		buff_level = B.get_level()
	else:
		buff_level = 0
	
	T.do_attack_damage(U, P.user_real * 0.45, 1.0)

	frag_bt.apply(T, U, buff_level)


# NOTE: BT_DMG() in original script
func frag_bt_on_damaged(event: YtEvent):
	if event.is_main_target() == false && event.is_spell_damage() == false:
		event.damage = event.damage * 1.40


func item_init():
	frag_pt = YtProjectileType.create("path_to_projectile_sprite", 0.0, 1000.0, self)
	frag_pt.enable_homing(frag_pt_on_hit, 0.1)

	frag_bt = YtBuffType.new("frag_bt", 5.0, 0.0, false, self)
	frag_bt.set_buff_icon("res://resources/icons/generic_icons/mine_explosion.tres")
	frag_bt.set_buff_tooltip(YtUtils.text("7ZPH"))
	frag_bt.add_event_on_damaged(frag_bt_on_damaged)


func on_damage(event: YtEvent):
	var tower: YtUnit = item.get_carrier()

	var fragmentation_round_chance: float = 0.40

	if !tower.calc_chance(fragmentation_round_chance):
		return

	YtCombatLog.log_item_ability(item, null, "Fragmentation Round")

	var I: YtIterate
	var U: YtUnit
	var Targ: YtUnit
	var i: int = 2

	if event.is_main_target():
		Targ = event.get_target()
		I = YtIterate.over_units_in_range_of_unit(item.get_carrier(), YtTargetType.new(YtTargetType.CREEPS), Targ, 500)

		while true:
			U = I.next()

			if U == null:
				break

			if U != Targ:
				var projectile: YtProjectile = YtProjectile.create_from_unit_to_unit(frag_pt, item.get_carrier(), 1.0, 1.0, Targ, U, true, false, true)
				projectile.user_real = event.damage
				i = i - 1

				if i == 0:
					break
