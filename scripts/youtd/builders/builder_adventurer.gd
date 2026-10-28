extends YtBuilder
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func _get_tower_modifier() -> YtModifier:
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_ITEM_CHANCE_ON_KILL, 0.15, 0.0)
	mod.add_modification(YtModificationType.enm.MOD_ITEM_QUALITY_ON_KILL, 0.20, 0.0)

	return mod
