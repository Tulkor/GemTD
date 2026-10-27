extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: rewrote script a bit. Instead of enabling/disabling
# periodic event I added a flag.

# NOTE: [ORIGINAL_GAME_BUG] (NOT FIXED) Original script has
# a bug where it refunds the cost of autocast in
# on_autocast(). It refunds the cost by calling set_mana()
# but the problem is that at the time when on_autocast() is
# called, the mana cost has not been spent yet. Therefore,
# refund fails if tower is at max mana because set_mana()
# can't go above max mana. Not critical - don't need to fix.


var frozen_bt: YtBuffType
var missile_pt: YtProjectileType

var _battery_overload_is_active: bool = false


func get_tier_stats() -> Dictionary:
	return {
		1: {projectile_damage = 300, projectile_damage_add = 12, slow_amount = 0.10, slow_amount_add = 0.003},
		2: {projectile_damage = 750, projectile_damage_add = 30, slow_amount = 0.15, slow_amount_add = 0.0045},
		3: {projectile_damage = 1800, projectile_damage_add = 72, slow_amount = 0.20, slow_amount_add = 0.006},
	}


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)
	triggers.add_periodic_event(periodic, 0.2)


func on_autocast(_event: YtEvent):
	tower.set_mana(tower.get_mana() + 100)
	_battery_overload_is_active = true


func hit(_p: YtProjectile, creep: YtUnit):
	if creep == null:
		return

	var level: int = tower.get_level()
	var damage: float = _stats.projectile_damage + _stats.projectile_damage_add * level

	tower.do_spell_damage(creep, damage, tower.calc_spell_crit_no_bonus())
	frozen_bt.apply(tower, creep, level)


func tower_init():
	var slow: YtModifier = YtModifier.new()
	slow.add_modification(YtModificationType.enm.MOD_MOVESPEED, -_stats.slow_amount, -_stats.slow_amount_add)

	frozen_bt = YtBuffType.new("frozen_bt", 9, 0.3, false, self)
	frozen_bt.set_buff_icon("res://resources/icons/generic_icons/azul_flake.tres")
	frozen_bt.set_buff_modifier(slow)
	frozen_bt.set_buff_tooltip(YtUtils.text("FBX1"))

	missile_pt = YtProjectileType.create("path_to_projectile_sprite", 10, 1200, self)
	missile_pt.enable_homing(hit, 0)


func on_damage(event: YtEvent):
	frozen_bt.apply(tower, event.get_target(), tower.get_level())


func on_create(_preceding_tower: YtTower):
	tower.user_int = 0
	tower.set_mana(0)


func periodic(_event: YtEvent):
	if !_battery_overload_is_active:
		return

	if tower.get_mana() > 10:
		var in_range: YtIterate = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.CREEPS), 1200)
		var target: YtUnit = in_range.next_random()

		if target != null:
# 			NOTE: original script used createFromPointToUnit and made projectiles from high above the tower
			var p: YtProjectile = YtProjectile.create_from_unit_to_unit(missile_pt, tower, 1.0, 1.0, tower, target, true, false, false)
			p.set_projectile_scale(0.5)

#		Spend mana, note that mana is used for unsuccessful
#		attempts as well
		tower.set_mana(tower.get_mana() - 10)
	else:
#		YtTower is out of mana so stop shooting
		_battery_overload_is_active = false
