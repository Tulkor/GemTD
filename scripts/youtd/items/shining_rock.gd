extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func on_create():
	item.user_real = 100


func on_drop():
	var tower: YtTower = item.get_carrier()
	item.user_real = tower.remove_exp_flat(100)


func on_pickup():
	var tower: YtUnit = item.get_carrier()
	var r: float = item.user_real
	if r > 0:
		tower.add_exp_flat(r)
