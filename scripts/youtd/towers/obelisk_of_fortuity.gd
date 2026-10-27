extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func get_tier_stats() -> Dictionary:
	return {
		1: {miss_chance_base = 0.3},
		2: {miss_chance_base = 0.4},
		3: {miss_chance_base = 0.5},
		4: {miss_chance_base = 0.6},
		5: {miss_chance_base = 0.7},
	}


func load_triggers(triggers_buff_type: YtBuffType):
	triggers_buff_type.add_event_on_damage(on_damage)


func on_damage(event: YtEvent):
	if tower.calc_bad_chance(_stats.miss_chance_base - tower.get_level() * 0.006):
		YtCombatLog.log_ability(tower, event.get_target(), "Warming Up")
		event.damage = 0
		tower.get_player().display_floating_text_x(YtUtils.text("FLOATING_TEXT_MISS"), tower, Color8(255, 0, 0, 255), 0.05, 0.0, 2.0)
