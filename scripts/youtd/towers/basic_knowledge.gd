extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func get_tier_stats() -> Dictionary:
	return {
		1: {exp = 0.40},
		2: {exp = 0.55},
		3: {exp = 0.70},
		4: {exp = 0.85},
		5: {exp = 1.00},
	}


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func on_attack(_event: YtEvent):
	tower.add_exp(_stats.exp)
