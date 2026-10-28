extends YtBuffType
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func _init(parent: Node):
	super("creep_fireball", 0, 0, true, parent)

	add_event_on_damaged(on_damaged)


func on_damaged(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var creep: YtUnit = buff.get_buffed_unit()
	var attacker: YtUnit = event.get_target()

	if !creep.calc_chance(0.05):
		return

	creep.kill_instantly(attacker)
