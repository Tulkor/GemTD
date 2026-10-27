extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: [ORIGINAL_GAME_BUG] Original script appears to be
# completely broken? It uses addEventOnDamage() which means
# that the handler will be called when creep *deals damage*
# and that's clearly not what's supposed to happen. Fixed it
# by switching to addEventOnDamaged()/add_event_on_damaged()
# so that the handler which increases damage taken by creep
# is called when creep takes damage.

# NOTE: [ORIGINAL_GAME_BUG] Fixed Fear the Dark behavior:
# "each creep in range decreases the effect by 25%, creeps
# with this buff don't count".
# - Ability description states that "creeps with this buff
#   don't count".
# - YtTower behavior in original game is the opposite - creeps
#   with the buff count and creeps without buff don't count.
# 
# Assume that ability description is the correct behavior,
# so made the behavior work like in description.

# NOTE: the trigger chance for Fear the Dark ability appears
# to have been changed often. Used 20% which is the value on
# youtd.best and appears to be the most recent.


var fear_dark_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func tower_init():
	fear_dark_bt = YtBuffType.new("fear_dark_bt", 5, 0.1, false, self)
	fear_dark_bt.set_buff_icon("res://resources/icons/generic_icons/ghost.tres")
	fear_dark_bt.set_buff_tooltip(YtUtils.text("EZS3"))
	fear_dark_bt.add_event_on_create(fear_dark_bt_on_create)
	fear_dark_bt.add_event_on_cleanup(fear_dark_bt_on_cleanup)
	fear_dark_bt.add_event_on_damaged(fear_dark_bt_on_damaged)
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, -0.5, 0.0)
	mod.add_modification(YtModificationType.enm.MOD_HP_REGEN_PERC, -0.5, -0.01)
	mod.add_modification(YtModificationType.enm.MOD_ARMOR_PERC, 0.5, -0.008)
	mod.add_modification(YtModificationType.enm.MOD_ITEM_QUALITY_ON_DEATH, 0.25, 0.01)
	fear_dark_bt.set_buff_modifier(mod)


func on_damage(event: YtEvent):
	var chance: float = 0.20 + 0.004 * tower.get_level()

	if !tower.calc_chance(chance):
		return

	YtCombatLog.log_ability(tower, event.get_target(), "Fear the Dark")

	fear_dark_bt.apply(tower, event.get_target(), tower.get_level())


# NOTE: startA() in original script
func fear_dark_bt_on_create(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var unit: YtUnit = buff.get_buffed_unit()
	unit.set_sprite_color(Color8(125, 125, 125, 255))


# NOTE: clean() in original script
func fear_dark_bt_on_cleanup(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var unit: YtUnit = buff.get_buffed_unit()
	unit.set_sprite_color(Color8(255, 255, 255, 255))


# NOTE: dmg() in original script
func fear_dark_bt_on_damaged(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var caster: YtTower = buff.get_caster()
	var target: YtUnit = buff.get_buffed_unit()
	var it: YtIterate = YtIterate.over_units_in_range_of_unit(caster, YtTargetType.new(YtTargetType.CREEPS), target, 500)

	var damage_increase: float = 0.30 + 0.012 * caster.get_level()
	if target.get_size() >= YtCreepSize.enm.BOSS:
		damage_increase *= 0.5

	while true:
		var creep: YtUnit = it.next()
		if creep == null:
			break

		var creep_has_buff: bool = creep.get_buff_of_type(fear_dark_bt) != null

		if creep_has_buff:
			continue

		damage_increase *= 0.75

	event.damage *= (1.0 + damage_increase)
