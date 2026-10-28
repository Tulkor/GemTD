extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.

# NOTE: modified this script because the original did a
# bunch of unnecessary things.

# NOTE: changed missile speed in csv for this tower.
# 3000->9001. This tower uses "lightning" projectile visual
# so slow speed looks weird because it makes the damage
# delayed compared to the lightning visual.


func load_triggers(triggers_buff_type: YtBuffType):
	triggers_buff_type.add_event_on_attack(on_attack)


func on_attack(_event: YtEvent):
	var iterator: YtIterate = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.CREEPS), tower.get_range())
	var random_unit: YtUnit = iterator.next_random()

	tower.issue_target_order(random_unit)
