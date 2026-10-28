extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var stun_bt: YtBuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {attack_mana_cost = 1, release_energy_dmg = 4000, release_energy_dmg_add = 150, stun_duration = 3, stun_duration_for_bosses = 1},
		2: {attack_mana_cost = 2, release_energy_dmg = 12000, release_energy_dmg_add = 450, stun_duration = 5, stun_duration_for_bosses = 1.75},
	}


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func tower_init():
	stun_bt = YtCbStun.new("stun_bt", 0, 0, false, self)


func on_autocast(event: YtEvent):
	var creep: YtUnit = event.get_target()
	var creep_size: YtCreepSize.enm = creep.get_size()
	var damage: float = _stats.release_energy_dmg + _stats.release_energy_dmg_add * tower.get_level()

	tower.do_spell_damage(creep, damage, tower.calc_spell_crit_no_bonus())
	YtEffect.create_simple_at_unit("res://src/effects/revive_human.tscn", creep, YtUnit.BodyPart.CHEST)

	var stun_duration: float
	if creep_size < YtCreepSize.enm.BOSS:
		stun_duration = _stats.stun_duration
	else:
		stun_duration = _stats.stun_duration_for_bosses

	stun_bt.apply_only_timed(tower, creep, stun_duration)


func on_attack(_event: YtEvent):
	var mana: float = tower.get_mana()

	if mana < _stats.attack_mana_cost:
		tower.order_stop()
	else:
		tower.subtract_mana(_stats.attack_mana_cost, false)
