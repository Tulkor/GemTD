extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


const SEEKER_ARCANE_OIL_ID: int = 1019


func on_pickup():
	preload("res://scripts/youtd/items/seekers_oil.gd").seeker_oil_on_pickup(item, SEEKER_ARCANE_OIL_ID)
