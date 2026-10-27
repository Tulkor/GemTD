extends YtBuilder
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func _get_tower_modifier() -> YtModifier:
    var mod: YtModifier = YtModifier.new()
    mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 0.10, 0.0)
    mod.add_modification(YtModificationType.enm.MOD_DAMAGE_BASE_PERC, 0.35, 0.0)
    mod.add_modification(YtModificationType.enm.MOD_ATK_CRIT_CHANCE, 0.0, 0.004)
    mod.add_modification(YtModificationType.enm.MOD_ATK_CRIT_DAMAGE, 0.0, 0.02)
    mod.add_modification(YtModificationType.enm.MOD_MULTICRIT_COUNT, 2.0, 0.0)

    mod.add_modification(YtModificationType.enm.MOD_MANA_REGEN_PERC, -3.0, 0.0)
    mod.add_modification(YtModificationType.enm.MOD_SPELL_DAMAGE_DEALT, -1.0, 0.0)

    return mod
