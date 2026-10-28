extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var slow_bt: YtBuffType


const SLOW_DURATION: float = 4.0


func get_tier_stats() -> Dictionary:
	return {
		1: {mod_movespeed = 0.18, mod_movespeed_add = 0.0040},
		2: {mod_movespeed = 0.24, mod_movespeed_add = 0.0045},
		3: {mod_movespeed = 0.30, mod_movespeed_add = 0.0050},
	}


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func tower_init():
	slow_bt = YtBuffType.new("slow_bt", SLOW_DURATION, 0, false, self)
	var slow_bt_mod: YtModifier = YtModifier.new()
	slow_bt_mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, -_stats.mod_movespeed, -_stats.mod_movespeed_add)
	slow_bt.set_buff_icon("res://resources/icons/generic_icons/foot_trip.tres")
	slow_bt.set_buff_modifier(slow_bt_mod)
	slow_bt.set_buff_tooltip(YtUtils.text("YCQN"))


func on_damage(event: YtEvent):
	var target: YtUnit = event.get_target()
	var level: int = tower.get_level()

	slow_bt.apply(tower, target, level)
