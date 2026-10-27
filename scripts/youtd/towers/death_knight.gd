extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var will_positive_bt: YtBuffType
var will_negative_bt: YtBuffType
var withering_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)
	triggers.add_event_on_kill(on_kill)
	triggers.add_event_on_unit_comes_in_range(on_unit_in_range, 900, YtTargetType.new(YtTargetType.CREEPS))


func tower_init():
	will_positive_bt = YtBuffType.new("will_positive_bt", 5, 0, true, self)
	var will_positive_bt_mod: YtModifier = YtModifier.new()
	will_positive_bt_mod.add_modification(YtModificationType.enm.MOD_DAMAGE_BASE_PERC, 0.0, 0.002)
	will_positive_bt.set_buff_modifier(will_positive_bt_mod)
	will_positive_bt.set_buff_icon("res://resources/icons/generic_icons/alien_skull.tres")
	will_positive_bt.set_buff_tooltip(YtUtils.text("Q60A"))

	will_negative_bt = YtBuffType.new("will_negative_bt", 5, 0, false, self)
	var will_negative_bt_mod: YtModifier = YtModifier.new()
	will_negative_bt_mod.add_modification(YtModificationType.enm.MOD_DAMAGE_BASE_PERC, 0.0, -0.002)
	will_negative_bt.set_buff_modifier(will_negative_bt_mod)
	will_negative_bt.set_buff_icon("res://resources/icons/generic_icons/pisces.tres")
	will_negative_bt.set_buff_tooltip(YtUtils.text("BK97"))

	withering_bt = YtBuffType.new("withering_bt", 4, 0, false, self)
	var withering_bt_mod: YtModifier = YtModifier.new()
	withering_bt_mod.add_modification(YtModificationType.enm.MOD_HP_REGEN_PERC, -0.5, -0.1)
	withering_bt_mod.add_modification(YtModificationType.enm.MOD_EXP_GRANTED, -0.5, 0.01)
	withering_bt_mod.add_modification(YtModificationType.enm.MOD_BOUNTY_GRANTED, -0.5, 0.01)
	withering_bt.set_buff_modifier(withering_bt_mod)
	withering_bt.set_buff_icon("res://resources/icons/generic_icons/ghost.tres")
	withering_bt.set_buff_tooltip(YtUtils.text("JRGL"))
	withering_bt.add_periodic_event(withering_bt_periodic, 1.0)


func on_damage(event: YtEvent):
	var level: int = tower.get_level()
	var mana: float = tower.get_mana()
	var max_mana: float = tower.get_overall_mana()
	var mana_gain: float = max_mana * 0.01
	var damage_bonus_from_mana: float = event.damage * (max_mana - mana) * (0.025 + 0.001 * level)

	tower.add_mana(mana_gain)
	event.damage += damage_bonus_from_mana


func on_kill(_event: YtEvent):
	var max_mana: float = tower.get_overall_mana()
	var mana_gain: float = max_mana * 0.05

	tower.add_mana(mana_gain)


func on_unit_in_range(event: YtEvent):
	var target: YtUnit = event.get_target()
	var level: int = tower.get_level()
	var withering_presence_chance: float = 0.15 + 0.004 * level

	if !tower.calc_chance(withering_presence_chance):
		return

	YtCombatLog.log_ability(tower, target, "Withering Presence")

	withering_bt.apply(tower, target, level)


func on_autocast(_event: YtEvent):
	var level: int = tower.get_level()
	var it: YtIterate = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.TOWERS), 200)
	var mana: float = tower.get_mana()
	var tower_count: int = 0

	tower.set_mana(mana / 2)

	while true:
		var next: YtUnit = it.next()

		if next == null:
			break

		if next == tower || next.get_gold_cost() < 1300:
			continue

		tower_count += 1

		will_negative_bt.apply(tower, next, 50 + level)

	if tower_count > 0:
		will_positive_bt.apply(tower, tower, (75 + level) * tower_count)

	if tower_count == 0:
		YtCombatLog.log_ability(tower, null, "Will of the Undying failed because nearby towers are cheap")


func withering_bt_periodic(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var buffed_unit: YtUnit = buff.get_buffed_unit()
	var hp: float = buffed_unit.get_health()
	var hp_loss: float = hp * 0.05

	buffed_unit.set_health(hp - hp_loss)
