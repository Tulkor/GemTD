extends YtBuffType
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: this is commented out because invisibility mechanic
# is not implemented


func _init(parent: Node):
	super("creep_invisible", 0, 0, true, parent)

	# add_event_on_create(on_create)


# func on_create(event: YtEvent):
# 	var buff: YtBuff = event.get_buff()
# 	var creep: YtUnit = buff.get_buffed_unit()
# 	creep.set_invisible(true)
