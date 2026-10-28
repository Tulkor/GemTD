extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func on_damage(event: YtEvent):
	var damage: float = event.damage
	var creep: YtUnit = event.get_target()
	var tower: YtTower = item.get_carrier()

	event.damage = damage * 0.7
	tower.do_spell_damage(creep, damage * 0.3, tower.calc_spell_crit_no_bonus())
