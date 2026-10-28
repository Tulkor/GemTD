extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var aura_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)
	triggers.add_event_on_kill(on_kill)


func item_init():
	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", true, self)
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/rolling_energy.tres")
	aura_bt.set_buff_tooltip(YtUtils.text("2UJE"))
	var mod: YtModifier = YtModifier.new() 
	mod.add_modification(YtModificationType.enm.MOD_MANA_REGEN_PERC, 0.075, 0.0) 
	aura_bt.set_buff_modifier(mod)


func on_attack(_event: YtEvent):
	item.user_int = item.user_int + 1

	if item.user_int == 3:
		item.get_carrier().add_mana_perc(0.01)
		item.user_int = 0


func on_pickup():
	item.user_int = 0


func on_kill(_event: YtEvent):
	var tower: YtTower = item.get_carrier()
	YtEffect.create_scaled("res://src/effects/replenish_mana.tscn", tower.get_position_wc3(), 0.0, 1)

