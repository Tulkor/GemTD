extends YtBuilder
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func apply_to_player(player: YtPlayer):
	player.modify_income_rate(0.15)
	player.modify_interest_rate(0.02)


func _get_tower_modifier() -> YtModifier:
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_BOUNTY_RECEIVED, 0.20, 0.0)
	mod.add_modification(YtModificationType.enm.MOD_ITEM_QUALITY_ON_KILL, 0.35, 0.02)

	mod.add_modification(YtModificationType.enm.MOD_BUFF_DURATION, -0.35, 0.0)
	mod.add_modification(YtModificationType.enm.MOD_DEBUFF_DURATION, 0.25, 0.0)
	mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, -0.15, 0.0)

	return mod
