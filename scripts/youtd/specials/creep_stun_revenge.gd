extends YtBuffType
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var stun_bt: YtBuffType


func _init(parent: Node):
	super("creep_stun_revenge", 0, 0, true, parent)

	stun_bt = YtCbStun.new("stun_bt", 0, 0, false, self)
	stun_bt.set_special_effect("res://src/effects/shackle.tscn", 50, 1.0, Color(Color.GOLD, 0.75))

	add_event_on_attacked(on_attacked)


func on_attacked(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var creep: YtUnit = buff.get_buffed_unit()
	var attacker: YtUnit = event.get_target()
	
	var creep_is_silenced: bool = creep.is_silenced()
	if creep_is_silenced:
		return

	var stun_success: bool = creep.calc_chance(0.3)
	if stun_success:
		stun_bt.apply_only_timed(creep, attacker, 3.0)

		YtSFX.sfx_at_unit(YtSfxPaths.MAGIC_FIZZLE, attacker)
