class_name YtCbSilence
extends YtBuffType
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.

# NOTE: globally available cb_silence in JASS


# NOTE: YtBuffType.createDuplicate(cb_silence...) in JASS
func _init(type: String, time_base: float, time_level_add: float,friendly: bool, parent: Node):
	super(type, time_base, time_level_add, friendly, parent)
	add_event_on_create(on_create)
	add_event_on_cleanup(_on_cleanup)

	set_buff_icon("res://resources/icons/generic_icons/beard.tres")
	set_buff_tooltip(YtUtils.text("TCH4"))


func on_create(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var target = buff.get_buffed_unit()

	target.add_silence()


func _on_cleanup(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var target = buff.get_buffed_unit()

	target.remove_silence()
