extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var aura_bt: YtBuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {mod_attack_speed = 0.10, mod_attack_speed_add = 0.0050},
		2: {mod_attack_speed = 0.15, mod_attack_speed_add = 0.0075},
		3: {mod_attack_speed = 0.20, mod_attack_speed_add = 0.0100},
	}


func tower_init():
	var m: YtModifier = YtModifier.new()
	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", true, self)
	m.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, _stats.mod_attack_speed, _stats.mod_attack_speed_add)
	aura_bt.set_buff_modifier(m)
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/aries.tres")
	aura_bt.set_buff_tooltip(YtUtils.text("GGZN"))
