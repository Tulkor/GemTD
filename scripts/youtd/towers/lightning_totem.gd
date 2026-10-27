extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var aura_bt : YtBuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {mod_spell_crit = 0.10},
		2: {mod_spell_crit = 0.15},
		3: {mod_spell_crit = 0.20},
	}


const MOD_SPELL_CRIT_ADD: float = 0.002


func tower_init():
	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", true, self)
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_SPELL_CRIT_CHANCE, _stats.mod_spell_crit, MOD_SPELL_CRIT_ADD)
	aura_bt.set_buff_modifier(mod)
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/polar_star.tres")
	aura_bt.set_buff_tooltip(YtUtils.text("D49Z"))
