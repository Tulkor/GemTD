extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: [ORIGINAL_GAME_BUG] Original script has a bug where
# the projectile created by aura deals 2 damage because
# do_spell_damage() is called on tower instead of
# projectile. It was intended that projectile stores damage
# ratio and then deals damage using that ratio. Fixed bug by
# not using damage ratio (not needed really) and storing
# damage in user_real of projectile.


var aura_bt: YtBuffType
var demonic_mana_bt: YtBuffType
var maledict_bt: YtBuffType
var darkness_bt: YtBuffType
var missile_pt: YtProjectileType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func tower_init():
	darkness_bt = YtBuffType.new("darkness_bt", 5, 0, false, self)
	var dave_council_darkness_mod: YtModifier = YtModifier.new()
	dave_council_darkness_mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, -0.4, -0.006)
	dave_council_darkness_mod.add_modification(YtModificationType.enm.MOD_ATK_DAMAGE_RECEIVED, -0.95, 0.0)
	darkness_bt.set_buff_modifier(dave_council_darkness_mod)
	darkness_bt.set_buff_icon("res://resources/icons/generic_icons/fire_dash.tres")
	darkness_bt.add_periodic_event(dave_council_darkness_periodic, 1.0)
	darkness_bt.add_event_on_damaged(dave_council_darkness_on_damaged)
	darkness_bt.add_event_on_expire(dave_council_darkness_on_expire)
	darkness_bt.set_buff_tooltip(YtUtils.text("XJLT"))

	maledict_bt = YtBuffType.new("maledict_bt", 5, 0, false, self)
	var dave_council_maledict_mod: YtModifier = YtModifier.new()
	dave_council_maledict_mod.add_modification(YtModificationType.enm.MOD_SPELL_DAMAGE_RECEIVED, 0.2, 0.006)
	maledict_bt.set_buff_modifier(dave_council_maledict_mod)
	maledict_bt.set_buff_icon("res://resources/icons/generic_icons/fire_dash.tres")
	maledict_bt.add_event_on_spell_targeted(dave_council_maledict_on_spell_targeted)
	maledict_bt.set_buff_tooltip(YtUtils.text("Q488"))

	demonic_mana_bt = YtBuffType.new("demonic_mana_bt", 3, 0, true, self)
	var dave_council_mana_mod: YtModifier = YtModifier.new()
	dave_council_mana_mod.add_modification(YtModificationType.enm.MOD_MANA_REGEN_PERC, 1.0, 0.02)
	demonic_mana_bt.set_buff_modifier(dave_council_mana_mod)
	demonic_mana_bt.set_buff_icon("res://resources/icons/generic_icons/star_swirl.tres")
	demonic_mana_bt.set_buff_tooltip(YtUtils.text("LN06"))

	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", true, self)
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/burning_meteor.tres")
	aura_bt.add_event_on_spell_casted(aura_bt_on_spell_casted)
	aura_bt.set_buff_tooltip(YtUtils.text("RTYZ"))

	missile_pt = YtProjectileType.create("path_to_projectile_sprite", 4, 1300, self)
	missile_pt.enable_homing(missile_pt_on_hit, 0)


func on_damage(event: YtEvent):
	var creep: YtUnit = event.get_target()
	var level: int = tower.get_level()
	var maledict_chance: float = 0.2 + 0.004 * level

	if !tower.calc_chance(maledict_chance):
		return

	YtCombatLog.log_ability(tower, creep, "Maledict")

	maledict_bt.apply(tower, creep, level)


func on_autocast(event: YtEvent):
	var target: YtUnit = event.get_target()
	var level: int = tower.get_level()
	darkness_bt.apply(tower, target, level)


func aura_bt_on_spell_casted(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var target: YtUnit = event.get_target()
	var caster: YtTower = buff.get_buffed_unit()
	var goldcost: float = caster.get_gold_cost()
	var cd: float = event.get_autocast_type().get_cooldown()
	var projectile_damage: float = 2 * goldcost * cd

	if !target is YtCreep:
		return
	
	YtCombatLog.log_ability(tower, target, "Demonic Edict on spell casted")
	
	YtEffect.create_simple_at_unit("res://src/effects/death_coil.tscn", target)
	var p: YtProjectile = YtProjectile.create_from_unit_to_unit(missile_pt, tower, 1.0, 1.0, caster, target, true, false, true)
	p.user_real = projectile_damage
	demonic_mana_bt.apply(tower, caster, tower.get_level())


func missile_pt_on_hit(p: YtProjectile, creep: YtUnit):
	if creep == null:
		return

	var projectile_damage: float = p.user_real
	tower.do_spell_damage(creep, projectile_damage, tower.calc_spell_crit_no_bonus())


func dave_council_maledict_on_spell_targeted(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var caster: YtTower = event.get_target()
	var target: YtUnit = buff.get_buffed_unit()
	var gold: float = caster.get_gold_cost()
	var maledict_damage: float = 3 * gold

	if target.is_immune():
		return

	YtCombatLog.log_ability(tower, target, "Impenetrable Darkness periodic")
	
	tower.do_spell_damage(target, maledict_damage, tower.calc_spell_crit_no_bonus())
	YtEffect.create_simple_at_unit("res://src/effects/death_and_decay.tscn", target)
	YtSFX.sfx_at_unit(YtSfxPaths.GHOST_EXHALE, target)


func dave_council_darkness_periodic(event: YtEvent):
	var target: YtUnit = event.get_target()
	var level: int = tower.get_level()
	var damage: float = 1000 + 40 * level

	YtCombatLog.log_ability(tower, target, "Maledict on spell targeted")
	
	tower.do_spell_damage(target, damage, tower.calc_spell_crit_no_bonus())


func dave_council_darkness_on_damaged(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var stored_damage: float = buff.user_real
	stored_damage += event.damage
	buff.user_real = stored_damage


func dave_council_darkness_on_expire(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var level: int = tower.get_level()
	var target: YtUnit = buff.get_buffed_unit()
	var stored_damage: float = buff.user_real
	var damage_multiplier: float = 0.75 + 0.01 * level
	var final_damage: float = stored_damage * damage_multiplier

	YtCombatLog.log_ability(tower, target, "Impenetrable Darkness on expire")

	tower.do_spell_damage(target, final_damage, 1)
	YtEffect.create_simple_at_unit("res://src/effects/death_coil.tscn", target)

	var floating_text: String = YtUtils.format_float(final_damage, 0)
	tower.get_player().display_floating_text(floating_text, target, Color8(50, 50, 50))
