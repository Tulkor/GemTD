extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: [ORIGINAL_GAME_DEVIATION] Original script moves
# lifted creeps a little by random offset. Removed it
# because youtd2 creeps are supposed to always be "on
# rails", on creep path.


var ascended_bt: YtBuffType


func load_triggers(triggers_buff_type: YtBuffType):
	triggers_buff_type.add_event_on_damage(on_damage)


# NOTE: drol_lift_up() in original script
func ascended_bt_on_create(event: YtEvent):
	var b: YtBuff = event.get_buff()
	var c: YtUnit = b.get_buffed_unit()
	b.user_int = YtEffect.create_simple_at_unit_attached("res://src/effects/cyclone_target.tscn", c, YtUnit.BodyPart.ORIGIN)
	YtEffect.set_auto_destroy_enabled(b.user_int, false)
	c.adjust_height(300, 150)


# NOTE: drol_lift_period() in original script
func ascended_bt_periodic(event: YtEvent):
	var b: YtBuff = event.get_buff()
	var c: YtUnit = b.get_buffed_unit()
	c.set_unit_facing(c.get_unit_facing() + 125)


# NOTE: drol_lift_down() in original script
func ascended_bt_on_cleanup(event: YtEvent):
	var b: YtBuff = event.get_buff()
	var c: YtUnit = b.get_buffed_unit()
	c.adjust_height(-300, 2500)
	YtEffect.destroy_effect(b.user_int)
	
	YtSFX.sfx_at_unit(YtSfxPaths.CLOUD_POOF, c)
	var creep_pos: Vector2 = c.get_position_wc3_2d()
	var effect: int = YtEffect.create_simple("res://src/effects/warstomp_caster.tscn", creep_pos)
	YtEffect.set_z_index(effect, YtEffect.Z_INDEX_BELOW_CREEPS)


func item_init():
	ascended_bt = YtCbStun.new("ascended_bt", 2.0, 0, false, self)
	ascended_bt.set_buff_icon("res://resources/icons/generic_icons/rolling_energy.tres")
	ascended_bt.set_buff_tooltip(YtUtils.text("MJ83"))
	ascended_bt.add_event_on_create(ascended_bt_on_create)
	ascended_bt.add_periodic_event(ascended_bt_periodic, 0.1)
	ascended_bt.add_event_on_cleanup(ascended_bt_on_cleanup)
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_EXP_GRANTED, 0.2, 0.008)
	ascended_bt.set_buff_modifier(mod)


func on_damage(event: YtEvent):
	var tower: YtTower = item.get_carrier()
	var size: YtCreepSize.enm = event.get_target().get_size()

	if event.is_main_target() && tower.calc_chance(0.08 * tower.get_base_attack_speed()) && (size == YtCreepSize.enm.MASS || size == YtCreepSize.enm.CHALLENGE_MASS || size == YtCreepSize.enm.NORMAL):
		YtCombatLog.log_item_ability(item, null, "Ascension")
		ascended_bt.apply(tower, event.get_target(), tower.get_level())
