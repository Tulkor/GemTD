extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var aura_bt: YtBuffType
var awaken_bt: YtBuffType
var missile_pt: YtProjectileType
var is_awake: bool = false


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)
	triggers.add_event_on_kill(on_kill)
	triggers.add_event_on_spell_targeted(on_spell_targeted)


func tower_init():
	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", true, self)
	aura_bt.set_buff_tooltip(YtUtils.text("WMXC"))
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/shiny_omega.tres")
	aura_bt.add_event_on_create(aura_bt_on_create)
	aura_bt.add_event_on_spell_casted(aura_bt_on_spell_casted)

	awaken_bt = YtBuffType.new("awaken_bt", 5, 0, true, self)
	awaken_bt.set_buff_icon("res://resources/icons/generic_icons/semi_closed_eye.tres")
	awaken_bt.set_buff_tooltip(YtUtils.text("KY4C"))
	awaken_bt.add_event_on_create(awaken_bt_on_create)
	awaken_bt.add_event_on_cleanup(awaken_bt_on_cleanup)

	missile_pt = YtProjectileType.create("path_to_projectile_sprite", 10, 1500, self)
	missile_pt.enable_homing(missile_pt_on_hit, 0.0)


func on_attack(event: YtEvent):
	var damage: float = (6 + 0.1 * tower.get_level()) * tower.get_mana()
	var creep: YtCreep = event.get_target()

	if !is_awake:
		tower.order_stop()

		return

	var p: YtProjectile = YtProjectile.create_from_unit_to_unit(missile_pt, tower, 1.0, tower.calc_spell_crit_no_bonus(), tower, creep, true, false, false)

	var arcane_aura_chance: float = 0.1 + 0.004 * tower.get_level()

	if tower.get_mana() >= 100:
		tower.subtract_mana(100, false)

		if tower.calc_chance(arcane_aura_chance):
			arcane_mana_replenish(tower)

		var floating_text: String = "+%s" % YtUtils.format_float(damage, 0)
		tower.get_player().display_floating_text_x(floating_text, tower, Color8(255, 0, 255, 255), 0.05, 2, 3)
		p.user_real = damage
	else:
		p.user_real = 0


func on_kill(_event: YtEvent):
	tower.modify_property(YtModificationType.enm.MOD_MANA, 1)


func on_spell_targeted(_event: YtEvent):
	awaken_bt.apply(tower, tower, 0)


func on_create(preceding_tower: YtTower):
	if preceding_tower == null:
		return

	var preceding_kills: int = preceding_tower.get_kills()
	tower.modify_property(YtModificationType.enm.MOD_MANA, preceding_kills)


func aura_bt_on_create(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var last_proc_tick: int = 0
	buff.user_int = last_proc_tick


func aura_bt_on_spell_casted(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var buffed_tower: YtTower = buff.get_buffed_unit()
	var last_proc_tick: int = buff.user_int
	var autocast: YtAutocast = event.get_autocast_type()

#	NOTE: use tick-based calculation to avoid float precision
#	drift in multiplayer.
	var cooldown_ticks: int = YtUtils.time_to_ticks(5)
	var current_tick: int = YtUtils.get_current_tick()
	var can_proc: bool = last_proc_tick + cooldown_ticks < current_tick && autocast.get_mana_cost() > 0

	if !can_proc:
		return

	var proc_chance: bool = 0.10 + 0.004 * buffed_tower.get_level()

	if !buffed_tower.calc_chance(proc_chance):
		return

	YtCombatLog.log_ability(buffed_tower, null, "Arcane Aura proc")

	arcane_mana_replenish(buffed_tower)

	last_proc_tick = current_tick
	buff.user_int = last_proc_tick


func arcane_mana_replenish(target: YtTower):
	YtEffect.create_colored("res://src/effects/replenish_mana.tscn", Vector3(target.get_x(), target.get_y(), 80), 0.0, 5, Color8(100, 100, 255, 255))
	var mana_gain: float = 0.1 + 0.002 * target.get_level()
	target.add_mana_perc(mana_gain)


func awaken_bt_on_create(_event: YtEvent):
	# AddUnitAnimationProperties(u, "stand alternate", true)
	# SetUnitFlyHeight(u, 100, 2000)

	YtCombatLog.log_ability(tower, null, "Grotesque Awakening")

	is_awake = true


func awaken_bt_on_cleanup(_event: YtEvent):
	# AddUnitAnimationProperties(u, "stand alternate", false)
	# SetUnitFlyHeight(u, 40, 2000)

	YtCombatLog.log_ability(tower, null, "Grotesque Awakening End")

	is_awake = false


func missile_pt_on_hit(p: YtProjectile, target: YtUnit):
	if target == null:
		return

	var damage: float = p.user_real
	p.do_spell_damage(target, damage)
