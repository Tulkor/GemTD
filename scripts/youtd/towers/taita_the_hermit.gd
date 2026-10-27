extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: [ORIGINAL_GAME_BUG] (NOT FIXED) this tower will deal
# 0 damage if Frost Bolt ability hits a creep with no Icy
# Touch stacks. Kind of weird.


var cold_blood_bt: YtBuffType
var icy_touch_bt: YtBuffType
var frostbolt_pt: YtProjectileType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)
	triggers.add_event_on_damage(on_damage)
	triggers.add_event_on_kill(on_kill)


func tower_init():
	cold_blood_bt = YtBuffType.new("cold_blood_bt", 3, 0, true, self)
	var dave_taita_blood_mod: YtModifier = YtModifier.new()
	dave_taita_blood_mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 0.5, 0.005)
	cold_blood_bt.set_buff_modifier(dave_taita_blood_mod)
	cold_blood_bt.set_buff_icon("res://resources/icons/generic_icons/azul_flake.tres")
	cold_blood_bt.set_buff_tooltip(YtUtils.text("BZF0"))

	icy_touch_bt = YtBuffType.new("icy_touch_bt", 5, 0, false, self)
	var dave_taita_touch_mod: YtModifier = YtModifier.new()
	dave_taita_touch_mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, 0.0, -0.1)
	icy_touch_bt.set_buff_modifier(dave_taita_touch_mod)
	icy_touch_bt.set_buff_icon("res://resources/icons/generic_icons/foot_trip.tres")
	icy_touch_bt.set_buff_tooltip(YtUtils.text("YSCT"))

	frostbolt_pt = YtProjectileType.create("path_to_projectile_sprite", 4, 900, self)
	frostbolt_pt.enable_homing(frostbolt_pt_on_hit, 0)


func on_attack(event: YtEvent):
	var creep: YtUnit = event.get_target()
	var speed: float = YtConstants.DEFAULT_MOVE_SPEED
	var current_speed: float = creep.get_current_movespeed()
	var slow: float = (speed - current_speed) / speed

	if !tower.calc_chance(slow):
		return

	YtCombatLog.log_ability(tower, creep, "Frost Bolt")

	YtProjectile.create_from_unit_to_unit(frostbolt_pt, tower, 1, 1, tower, creep, true, false, false)


func on_damage(event: YtEvent):
	var target: YtUnit = event.get_target()
	var buff: YtBuff = target.get_buff_of_type(icy_touch_bt)
	var buff_level: int = 0
	var damage: float = tower.get_current_attack_damage_with_bonus()
	var level: int = tower.get_level()

	if buff != null:
		buff_level = buff.get_level()
		event.damage = event.damage * (1 + buff_level * (0.1 + 0.02 * level))

	if buff_level < 6:
		icy_touch_bt.apply(tower, target, buff_level + 1)

	buff = target.get_buff_of_type(icy_touch_bt)
	if buff != null:
		buff.set_displayed_stacks(buff.get_level())


func on_kill(_event: YtEvent):
	var level: int = tower.get_level()

	cold_blood_bt.apply(tower, tower, level)


func frostbolt_pt_on_hit(_p: YtProjectile, creep: YtUnit):
	if creep == null:
		return

	var level: int = tower.get_level()
	var buff: YtBuff = creep.get_buff_of_type(icy_touch_bt)

	var buff_level: int
	if buff != null:
		buff_level = buff.get_level()
	else:
		buff_level = 0

	var damage: float = tower.get_current_attack_damage_with_bonus() * buff_level * (0.2 + (0.004 * level))
	if creep.is_stunned():
		damage *= 2

	YtCombatLog.log_ability(tower, creep, "Frost Bolt Hit AoE")

	tower.do_attack_damage_aoe_unit(creep, 200, damage, tower.calc_attack_multicrit_no_bonus(), 0.0)
