extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: original function removed all buffs made by this
# tower in on_destruct() to remove visual effects. This is
# not needed in godot engine because buffs are already
# automatically removed when one of their event handlers is
# removed.


var jolt_bt: YtBuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {attack_speed = 0.2, attack_speed_add = 0.002, damage_on_attack = 150},
		2: {attack_speed = 0.25, attack_speed_add = 0.004, damage_on_attack = 320},
		3: {attack_speed = 0.32, attack_speed_add = 0.0052, damage_on_attack = 500},
	}


func junction_on_create(event: YtEvent):
	var b: YtBuff = event.get_buff()
	var buffee: YtTower = b.get_buffed_unit()

	b.user_int = 0

	if tower != buffee:
		var lightning: YtInterpolatedSprite = YtInterpolatedSprite.create_from_unit_to_unit(YtInterpolatedSprite.LIGHTNING, tower, buffee)
		lightning.modulate = Color.LIGHT_BLUE

		# NOTE: usage of get_instance_id() is OK here and
		# doesn't cause desyncs because the lightning object
		# is visual only.
		b.user_int = lightning.get_instance_id()

#	NOTE: add & save attack speed
	b.user_real = tower.user_real + tower.user_real2 * tower.get_level()
	buffee.modify_property(YtModificationType.enm.MOD_ATTACKSPEED, b.user_real)


func junction_on_damage(event: YtEvent):
	var b: YtBuff = event.get_buff()
	var caster: YtTower = b.get_caster()
	var buffee: YtTower = b.get_buffed_unit()
	var creep: YtCreep = event.get_target()
	var damage: float = caster.user_real3 * (1 + caster.get_level() / 25.0) * buffee.get_base_attack_speed()

	buffee.do_spell_damage(creep, damage, buffee.calc_spell_crit_no_bonus())
	buffee.do_attack_damage(creep, damage, buffee.calc_attack_multicrit(0, 0, 0))

	YtEffect.create_simple_at_unit("res://src/effects/purge_buff_target.tscn", creep)


func junction_on_cleanup(event: YtEvent):
	var b: YtBuff = event.get_buff()

	if b.user_int != 0:
		# NOTE: usage of instance_from_id() is OK here and
		# doesn't cause desyncs because the lightning object
		# is visual only.
		var lightning: YtInterpolatedSprite = instance_from_id(b.user_int) as YtInterpolatedSprite
		if lightning != null:
			lightning.queue_free()

	b.get_buffed_unit().modify_property(YtModificationType.enm.MOD_ATTACKSPEED, -b.user_real)


func tower_init():
	jolt_bt = YtBuffType.new("jolt_bt", 10, 0, true, self)
	jolt_bt.set_buff_icon("res://resources/icons/generic_icons/electric.tres")
	jolt_bt.add_event_on_create(junction_on_create)
	jolt_bt.add_event_on_attack(junction_on_damage)
	jolt_bt.add_event_on_cleanup(junction_on_cleanup)
	jolt_bt.set_buff_tooltip(YtUtils.text("J0NB"))


func on_create(_preceding_tower: YtTower):
# 	base attack_speed boost
	tower.user_real = _stats.attack_speed
# 	attack speed boost add
	tower.user_real2 = _stats.attack_speed_add
# 	base dmg & spelldmg per attack (/25 for level bonus)
	tower.user_real3 = _stats.damage_on_attack
