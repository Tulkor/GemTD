extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var slow_bt: YtBuffType
var aura_bt: YtBuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {cursed_attack_damage = 200, cursed_attack_damage_add = 10, mod_movespeed = 0.20, mod_spell_dmg_received = 0.100, aura_effect = 0.10, aura_effect_add = 0.004},
		2: {cursed_attack_damage = 320, cursed_attack_damage_add = 16, mod_movespeed = 0.25, mod_spell_dmg_received = 0.125, aura_effect = 0.15, aura_effect_add = 0.006},
		3: {cursed_attack_damage = 560, cursed_attack_damage_add = 28, mod_movespeed = 0.30, mod_spell_dmg_received = 0.150, aura_effect = 0.20, aura_effect_add = 0.008},
	}

const CURSED_ATTACK_CHANCE: float = 0.25
const CURSED_ATTACK_CHANCE_ADD: float = 0.01
const CURSED_DURATION: float = 4
const CURSED_DURATION_ADD: float = 0.1


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func tower_init():
	slow_bt = YtBuffType.new("slow_bt", CURSED_DURATION, CURSED_DURATION_ADD, false, self)
	var slow_bt_mod: YtModifier = YtModifier.new()
	slow_bt_mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, -_stats.mod_movespeed, 0)
	slow_bt_mod.add_modification(YtModificationType.enm.MOD_SPELL_DAMAGE_RECEIVED, _stats.mod_spell_dmg_received, 0)
	slow_bt.set_buff_modifier(slow_bt_mod)
	slow_bt.set_buff_icon("res://resources/icons/generic_icons/alien_skull.tres")
	slow_bt.set_buff_tooltip(YtUtils.text("D4LZ"))

	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", true, self)
	var aura_bt_mod: YtModifier = YtModifier.new()
	aura_bt_mod.add_modification(YtModificationType.enm.MOD_DMG_TO_HUMANOID, _stats.aura_effect, _stats.aura_effect_add)
	aura_bt_mod.add_modification(YtModificationType.enm.MOD_DMG_TO_ORC, _stats.aura_effect, _stats.aura_effect_add)
	aura_bt_mod.add_modification(YtModificationType.enm.MOD_DMG_TO_NATURE, _stats.aura_effect, _stats.aura_effect_add)
	aura_bt.set_buff_modifier(aura_bt_mod)
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/over_infinity.tres")
	aura_bt.set_buff_tooltip(YtUtils.text("O5X3"))


func on_damage(event: YtEvent):
	var target: YtUnit = event.get_target()
	var level: int = tower.get_level()

	var cursed_attack_chance: float = CURSED_ATTACK_CHANCE + CURSED_ATTACK_CHANCE_ADD * level

	if !tower.calc_chance(cursed_attack_chance):
		return

	if !target.is_immune():
		YtCombatLog.log_ability(tower, target, "Cursed Attack")

		var damage: float = _stats.cursed_attack_damage + _stats.cursed_attack_damage_add * level
		tower.do_spell_damage(target, damage, tower.calc_spell_crit_no_bonus())

		slow_bt.apply(tower, target, level)
		YtEffect.create_simple_at_unit("res://src/effects/spell_aima.tscn", target)
