extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func on_damage(event: YtEvent):
	var T: YtCreep = event.get_target()

	if T.get_armor_type() == YtArmorType.enm.LUA:
		event.damage = event.damage * 1.25
		YtEffect.create_simple_at_unit("res://src/effects/frag_boom_spawn.tscn", T)
