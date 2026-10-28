class_name YtExperience
extends RefCounted
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Erfahrungstabelle der Tower aus data/youtd/xp.json.


static func get_exp_for_level(level: int) -> int:
	var table := YoutdData.tower_exp_table()
	return int(table[level]) if level >= 0 and level < table.size() else 1000000


static func get_level_at_exp(experience: float, player: YtPlayer) -> int:
	var cap := player.get_max_tower_level() if player != null else YtConstants.TOWER_MAX_LEVEL_WITH_BONUS
	if experience < 0.0:
		return 0
	return YoutdData.level_at(YoutdData.tower_exp_table(), floorf(experience), cap)
