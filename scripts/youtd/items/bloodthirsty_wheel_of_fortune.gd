extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var multiboard: YtMultiboardValues


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_kill(on_kill)


func item_init():
	multiboard = YtMultiboardValues.new(1)
	var fortune_bonus_label: String = YtUtils.text("ILG6")
	multiboard.set_key(0, fortune_bonus_label)


func on_create():
	item.user_real = 0.0


func on_drop():
	if item.user_real != 0.0:
		item.get_carrier().modify_property(YtModificationType.enm.MOD_ITEM_CHANCE_ON_KILL, -1 * item.user_real)


func on_pickup():
	if item.user_real != 0.0:
		item.get_carrier().modify_property(YtModificationType.enm.MOD_ITEM_CHANCE_ON_KILL, item.user_real)


func on_kill(_event: YtEvent):
	var t: YtTower
	t = item.get_carrier()

	if t.calc_chance(0.25):		
		if YtUtils.rand_chance(YtGlobals.synced_rng, 0.33):
			if item.user_real >= -0.20:
				YtCombatLog.log_item_ability(item, null, "Lower Item Chance")
				
				item.user_real = item.user_real - 0.04
				t.modify_property(YtModificationType.enm.MOD_ITEM_CHANCE_ON_KILL, -0.04)
				var item_chance_lowered_text: String = YtUtils.text("GZ82")
				t.get_player().display_small_floating_text(item_chance_lowered_text, t, Color8(255, 0, 0), 30)
		else:
			if item.user_real <= 0.44:
				YtCombatLog.log_item_ability(item, null, "Raise Item Chance")
				
				item.user_real = item.user_real + 0.04
				t.modify_property(YtModificationType.enm.MOD_ITEM_CHANCE_ON_KILL, 0.04)
				var item_chance_raised_text: String = YtUtils.text("YRQV")
				t.get_player().display_small_floating_text(item_chance_raised_text, t, Color8(0, 0, 255), 30)


func on_tower_details() -> YtMultiboardValues:
	multiboard.set_value(0, YtUtils.format_percent_add_color(item.user_real, 0))

	return multiboard
