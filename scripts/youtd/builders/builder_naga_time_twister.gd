extends YtBuilder
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func _get_tower_modifier() -> YtModifier:
    var mod: YtModifier = YtModifier.new()
    mod.add_modification(YtModificationType.enm.MOD_TRIGGER_CHANCES, 0.40, 0.0)
    mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 0.30, 0.0)

    mod.add_modification(YtModificationType.enm.MOD_DAMAGE_BASE_PERC, -0.25, 0.0)
    mod.add_modification(YtModificationType.enm.MOD_SPELL_DAMAGE_DEALT, -0.25, 0.0)

    return mod
