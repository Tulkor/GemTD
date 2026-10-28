extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var aura_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func tower_init():
	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", true, self)
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_TRIGGER_CHANCES, 0.30, 0.006)
	aura_bt.set_buff_modifier(mod)
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/electric.tres")
	aura_bt.set_buff_tooltip(YtUtils.text("CC46"))


func on_damage(event: YtEvent):
	var creep: YtCreep = event.get_target()
	var target_is_boss: bool = creep.get_size() >= YtCreepSize.enm.BOSS
	var chance_for_boss: float = 0.20 + 0.005 * tower.get_level()

	if target_is_boss && !tower.calc_chance(chance_for_boss):
		return

	var old_position: Vector2 = creep.get_position_wc3_2d()
	var old_path_index: int = creep._current_path_index
	var effect: int = YtEffect.create_simple_at_unit_attached("res://src/effects/mass_teleport_caster.tscn", creep, YtUnit.BodyPart.ORIGIN)
	YtEffect.set_auto_destroy_enabled(effect, false)

	await YtUtils.create_manual_timer(3.0, self).timeout

	YtEffect.destroy_effect(effect)

#	NOTE: need to also restore old path index because
#	otherwise the creep would be teleported to old position
#	but will go in a straight line towards some further path
#	point.
	if YtUtils.unit_is_valid(creep):
		creep.set_position_wc3_2d(old_position)
		creep._current_path_index = old_path_index
		YtEffect.create_simple_at_unit("res://src/effects/silence_area.tscn", creep)
