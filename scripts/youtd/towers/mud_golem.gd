extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var aura_bt: YtBuffType
var slow_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func tower_init():
	slow_bt = YtBuffType.new("slow_bt", 0.5, 0.012, false, self)
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, -0.60, 0.0)
	slow_bt.set_buff_modifier(mod)
	slow_bt.set_buff_icon("res://resources/icons/generic_icons/hammer_drop.tres")
	slow_bt.set_buff_tooltip(YtUtils.text("INTD"))

	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", true, self)
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/cog.tres")
	aura_bt.add_event_on_attack(aura_bt_on_attack)
	aura_bt.set_buff_tooltip(YtUtils.text("GYWF"))


func on_damage(_event: YtEvent):
	YtCombatLog.log_ability(tower, null, "Ground Smash")

	smash()


func aura_bt_on_attack(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var buffed_tower: YtTower = buff.get_buffed_unit()
	var ground_smash_chance: float = (0.03 + 0.0004 * tower.get_level()) * buffed_tower.get_base_attack_speed()

	if !buffed_tower.calc_chance(ground_smash_chance):
		return

	YtCombatLog.log_ability(buffed_tower, null, "Ground Smash")

	smash()


func smash():
	var level: int = tower.get_level()
	var smash_damage: float = (4300 + 230 * level) * tower.get_prop_spell_damage_dealt()

	var smash_range: float
	if level == 25:
		smash_range = 800
	else:
		smash_range = 750

	var it: YtIterate = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.CREEPS), smash_range)
	
	while true:
		var next: YtUnit = it.next()

		if next == null:
			break

		if next.get_size() == YtCreepSize.enm.AIR:
			continue

#		NOTE: using do_attack_damage() with args based on
#		spell damage is not a typo. Written this way in
#		original script on purpose.
		slow_bt.apply(tower, next, level)
		tower.do_attack_damage(next, smash_damage, tower.calc_spell_crit_no_bonus())
