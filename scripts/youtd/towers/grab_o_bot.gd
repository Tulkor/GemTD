extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var grapple_bt: YtBuffType
var shock_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func tower_init():
	grapple_bt = YtCbStun.new("grapple_bt", 2.5, 0, false, self)
	grapple_bt.set_buff_icon("res://resources/icons/generic_icons/pokecog.tres")
	grapple_bt.add_event_on_create(grapple_bt_on_create)
	grapple_bt.add_event_on_cleanup(grapple_bt_on_cleanup)

	shock_bt = YtCbStun.new("shock_bt", 2.5, 0, false, self)
	shock_bt.set_buff_icon("res://resources/icons/generic_icons/atomic_slashes.tres")


func on_attack(event: YtEvent):
	var target: YtUnit = event.get_target()
	var grapple_chance: float = 0.08 + 0.0032 * tower.get_level()

	var grapple_duration: float
	if target.get_size() >= YtCreepSize.enm.CHAMPION:
		grapple_duration = 0.9
	else:
		grapple_duration = 2.5

	if !tower.calc_chance(grapple_chance):
		return

	YtCombatLog.log_ability(tower, target, "Grapple")

	grapple_bt.apply_only_timed(tower, target, grapple_duration)


func on_autocast(event: YtEvent):
	var target: YtUnit = event.get_target()
	var shock_damage: float = 1250 + 185 * tower.get_level()

	YtEffect.create_simple_at_unit("res://src/effects/thunder_clap.tscn", target)

	tower.do_spell_damage_aoe_unit(target, 250, shock_damage, tower.calc_spell_crit_no_bonus(), 0.5)

	var it: YtIterate = YtIterate.over_units_in_range_of_unit(tower, YtTargetType.new(YtTargetType.CREEPS), target, 250)

	while true:
		var next: YtUnit = it.next()

		if next == null:
			break

		shock_bt.apply_only_timed(tower, next, 2.0)


func grapple_bt_on_create(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var target: YtUnit = buff.get_buffed_unit()
	var caster: YtUnit = buff.get_caster()

	var lightning_start: Vector3 = Vector3(caster.get_x(), caster.get_y(), 100)
	var lightning_end: Vector3 = Vector3(target.get_x(), target.get_y(), 0)
	var lightning: YtInterpolatedSprite = YtInterpolatedSprite.create_from_point_to_point(YtInterpolatedSprite.LIGHTNING, lightning_start, lightning_end)

	# NOTE: usage of get_instance_id() is OK here and
	# doesn't cause desyncs because the lightning object is
	# visual only.
	buff.user_int = lightning.get_instance_id()


func grapple_bt_on_cleanup(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var lightning_id: int = buff.user_int

	# NOTE: usage of instance_from_id() is OK here and
	# doesn't cause desyncs because the lightning object is
	# visual only.
	var lightning_object: Object = instance_from_id(lightning_id)

	if lightning_object != null:
		var lightning_node: Node = lightning_object as Node
		lightning_node.queue_free()
