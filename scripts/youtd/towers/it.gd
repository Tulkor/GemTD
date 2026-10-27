extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: [ORIGINAL_GAME_DEVIATION] Original script did not
# allow placing Corruption Field before placing Recreation
# Field. Removed this restriction.


class YtSummoner:
	var size: float = 3.0
	var corruption_effect: int = 0
	var recreation_effect: int = 0
	var from_pos: Vector2 = Vector2.INF
	var dest_pos: Vector2 = Vector2.INF


# NOTE: SCALE_MIN should match the value in tower sprite
# scene
const SCALE_MIN: float = 0.7
const SCALE_MAX: float = 1.0
const TRANSPORT_CD: float = 1.0
const FIELD_RADIUS: float = 250
const FIELD_DAMAGE: float = 3000
const FIELD_DAMAGE_ADD: float = 100


var multiboard: YtMultiboardValues
var sum: YtSummoner = YtSummoner.new()
# NOTE: this map is never cleared which is a bit suspect but
# considering that the amount of creeps in game is capped at
# 1000's and this stores references - it's not a big deal.
var summoner_units: Dictionary = {}
var tick_when_last_transported: int = 0


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)
	triggers.add_event_on_kill(on_kill)


func tower_init():
	multiboard = YtMultiboardValues.new(1)
	var spelldamage_bonus_label: String = YtUtils.text("KERS")
	multiboard.set_key(0, spelldamage_bonus_label)


func on_destruct():
	var recreation_effect: int = sum.recreation_effect
	YtEffect.destroy_effect(recreation_effect)
	var corruption_effect: int = sum.corruption_effect
	YtEffect.destroy_effect(corruption_effect)


func on_attack(_event: YtEvent):
	var both_fields_were_placed: bool = sum.dest_pos != Vector2.INF && sum.from_pos != Vector2.INF

	if !both_fields_were_placed:
		return

#	NOTE: use tick-based calculation to avoid float precision
#	drift in multiplayer.
	var transport_cd_ticks: int = YtUtils.time_to_ticks(TRANSPORT_CD)
	var current_tick: int = YtUtils.get_current_tick()
	var ticks_since_last_transport: int = current_tick - tick_when_last_transported
	var transport_is_on_cooldown: bool = ticks_since_last_transport < transport_cd_ticks

	if transport_is_on_cooldown:
		return

	tick_when_last_transported = current_tick

	var aoe_dmg: float = FIELD_DAMAGE + FIELD_DAMAGE_ADD * tower.get_level()
	tower.do_spell_damage_aoe(sum.from_pos, FIELD_RADIUS, aoe_dmg, tower.calc_spell_crit_no_bonus(), 0.0)

	var effect_from: int = YtEffect.create_colored("res://src/effects/arcane_tower_attack_flat.tscn", Vector3(sum.from_pos.x, sum.from_pos.y, 100.0), 270.0, 2, Color8(0, 0, 0, 255))
	YtEffect.set_z_index(effect_from, YtEffect.Z_INDEX_BELOW_CREEPS)

	var it: YtIterate = YtIterate.over_units_in_range_of(tower, YtTargetType.new(YtTargetType.CREEPS), sum.from_pos, FIELD_RADIUS)

	while true:
		var next: YtUnit = it.next()

		if next == null:
			break

		var creep: YtCreep = next as YtCreep

		if creep.get_size() >= YtCreepSize.enm.BOSS:
			continue

		var already_summoned: bool = summoner_units.has(creep)

		if already_summoned:
			continue

		summoner_units[creep] = true

		it_hunger_ability()

		var random_offset: Vector2 = Vector2(YtGlobals.synced_rng.randf_range(-25, 25), YtGlobals.synced_rng.randf_range(-25, 25))
		var dest_pos: Vector2 = sum.dest_pos + random_offset

		creep.move_to_point(dest_pos)

	tower.do_spell_damage_aoe(sum.dest_pos, FIELD_RADIUS, aoe_dmg, tower.calc_spell_crit_no_bonus(), 0.0)
	var effect_dest: int = YtEffect.create_colored("res://src/effects/arcane_tower_attack_flat.tscn", Vector3(sum.dest_pos.x, sum.dest_pos.y, 100.0), 270.0, 2, Color8(0, 0, 0, 255))
	YtEffect.set_z_index(effect_dest, YtEffect.Z_INDEX_BELOW_CREEPS)


func on_kill(_event: YtEvent):
	it_hunger_ability()


# NOTE: need to check that position of Recreation Field is
# on creep path because creeps will get transported to that
# position.
func on_autocast_recreation(event: YtEvent):
	var autocast: YtAutocast = event.get_autocast_type()
	var target_pos: Vector2 = autocast.get_target_pos()
	
	var target_pos_is_on_path: bool = YtUtils.is_point_on_creep_path(target_pos, tower.get_player())

	if !target_pos_is_on_path:
		var invalid_location_text: String = YtUtils.text("FFW7")
		tower.get_player().display_small_floating_text(invalid_location_text, tower, Color8(255, 150, 0), 30)

		return

	sum.dest_pos = target_pos

	var recreation_field_exists: bool = sum.recreation_effect != 0

	if !recreation_field_exists:
		sum.recreation_effect = YtEffect.create_animated("res://src/effects/vampiric_aura.tscn", Vector3(target_pos.x, target_pos.y, 0), 270.0)
		YtEffect.set_z_index(sum.recreation_effect, YtEffect.Z_INDEX_BELOW_CREEPS)
		YtEffect.set_auto_destroy_enabled(sum.recreation_effect, false)
		YtEffect.set_color(sum.recreation_effect, Color8(255, 0, 0, 150))
	else:
		YtEffect.set_position(sum.recreation_effect, target_pos)


func on_autocast_corruption(event: YtEvent):
	var autocast: YtAutocast = event.get_autocast_type()
	var target_pos: Vector2 = autocast.get_target_pos()

	sum.from_pos = target_pos

	var corruption_field_exists: bool = sum.corruption_effect != 0

	if !corruption_field_exists:
		sum.corruption_effect = YtEffect.create_animated("res://src/effects/vampiric_aura.tscn", Vector3(target_pos.x, target_pos.y, 0), 270.0)
		YtEffect.set_z_index(sum.corruption_effect, YtEffect.Z_INDEX_BELOW_CREEPS)
		YtEffect.set_auto_destroy_enabled(sum.corruption_effect, false)
		YtEffect.set_color(sum.corruption_effect, Color8(0, 0, 255, 150))
	else:
		YtEffect.set_position(sum.corruption_effect, target_pos)


func on_tower_details() -> YtMultiboardValues:
	var spelldmg_bonus: float = sum.size - 3.0
	var spelldmg_bonus_string: String = YtUtils.format_percent(spelldmg_bonus, 1)
	multiboard.set_value(0, spelldmg_bonus_string)

	return multiboard


# NOTE: "It_kill()" in original script
func it_hunger_ability():
	var mod: float = 0.001 + 0.0001 * tower.get_level()

	if sum.size < 10.0:
#		700% cap
		tower.modify_property(YtModificationType.enm.MOD_SPELL_DAMAGE_DEALT, mod)
		sum.size += mod

	if sum.size < 3.7:
		var tower_scale: float = YtUtils.get_scale_from_grows(SCALE_MIN, SCALE_MAX, sum.size - 3.0, 0.7)
		tower.set_unit_scale(tower_scale)
