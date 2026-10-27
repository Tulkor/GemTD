extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var armor_bt: YtBuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {armor_decrease = 2},
		2: {armor_decrease = 3},
		3: {armor_decrease = 5},
		4: {armor_decrease = 7},
		5: {armor_decrease = 10},
	}


func load_triggers(triggers_buff_type: YtBuffType):
	triggers_buff_type.add_event_on_damage(on_damage)


func tower_init():
	var armor: YtModifier = YtModifier.new()
	armor.add_modification(YtModificationType.enm.MOD_ARMOR, 0, -1)
	armor_bt = YtBuffType.new("armor_bt", 0, 0, false, self)
	armor_bt.set_buff_icon("res://resources/icons/generic_icons/semi_closed_eye.tres")
	armor_bt.set_buff_modifier(armor)

	armor_bt.set_buff_tooltip(YtUtils.text("Y0QD"))


func on_damage(event: YtEvent):
	var lvl: int = tower.get_level()
	var creep: YtUnit = event.get_target()
	var size_factor: float = 1.0

	if creep.get_size() == YtCreepSize.enm.BOSS:
		size_factor = 2.0

	if tower.calc_chance((0.05 + lvl * 0.006) * size_factor):
		YtCombatLog.log_ability(tower, creep, "Afterglow")
		
		armor_bt.apply_custom_timed(tower, creep, _stats.armor_decrease, 5 + lvl * 0.25)
