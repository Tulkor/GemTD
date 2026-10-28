extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: in original script, item is used as caster for
# stun_bt. Changed to tower itself because in our engine
# YtItem is not a YtUnit.


var stun_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func item_init():
	stun_bt = YtCbStun.new("stun_bt", 0, 0, false, self)


func on_attack(_event: YtEvent):
	var twr: YtTower = item.get_carrier()

	if YtUtils.rand_chance(YtGlobals.synced_rng, 0.15 / twr.get_prop_trigger_chances()):
		YtCombatLog.log_item_ability(item, null, "Tricky Weapon")

		stun_bt.apply_only_timed(twr, twr, 1)
