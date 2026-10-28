extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func get_tier_stats() -> Dictionary:
	return {
		1: {item_rarity = YtRarity.enm.COMMON},
		2: {item_rarity = YtRarity.enm.UNCOMMON},
		3: {item_rarity = YtRarity.enm.RARE},
		4: {item_rarity = YtRarity.enm.UNIQUE},
	}


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func on_attack(_event: YtEvent):
	var itm
	var i: int = 1

	var item_rarity: YtRarity.enm = _stats.item_rarity

	while true:
		if i > 6:
			break

		itm = tower.get_held_item(i)

		if itm != null && itm.get_rarity() != item_rarity:
			itm.drop()
			itm.fly_to_stash(0.0)

		i = i + 1
