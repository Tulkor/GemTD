extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func on_damage(event: YtEvent):
	var twr: YtTower = item.get_carrier() 

	if event.is_main_target():
		twr.do_spell_damage(event.get_target(), (0.08 + 0.001 * twr.get_level()) * twr.get_gold_cost() * twr.get_base_attack_speed(), twr.calc_spell_crit_no_bonus())
