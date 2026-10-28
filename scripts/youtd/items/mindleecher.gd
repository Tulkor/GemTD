extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func on_autocast(_event: YtEvent):
	var tower: YtTower = item.get_carrier()
	var it: YtIterate = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.TOWERS), 450)
	var next: YtUnit

	while true:
		next = it.next_random()

		if next == null:
			break

		if next != tower && next.get_exp() > 0:
			break

	if next != null:
		tower.add_exp_flat(next.remove_exp_flat(YtGlobals.synced_rng.randi_range(15, 60)))
		YtEffect.create_simple_at_unit("res://src/effects/animated_dead_target.tscn", next, YtUnit.BodyPart.HEAD)
		YtEffect.create_simple_at_unit("res://src/effects/death_coil.tscn", next, YtUnit.BodyPart.HEAD)
