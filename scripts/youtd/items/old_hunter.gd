extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_kill(on_damage)


func on_damage(_event: YtEvent):
	var tower: YtTower = item.get_carrier()
	var next: YtTower
	var in_range: YtIterate
	var count: int

#	test if tower is minimum lvl 5
	if tower.get_level() >= 5:
#		test, if there are towers in range
		in_range = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.TOWERS), 500)
		count = min(5, in_range.count())

		if count > 0:
			tower.remove_exp_flat(count)

			while true:
				next = in_range.next_random()

				if next == null:
					break

				next.add_exp_flat(1)
				YtEffect.create_simple_at_unit("res://src/effects/animated_dead_target.tscn", next)
				count = count - 1

				if count == 0:
					break
