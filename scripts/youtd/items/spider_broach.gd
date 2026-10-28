extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var threads_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func item_init():
	threads_bt = YtBuffType.new("threads_bt", 5.0, 0.1, false, self)
	threads_bt.set_buff_icon("res://resources/icons/generic_icons/spider_web.tres")
	threads_bt.set_buff_tooltip(YtUtils.text("A8WN"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_ITEM_QUALITY_ON_DEATH, 0.4, 0.01)
	threads_bt.set_buff_modifier(mod)


func on_damage(event: YtEvent):
	var tower: YtTower = item.get_carrier()

	if tower.calc_chance(0.15 * tower.get_base_attack_speed()):
		YtCombatLog.log_item_ability(item, null, "Silver Threads")
		threads_bt.apply(tower, event.get_target(), tower.get_level())
