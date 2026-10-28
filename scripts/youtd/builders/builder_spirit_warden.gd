extends YtBuilder
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func _get_tower_modifier() -> YtModifier:
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_DEBUFF_DURATION, -0.30, 0.0)
	mod.add_modification(YtModificationType.enm.MOD_BUFF_DURATION, 0.80, 0.0)
	mod.add_modification(YtModificationType.enm.MOD_DMG_TO_MASS, 0.10, 0.0)

	mod.add_modification(YtModificationType.enm.MOD_DMG_TO_BOSS, -0.10, 0.0)

	return mod
