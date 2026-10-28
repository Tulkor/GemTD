extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: [ORIGINAL_GAME_BUG] Fixed bug which happened if
# robot ability failed to find a target. It would do an
# early return and stop emitter from happening. Note that
# this bug is not critical because robot ability almost
# always finds a target because there are many towers
# nearby.

# NOTE: original script used same YtProjectileType for robot
# and emitter. Created separate PT for emitter.


var sapper_pt: YtProjectileType
var robot_pt: YtProjectileType
var emitter_pt: YtProjectileType
var sapper_bt: YtBuffType
var robot_bt: YtBuffType
var emitter_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func tower_init():
	sapper_pt = YtProjectileType.create("path_to_projectile_sprite", 20, 700, self)
	sapper_pt.enable_homing(sapper_pt_on_hit, 0)

	robot_pt = YtProjectileType.create_interpolate("path_to_projectile_sprite", 200, self)
	robot_pt.set_event_on_interpolation_finished(robot_pt_on_hit)

	emitter_pt = YtProjectileType.create_interpolate("path_to_projectile_sprite", 200, self)
	emitter_pt.set_event_on_interpolation_finished(emitter_pt_on_hit)

	sapper_bt = YtBuffType.new("sapper_bt", 3, 0, false, self)
	var cedi_goblin_sapper_mod: YtModifier = YtModifier.new()
	cedi_goblin_sapper_mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, 0.0, -0.001)
	sapper_bt.set_buff_modifier(cedi_goblin_sapper_mod)
	sapper_bt.set_buff_icon("res://resources/icons/generic_icons/barefoot.tres")
	sapper_bt.set_buff_tooltip(YtUtils.text("SBOV"))

	robot_bt = YtBuffType.new("robot_bt", 5, 0, true, self)
	var cedi_goblin_robot_mod: YtModifier = YtModifier.new()
	cedi_goblin_robot_mod.add_modification(YtModificationType.enm.MOD_DAMAGE_ADD_PERC, 0.0, 0.001)
	cedi_goblin_robot_mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 0.0, 0.001)
	robot_bt.set_buff_modifier(cedi_goblin_robot_mod)
	robot_bt.set_buff_icon("res://resources/icons/generic_icons/cog.tres")
	robot_bt.set_special_effect("res://src/effects/holy_bolt.tscn", 100, 1.0)
	robot_bt.set_buff_tooltip(YtUtils.text("ZENW"))

	emitter_bt = YtBuffType.new("emitter_bt", 5, 0, true, self)
	var cedi_goblin_emitter_mod: YtModifier = YtModifier.new()
	cedi_goblin_emitter_mod.add_modification(YtModificationType.enm.MOD_TRIGGER_CHANCES, 0.0, 0.001)
	emitter_bt.set_buff_modifier(cedi_goblin_emitter_mod)
	emitter_bt.set_buff_icon("res://resources/icons/generic_icons/azul_flake.tres")
	emitter_bt.set_special_effect("res://src/effects/frost_bolt_missile.tscn", 100, 1.0)
	emitter_bt.set_buff_tooltip(YtUtils.text("KB5O"))


func on_attack(event: YtEvent):
	var target: YtUnit = event.get_target()
	var level: int = tower.get_level()
#	NOTE: it's the same chance value for all 3 abilities
	var chance: float = 0.20 + 0.004 * level
	var do_sapper: bool = tower.calc_chance(chance)
	var do_robot: bool = tower.calc_chance(chance)
	var do_emitter: bool = tower.calc_chance(chance)

	if do_sapper:
		YtCombatLog.log_ability(tower, target, "Goblin Sapper")
		YtProjectile.create_from_unit_to_unit(sapper_pt, tower, 1.0, 1.0, tower, target, true, false, false)

	if do_robot:
		YtCombatLog.log_ability(tower, target, "Clockwork Engineer")
		var it: YtIterate = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.TOWERS), 500)
		var next: YtUnit = it.next_random()

#		Don't target self
		if next == tower:
			next = it.next_random()

		if next != null:
			YtProjectile.create_linear_interpolation_from_unit_to_unit(robot_pt, tower, 1.0, 1.0, tower, next, 0.35, true)

	if do_emitter:
		YtCombatLog.log_ability(tower, null, "Probability Field Emitter")
		var it: YtIterate = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.TOWERS), 500)
		var next: YtUnit = it.next_random()

#		Don't target self
		if next == tower:
			next = it.next_random()

		if next != null:
			var projectile: YtProjectile = YtProjectile.create_linear_interpolation_from_unit_to_unit(emitter_pt, tower, 1.0, 1.0, tower, next, 0.33, true)
			var emitter_buff_level: int = YtGlobals.synced_rng.randi_range(300, 600) + 6 * level
			projectile.user_int = emitter_buff_level

	var used_ability: bool = do_sapper || do_robot || do_emitter
	if !used_ability:
		YtCombatLog.log_ability(tower, null, "Reimbursement")
		tower.get_player().give_gold(5, tower, true, true)


func sapper_pt_on_hit(projectile: YtProjectile, target: YtUnit):
	if target == null:
		return

	var level: int = tower.get_level()
	var sapper_damage: float = YtGlobals.synced_rng.randi_range(1350, 7650) + 180 * level
	var slow_buff_level: int = YtGlobals.synced_rng.randi_range(250, 450) + 6 * level

	if tower == null:
		return

	var slow_text: String = YtUtils.text("EMCY") % (slow_buff_level / 10) 
	tower.get_player().display_small_floating_text(slow_text, target, Color8(100, 100, 255), 40)

	YtEffect.add_special_effect("res://src/effects/frag_boom_spawn.tscn", Vector2(projectile.get_x(), projectile.get_y()))

	var it: YtIterate = YtIterate.over_units_in_range_of_unit(tower, YtTargetType.new(YtTargetType.CREEPS), target, 250)
	
	while true:
		var next: YtUnit = it.next()

		if next == null:
			break

		tower.do_spell_damage(next, sapper_damage, tower.calc_spell_crit_no_bonus())
		sapper_bt.apply(tower, next, slow_buff_level)


func robot_pt_on_hit(_projectile: YtProjectile, target: YtUnit):
	if target == null:
		return

	var level: int = tower.get_level()
	var buff_level: int = YtGlobals.synced_rng.randi_range(100, 400) + 6 * level

	if tower == null:
		return

	robot_bt.apply(tower, target, buff_level)

	var attackspeed_and_dmg_text: String = YtUtils.text("F7DM") % (buff_level / 10) 
	tower.get_player().display_small_floating_text(attackspeed_and_dmg_text, target, Color8(100, 255, 100), 40)


func emitter_pt_on_hit(_projectile: YtProjectile, target: YtUnit):
	if target == null:
		return

	var level: int = tower.get_level()
	var buff_level: int = YtGlobals.synced_rng.randi_range(300, 600) + 6 * level

	if tower == null:
		return

	emitter_bt.apply(tower, target, buff_level)

	var trigger_chances_text: String = YtUtils.text("R735") % (buff_level / 10) 
	tower.get_player().display_small_floating_text(trigger_chances_text, target, Color8(100, 255, 100), 40)
