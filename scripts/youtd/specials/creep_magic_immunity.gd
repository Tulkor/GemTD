extends YtBuffType
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func _init(parent: Node):
	super("creep_magic_immunity", 0, 0, true, parent)
	add_periodic_event(periodic, 0.1)


func periodic(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var creep: YtUnit = buff.get_buffed_unit()
	var creep_mana: float = creep.get_mana()
	var should_be_immune: bool = creep_mana >= 10
	creep.set_immune(should_be_immune)
