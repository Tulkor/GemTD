extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var chameleon_pt: YtProjectileType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


# NOTE: hit() in original script
func chameleon_pt_on_hit(p: YtProjectile, creep: YtUnit):
	if creep == null:
		return

	var tower: YtTower = p.get_caster()
	tower.do_attack_damage(creep, tower.get_current_attack_damage_with_bonus(), tower.calc_attack_multicrit(0, 0, 0))


func item_init():
	chameleon_pt = YtProjectileType.create("path_to_projectile_sprite", 4, 1000, self)
	chameleon_pt.enable_homing(chameleon_pt_on_hit, 0)


func on_attack(event: YtEvent):
	var tower: YtTower = item.get_carrier()
	var creep: YtUnit = event.get_target()
	var p: YtProjectile

	if !tower.calc_chance(0.4 + 0.004 * tower.get_level()):
		return

	YtCombatLog.log_item_ability(item, null, "Launch Glaive!")

	await YtUtils.create_manual_timer(0.1, self).timeout

	if !YtUtils.unit_is_valid(tower) || !YtUtils.unit_is_valid(creep):
		return

	p = YtProjectile.create_from_unit_to_unit(chameleon_pt, tower, 1, 0, tower, creep, true, false, false)
	p.set_projectile_scale(0.75)
