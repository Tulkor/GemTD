extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: this is the "fizzbuzz tower" ;)


# NOTE: SCALE_MIN should match the value in tower sprite
# scene
const SCALE_MIN: float = 0.7
const SCALE_MAX: float = 1.2


var slow_bt: YtBuffType
var grow_bt: YtBuffType
var multiboard: YtMultiboardValues


var attack_count: int = 0
var do_splash_next: bool = false
var growth_count: int = 0


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)
	triggers.add_event_on_damage(on_damage)


func tower_init():
	multiboard = YtMultiboardValues.new(4)
	var attacks_to_crit_label: String = YtUtils.text("HZU6")
	var attacks_to_damage_label: String = YtUtils.text("NB2A")
	var attacks_to_splash_label: String = YtUtils.text("HFOL")
	var attacks_to_grow_label: String = YtUtils.text("LBKG")
	multiboard.set_key(0, attacks_to_crit_label)
	multiboard.set_key(1, attacks_to_damage_label)
	multiboard.set_key(2, attacks_to_splash_label)
	multiboard.set_key(3, attacks_to_grow_label)

	slow_bt = YtBuffType.new("slow_bt", 5, 0, false, self)
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, -0.10, -0.001)
	slow_bt.set_buff_modifier(mod)
	slow_bt.set_buff_icon("res://resources/icons/generic_icons/foot_trip.tres")
	slow_bt.set_buff_tooltip(YtUtils.text("GLMC"))
	slow_bt.add_periodic_event(slow_bt_periodic, 1.0)

	grow_bt = YtBuffType.new("grow_bt", -1, 0, true, self)
	grow_bt.set_buff_icon("res://resources/icons/generic_icons/biceps.tres")
	grow_bt.set_buff_tooltip(YtUtils.text("KQ64"))


func on_create(_preceding: YtTower):
	var grow_buff: YtBuff = grow_bt.apply_to_unit_permanent(tower, tower, 0)
	grow_buff.set_displayed_stacks(growth_count)


func on_attack(event: YtEvent):
	var target: YtUnit = event.get_target()
	var level: int = tower.get_level()
	var crit: int = 0

	attack_count += 1

#	Crit (every 3rd)
	if attack_count % 3 == 0:
		YtCombatLog.log_ability(tower, null, "Crit")
		tower.add_attack_crit()
#		So the triggered attack damage can crit too!
		crit = 1

#	Bonus damage (every 7th)
	if attack_count % 7 == 0:
		YtCombatLog.log_ability(tower, null, "Bonus Damage")
#		Splashed bonus damage (every 84th)
		if attack_count % 12 == 0:
			tower.do_attack_damage_aoe_unit(target, 200, 3000 + 200 * level, tower.calc_attack_multicrit(0, 0, crit), 0)
			var effect: int = YtEffect.create_scaled("res://src/effects/doom_death.tscn", Vector3(target.get_x(), target.get_y(), 0), 0, 1)
			YtEffect.set_z_index(effect, YtEffect.Z_INDEX_BELOW_CREEPS)
		else:
			tower.do_attack_damage(target, 3000 + 200 * level, tower.calc_attack_multicrit(0, 0, crit), 0)
			var effect: int = YtEffect.create_scaled("res://src/effects/doom_death.tscn", Vector3(target.get_x(), target.get_y(), 0), 0, 1)
			YtEffect.set_z_index(effect, YtEffect.Z_INDEX_BELOW_CREEPS)

#	Splash (every 12th)
	if attack_count % 12 == 0:
		YtCombatLog.log_ability(tower, null, "Splash")
		do_splash_next = true

#	Growth (every 15th)
	if attack_count % 15 == 0:
		YtCombatLog.log_ability(tower, null, "Growth")
		
		tower.modify_property(YtModificationType.enm.MOD_DAMAGE_ADD_PERC, 0.005)

#		Rare text has increased chance to show with increased triggerchances. ;]
		var floating_text: String
		if tower.calc_chance(0.005):
			var bathe_in_blood_text: String = YtUtils.text("DQXT")
			floating_text = bathe_in_blood_text
		elif tower.calc_chance(0.1):
			var fear_me_text: String = YtUtils.text("C08E")
			floating_text = fear_me_text
		elif tower.calc_chance(0.4):
			var grrr_text: String = YtUtils.text("MRXN")
			floating_text = grrr_text
		else:
			var roar_text: String = YtUtils.text("JXN3")
			floating_text = roar_text

		tower.get_player().display_floating_text(floating_text, tower, Color8(255, 100, 100))

#		Increase model size
		growth_count += 1

		var grow_buff: YtBuff = tower.get_buff_of_type(grow_bt)
		grow_buff.set_displayed_stacks(growth_count)

		var tower_scale: float = YtUtils.get_scale_from_grows(SCALE_MIN, SCALE_MAX, growth_count, 1000)
		tower.set_unit_scale(tower_scale)

	if attack_count >= 420:
		attack_count = 0


func on_damage(event: YtEvent):
	var target: YtCreep = event.get_target()

	if do_splash_next:
		do_splash_next = false

#		+1 multicrit count for the guaranteed crit every three attacks
		tower.do_attack_damage_aoe_unit(target, 200, tower.get_current_attack_damage_with_bonus(), tower.calc_attack_multicrit(0, 0, 1), 0.0)

#		Cancel damage from regular attack
		event.damage = 0

#		Apply slow to all creeps hit
		var it: YtIterate = YtIterate.over_units_in_range_of_unit(tower, YtTargetType.new(YtTargetType.CREEPS), target, 200)
		
		while true:
			var creep: YtCreep = it.next()

			if creep == null:
				break

			if creep.get_buff_of_type(slow_bt) == null:
				slow_bt.apply(tower, creep, 0)
	else:
		if target.get_buff_of_type(slow_bt) == null:
			slow_bt.apply(tower, target, 0)


func on_tower_details() -> YtMultiboardValues:
	var attacks_to_crit: String = str(3 - attack_count % 3)
	var attacks_to_damage: String = str(7 - attack_count % 7)
	var attacks_to_splash: String = str(12 - attack_count % 12)
	var attacks_to_grow: String = str(15 - attack_count % 15)

	multiboard.set_value(0, attacks_to_crit)
	multiboard.set_value(1, attacks_to_damage)
	multiboard.set_value(2, attacks_to_splash)
	multiboard.set_value(3, attacks_to_grow)

	return multiboard


func slow_bt_periodic(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var active_level: int = buff.get_level()
	var slow_per_stack: float = 0.05 + 0.01 * tower.get_level()
	var new_level: int = active_level + floori(slow_per_stack * 1000)
	buff.set_level(new_level)
