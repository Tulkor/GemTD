extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: [ORIGINAL_GAME_DEVIATION] Day/night mechanic is not
# implemented so changed this item effect to be average
# between day and night. Original script gives 2 during day
# and 4 at night, so average it down to 3.


func load_triggers(triggers: YtBuffType):
	triggers.add_periodic_event(periodic, 15)


func periodic(_event: YtEvent):
	var target_effect: int
	var tower: YtUnit = item.get_carrier()

	target_effect = YtEffect.create_scaled("res://src/effects/dispel_magic_target.tscn", tower.get_position_wc3(), 0, 2)
	YtEffect.set_lifetime(target_effect, 2.0)

	YtCombatLog.log_item_ability(item, null, "Celestial Wisdom")
	tower.add_exp(3.0)
