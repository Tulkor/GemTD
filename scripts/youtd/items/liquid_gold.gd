extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var drunk_bt: YtBuffType
var stun_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


# NOTE: drolDrunk() in original script
func drunk_bt_on_expire(event: YtEvent):
	var b: YtBuff = event.get_buff()
	var tower: YtUnit = b.get_caster()
	stun_bt.apply_only_timed(tower, tower, 3 - tower.get_level() * 0.1)


func item_init():
	stun_bt = YtCbStun.new("stun_bt", 0, 0, false, self)
	
	drunk_bt = YtBuffType.new("drunk_bt", 8, 0, false, self)
	drunk_bt.set_buff_icon("res://resources/icons/generic_icons/perpendicular_rings.tres")
	drunk_bt.set_buff_tooltip(YtUtils.text("W9YO"))
	drunk_bt.add_event_on_expire(drunk_bt_on_expire)
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, -0.30, 0.01)
	drunk_bt.set_buff_modifier(mod)


func on_attack(_event: YtEvent):
	var tower: YtTower = item.get_carrier()
	var speed: float = tower.get_base_attack_speed()

	if tower.calc_bad_chance(0.1 * speed):
		YtCombatLog.log_item_ability(item, null, "Hangover")
		drunk_bt.apply(tower, tower, tower.get_level())
