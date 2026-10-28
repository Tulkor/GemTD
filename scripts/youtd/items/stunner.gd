extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var stun_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func item_init():
	stun_bt = YtCbStun.new("stun_bt", 0, 0, false, self)


func on_damage(event: YtEvent):
	var target: YtCreep = event.get_target()
	var size: int = target.get_size()
	var tower: YtTower = item.get_carrier()
	var speed: float = tower.get_base_attack_speed()

	if !event.is_main_target():
		return

	if size < YtCreepSize.enm.BOSS:
		if tower.calc_chance((0.15 + tower.get_level() * 0.0025) * speed) && event.is_main_target() == true:
			YtCombatLog.log_item_ability(item, null, "Stun")
			stun_bt.apply_only_timed(tower, target, 1)
	else:
		if tower.calc_chance((0.15 + tower.get_level() * 0.0025) / 3 * speed) && event.is_main_target() == true:
			YtCombatLog.log_item_ability(item, null, "Stun")
			stun_bt.apply_only_timed(tower, target, 1)
