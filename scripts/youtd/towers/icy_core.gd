extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var aura_bt: YtBuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {mod_movespeed = 0.15, mod_movespeed_add = 0.004},
		2: {mod_movespeed = 0.25, mod_movespeed_add = 0.006},
	}


func tower_init():
	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", false, self)
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, -_stats.mod_movespeed, -_stats.mod_movespeed_add)
	aura_bt.set_buff_modifier(mod)
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/barefoot.tres")
	aura_bt.set_buff_tooltip(YtUtils.text("BHFS"))
