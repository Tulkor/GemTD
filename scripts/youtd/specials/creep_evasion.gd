extends YtBuffType
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func _init(parent: Node):
	super("creep_evasion", 0, 0, true, parent)
	add_event_on_damaged(on_damaged)


func on_damaged(event: YtEvent):
	evasion_effect(event, 0.25)


static func evasion_effect(event: YtEvent, chance: float):
	var buff: YtBuff = event.get_buff()
	var creep: YtUnit = buff.get_buffed_unit()
	var tower: YtUnit = event.get_target()
	var evade_success: bool = creep.calc_chance(chance)

	if evade_success && !event.is_spell_damage():
		event.damage = 0
		tower.get_player().display_floating_text_x(YtUtils.tr_text("FLOATING_TEXT_MISS"), tower, Color.RED, 0.05, 0.0, 2.0)
