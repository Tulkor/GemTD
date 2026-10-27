extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var bronze_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func tower_init():
	bronze_bt = YtBuffType.new("bronze_bt", 5, 0.1, false, self)
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, -0.5, 0.0)
	mod.add_modification(YtModificationType.enm.MOD_HP_REGEN_PERC, -0.5, -0.01)
	mod.add_modification(YtModificationType.enm.MOD_ARMOR_PERC, 0.5, -0.008)
	mod.add_modification(YtModificationType.enm.MOD_ITEM_QUALITY_ON_DEATH, 0.25, 0.01)
	bronze_bt.set_buff_modifier(mod)
	bronze_bt.set_buff_icon("res://resources/icons/generic_icons/gold_bar.tres")
	bronze_bt.add_event_on_create(bronze_bt_on_create)
	bronze_bt.add_event_on_cleanup(bronze_bt_on_cleanup)
	bronze_bt.set_buff_tooltip(YtUtils.text("MCA0"))


func on_damage(event: YtEvent):
	var chance: float = 0.1 + 0.004 * tower.get_level()

	if !tower.calc_chance(chance):
		return

	YtCombatLog.log_ability(tower, event.get_target(), "Bronzefication")

	bronze_bt.apply(tower, event.get_target(), tower.get_level())


func bronze_bt_on_create(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var unit: YtUnit = buff.get_buffed_unit()
	unit.set_sprite_color(Color8(255, 255, 125, 255))


func bronze_bt_on_cleanup(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var unit: YtUnit = buff.get_buffed_unit()
	unit.set_sprite_color(Color8(255, 255, 255, 255))
