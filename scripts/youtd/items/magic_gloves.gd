extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func on_attack(event: YtEvent):
	var tower: YtTower = item.get_carrier()
	tower.do_spell_damage(event.get_target(), (100 + (tower.get_level() * 5)) * tower.get_base_attack_speed(), tower.calc_spell_crit_no_bonus())
