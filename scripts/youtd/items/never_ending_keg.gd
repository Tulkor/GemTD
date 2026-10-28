extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func on_damage(event: YtEvent):
	if YtUtils.rand_chance(YtGlobals.synced_rng, 0.10):
		YtCombatLog.log_item_ability(item, null, "Drunk!")
		item.get_carrier().get_player().display_small_floating_text(YtUtils.text("FLOATING_TEXT_MISS"), item.get_carrier(), Color8(255, 0, 0), 40.0)
		event.damage = 0
