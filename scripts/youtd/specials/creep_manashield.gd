extends YtBuffType
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.

# TODO: add explode visual and also make it so that there's
# no corpse.

static var _max_cost_map: Dictionary = {
	YtCreepSize.enm.MASS: 3,
	YtCreepSize.enm.NORMAL: 6,
	YtCreepSize.enm.AIR: 12,
	YtCreepSize.enm.CHAMPION: 12,
	YtCreepSize.enm.BOSS: 12,
	YtCreepSize.enm.CHALLENGE_MASS: 0,
	YtCreepSize.enm.CHALLENGE_BOSS: 0,
}


func _init(parent: Node):
	super("creep_mana_shield", 0, 0, true, parent)

	add_event_on_damaged(on_damaged)


func on_damaged(event: YtEvent):
	var spend_mana: bool = true
	shield_effect(event, spend_mana)


static func shield_effect(event: YtEvent, spend_mana: bool):
	var caster: YtUnit = event.get_target()
	var buff: YtBuff = event.get_buff()
	var creep: YtUnit = buff.get_buffed_unit()

	var creep_size: YtCreepSize.enm = creep.get_size_including_challenge_sizes()
	var shield_cost_max: float = _max_cost_map[creep_size]
	var damage_ratio: float = YtUtils.divide_safe(event.damage, creep.get_overall_health())
	var shield_cost: float = min(80 * damage_ratio, shield_cost_max)

	var mana_ratio = creep.get_mana_ratio()
	var damage_multiplier: float = clampf(1.0 - 0.8 * mana_ratio, 0.2, 1.0)
	event.damage *= damage_multiplier

	if spend_mana:
		creep.subtract_mana(shield_cost, false)

#	NOTE: when creep reaches 0 mana it's supposed to
#	explode. Simulate this by killing creep instantly.
	if creep.get_mana() == 0:
		caster.kill_instantly(creep)
