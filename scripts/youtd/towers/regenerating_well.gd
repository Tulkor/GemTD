extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: [ORIGINAL_GAME_BUG] changed autocast type
# AC_TYPE_ALWAYS_BUFF->AC_TYPE_ALWAYS_IMMEDIATE because the
# autocast is an AoE effect. Original script must have used
# AC_TYPE_ALWAYS_BUFF by mistake.


var aura_bt: YtBuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {replenish_mana = 0.10, replenish_mana_add = 0.004, mod_spell_dmg = 0.15, mod_spell_dmg_add = 0.006},
		2: {replenish_mana = 0.15, replenish_mana_add = 0.006, mod_spell_dmg = 0.20, mod_spell_dmg_add = 0.008},
		3: {replenish_mana = 0.20, replenish_mana_add = 0.008, mod_spell_dmg = 0.25, mod_spell_dmg_add = 0.010},
	}


func tower_init():
	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", true, self)
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_SPELL_DAMAGE_DEALT, _stats.mod_spell_dmg, _stats.mod_spell_dmg_add)
	aura_bt.set_buff_modifier(mod)
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/atomic_slashes.tres")
	aura_bt.set_buff_tooltip(YtUtils.text("B1E6"))


func on_autocast(_event: YtEvent):
	var towers_in_range: YtIterate = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.TOWERS), 500)
	var mana_gain_ratio: float = _stats.replenish_mana + _stats.replenish_mana_add * tower.get_level()

	while true:
		var target: YtUnit = towers_in_range.next()

		if target == null:
			break

		var is_same_family: bool = target.get_family() == tower.get_family()

		var replenish_mana: float
		if is_same_family:
			replenish_mana = target.get_overall_mana() * mana_gain_ratio * 0.5
		else:
			replenish_mana = target.get_overall_mana() * mana_gain_ratio

		target.add_mana(replenish_mana)
