extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: [ORIGINAL_GAME_DEVIATION] Renamed
# "Nerubian Queen"=>"Spider Queen"


var multiboard: YtMultiboardValues
var parasite_bt: YtBuffType
var spider_pt: YtProjectileType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func tower_init():
	parasite_bt = YtBuffType.new("parasite_bt", 10, 0, false, self)
	var mod: YtModifier = YtModifier.new()
	parasite_bt.set_buff_modifier(mod)
	parasite_bt.add_periodic_event(parasite_bt_periodic, 1.0)
	parasite_bt.add_event_on_death(parasite_bt_on_death)
	parasite_bt.set_buff_icon("res://resources/icons/generic_icons/amber_mosquito.tres")
	parasite_bt.set_buff_tooltip(YtUtils.text("GBJV"))

	spider_pt = YtProjectileType.create_interpolate("path_to_projectile_sprite", 500, self)
	spider_pt.set_event_on_cleanup(spider_pt_on_cleanup)
	spider_pt.disable_explode_on_hit()

	multiboard = YtMultiboardValues.new(1)
	var damage_gained_label: String = YtUtils.text("GTNC")
	multiboard.set_key(0, damage_gained_label)


func on_damage(event: YtEvent):
	var target: YtUnit = event.get_target()
	var chance: float = 0.30 + 0.004 * tower.get_level()

	if !tower.calc_chance(chance):
		return

	YtCombatLog.log_ability(tower, target, "Inject Parasite")

	parasite_bt.apply(tower, target, tower.get_level())


func on_create(_preceding_tower: YtTower):
	tower.user_real = 0


func on_tower_details() -> YtMultiboardValues:
	var damage_gained: String = YtUtils.format_percent(tower.user_real, 0)
	multiboard.set_value(0, damage_gained)

	return multiboard


func parasite_bt_periodic(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var target: YtUnit = buff.get_buffed_unit()
	var level: int = buff.get_level()
	var damage: float = 500 + 100 * level
	var mod_armor: float = -(0.02 + 0.0008 * level)

	tower.do_spell_damage(target, damage, tower.calc_spell_crit_no_bonus())
	target.modify_property(YtModificationType.enm.MOD_ARMOR_PERC, mod_armor)


func parasite_bt_on_death(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var creep: YtUnit = buff.get_buffed_unit()
	var it: YtIterate = YtIterate.over_units_in_range_of_unit(tower, YtTargetType.new(YtTargetType.CREEPS), creep, 500)

	YtEffect.create_simple("res://src/effects/crypt_fiend_eggsack.tscn", Vector2(creep.get_x(), creep.get_y()))

	tower.modify_property(YtModificationType.enm.MOD_DAMAGE_ADD_PERC, 0.0075)
	tower.user_real += 0.0075

	var new_host: YtUnit = it.next()
	var temp: YtUnit = null
	while true:
		if new_host == null || new_host.get_buff_of_type(parasite_bt) == null:
			break

		if new_host != creep:
			temp = new_host

		new_host = it.next()

#	Find a new host! Prefers targets that aren't carrying
#	parasites already.
	if new_host == null:
		if temp == null:
#			No one to jump to! parasite dies :(
			YtEffect.create_scaled("res://src/effects/frost_armor_damage_purple.tscn", Vector3(creep.get_x(), creep.get_y(), 0), 0, 1)
			
			return
		else:
#			Can only jump to a target that already has a
#			parasite. Do it anyway, to refresh the buff
#			duration.
			new_host = temp

	var projectile: YtProjectile = YtProjectile.create_linear_interpolation_from_unit_to_unit(spider_pt, tower, 0, 0, creep, new_host, 0.5, true)
	projectile.set_projectile_scale(0.2)


func spider_pt_on_cleanup(projectile: YtProjectile):
	var creep: YtCreep = projectile.get_target()
	var caster: YtUnit = projectile.get_caster()

	if !YtUtils.unit_is_valid(creep):
		return
	
	parasite_bt.apply(caster, creep, caster.get_level())
