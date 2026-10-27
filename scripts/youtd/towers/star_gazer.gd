extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func get_tier_stats() -> Dictionary:
	return {
		1: {damage_bonus = 0.01},
		2: {damage_bonus = 0.02},
		3: {damage_bonus = 0.03},
		4: {damage_bonus = 0.04},
	}


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func on_damage(event: YtEvent):
	var creep: YtUnit = event.get_target()

	if creep.is_immune():
		tower.do_attack_damage(creep, tower.get_current_attack_damage_with_bonus() * 0.8, tower.calc_attack_multicrit(0, 0, 0))
	else:
		tower.do_spell_damage(creep, tower.get_current_attack_damage_with_bonus() * (1 + _stats.damage_bonus * tower.get_level()), tower.calc_spell_crit_no_bonus())
