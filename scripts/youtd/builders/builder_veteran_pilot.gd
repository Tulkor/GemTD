extends YtBuilder
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func _get_tower_modifier() -> YtModifier:
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 0.20, 0.02)

	return mod


func _get_creep_modifier() -> YtModifier:
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_MOVESPEED_ABSOLUTE, 50, 0)

	return mod
