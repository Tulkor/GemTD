extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var extract_bt: YtBuffType
var channel_bt: YtBuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {extract_exp = 1, extract_exp_add = 0.05, channel_exp = 1, channel_mod_dmg = 0.15, channel_buff_duration = 10},
		2: {extract_exp = 2, extract_exp_add = 0.10, channel_exp = 2, channel_mod_dmg = 0.20, channel_buff_duration = 12},
	}


const EXTRACT_CHANCE: float = 0.33
const EXTRACT_DURATION: float = 10.0
const EXTRACT_COUNT: int = 10
const EXTRACT_COUNT_ADD: int = 1
const CHANNEL_MOD_DMG_ADD: float = 0.005
const CHANNEL_BUFF_DURATION_ADD: float = 0.1
const CHANNEL_STACK_COUNT: int = 15


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_spell_targeted(on_spell_target)


func tower_init():
	extract_bt = YtBuffType.new("extract_bt", EXTRACT_DURATION, 0, false, self)
	extract_bt.add_event_on_damaged(extract_bt_on_damaged)
	extract_bt.set_buff_icon("res://resources/icons/generic_icons/gold_bar.tres")
	extract_bt.set_buff_tooltip(YtUtils.text("PGA5"))

	channel_bt = YtBuffType.new("channel_bt", -1, 0, true, self)
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_DAMAGE_ADD_PERC, 0.0, 0.001)
	channel_bt.set_buff_modifier(mod)
	channel_bt.set_buff_icon("res://resources/icons/generic_icons/aquarius.tres")
	channel_bt.set_buff_tooltip(YtUtils.text("ETOI"))


func on_spell_target(event: YtEvent):
	var caster: YtUnit = event.get_target()
	var buff: YtBuff = tower.get_buff_of_type(channel_bt)
	var tower_level: int = tower.get_level()
	var buff_level: int = int((_stats.channel_mod_dmg + CHANNEL_MOD_DMG_ADD * tower_level) * 1000)
	var stack_duration: float = _stats.channel_buff_duration + CHANNEL_BUFF_DURATION_ADD * tower_level

	if !caster is YtTower:
		return

	caster.add_exp(1)

	if buff == null:
		buff = channel_bt.apply(tower, tower, buff_level)
		buff.user_int = 1
		buff.set_displayed_stacks(1)
	else:
		var reached_max_stacks: bool = buff.user_int >= CHANNEL_STACK_COUNT
		if reached_max_stacks:
			return

		buff.user_int += 1
		buff.set_level(buff.get_level() + buff_level)
		buff.set_displayed_stacks(buff.user_int)

	await YtUtils.create_manual_timer(stack_duration, self).timeout

	if YtUtils.unit_is_valid(tower):
		buff = tower.get_buff_of_type(channel_bt)

		if buff == null:
			return

		if buff.user_int <= 1:
			buff.remove_buff()
		else:
			buff.user_int -= 1
			buff.set_level(buff.get_level() - buff_level)
			buff.set_displayed_stacks(buff.user_int)


func on_autocast(event: YtEvent):
	var level: int = tower.get_level()
	var buff: YtBuff = extract_bt.apply(tower, event.get_target(), level)
	var extraction_count: int = EXTRACT_COUNT + EXTRACT_COUNT_ADD * level
	buff.user_int = extraction_count


func extract_bt_on_damaged(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var exp_gain: float = _stats.extract_exp + buff.get_level() * _stats.extract_exp_add
	var extract_count: int = buff.user_int

	if !tower.calc_chance(EXTRACT_CHANCE):
		return

	YtCombatLog.log_ability(tower, event.get_target(), "Extract Experience")

	if extract_count > 0:
		event.get_target().add_exp(exp_gain)
		buff.user_int -= 1
	else:
		buff.remove_buff()
