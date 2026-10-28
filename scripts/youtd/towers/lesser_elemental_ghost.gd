extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var wrath_bt: YtBuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {wrath_mod_trigger_chances_add = 0.005, elemental_wrath_chance = 0.150},
		2: {wrath_mod_trigger_chances_add = 0.006, elemental_wrath_chance = 0.175},
		3: {wrath_mod_trigger_chances_add = 0.007, elemental_wrath_chance = 0.200},
		4: {wrath_mod_trigger_chances_add = 0.008, elemental_wrath_chance = 0.225},
		5: {wrath_mod_trigger_chances_add = 0.009, elemental_wrath_chance = 0.250},
	}


var BUFF_DURATION: float = 5.0
var BUFF_DURATION_ADD: float = 0.1
var WRATH_MOD_TRIGGER_CHANCES: float = 0.15


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)
	triggers.add_event_on_damage(on_damage)


func tower_init():
	var modifier: YtModifier = YtModifier.new()
	modifier.add_modification(YtModificationType.enm.MOD_TRIGGER_CHANCES, WRATH_MOD_TRIGGER_CHANCES, _stats.wrath_mod_trigger_chances_add)
	wrath_bt = YtBuffType.new("wrath_bt", BUFF_DURATION, BUFF_DURATION_ADD, true, self)
	wrath_bt.set_buff_icon("res://resources/icons/generic_icons/holy_grail.tres")
	wrath_bt.set_buff_modifier(modifier)
	wrath_bt.set_buff_tooltip(YtUtils.text("ANUA"))


func on_attack(_event: YtEvent):
	if !tower.calc_chance(_stats.elemental_wrath_chance):
		return

	if tower.get_buff_of_type(wrath_bt) == null:
		YtCombatLog.log_ability(tower, null, "Elemental Wrath")

		var level: int = tower.get_level()

		wrath_bt.apply(tower, tower, level)


func on_damage(event: YtEvent):
	var target: YtCreep = event.get_target()
	var immune: bool = target.is_immune()
	var sif: bool = target.get_armor_type() == YtArmorType.enm.SIF
	var zod: bool = target.get_armor_type() == YtArmorType.enm.ZOD
	var damage_add: float
	var pos_damage_types: float = 3.0

	if immune:
		pos_damage_types = 2.0

	if YtUtils.rand_chance(YtGlobals.synced_rng, 0.5):
		if sif || zod:
			damage_add = 1.0
		elif tower.calc_chance(1.0 / pos_damage_types):
			damage_add = 1.8
		elif !immune && tower.calc_chance(1.0 / (pos_damage_types - 1)):
			damage_add = 1.5
		else:
			damage_add = 1.2
	else:
		if zod:
			damage_add = 0.9
		elif sif:
			if !immune || (immune && tower.calc_chance(0.5)):
				damage_add = 0.4
			else:
				damage_add = 0.0
		elif tower.calc_chance(1.0 / (6.0 - pos_damage_types)):
			damage_add = 1.0
		elif tower.calc_chance(1.0 / (6.0 - (pos_damage_types + 1))):
			damage_add = 0.9
		elif !immune || (immune && tower.calc_chance(1.0 / (6.0 - (pos_damage_types + 2)))):
			damage_add = 0.6
		else:
			damage_add = 0.0

	event.damage = event.damage * damage_add

	if damage_add > 1.0:
		tower.get_player().display_small_floating_text(YtUtils.format_float(damage_add, 2), tower, Color8(0, 255, 0), 40)
	elif damage_add < 1.0:
		tower.get_player().display_small_floating_text(YtUtils.format_float(damage_add, 2), tower, Color8(255, 0, 0), 40)
	else:
		tower.get_player().display_small_floating_text(YtUtils.format_float(damage_add, 2), tower, Color8(255, 255, 255), 40)
