extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: made changes to original script but overall
# it's the same logic.


# NOTE: tower increases dmg against only one category at a
# time (for other towers). This is intentional and works
# like this in original game.


var aura_bt: YtBuffType
var undead_bt: YtBuffType
var magic_bt: YtBuffType
var nature_bt: YtBuffType
var orc_bt: YtBuffType
var humanoid_bt: YtBuffType


var bonus_levels_in_progress: bool = false
var force_show_research_message: bool = false
# which creep type i attacked - that's the type i'll buff next
var current_creep_category: YtCreepCategory.enm = YtCreepCategory.enm.UNDEAD
# memory of prev. attacked creep type
var prev_creep_category: YtCreepCategory.enm = YtCreepCategory.enm.UNDEAD
var bonus_map: Dictionary = {
	YtCreepCategory.enm.UNDEAD: 0,
	YtCreepCategory.enm.MAGIC: 0,
	YtCreepCategory.enm.NATURE: 0,
	YtCreepCategory.enm.ORC: 0,
	YtCreepCategory.enm.HUMANOID: 0,
	YtCreepCategory.enm.CHALLENGE: 0,
}


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)
	triggers.add_event_on_damage(on_damage)
	triggers.add_periodic_event(periodic, 6.0)


func tower_init():
	undead_bt = YtBuffType.new("undead_bt", 1, 0, true, self)
	var palandu_xeno_undead_mod: YtModifier = YtModifier.new()
	palandu_xeno_undead_mod.add_modification(YtModificationType.enm.MOD_DMG_TO_UNDEAD, 0.0, 0.001)
	undead_bt.set_buff_modifier(palandu_xeno_undead_mod)
	undead_bt.set_buff_icon("res://resources/icons/generic_icons/spell_book.tres")
	undead_bt.set_buff_tooltip(YtUtils.text("JRUK"))

	magic_bt = YtBuffType.new("magic_bt", 1, 0, true, self)
	var palandu_xeno_magic_mod: YtModifier = YtModifier.new()
	palandu_xeno_magic_mod.add_modification(YtModificationType.enm.MOD_DMG_TO_MAGIC, 0.0, 0.001)
	magic_bt.set_buff_modifier(palandu_xeno_magic_mod)
	magic_bt.set_buff_icon("res://resources/icons/generic_icons/spell_book.tres")
	magic_bt.set_buff_tooltip(YtUtils.text("O429"))

	nature_bt = YtBuffType.new("nature_bt", 1, 0, true, self)
	var palandu_xeno_nature_mod: YtModifier = YtModifier.new()
	palandu_xeno_nature_mod.add_modification(YtModificationType.enm.MOD_DMG_TO_NATURE, 0.0, 0.001)
	nature_bt.set_buff_modifier(palandu_xeno_nature_mod)
	nature_bt.set_buff_icon("res://resources/icons/generic_icons/spell_book.tres")
	nature_bt.set_buff_tooltip(YtUtils.text("V3LT"))

	orc_bt = YtBuffType.new("orc_bt", 1, 0, true, self)
	var palandu_xeno_orc_mod: YtModifier = YtModifier.new()
	palandu_xeno_orc_mod.add_modification(YtModificationType.enm.MOD_DMG_TO_ORC, 0.0, 0.001)
	orc_bt.set_buff_modifier(palandu_xeno_orc_mod)
	orc_bt.set_buff_icon("res://resources/icons/generic_icons/spell_book.tres")
	orc_bt.set_buff_tooltip(YtUtils.text("BZQR"))

	humanoid_bt = YtBuffType.new("humanoid_bt", 1, 0, true, self)
	var palandu_xeno_humanoid_mod: YtModifier = YtModifier.new()
	palandu_xeno_humanoid_mod.add_modification(YtModificationType.enm.MOD_DMG_TO_HUMANOID, 0.0, 0.001)
	humanoid_bt.set_buff_modifier(palandu_xeno_humanoid_mod)
	humanoid_bt.set_buff_icon("res://resources/icons/generic_icons/spell_book.tres")
	humanoid_bt.set_buff_tooltip(YtUtils.text("UELS"))

	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", true, self)
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/spell_book.tres")
	aura_bt.set_buff_tooltip(YtUtils.text("QS5Q"))


func on_attack(event: YtEvent):
	if bonus_levels_in_progress:
		return

	var creep: YtCreep = event.get_target()
	var creep_category: YtCreepCategory.enm = creep.get_category()

	if creep.get_spawn_level() > YtUtils.get_max_level():
		bonus_levels_in_progress = true

	current_creep_category = creep_category

	var is_type_change: bool = current_creep_category != prev_creep_category
	if is_type_change:
		xeno_buff_towers(true)


func on_damage(event: YtEvent):
	if bonus_levels_in_progress:
		return
	
	var creep: YtCreep = event.get_target()
	var creep_category: YtCreepCategory.enm = creep.get_category()
	var chance: float = 0.25 + 0.01 * tower.get_level()

	if !tower.calc_chance(chance):
		return

# 	NOTE: ignore challenge creeps
	if creep_category == YtCreepCategory.enm.CHALLENGE:
		return

	var bonus_max: int = 250 + 10 * tower.get_level()
	var current_bonus: int = bonus_map[creep_category]

	if current_bonus >= bonus_max:
		return

	YtCombatLog.log_ability(tower, creep, "Sample Collection")

	var sample_collected_text: String = YtUtils.text("Q346")
	tower.get_player().display_small_floating_text(sample_collected_text, creep, Color8(200, 200, 200), 40.0)
	var new_bonus: int = min(current_bonus + 50, bonus_max)
	bonus_map[creep_category] = new_bonus
	force_show_research_message = true


func periodic(_event: YtEvent):
	if !bonus_levels_in_progress:
		xeno_buff_towers(current_creep_category != prev_creep_category)


func xeno_manage_bonuses(is_type_change: bool, current_bonus: int):
# 	NOTE: ignore challenge creeps
	if current_creep_category == YtCreepCategory.enm.CHALLENGE:
		return

	if is_type_change:
#		NOTE: sort keys to ensure deterministic iteration order for multiplayer sync
		var sorted_category_keys: Array = bonus_map.keys()
		sorted_category_keys.sort()
		for category in sorted_category_keys:
			bonus_map[category] = bonus_map[category] / 2
#		now restore the correct one :P
		bonus_map[current_creep_category] = current_bonus

#	now set the correct race bonuses for this tower
#	NOTE: sort keys to ensure deterministic iteration order for multiplayer sync
	var sorted_bonus_keys: Array = bonus_map.keys()
	sorted_bonus_keys.sort()
	for category in sorted_bonus_keys:
		var ideal_bonus: float = 1.0 + bonus_map[category] / 1000.0
		var current_race_bonus: float = tower.get_damage_to_category(category)
		var mod_type: YtModificationType.enm = YtCreepCategory.convert_to_mod_dmg_type(category)

		if ideal_bonus != current_race_bonus:
			var delta: float = ideal_bonus - current_race_bonus
			tower.modify_property(mod_type, delta)


func xeno_buff_towers(is_type_change: bool):
# 	NOTE: ignore challenge creeps
	if current_creep_category == YtCreepCategory.enm.CHALLENGE:
		return

	var buff_level: int = bonus_map[current_creep_category]
	prev_creep_category = current_creep_category

	var category_string = YtCreepCategory.get_display_string(current_creep_category)
	var category_color: Color = YtCreepCategory.get_color(current_creep_category)
	var research_published_text: String = YtUtils.text("E2IZ").format({CREEP_RACE = category_string})

	if (is_type_change && buff_level > 0) || force_show_research_message:
		tower.get_player().display_floating_text(research_published_text, tower, category_color)
		force_show_research_message = false

	var category_to_bt: Dictionary = {
		YtCreepCategory.enm.UNDEAD: undead_bt,
		YtCreepCategory.enm.MAGIC: magic_bt,
		YtCreepCategory.enm.NATURE: nature_bt,
		YtCreepCategory.enm.ORC: orc_bt,
		YtCreepCategory.enm.HUMANOID: humanoid_bt,
		YtCreepCategory.enm.CHALLENGE: humanoid_bt,
	}
	var selected_buff: YtBuffType = category_to_bt[current_creep_category]

	xeno_manage_bonuses(is_type_change, buff_level)

	if buff_level <= 0:
		return

#	larger AoE needed as aura centre seems to be diff + collision problems
	var towers_in_aura: YtIterate = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.TOWERS), 315)

	while true:
		var next_tower: YtTower = towers_in_aura.next()

		if next_tower == null:
			break

		var tower_is_self: bool = next_tower == tower
		if tower_is_self:
			continue

		var tower_is_in_aura: bool = next_tower.get_buff_of_type(aura_bt) != null

		if tower_is_in_aura:
#			NOTE: divide by tower buff duration to force
#			duration to always be 6.5 seconds. (duration is
#			multiplied by tower buff duration during
#			apply()).
			var buff_duration: float = 6.5 / tower.get_prop_buff_duration()
			selected_buff.apply_custom_timed(tower, next_tower, buff_level, buff_duration)
