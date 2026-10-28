extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func on_pickup():
	var carrier: YtTower = item.get_carrier()
	carrier.add_exp_flat(120)
