extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var attack_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


func item_init():
	attack_bt = YtBuffType.new("attack_bt", 4, 0.1, true, self)
	attack_bt.set_buff_icon("res://resources/icons/generic_icons/hammer_drop.tres")
	attack_bt.set_buff_tooltip(YtUtils.text("W1NC"))
	var mod: YtModifier = YtModifier.new() 
	mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 0.50, 0) 
	attack_bt.set_buff_modifier(mod) 


func on_attack(_event: YtEvent):
	var tower: YtTower = item.get_carrier() 
	var in_range: YtIterate
	var nxt: YtTower
	var spieler: YtPlayer = tower.get_player()
	var speed: float = tower.get_base_attack_speed()

	if tower.calc_chance(speed * (0.02 + 0.001 * tower.get_level())):
		YtCombatLog.log_item_ability(item, null, "Attack!")
		
		var attack_text: String = YtUtils.text("HY2D")
		spieler.display_floating_text(attack_text, tower, Color8(255, 0, 0))
		YtEffect.create_simple_at_unit_attached("res://src/effects/roar.tscn", tower, YtUnit.BodyPart.ORIGIN)
		in_range = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.TOWERS), 350)

		while true:
			nxt = in_range.next()

			if nxt == null:
				break

			attack_bt.apply_custom_timed(tower, nxt, tower.get_level(), 4 + 0.2 * tower.get_level())
