extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func on_damage(event: YtEvent):
	var carrier: YtTower = item.get_carrier()
	var regen: float = carrier.get_base_mana_regen_bonus_percent()
	
	item.user_int = item.user_int + 1

	if item.user_int >= 5:
		YtCombatLog.log_item_ability(item, null, "Infuse with Regeneration")
		
#		NOTE: original script multiplies damage by (2.0 +
#		regen). Changed it to (1.0 + regen) because of
#		differences in how
#		get_base_mana_regen_bonus_percent() works.
#		- In original youtd, that f-n returns 0.0 by
#		  default.
#		- In youtd2, it returns 1.0 by default.
#		
#		So in original game damage was multiplied by 2.0 for
#		a default tower. max(0.0, ...) allows for damage
#		penalty when mana regen is reduced by i.e. mana
#		drain aura creeps while preventing it from turning
#		negative.
#		
#		NOTE: damage is multiplied by 2.0 for a default
#		tower because by default, towers have 100%
#		"percentual mana regeneration". This is different
#		from "percentual mana regeneration bonus" stat which
#		starts at +0%.
		event.damage *= max(0.0, 1.0 + regen)
		item.user_int = 0
		var damage_text: String = YtUtils.format_float(event.damage, 0)
		carrier.get_player().display_small_floating_text(damage_text, carrier, Color8(255, 0, 255), 40.0)


func on_create():
	item.user_int = 0
