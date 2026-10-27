extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var aura_bt: YtBuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {damage_increase = 0.180, damage_increase_add = 0.005},
		2: {damage_increase = 0.300, damage_increase_add = 0.008},
	}


func tower_init():
	var m: YtModifier = YtModifier.new()
	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", true, self)
	m.add_modification(YtModificationType.enm.MOD_DAMAGE_ADD_PERC, _stats.damage_increase, _stats.damage_increase_add)
	aura_bt.set_buff_modifier(m)
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/angel_outfit.tres")
	aura_bt.set_buff_tooltip(YtUtils.text("LQM2"))
