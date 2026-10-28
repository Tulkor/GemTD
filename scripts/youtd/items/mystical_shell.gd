extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var resonance_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func item_init():
	resonance_bt = YtBuffType.new("resonance_bt", 5, 0, false, self)
	resonance_bt.set_buff_icon("res://resources/icons/generic_icons/rss.tres")
	resonance_bt.set_buff_tooltip(YtUtils.text("CRZY"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_SPELL_DAMAGE_RECEIVED, 0.15, 0.0)
	resonance_bt.set_buff_modifier(mod)


func on_attack(event: YtEvent):
	var tower: YtTower = item.get_carrier()

	if tower.calc_chance(0.10 * tower.get_base_attack_speed()):
		YtCombatLog.log_item_ability(item, event.get_target(), "Resonance")
		resonance_bt.apply(tower, event.get_target(), tower.get_level())
