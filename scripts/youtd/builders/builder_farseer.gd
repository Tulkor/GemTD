extends YtBuilder
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: commented out sections relevant to invisibility
# because invisible waves are currently disabled.


func _init():
	_range_bonus = 75


# func _get_tower_buff() -> YtBuffType:
# 	var farseer_bt: YtBuffType = MagicalSightBuff.new("farseer_bt", 700, self)

# 	return farseer_bt


func _get_tower_modifier() -> YtModifier:
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_SPELL_DAMAGE_DEALT, 0.10, 0.0)

	return mod
