extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var slow_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func item_init():
	slow_bt = YtBuffType.new("slow_bt", 4, 0, false, self)
	slow_bt.set_buff_icon("res://resources/icons/generic_icons/spider_web.tres") 
	slow_bt.set_buff_tooltip(YtUtils.text("Y2QA"))
	var mod: YtModifier = YtModifier.new() 
	mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, -0.05, 0) 
	slow_bt.set_buff_modifier(mod) 


func on_attack(event: YtEvent):
	var tower: YtTower = item.get_carrier() 
	var speed: float = tower.get_base_attack_speed()  

	if tower.calc_chance(0.25 * speed) == true:
		YtCombatLog.log_item_ability(item, event.get_target(), "Spiderling Poison")
		slow_bt.apply(tower, event.get_target(), 1)
