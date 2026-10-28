extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func on_damage(event: YtEvent):
	var tower: YtTower = item.get_carrier()
	var creep: YtCreep = event.get_target()

	# var l: Lightning

	if event.is_main_target():
		if creep.subtract_mana((8 + 0.6 * tower.get_level() * tower.get_base_attack_speed()) * (55 / pow(tower.get_base_range(), 0.6)), true) > 0:
			var lightning: YtInterpolatedSprite = YtInterpolatedSprite.create_from_unit_to_unit(YtInterpolatedSprite.LIGHTNING, tower, creep)
			lightning.modulate = Color.LIGHT_GREEN
			lightning.set_lifetime(0.1)
			var effect: int = YtEffect.create_simple_at_unit("res://src/effects/arcane_tower_attack.tscn", creep)
			YtEffect.set_color(effect, Color.LIGHT_BLUE)
