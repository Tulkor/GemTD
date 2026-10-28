extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var alert_bt: YtBuffType
var trespasser_bt: YtBuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {alert_duration = 5, armor_shred_chance = 0.40, armor_shred_amount = 3, armor_shred_amount_add = 0.10, awareness_duration = 5},
		2: {alert_duration = 10, armor_shred_chance = 0.50, armor_shred_amount = 4, armor_shred_amount_add = 0.15, awareness_duration = 8},
		3: {alert_duration = 15, armor_shred_chance = 0.60, armor_shred_amount = 5, armor_shred_amount_add = 0.20, awareness_duration = 12},
	}

const ARMOR_SHRED_STACKS_MAX: int = 5
const ALERT_MOD_DMG: float = 0.075
const ALERT_MOD_DMG_ADD: float = 0.005
const ALERT_RANGE: int = 500
const TRESSPASSER_RANGE: int = 925


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_unit_comes_in_range(on_unit_in_range, TRESSPASSER_RANGE, YtTargetType.new(YtTargetType.CREEPS))


func tower_init():
	alert_bt = YtBuffType.new("alert_bt", 0, 0, true, self)
	var alert_mod: YtModifier = YtModifier.new()
	alert_mod.add_modification(YtModificationType.enm.MOD_DAMAGE_BASE_PERC, ALERT_MOD_DMG, ALERT_MOD_DMG_ADD)
	alert_bt.set_buff_modifier(alert_mod)
	alert_bt.set_buff_icon("res://resources/icons/generic_icons/barbute.tres")
	alert_bt.set_buff_tooltip(YtUtils.text("RILU"))

	trespasser_bt = YtBuffType.new("trespasser_bt", -1, 0, false, self)
	var trespasser_mod: YtModifier = YtModifier.new()
	trespasser_mod.add_modification(YtModificationType.enm.MOD_ARMOR, 0.0, -0.01)
	trespasser_bt.set_buff_modifier(trespasser_mod)
	trespasser_bt.set_buff_icon("res://resources/icons/generic_icons/semi_closed_eye.tres")
	trespasser_bt.set_buff_tooltip(YtUtils.text("G6KV"))


func on_unit_in_range(event: YtEvent):
	var creep: YtUnit = event.get_target()
	var creep_size: YtCreepSize.enm = creep.get_size_including_challenge_sizes()
	var level: int = tower.get_level()
	var buff: YtBuff = creep.get_buff_of_type(trespasser_bt)

	var buff_level: int = int((_stats.armor_shred_amount + _stats.armor_shred_amount_add * level) * 100)
	if buff != null:
		buff_level = min(buff_level + buff.get_level(), buff_level * ARMOR_SHRED_STACKS_MAX)

#	NOTE: original script relies of sizes mapping to
#	specific int's. Do this mapping here instead.
	var size_multiplier_map: Dictionary = {
		YtCreepSize.enm.MASS: 1,
		YtCreepSize.enm.NORMAL: 3,
		YtCreepSize.enm.AIR: 4,
		YtCreepSize.enm.CHAMPION: 5,
		YtCreepSize.enm.CHALLENGE_MASS: 2,
		YtCreepSize.enm.BOSS: 6,
		YtCreepSize.enm.CHALLENGE_BOSS: 8,
	}
	var size_multiplier: int = size_multiplier_map[creep_size]

	var mod_damage_value: float = (0.05 + 0.001 * level) * size_multiplier

	var alert_sizes: Array[YtCreepSize.enm] = [
		YtCreepSize.enm.AIR,
		YtCreepSize.enm.CHAMPION,
		YtCreepSize.enm.BOSS,
		YtCreepSize.enm.CHALLENGE_BOSS
	]
	var size_is_big_enough_for_alert: bool = alert_sizes.has(creep_size)

	if tower.calc_chance(_stats.armor_shred_chance):
		var trespasser_buff: YtBuff = trespasser_bt.apply(tower, creep, buff_level)
		trespasser_buff.set_displayed_stacks(trespasser_buff.get_level())

	tower.modify_property(YtModificationType.enm.MOD_DAMAGE_BASE_PERC, mod_damage_value)

	if size_is_big_enough_for_alert:
		var it: YtIterate = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.TOWERS), ALERT_RANGE)

		while true:
			var next: YtUnit = it.next()

			if next == null:
				break

			var alert_duration: float = _stats.alert_duration
			alert_bt.apply_custom_timed(tower, next, 0, alert_duration)

	await YtUtils.create_manual_timer(_stats.awareness_duration, self).timeout

	if YtUtils.unit_is_valid(tower):
		tower.modify_property(YtModificationType.enm.MOD_DAMAGE_BASE_PERC, -mod_damage_value)
