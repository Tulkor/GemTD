extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var multiboard: YtMultiboardValues


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func item_init():
	multiboard = YtMultiboardValues.new(1)
	var kill_count_label: String = YtUtils.text("UICO")
	multiboard.set_key(0, kill_count_label)


func on_attack(event: YtEvent):
	var tower: YtTower = item.get_carrier()
	var creep: YtUnit = event.get_target()

	if creep.get_size() < YtCreepSize.enm.CHAMPION && tower.calc_chance((0.0025 + (tower.get_level() * 0.0001)) * tower.get_base_attack_speed()):
		YtCombatLog.log_item_ability(item, null, "Curse of the Grave")

		tower.kill_instantly(creep)
		YtEffect.create_simple_at_unit("res://src/effects/death_coil.tscn", creep)
		YtSFX.sfx_at_unit(YtSfxPaths.WATER_SLASH, creep)
		item.user_int = item.user_int + 1


func on_create():
#	number of innocent creeps slaughtered mercilessly.
	item.user_int = 0


func on_tower_details() -> YtMultiboardValues:
	var tombstone_kills_text: String = YtUtils.format_float(item.user_int, 0)
	multiboard.set_value(0, tombstone_kills_text)
	
	return multiboard
