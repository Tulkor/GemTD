extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func on_drop():
    var tower: YtTower = item.get_carrier()

    tower.modify_property(YtModificationType.enm.MOD_DAMAGE_ADD_PERC, -tower.get_gold_cost() * 0.0001)


func on_pickup():
    var tower: YtTower = item.get_carrier()

    tower.modify_property(YtModificationType.enm.MOD_DAMAGE_ADD_PERC, tower.get_gold_cost() * 0.0001)
