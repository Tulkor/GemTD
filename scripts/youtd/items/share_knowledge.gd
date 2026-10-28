extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_periodic_event(periodic, 15)


func periodic(_event: YtEvent):
	var tower: YtTower = item.get_carrier()
	var next: YtTower
	var in_range: YtIterate
	var count: int
	var experience: float

#	test if tower is level 2 or higher
	if tower.get_level() > 1:		
#		test, if there are towers in range
		in_range = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.TOWERS), 400)
		count = min(5, in_range.count())

		if count > 0:
			YtCombatLog.log_item_ability(item, null, "Share Knowledge")

# 			(8 + number of towers) / number of towers
			experience = (8.0 + count) / count
			tower.remove_exp_flat(10)

			while true:
				next = in_range.next_random()

				if next == null:
					break

				next.add_exp_flat(experience)
				YtEffect.create_simple_at_unit("res://src/effects/polymorph_target.tscn", next)
				count = count - 1

				if count == 0:
					break
