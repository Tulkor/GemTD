extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_kill(on_kill)


func on_kill(_event: YtEvent):
	var tower: YtTower = item.get_carrier()
	tower.add_mana_perc(0.07)
	var effect: int = YtEffect.create_simple_at_unit("res://src/effects/replenish_mana.tscn", tower)
	YtEffect.set_color(effect, Color.RED)
