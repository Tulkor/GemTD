extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: [ORIGINAL_GAME_DEVIATION] Original script uses
# "acidbomb" cast for the acid skull ability. Implemented it
# using regular projectile instead. Final behavior is the
# same.

# NOTE: [ORIGINAL_GAME_DEVIATION] Original script applies
# armor debuffs before acid skull hits the targets. That is
# weird, changed it so that debuffs are applied after the
# projectile hits the target.


var acid_skull_bt: YtBuffType
var soulsteal_bt: YtBuffType
var aura_bt: YtBuffType
var acid_skull_pt: YtProjectileType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)
	triggers.add_event_on_damage(on_damage)


func tower_init():
	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", false, self)
	var sir_soul_vault_aura_mod: YtModifier = YtModifier.new()
	sir_soul_vault_aura_mod.add_modification(YtModificationType.enm.MOD_ARMOR_PERC, -0.25, -0.002)
	aura_bt.set_buff_modifier(sir_soul_vault_aura_mod)
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/open_wound.tres")
	aura_bt.set_buff_tooltip(YtUtils.text("RGDD"))

	acid_skull_bt = YtBuffType.new("acid_skull_bt", 4.5, 0, false, self)
	var sir_soul_vault_acid_skull_mod: YtModifier = YtModifier.new()
	sir_soul_vault_acid_skull_mod.add_modification(YtModificationType.enm.MOD_ARMOR, 0.50, 0.02)
	acid_skull_bt.set_buff_modifier(sir_soul_vault_acid_skull_mod)
	acid_skull_bt.set_buff_icon("res://resources/icons/generic_icons/poison_gas.tres")
	acid_skull_bt.set_buff_tooltip(YtUtils.text("Y5US"))

	soulsteal_bt = YtBuffType.new("soulsteal_bt", 1000, 0, false, self)
	var sir_soul_vault_soulsteal_mod: YtModifier = YtModifier.new()
	sir_soul_vault_soulsteal_mod.add_modification(YtModificationType.enm.MOD_SPELL_DAMAGE_RECEIVED, 0.50, 0.02)
	soulsteal_bt.set_buff_modifier(sir_soul_vault_soulsteal_mod)
	soulsteal_bt.set_buff_icon("res://resources/icons/generic_icons/ghost.tres")
	soulsteal_bt.set_buff_tooltip(YtUtils.text("MJC1"))

	acid_skull_pt = YtProjectileType.create("path_to_projectile_sprite", 20, 700, self)
	acid_skull_pt.enable_homing(acid_skull_pt_on_hit, 0)


func on_attack(event: YtEvent):
	var target: YtUnit = event.get_target()
	var acid_skull_chance: float = 0.25 + 0.004 * tower.get_level()

	if !tower.calc_chance(acid_skull_chance):
		return

	YtCombatLog.log_ability(tower, target, "Acid Skull")

	YtProjectile.create_from_unit_to_unit(acid_skull_pt, tower, 1.0, 1.0, tower, target, true, false, false)


func on_damage(event: YtEvent):
	var target: YtUnit = event.get_target()
	var soulsteal_chance: float = 0.125 + 0.001 * tower.get_level()

	if !tower.calc_chance(soulsteal_chance):
		return

	YtCombatLog.log_ability(tower, target, "Soul Steal")

	soulsteal_bt.apply(tower, target, tower.get_level())


func acid_skull_pt_on_hit(_projectile: YtProjectile, target: YtUnit):
	if target == null:
		return

	var it: YtIterate = YtIterate.over_units_in_range_of_unit(tower, YtTargetType.new(YtTargetType.CREEPS), target, 225)

	while true:
		var next: YtUnit = it.next()

		if next == null:
			break

		var is_main_target: bool = next == target

		var skull_damage: float
		if is_main_target:
			skull_damage = 1800 * (1.0 + 0.05 * tower.get_level())
		else:
			skull_damage = 1440 * (1.0 + 0.05 * tower.get_level())

		tower.do_spell_damage(next, skull_damage, tower.calc_spell_crit_no_bonus())
		acid_skull_bt.apply(tower, next, tower.get_level())
