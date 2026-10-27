extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var freezing_bt: YtBuffType
var aura_bt: YtBuffType


func tower_init():
	freezing_bt = YtBuffType.new("freezing_bt", 5, 0.05, true, self)
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_DMG_TO_AIR, 0.1, 0.008)
	freezing_bt.set_buff_modifier(mod)
	freezing_bt.set_buff_icon("res://resources/icons/generic_icons/energy_breath.tres")
	freezing_bt.set_buff_tooltip(YtUtils.text("EY29"))

	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", true, self)
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/atomic_slashes.tres")
	aura_bt.add_event_on_create(gust_on_create)
	aura_bt.add_periodic_event(gust_periodic, 1.0)
	aura_bt.add_event_on_cleanup(gust_on_cleanup)
	aura_bt.set_buff_tooltip(YtUtils.text("N6RI"))


func gust_on_create(event: YtEvent):
#	Sstore tower's bonus damage in buff's user_real
	var buff: YtBuff = event.get_buff()
	buff.user_real = 0.0


func gust_periodic(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var target: YtUnit = buff.get_buffed_unit()
	var multiplier: float = 0.5 + 0.008 * tower.get_level()
	var dmg_to_air: float = target.get_damage_to_size(YtCreepSize.enm.AIR)

	var bonus_damage: float = 1.0 * (dmg_to_air - 1.0) * multiplier
	
	var target_has_freezing_gust: bool = target.get_buff_of_type(freezing_bt) != null
	if target_has_freezing_gust:
		bonus_damage *= 2.0

	target.modify_property(YtModificationType.enm.MOD_DAMAGE_ADD_PERC, bonus_damage - buff.user_real)
	buff.user_real = bonus_damage


func gust_on_cleanup(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var target: YtUnit = buff.get_buffed_unit()
	var bonus_dmg: float = buff.user_real
	target.modify_property(YtModificationType.enm.MOD_DAMAGE_ADD_PERC, -bonus_dmg)
