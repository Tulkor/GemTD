extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: [ORIGINAL_GAME_DEVIATION] Renamed
# "Mini Furbolg"=>"Mini Forest Troll"


var rampage_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func item_init():
	rampage_bt = YtBuffType.new("rampage_bt", 4, 0, true, self)
	rampage_bt.set_buff_icon("res://resources/icons/generic_icons/mighty_force.tres")
	rampage_bt.set_buff_tooltip(YtUtils.text("R5MU"))
	var mod: YtModifier = YtModifier.new() 
	mod.add_modification(YtModificationType.enm.MOD_MULTICRIT_COUNT, 1.00, 0.0) 
	mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 0.25, 0.0) 
	mod.add_modification(YtModificationType.enm.MOD_ATK_CRIT_CHANCE, 0.05, 0.0) 
	mod.add_modification(YtModificationType.enm.MOD_ATK_CRIT_DAMAGE, 0.40, 0.0) 
	rampage_bt.set_buff_modifier(mod) 


func on_attack(_event: YtEvent):
	var tower: YtTower = item.get_carrier()

	if !(tower.get_buff_of_type(rampage_bt) != null) && tower.calc_chance(0.14 * tower.get_base_attack_speed()):
		YtCombatLog.log_item_ability(item, null, "Rampage")
		rampage_bt.apply(tower, tower, tower.get_level())
