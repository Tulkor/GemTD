extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var fire_bt: YtBuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {mod_crit = 0.050, mod_crit_add = 0.002},
		2: {mod_crit = 0.075, mod_crit_add = 0.003},
		3: {mod_crit = 0.100, mod_crit_add = 0.004},
	}


func tower_init():
	var m: YtModifier = YtModifier.new()
	m.add_modification(YtModificationType.enm.MOD_ATK_CRIT_CHANCE, _stats.mod_crit, _stats.mod_crit_add)
	fire_bt = YtBuffType.create_aura_effect_type("fire_bt", true, self)
	fire_bt.set_buff_icon("res://resources/icons/generic_icons/shiny_omega.tres")
	fire_bt.set_buff_modifier(m)
	fire_bt.set_buff_tooltip(YtUtils.text("SMKF"))
