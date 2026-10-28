extends YtBuffType
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var slow_aura_effect: YtBuffType


func _init(parent: Node):
	super("creep_slow_aura", 0, 0, true, parent)

	var draw_below_unit: bool = true
	set_special_effect("res://src/effects/spell_aire_flat.tscn", 0, 1.0, Color.ORANGE, draw_below_unit)
	
	slow_aura_effect = YtBuffType.create_aura_effect_type("creep_slow_aura_effect", false, self)
	var modifier: YtModifier = YtModifier.new()
	modifier.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, -0.50, 0.0)
	slow_aura_effect.set_buff_modifier(modifier)
	slow_aura_effect.set_buff_tooltip(YtUtils.text("ZW9E"))

	add_aura(108, self)
