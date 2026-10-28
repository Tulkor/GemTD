extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func on_damage(event: YtEvent):
	var dmg: float = item.get_carrier().get_current_attack_damage_base()

	if event.damage < dmg && event.is_main_target():
		event.damage = dmg
