extends YtBuilder
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func _get_tower_modifier() -> YtModifier:
    var mod: YtModifier = YtModifier.new()
    mod.add_modification(YtModificationType.enm.MOD_SPELL_DAMAGE_DEALT, 0.50, 0.0)
    mod.add_modification(YtModificationType.enm.MOD_SPELL_CRIT_CHANCE, 0.20, 0.0)
    mod.add_modification(YtModificationType.enm.MOD_SPELL_CRIT_DAMAGE, 0.50, 0.02)
    mod.add_modification(YtModificationType.enm.MOD_DMG_TO_MAGIC, 0.0, 0.01)

    mod.add_modification(YtModificationType.enm.MOD_DAMAGE_BASE_PERC, -0.10, -0.012)

    return mod
