extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_periodic_event(periodic, 5)



func on_pickup():
	item.user_real = item.get_carrier().get_mana()


func periodic(_event: YtEvent):
	var u: YtUnit = item.get_carrier()
	var cur_mana: float = u.get_mana()

	if cur_mana < item.user_real && u.calc_chance(0.25):
		YtCombatLog.log_item_ability(item, null, "Circle of Power")
		u.set_mana(item.user_real)
		var effect: int = YtEffect.create_simple_at_unit("res://src/effects/spell_aima.tscn", u)
		YtEffect.set_color(effect, Color.GOLD)
	else:
		item.user_real = cur_mana
