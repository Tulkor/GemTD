extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: original script does weird things with putting
# creeps into list/hashtable and counting creeps in range.
# Removed that, same behavior can be achieved without it.
# What's the point of checking that creeps are in range? The
# aura does that already and removes the buff when creeps go
# out of range.


var aura_bt: YtBuffType
var link_bt: YtBuffType
var flux_pt: YtProjectileType
var multiboard: YtMultiboardValues
var linked_tower: YtTower = null
var saved_lightning: YtInterpolatedSprite = null
var spell_damage_by_linked_tower: float = 0.0
var link_time: float = 0.0
var logged_link_ability: bool = false


func load_triggers(triggers: YtBuffType):
	triggers.add_periodic_event(periodic, 1.0)


func tower_init():
	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", false, self)
	aura_bt.add_event_on_damaged(aura_bt_on_damaged)
	aura_bt.set_hidden()

	link_bt = YtBuffType.new("link_bt", -1, 0, true, self)
	link_bt.add_event_on_create(aura_bt_on_create)
	link_bt.add_event_on_cleanup(aura_bt_on_cleanup)
	link_bt.set_buff_icon("res://resources/icons/generic_icons/aquarius.tres")
	link_bt.set_buff_tooltip(YtUtils.text("DM73"))

	multiboard = YtMultiboardValues.new(1)
	var dps_label: String = YtUtils.text("YWRV")
	multiboard.set_key(0, dps_label)

	flux_pt = YtProjectileType.create_interpolate("path_to_projectile_sprite", 1000, self)
	flux_pt.set_event_on_interpolation_finished(flux_pt_on_hit)


func on_destruct():
#	Remove link on destroy of this tower
	if linked_tower != null:
		var buff: YtBuff = linked_tower.get_buff_of_type(link_bt)
		buff.remove_buff()


func on_autocast(event: YtEvent):
	var target: YtUnit = event.get_target()
	var buff_on_new_target: YtBuff = target.get_buff_of_type(link_bt)

	if buff_on_new_target != null:
#		Target is linked to another one of these towers.
#		Destroy that link
		buff_on_new_target.remove_buff()

#	It should be impossible for this to create a double free as this can only be true if the
#	linked tower and the target aren't the same. Else the buff is destroyed before this
#	-> linked_tower == null (buff cleanup)
	if linked_tower != null:
		var buff_on_old_target: YtBuff = linked_tower.get_buff_of_type(link_bt)
		buff_on_old_target.remove_buff()

	linked_tower = target
	link_bt.apply(tower, target, 0)


func on_tower_details() -> YtMultiboardValues:
	var dps: float = get_dps_from_link()
	var dps_string: String = YtUtils.format_float(dps, 0)

	multiboard.set_value(0, dps_string)

	return multiboard


func periodic(event: YtEvent):
	var attack_speed: float = tower.get_current_attack_speed()

	event.enable_advanced(attack_speed, false)

	if linked_tower == null:
#		NOT LINKED! Do nothing!
		link_time = 0.0
		logged_link_ability = false

		return

	if spell_damage_by_linked_tower <= 0.0:
#		No dmg to deal! Do nothing!
		return

	link_time += attack_speed

	var linked_for_10_sec: bool = link_time >= 10.0

	if !linked_for_10_sec:
		return

	if linked_for_10_sec && !logged_link_ability:
		YtCombatLog.log_ability(tower, null, "Link damage active")
		logged_link_ability = true

	var it: YtIterate = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.CREEPS), 800)
	var next: YtUnit = it.next_random()

	if next != null:
		YtProjectile.create_bezier_interpolation_from_unit_to_unit(flux_pt, tower, 1.0, 1.0, tower, next, 0.35, 0, 0, true)


# NOTE: "ProjHit()" in original script
func flux_pt_on_hit(_p: YtProjectile, target: YtUnit):
	if target == null:
		return

	var damage: float = get_dps_from_link()
	tower.do_custom_attack_damage(target, damage, tower.calc_attack_multicrit_no_bonus(), YtAttackType.enm.ENERGY)


# NOTE: "BuffTrigger()" in original script
func aura_bt_on_damaged(event: YtEvent):
	var attacker: YtUnit = event.get_target()

	if event.is_spell_damage() && attacker == linked_tower:
		spell_damage_by_linked_tower += event.damage


# NOTE: "LinkCreate()" in original script
func aura_bt_on_create(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var caster: YtTower = buff.get_caster()
	var lightning: YtInterpolatedSprite = YtInterpolatedSprite.create_from_point_to_unit(YtInterpolatedSprite.LIGHTNING, Vector3(caster.get_x(), caster.get_y(), 220), linked_tower)
	lightning.modulate = Color.LIGHT_BLUE
	saved_lightning = lightning


# NOTE: "LinkEnd()" in original script
func aura_bt_on_cleanup(_event: YtEvent):
	if saved_lightning != null:
		saved_lightning.queue_free()
		saved_lightning = null

	linked_tower = null


func get_dps_from_link() -> float:
	if link_time <= 0.0:
		return 0.0

	var spell_dps_by_linked_tower: float = spell_damage_by_linked_tower / link_time
	var multiplier: float = 0.25 + 0.01 * tower.get_level()
	var dps: float = spell_dps_by_linked_tower * multiplier

	return dps
