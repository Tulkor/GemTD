extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var aura_bt: YtBuffType
var slow_bt: YtBuffType


const AURA_RANGE: int = 750


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func tower_init():
	slow_bt = YtBuffType.new("slow_bt", 2, 0, false, self)
	slow_bt.set_buff_icon("res://resources/icons/generic_icons/foot_trip.tres")
	slow_bt.set_buff_tooltip(YtUtils.text("DQPN"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, -0.3, -0.01)
	slow_bt.set_buff_modifier(mod)

	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", false, self)
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/ophiucus.tres")
	aura_bt.set_buff_tooltip(YtUtils.text("KSQW"))
	aura_bt.add_periodic_event(aura_bt_periodic, 1.0)


func on_damage(event: YtEvent):
	var level: int = tower.get_level()
	var target: YtCreep = event.get_target()
	var target_is_boss: bool = target.get_size() >= YtCreepSize.enm.BOSS
	var enough_mana: bool = tower.get_mana() >= 30

	if !enough_mana:
		return

	var rift_chance: float = 0.10 + 0.004 * level
	if target_is_boss:
		rift_chance *= 0.5

	if !tower.calc_chance(rift_chance):
		return

	tower.subtract_mana(30, false)

	YtEffect.create_animated("res://src/effects/replenish_mana.tscn", tower.get_position_wc3(), 0)
	YtEffect.create_simple("res://src/effects/spell_aiil.tscn", Vector2(target.get_x(), target.get_y()))

	var move_aoe: bool = tower.calc_chance(0.15)

	if move_aoe:
		YtCombatLog.log_ability(tower, target, "Spacial Rift AoE")

		var spacial_rift_aoe_it: YtIterate = YtIterate.over_units_in_range_of_unit(tower, YtTargetType.new(YtTargetType.CREEPS), target, 175 + level)

		while true:
			var next: YtUnit = spacial_rift_aoe_it.next()

			if next == null:
				break

			move_creep_back(next)
	else:
		YtCombatLog.log_ability(tower, target, "Spacial Rift")

		move_creep_back(target)

	YtEffect.create_simple("res://src/effects/silence_area.tscn", Vector2(target.get_x(), target.get_y()))

	var slow_aoe_it: YtIterate = YtIterate.over_units_in_range_of_unit(tower, YtTargetType.new(YtTargetType.CREEPS), target, 250 + level)

	while true:
		var next: YtUnit = slow_aoe_it.next()

		if next == null:
			break

		slow_bt.apply(tower, next, level)


# NOTE: SPDamage() in original script
func aura_bt_periodic(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var creep: YtCreep = buff.get_buffed_unit()
	var damage: float = creep.get_current_movespeed() * (2.0 + 0.16 * tower.get_level())

	tower.do_spell_damage(creep, damage, tower.calc_spell_crit_no_bonus())


func move_creep_back(creep: YtUnit):
	var facing: float = creep.get_unit_facing()
	var facing_reversed: float = facing - 180
	var teleport_offset: Vector2 = Vector2(175 + tower.get_level(), 0).rotated(deg_to_rad(facing_reversed))
	var current_creep_pos: Vector2 = creep.get_position_wc3_2d()
	var new_creep_pos: Vector2 = current_creep_pos + teleport_offset
	creep.set_position_wc3_2d(new_creep_pos)
