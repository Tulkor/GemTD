extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var multiboard: YtMultiboardValues


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_unit_comes_in_range(on_unit_in_range, 600, YtTargetType.new(YtTargetType.CREEPS + YtTargetType.SIZE_BOSS))


func item_init():
	multiboard = YtMultiboardValues.new(1)
	var arms_sold_label: String = YtUtils.text("YQK4")
	multiboard.set_key(0, arms_sold_label)


func on_create():
	item.user_int = 0
	item.user_int2 = 0


func on_tower_details() -> YtMultiboardValues:
	var arms_sold_text: String = YtUtils.format_float(item.user_int2, 0)
	multiboard.set_value(0, arms_sold_text)

	return multiboard


func on_unit_in_range(event: YtEvent):
	var t: YtTower = item.get_carrier() 
	var c: YtCreep = event.get_target()
	var p: YtPlayer = t.get_player()
	var boss_level: int = c.get_spawn_level()
	var reward_value: int

	if item.user_int < boss_level && t.calc_chance(0.25):
		YtCombatLog.log_item_ability(item, null, "The Customer Is Boss")
		
		reward_value = t.get_level() + boss_level + 25
		p.give_gold(reward_value, t, true, false)
		var arms_sold_text: String = "%s %d" % [YtUtils.text("YQK4"), reward_value]
		p.display_floating_text(arms_sold_text, t, Color8(0, 255, 0))
		item.user_int = boss_level
		item.user_int2 = item.user_int2 + reward_value
