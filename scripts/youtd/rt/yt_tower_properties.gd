class_name YtTowerProperties
extends RefCounted
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Werte eines Towers nach id (data/youtd/towers.json), wie Skripte sie abfragen.


static func get_rarity(id: int) -> YtRarity.enm:
	return YtRarity.convert_from_string(str(YoutdData.tower(str(id)).get("rarity", "common")))


static func get_element(id: int) -> YtElement.enm:
	return YtElement.from_string(str(YoutdData.tower(str(id)).get("element", "ice")))
