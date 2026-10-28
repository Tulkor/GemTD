extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)
	triggers.add_event_on_damage(on_damage)


func on_attack(_event: YtEvent):
	item.user_real = item.user_real + 50.0 + 1.0 * item.get_carrier().get_level()
	item.set_charges(int(item.user_real))


func on_damage(event: YtEvent):
	var T: YtTower = item.get_carrier()
	var C: YtCreep = event.get_target()

	if item.user_real >= 100.0:
		event.damage = event.damage / YtAttackType.get_damage_against(T.get_attack_type(), C.get_armor_type()) * YtAttackType.get_damage_against(YtAttackType.enm.DECAY, C.get_armor_type())
		YtEffect.create_simple_at_unit("res://src/effects/death_and_decay.tscn", C)
		YtSFX.sfx_at_unit(YtSfxPaths.GHOST_EXHALE, C)
		item.user_real = item.user_real - 100.0
		item.set_charges(int(item.user_real))


func on_pickup():
	item.user_real = 0.0
	item.set_charges(0)
