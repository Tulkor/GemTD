extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var phazed_bt: YtBuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {value = 500, value_add = 30, duration = 5},
		2: {value = 800, value_add = 35, duration = 5},
		3: {value = 1000, value_add = 40, duration = 5},
		4: {value = 1200, value_add = 45, duration = 6},
		5: {value = 1500, value_add = 50, duration = 6},
	}


func load_triggers(triggers_buff_type: YtBuffType):
	triggers_buff_type.add_event_on_damage(on_damage)


func tower_init():
	var iron_mod: YtModifier = YtModifier.new()
	phazed_bt = YtBuffType.new("phazed_bt", 0, 0, false, self)
	iron_mod.add_modification(YtModificationType.enm.MOD_ITEM_QUALITY_ON_DEATH, 0.0, 0.0001)
	iron_mod.add_modification(YtModificationType.enm.MOD_ITEM_CHANCE_ON_DEATH, 0.0, 0.0001)
	phazed_bt.set_buff_modifier(iron_mod)
	phazed_bt.set_buff_icon("res://resources/icons/generic_icons/amber_mosquito.tres")
	phazed_bt.set_buff_tooltip(YtUtils.text("TILM"))


func on_damage(event: YtEvent):
	phazed_bt.apply_custom_timed(tower, event.get_target(), _stats.value + _stats.value_add * tower.get_level(), _stats.duration + tower.get_level() * 0.1)
