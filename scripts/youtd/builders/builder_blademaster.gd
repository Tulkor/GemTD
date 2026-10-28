extends YtBuilder
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func _get_tower_modifier() -> YtModifier:
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_ATK_CRIT_CHANCE, 0.08, 0.0)
	mod.add_modification(YtModificationType.enm.MOD_ATK_CRIT_DAMAGE, 0.40, 0.0)
	mod.add_modification(YtModificationType.enm.MOD_MULTICRIT_COUNT, 1.0, 0.0)

	return mod
