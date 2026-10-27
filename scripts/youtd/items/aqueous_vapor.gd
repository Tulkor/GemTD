extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func on_damage(event: YtEvent):
	var target: YtCreep = event.get_target()

	if target.get_armor_type() == YtArmorType.enm.MYT:
		event.damage = event.damage * 1.25
		YtEffect.create_simple_at_unit_attached("res://src/effects/crushing_wave.tscn", target)
