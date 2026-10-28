extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: [ORIGINAL_GAME_BUG] Fixed Awakening buff being
# applied with level 1 always. Use tower's level.

# NOTE: original script uses "frenzy" spell as a visual
# effect. Didn't implement that. Can implement using an
# YtEffect.

var awakening_bt: YtBuffType
var multiboard: YtMultiboardValues


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)
	triggers.add_event_on_kill(on_kill)


func tower_init():
	awakening_bt = YtBuffType.new("awakening_bt", 10, 0, true, self)
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 0.5, 0.02)
	mod.add_modification(YtModificationType.enm.MOD_MANA_REGEN, 20, 0.8)
	awakening_bt.set_buff_modifier(mod)
	awakening_bt.set_buff_icon("res://resources/icons/generic_icons/burning_dot.tres")
	awakening_bt.set_buff_tooltip(YtUtils.text("CYSV"))

	multiboard = YtMultiboardValues.new(2)
	var attack_speed_bonus_label: String = YtUtils.text("CYIQ")
	var mana_bonus_label: String = YtUtils.text("CUYM")
	multiboard.set_key(0, attack_speed_bonus_label)
	multiboard.set_key(1, mana_bonus_label)


func on_damage(event: YtEvent):
	var creep: YtUnit = event.get_target()
	var damage: float = (1 + 0.04 * tower.get_level()) * tower.get_overall_mana()
	var mana: float = tower.get_mana()

	if mana >= 80:
		tower.do_spell_damage(creep, damage, tower.calc_spell_crit_no_bonus())
		tower.subtract_mana(80, 0)
		YtEffect.create_scaled("res://src/effects/devour.tscn", Vector3(creep.get_x(), creep.get_y(), 30), 0, 2)


func on_kill(_event: YtEvent):
	tower.modify_property(YtModificationType.enm.MOD_ATTACKSPEED, 0.005)
	tower.user_real2 += 0.005

	if tower.user_real <= 2:
		tower.user_real += 0.01
		tower.modify_property(YtModificationType.enm.MOD_MANA, 10)


func on_tower_details() -> YtMultiboardValues:
	var attack_speed_bonus: String = YtUtils.format_percent(tower.user_real2, 1)
	var mana_bonus: String = str(int(tower.user_real * 1000))
	multiboard.set_value(0, attack_speed_bonus)
	multiboard.set_value(1, mana_bonus)
	
	return multiboard


func on_autocast(_event: YtEvent):
	awakening_bt.apply(tower, tower, tower.get_level())
