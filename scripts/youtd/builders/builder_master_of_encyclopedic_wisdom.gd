extends YtBuilder
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func _init():
	_tower_lvl_bonus = 5


func _get_tower_modifier() -> YtModifier:
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_EXP_RECEIVED, 0.60, 0.01)

	mod.add_modification(YtModificationType.enm.MOD_DAMAGE_BASE_PERC, -0.15, 0.0)

	return mod
