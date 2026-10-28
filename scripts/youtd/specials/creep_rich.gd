extends YtBuffType
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func _init(parent: Node):
	super("creep_rich", 0, 0, true, parent)
	var modifier: YtModifier = YtModifier.new()
	modifier.add_modification(YtModificationType.enm.MOD_BOUNTY_GRANTED, 0.60, 0.0)
	modifier.add_modification(YtModificationType.enm.MOD_EXP_GRANTED, -1.0, 0.0)
	set_buff_modifier(modifier)
