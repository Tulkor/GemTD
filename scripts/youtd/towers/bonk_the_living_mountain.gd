extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: SCALE_MIN must match the value in tower sprite
# scene
const SCALE_MIN: float = 0.5
const SCALE_MAX: float = 1.0

var stun_bt: YtBuffType
var morale_bt: YtBuffType
var grow_bt: YtBuffType
var rock_pt: YtProjectileType
var multiboard: YtMultiboardValues
var grow_count: int = 0


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)
	triggers.add_event_on_damage(on_damage)
	triggers.add_periodic_event(periodic, 25)


func tower_init():
	stun_bt = YtCbStun.new("stun_bt", 0, 0, false, self)
	
	morale_bt = YtBuffType.new("morale_bt", 10, 0, true, self)
	morale_bt.set_buff_icon("res://resources/icons/generic_icons/mighty_force.tres")
	morale_bt.set_buff_tooltip(YtUtils.text("Z5K1"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_DAMAGE_ADD_PERC, 0.10, 0.004)
	mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 0.10, 0.004)
	morale_bt.set_buff_modifier(mod)

	grow_bt = YtBuffType.new("grow_bt", -1, 0, true, self)
	grow_bt.set_buff_icon("res://resources/icons/generic_icons/biceps.tres")
	grow_bt.set_buff_tooltip(YtUtils.text("VCSG"))

	rock_pt = YtProjectileType.create("path_to_projectile_sprite", 4, 700, self)
	rock_pt.enable_homing(rock_pt_on_hit, 0)

	multiboard = YtMultiboardValues.new(1)
	var grow_count_label: String = YtUtils.text("D7GE")
	multiboard.set_key(0, grow_count_label)


func on_create(_preceding: YtTower):
	var grow_buff: YtBuff = grow_bt.apply_to_unit_permanent(tower, tower, 0)
	grow_buff.set_displayed_stacks(grow_count)


func on_attack(event: YtEvent):
	var target: YtUnit = event.get_target()
	var chance: float = 0.25
	var enough_grow_count_for_landslide: bool = grow_count >= 20

	if !tower.calc_chance(chance):
		return

	if !enough_grow_count_for_landslide:
		return

	YtCombatLog.log_ability(tower, target, "Landslide")

	var it: YtIterate = YtIterate.over_units_in_range_of_unit(tower, YtTargetType.new(YtTargetType.CREEPS), target, 300)

	while true:
		var next: YtUnit = it.next()

		if next == null:
			break

		YtProjectile.create_from_unit_to_unit(rock_pt, tower, 1.0, 0.0, tower, next, true, false, false)


func on_damage(event: YtEvent):
	var creep: YtUnit = event.get_target()
	var level: int = tower.get_level()
	var crush_damage: float = 5000 + 250 * level + 50 * grow_count

	var enough_grow_count_for_crush: bool = grow_count >= 10
	if !enough_grow_count_for_crush:
		return

	if !creep.is_stunned():
		return

	tower.do_spell_damage(creep, crush_damage, tower.calc_spell_crit_no_bonus())
	YtEffect.create_animated("res://src/effects/impale_target_dust.tscn", Vector3(creep.get_x(), creep.get_y(), 0.0), 0)

	var it: YtIterate = YtIterate.over_units_in_range_of_unit(tower, YtTargetType.new(YtTargetType.TOWERS), tower, 500)

	while true:
		var next: YtUnit = it.next()

		if next == null:
			break

		morale_bt.apply(tower, next, level)


func on_tower_details() -> YtMultiboardValues:
	multiboard.set_value(0, str(grow_count))

	return multiboard

func periodic(_event: YtEvent):
	var level: int = tower.get_level()
	var reached_max_growth: bool = grow_count >= 160

	if reached_max_growth:
		return

	var effect: int = YtEffect.create_simple_at_unit("res://src/effects/roots.tscn", tower)
	YtEffect.set_lifetime(effect, 1.0)

	tower.modify_property(YtModificationType.enm.MOD_DAMAGE_ADD_PERC, 0.03 + 0.001 * level)
	tower.add_exp(4)

	grow_count += 1

	var grow_buff: YtBuff = tower.get_buff_of_type(grow_bt)
	grow_buff.set_displayed_stacks(grow_count)

	var tower_scale: float = YtUtils.get_scale_from_grows(SCALE_MIN, SCALE_MAX, grow_count, 160)
	tower.set_unit_scale(tower_scale)


func rock_pt_on_hit(_projectile: YtProjectile, creep: YtUnit):
	if creep == null:
		return

	var damage: float = 700 + 50 * tower.get_level() + 15 * grow_count

	tower.do_spell_damage(creep, damage, tower.calc_spell_crit_no_bonus())
	stun_bt.apply_only_timed(tower, creep, 0.5)
