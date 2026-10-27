extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: reworked original script. Used the same logic as in
# "RottedFlashingGrave" tower which also attacks random
# targets.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func load_specials(modifier: YtModifier):
	modifier.add_modification(YtModificationType.enm.MOD_DMG_TO_MAGIC, 0.10, 0.01)


func on_attack(_event: YtEvent):
	var tower: YtTower = item.get_carrier()
	var iterator: YtIterate = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.CREEPS), tower.get_range())
	var random_unit: YtUnit = iterator.next_random()

	if random_unit == null:
		return

	tower.issue_target_order(random_unit)
