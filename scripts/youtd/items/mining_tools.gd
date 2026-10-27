extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var multiboard: YtMultiboardValues


func load_triggers(triggers: YtBuffType):
	triggers.add_periodic_event(periodic, 15)


func item_init():
	multiboard = YtMultiboardValues.new(1)
	var gold_found_label: String = YtUtils.text("H12F")
	multiboard.set_key(0, gold_found_label)


func on_create():
	item.user_int = 0


func on_tower_details() -> YtMultiboardValues:
	var gold_found_text: String = YtUtils.format_float(item.user_int, 0)
	multiboard.set_value(0, gold_found_text)

	return multiboard


func periodic(_event: YtEvent):
	var tower: YtTower = item.get_carrier()
	var target_effect: int

	target_effect = YtEffect.create_scaled("res://src/effects/ancient_protector_missile.tscn", tower.get_position_wc3(), 0, 2)
	YtEffect.set_lifetime(target_effect, 0.1)
	
	if tower.calc_chance(0.40 + tower.get_level() * 0.02):
		YtCombatLog.log_item_ability(item, null, "Mining Success")
		
		if tower.get_level() < 25:
			tower.get_player().give_gold(3, tower, false, true)
			item.user_int = item.user_int + 3
		else:
			tower.get_player().give_gold(4, tower, false, true)
			item.user_int = item.user_int + 4
	else:
		YtCombatLog.log_item_ability(item, null, "Mining Fail")
