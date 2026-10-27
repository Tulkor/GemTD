extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var presence_tower_bt: YtBuffType
var presence_creep_bt: YtBuffType


func item_init():
	presence_tower_bt = YtBuffType.create_aura_effect_type("presence_tower_bt", false, self)
	presence_tower_bt.set_buff_icon("res://resources/icons/generic_icons/poison_gas.tres")
	presence_tower_bt.set_buff_tooltip(YtUtils.text("7COB"))
	var presence_tower_bt_mod: YtModifier = YtModifier.new()
	presence_tower_bt_mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, -0.2, 0.002)
	presence_tower_bt.set_buff_modifier(presence_tower_bt_mod)

	presence_creep_bt = YtBuffType.create_aura_effect_type("presence_creep_bt", false, self)
	presence_creep_bt.set_buff_icon("res://resources/icons/generic_icons/poison_gas.tres")
	presence_creep_bt.set_buff_tooltip(YtUtils.text("H3NT"))
	var presence_creep_bt_mod: YtModifier = YtModifier.new()
	presence_creep_bt_mod.add_modification(YtModificationType.enm.MOD_ATK_DAMAGE_RECEIVED, 0.2, 0.004)
	presence_creep_bt_mod.add_modification(YtModificationType.enm.MOD_SPELL_DAMAGE_RECEIVED, 0.2, 0.004)
	presence_creep_bt.set_buff_modifier(presence_creep_bt_mod)
