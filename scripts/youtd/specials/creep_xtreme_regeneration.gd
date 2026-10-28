extends YtBuffType
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var _regen_ratio_map: Dictionary = {
	YtCreepSize.enm.MASS: 0.175,
	YtCreepSize.enm.NORMAL: 0.0875,
	YtCreepSize.enm.AIR: 0.1,
	YtCreepSize.enm.CHAMPION: 0.078,
	YtCreepSize.enm.BOSS: 0.025,
	YtCreepSize.enm.CHALLENGE_MASS: 0.0,
	YtCreepSize.enm.CHALLENGE_BOSS: 0.0,
}


func _init(parent: Node):
	super("creep_xtreme_regeneration", 0, 0, true, parent)
	add_event_on_create(on_create)


func on_create(event: YtEvent):
	preload("res://scripts/youtd/specials/creep_regeneration.gd").regen_special_on_create(event, _regen_ratio_map)
