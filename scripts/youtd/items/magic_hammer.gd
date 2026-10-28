extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_spell_casted(on_spell_cast)


func on_pickup():
	item.user_int = 0


func on_spell_cast(_event: YtEvent):
	item.user_int = item.user_int + 1

	if item.user_int >= 5:
		YtCombatLog.log_item_ability(item, null, "Magic Weapon")
		item.get_carrier().add_spell_crit()
		item.user_int = 0
