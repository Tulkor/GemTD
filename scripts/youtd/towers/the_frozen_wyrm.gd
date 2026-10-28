extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var slow_bt: YtBuffType
var stun_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func tower_init():
	stun_bt = YtCbStun.new("stun_bt", 1.5, 0.0, false, self)

	slow_bt = YtBuffType.new("slow_bt", 4.0, 0.24, true, self)
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, -0.27, -0.002)
	slow_bt.set_buff_modifier(mod)
	slow_bt.set_buff_icon("res://resources/icons/generic_icons/energy_breath.tres")
	slow_bt.set_buff_tooltip(YtUtils.text("P26M"))


func on_damage(event: YtEvent):
	var level: int = tower.get_level()
	var target: YtCreep = event.get_target()
	var slow_chance: float = 0.25 + 0.01 * level
	var stun_chance: float = 0.05 + 0.002 * level

	if tower.calc_chance(slow_chance):
		YtCombatLog.log_ability(tower, target, "Freezing Breath slow")
		slow_bt.apply(tower, target, level)

	if tower.calc_chance(stun_chance):
		YtCombatLog.log_ability(tower, target, "Freezing Breath stun")
		stun_bt.apply(tower, target, level)

