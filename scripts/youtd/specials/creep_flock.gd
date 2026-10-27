extends YtBuffType
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func _init(parent: Node):
	super("creep_flock", 0, 0, true, parent)
	var modifier: YtModifier = YtModifier.new()
	modifier.add_modification(YtModificationType.enm.MOD_BOUNTY_GRANTED, -0.50, 0.0)
	modifier.add_modification(YtModificationType.enm.MOD_EXP_GRANTED, -0.50, 0.0)
	modifier.add_modification(YtModificationType.enm.MOD_ITEM_CHANCE_ON_DEATH, -0.50, 0.0)
	set_buff_modifier(modifier)

	add_event_on_create(on_create)


func on_create(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var creep: YtCreep = buff.get_buffed_unit()

	creep.set_portal_damage_multiplier(0.5)

