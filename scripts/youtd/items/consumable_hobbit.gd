extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func on_consume():
	item.get_player().modify_food_cap(8)
	item.get_player().add_tomes(20)
	item.get_player().modify_income_rate(0.06)
	item.get_player().get_team().modify_lives(2)
