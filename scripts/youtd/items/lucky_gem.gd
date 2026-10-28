extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var stun_bt: YtBuffType
var slow_bt: YtBuffType
var armor_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func item_init():
	stun_bt = YtCbStun.new("stun_bt", 0, 0, false, self)
	
	slow_bt = YtBuffType.new("slow_bt", 0, 0, false, self)
	slow_bt.set_buff_icon("res://resources/icons/generic_icons/foot_trip.tres")
	slow_bt.set_buff_tooltip(YtUtils.text("KRA1"))
	var slow_bt_mod: YtModifier = YtModifier.new()
	slow_bt_mod.add_modification(YtModificationType.enm.MOD_MOVESPEED, 0, -0.001)
	slow_bt.set_buff_modifier(slow_bt_mod)

	armor_bt = YtBuffType.new("armor_bt", 0, 0, false, self)
	armor_bt.set_buff_icon("res://resources/icons/generic_icons/open_wound.tres")
	armor_bt.set_buff_tooltip(YtUtils.text("PJYW"))
	var armor_bt_mod: YtModifier = YtModifier.new()
	armor_bt_mod.add_modification(YtModificationType.enm.MOD_ARMOR, 0, -1)
	armor_bt.set_buff_modifier(armor_bt_mod)


func on_damage(event: YtEvent):
	var target: YtUnit = event.get_target()
	var a: int = YtGlobals.synced_rng.randi_range(0, 4)
	var tower: YtTower = item.get_carrier()
	var speed: float = tower.get_base_attack_speed()

	if tower.calc_chance(0.20 * speed) && event.is_main_target() == true:
		
		if a < 1:
			YtCombatLog.log_item_ability(item, null, "Stun!")
			stun_bt.apply_only_timed(tower, target, 0.5)
			var stun_text: String = YtUtils.text("NMYW")
			tower.get_player().display_small_floating_text(stun_text, tower, Color8(255, 165, 0), 30)
		elif a < 2:
			YtCombatLog.log_item_ability(item, null, "Slow!")
			slow_bt.apply_custom_timed(tower, target, 100, 3)
			var slow_text: String = YtUtils.text("Z5NR")
			tower.get_player().display_small_floating_text(slow_text, tower, Color8(255, 165, 0), 30)
		elif a < 3:
			YtCombatLog.log_item_ability(item, null, "Gold!")
			tower.get_player().give_gold(10, tower, true, true)
			var gold_text: String = YtUtils.text("S88X")
			tower.get_player().display_small_floating_text(gold_text, tower, Color8(255, 165, 0), 30)
		elif a < 4:
			YtCombatLog.log_item_ability(item, null, "Exp!")
			tower.add_exp(1.0)
			var exp_text: String = YtUtils.text("NUE1")
			tower.get_player().display_small_floating_text(exp_text, tower, Color8(255, 165, 0), 30)
		elif a < 5:
			YtCombatLog.log_item_ability(item, null, "Armor!")
			armor_bt.apply_custom_timed(tower, target, 5, 3)
			var armor_text: String = YtUtils.text("CC5X")
			tower.get_player().display_small_floating_text(armor_text, tower, Color8(255, 165, 0), 30)
