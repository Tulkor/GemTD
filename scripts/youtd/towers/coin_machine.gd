extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var golden_bt: YtBuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {mod_income = 0.05, buff_duration = 10, mod_bounty_gain = 0.40, gold_per_cast = 5},
		2: {mod_income = 0.10, buff_duration = 12, mod_bounty_gain = 0.60, gold_per_cast = 7},
	}


const AUTOCAST_RANGE: float = 400
const BUFF_DURATION_ADD: float = 0.4
const MOD_BOUNTY_GAIN_ADD: float = 0.006


func tower_init():
	golden_bt = YtBuffType.new("golden_bt", _stats.buff_duration, BUFF_DURATION_ADD, true, self)
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_BOUNTY_RECEIVED, _stats.mod_bounty_gain, MOD_BOUNTY_GAIN_ADD)
	golden_bt.set_buff_modifier(mod)
	golden_bt.set_buff_icon("res://resources/icons/generic_icons/holy_grail.tres")
	golden_bt.set_buff_tooltip(YtUtils.text("W9ET"))


func on_autocast(event: YtEvent):
	var target: YtUnit = event.get_target()
	var level: int = tower.get_level()
	
	golden_bt.apply(tower, target, level)
	tower.get_player().give_gold(_stats.gold_per_cast, tower, true, true)


func on_create(_preceding: YtTower):
	tower.get_player().modify_income_rate(_stats.mod_income)


func on_destruct():
	tower.get_player().modify_income_rate(-_stats.mod_income)
