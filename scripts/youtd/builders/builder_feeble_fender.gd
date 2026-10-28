extends YtBuilder
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func apply_to_player(player: YtPlayer):
	player.modify_income_rate(-0.20)
	player.add_tomes(-45)
	player.set_builder_wisdom_multiplier(1.25)


func _get_tower_modifier() -> YtModifier:
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_DMG_TO_UNDEAD, 0.50, 0.0)
	mod.add_modification(YtModificationType.enm.MOD_DMG_TO_ORC, 0.30, 0.0)
	mod.add_modification(YtModificationType.enm.MOD_DMG_TO_MASS, 0.50, 0.0)
	mod.add_modification(YtModificationType.enm.MOD_DMG_TO_MAGIC, -0.30, 0.0)

	return mod
