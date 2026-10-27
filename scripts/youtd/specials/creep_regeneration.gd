extends YtBuffType
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var _regen_ratio_map: Dictionary = {
	YtCreepSize.enm.MASS: 0.05,
	YtCreepSize.enm.NORMAL: 0.025,
	YtCreepSize.enm.AIR: 0.0285,
	YtCreepSize.enm.CHAMPION: 0.022,
	YtCreepSize.enm.BOSS: 0.007,
	YtCreepSize.enm.CHALLENGE_MASS: 0.0,
	YtCreepSize.enm.CHALLENGE_BOSS: 0.0,
}


func _init(parent: Node):
	super("creep_regeneration", 0, 0, true, parent)
	add_event_on_create(on_create)


func on_create(event: YtEvent):
	regen_special_on_create(event, _regen_ratio_map)


static func regen_special_on_create(event: YtEvent, regen_ratio_map: Dictionary):
	var buff: YtBuff = event.get_buff()
	var creep: YtUnit = buff.get_buffed_unit()
	var creep_size: YtCreepSize.enm = creep.get_size_including_challenge_sizes()
	var creep_hp: float = creep.get_overall_health()
	var regen_ratio: float = regen_ratio_map[creep_size]
	var regen_value: float = creep_hp * regen_ratio

	creep.modify_property(YtModificationType.enm.MOD_HP_REGEN, regen_value)
