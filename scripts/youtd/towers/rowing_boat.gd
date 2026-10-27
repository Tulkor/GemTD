extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var aura_bt: YtBuffType
var multiboard: YtMultiboardValues


func get_tier_stats() -> Dictionary:
	return {
		1: {plunder_amount = 0.3, mod_bounty = 0.10, mod_bounty_add = 0.005},
		2: {plunder_amount = 1.3, mod_bounty = 0.10, mod_bounty_add = 0.010},
		3: {plunder_amount = 2.4, mod_bounty = 0.15, mod_bounty_add = 0.010},
		4: {plunder_amount = 4.0, mod_bounty = 0.20, mod_bounty_add = 0.010},
	}


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func tower_init():
	var bounty_mod: YtModifier = YtModifier.new()
	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", true, self)
#	Set by aura
	bounty_mod.add_modification(YtModificationType.enm.MOD_BOUNTY_RECEIVED, _stats.mod_bounty, _stats.mod_bounty_add)
	aura_bt.set_buff_modifier(bounty_mod)
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/gold_bar.tres")
	aura_bt.set_buff_tooltip(YtUtils.text("KAMW"))

	multiboard = YtMultiboardValues.new(1)
	var gold_plundered_label: String = YtUtils.text("OMXK")
	multiboard.set_key(0, gold_plundered_label)


func on_attack(_event: YtEvent):
# 	The gold, that will be granted to the player on this attack 
	var gold_granted: float = _stats.plunder_amount
#	Set the statistics
	tower.user_real = tower.user_real + gold_granted
	tower.get_player().give_gold(gold_granted, tower, false, true)


func on_create(preceding_tower: YtTower):
	var parent: YtTower = preceding_tower

# 	Total gold, earned by this towers pirates ability 
	if parent != null && parent.get_family() == tower.get_family():
		tower.user_real = parent.user_real
	else:
		tower.user_real = 0


func on_tower_details() -> YtMultiboardValues:
	var gold_plundered_text: String = YtUtils.format_float(tower.user_real, 2)
	multiboard.set_value(0, gold_plundered_text)
	
	return multiboard
