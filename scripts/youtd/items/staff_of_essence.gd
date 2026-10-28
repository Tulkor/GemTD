extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func on_damage(event: YtEvent):
	var T: YtTower = item.get_carrier()
	var AT: YtAttackType.enm = T.get_attack_type()
	var C: YtCreep = event.get_target()
	var r: float = YtAttackType.get_damage_against(AT, C.get_armor_type())

#	NOTE: this check is actually not needed because DAMAGE
#	event is not called for spell damage
	if event.is_spell_damage() == false:
		event.damage = event.damage / r
