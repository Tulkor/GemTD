extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func on_drop():
    var tower: YtTower = item.get_carrier()
    var target_count: int = tower.get_target_count_from_item()
    tower.set_target_count_from_item(target_count - 3)


func on_pickup():
    var tower: YtTower = item.get_carrier()
    var target_count: int = tower.get_target_count_from_item()
    tower.set_target_count_from_item(target_count + 3)
