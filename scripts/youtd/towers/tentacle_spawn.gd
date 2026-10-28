extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var rend_bt: YtBuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {apply_level = 1, periodic_damage = 20, periodic_damage_add = 0.8},
		2: {apply_level = 2, periodic_damage = 60, periodic_damage_add = 2.4},
		3: {apply_level = 3, periodic_damage = 120, periodic_damage_add = 4.8},
		4: {apply_level = 4, periodic_damage = 240, periodic_damage_add = 10},
		5: {apply_level = 5, periodic_damage = 480, periodic_damage_add = 20},
		6: {apply_level = 6, periodic_damage = 960, periodic_damage_add = 40},
	}


func load_triggers(triggers_buff_type: YtBuffType):
	triggers_buff_type.add_event_on_damage(on_damage)


func tower_init():
	var m: YtModifier = YtModifier.new()
	m.add_modification(YtModificationType.enm.MOD_SPELL_DAMAGE_RECEIVED, 0.02, 0.01)

	rend_bt = YtBuffType.new("rend_bt", 6, 0, false, self)
	rend_bt.set_buff_icon("res://resources/icons/generic_icons/triple_scratches.tres")
	rend_bt.add_periodic_event(drol_tentacleDamage, 1)
	rend_bt.set_buff_modifier(m)
	rend_bt.set_buff_tooltip(YtUtils.text("OH6K"))


func drol_tentacleDamage(event: YtEvent):
	var b: YtBuff = event.get_buff()

	if !b.get_buffed_unit().is_immune():
		b.get_caster().do_spell_damage(b.get_buffed_unit(), b.user_real, b.get_caster().calc_spell_crit_no_bonus())
		YtEffect.create_simple_at_unit("res://src/effects/blood_splatter.tscn", b.get_buffed_unit(), YtUnit.BodyPart.CHEST)


func on_damage(event: YtEvent):
	var target: YtUnit = event.get_target()

	if !tower.calc_chance(0.25 + tower.get_level() * 0.01):
		return

	YtCombatLog.log_ability(tower, target, "Rend")
	
	rend_bt.apply(tower, target, _stats.apply_level).user_real = _stats.periodic_damage + _stats.periodic_damage_add * tower.get_level()
