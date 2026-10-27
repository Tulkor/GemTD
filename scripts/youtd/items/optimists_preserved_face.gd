extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func on_damage(event: YtEvent):
	var target: YtUnit = event.get_target()
	var health_ratio: float = target.get_health() / target.get_overall_health()
	event.damage = event.damage * (1.75 - (1.25 * (1 - health_ratio)))
