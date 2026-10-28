extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var power_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
    triggers.add_event_on_damage(on_damage)


func item_init():
    power_bt = YtBuffType.new("power_bt", 5, 0, false, self)
    power_bt.set_buff_icon("res://resources/icons/generic_icons/open_wound.tres")
    power_bt.set_buff_tooltip(YtUtils.text("F9SA"))
    var mod: YtModifier = YtModifier.new()
    mod.add_modification(YtModificationType.enm.MOD_ARMOR, 0.0, -0.2)
    power_bt.set_buff_modifier(mod)


func on_damage(event: YtEvent):
    var tower: YtTower = item.get_carrier()

    if event.is_main_target() == true:
        if YtUtils.rand_chance(YtGlobals.synced_rng, 0.5):
            power_bt.apply(tower, event.get_target(), 25 + tower.get_level())
        else:
            power_bt.apply(tower, event.get_target(), 50 + tower.get_level())
