extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: simplified original script because it didn't use
# YtIterate.next_random().


func get_tier_stats() -> Dictionary:
	return {
		1: {damage = 200, damage_add = 12},
		2: {damage = 400, damage_add = 24},
		3: {damage = 800, damage_add = 48},
		4: {damage = 1700, damage_add = 100},
	}


func on_autocast(_event: YtEvent):
	var lvl: int = tower.get_level()
	var iterate: YtIterate = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.CREEPS), 875)
	var next: YtUnit
	var loop_counter: int = 3
	var counter: int = 3

	while true:
		loop_counter = loop_counter - 1
		next = iterate.next_random()

		if next == null:
			break

		tower.do_spell_damage(next, (_stats.damage + lvl * _stats.damage_add) * counter, tower.calc_spell_crit_no_bonus())
		YtEffect.create_simple_at_unit("res://src/effects/spell_aire.tscn", next)
		counter = counter + 1

		if loop_counter == 0:
			break
