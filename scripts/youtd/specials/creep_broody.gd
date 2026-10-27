extends YtBuffType
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


const EGG_SCALE_MIN: float = 0.6
const EGG_SCALE_MAX: float = 1.0
const EGG_GROW_TIME: float = 3.0

const LESSER_HATCHLING_COUNT: int = 5
const LESSER_HATCHLING_HEALTH: float = 0.02
const LESSER_HATCHLING_SCALE: float = 0.3
const LESSER_HATCHLING_RANDOM_OFFSET: float = 100
const GREATER_HATCHLING_HEALTH: float = 0.10
const GREATER_HATCHLING_SCALE: float = 0.6


func _init(parent: Node):
	super("creep_broody", 0, 0, true, parent)

	add_event_on_create(on_create)


func on_create(event: YtEvent):
	var autocast: YtAutocast = YtAutocast.make(171, self)
	var buff: YtBuff = event.get_buff()
	var creep: YtUnit = buff.get_buffed_unit()
	creep.add_autocast(autocast)


func on_autocast(event: YtEvent):
#	Lay an egg
	var autocast: YtAutocast = event.get_autocast_type()
	var caster: YtCreep = autocast.get_caster()
	var caster_pos: Vector2 = caster.get_position_wc3_2d()
	var egg_effect: int = YtEffect.create_animated("res://src/effects/barrel.tscn", Vector3(caster_pos.x, caster_pos.y, 0), 0)
	YtEffect.set_auto_destroy_enabled(egg_effect, false)
	YtEffect.set_scale(egg_effect, EGG_SCALE_MIN)
	YtEffect.set_color(egg_effect, Color.GREEN)

#	Save properties of caster
	var player: YtPlayer = caster.get_player()
	var caster_armor_type: YtArmorType.enm = caster.get_armor_type()
	var caster_race: YtCreepCategory.enm = caster.get_category()
	var caster_size: YtCreepSize.enm = caster.get_size()
	var caster_health: float = caster.get_overall_health()
	var caster_armor: float = caster.get_base_armor()
	var caster_level: int = caster.get_spawn_level()

#	Add delay before spawning hatchlings. Increase egg scale
#	while waiting.
	for i in range(0, 5):
		var sleep_time: float = EGG_GROW_TIME / 6
		await YtUtils.create_manual_timer(sleep_time, self).timeout

		var egg_grow_progress: float = i / 6.0
		var egg_scale: float = EGG_SCALE_MIN + egg_grow_progress * (EGG_SCALE_MAX - EGG_SCALE_MIN)
		YtEffect.set_scale(egg_effect, egg_scale)

	YtEffect.destroy_effect(egg_effect)

	if !YtUtils.unit_is_valid(caster):
		return

#	Create hatchlings
	var hatchling_type_is_lesser: int = YtUtils.rand_chance(YtGlobals.synced_rng, 0.5)

	if hatchling_type_is_lesser:
		var hatchling_health = caster_health * LESSER_HATCHLING_HEALTH

		for i in range(0, LESSER_HATCHLING_COUNT):
			var hatchling: YtCreep = YtWorld.game.spawn_yt_creep(caster_size, caster_armor_type, caster_race, hatchling_health, caster_armor, caster_level)
			if hatchling == null:
				return

			var random_offset: Vector2 = Vector2(YtGlobals.synced_rng.randf_range(-1, 1) * LESSER_HATCHLING_RANDOM_OFFSET, YtGlobals.synced_rng.randf_range(-1, 1) * LESSER_HATCHLING_RANDOM_OFFSET)
			var hatchling_pos: Vector2 = caster_pos + random_offset
			hatchling.set_position_wc3_2d(hatchling_pos)
			
			hatchling.set_portal_damage_multiplier(LESSER_HATCHLING_HEALTH)
			
			hatchling.set_unit_scale(LESSER_HATCHLING_SCALE)
	else:
		var hatchling_health = caster_health * GREATER_HATCHLING_HEALTH

		var hatchling: YtCreep = YtWorld.game.spawn_yt_creep(caster_size, caster_armor_type, caster_race, hatchling_health, caster_armor, caster_level)
		if hatchling == null:
			return

		var hatchling_pos: Vector2 = caster_pos
		hatchling.set_position_wc3_2d(hatchling_pos)
		hatchling.set_portal_damage_multiplier(GREATER_HATCHLING_HEALTH)

		hatchling.set_unit_scale(GREATER_HATCHLING_SCALE)
