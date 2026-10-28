extends YtBuffType
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var unlucky_active: YtBuffType


func _init(parent: Node):
	super("creep_unlucky", 0, 0, true, parent)

	add_event_on_damaged(on_damaged)

	unlucky_active = YtBuffType.new("unlucky_active", 8.0, 0, false, self
		)
	var modifier: YtModifier = YtModifier.new()
	modifier.add_modification(YtModificationType.enm.MOD_TRIGGER_CHANCES, 0.0, -0.001)
	unlucky_active.set_buff_modifier(modifier)
	unlucky_active.set_buff_icon("res://resources/icons/generic_icons/aquarius.tres")
	unlucky_active.set_buff_icon_color(Color.YELLOW)


func on_damaged(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var creep: YtUnit = buff.get_buffed_unit()
	var attacker: YtUnit = event.get_target()
	var creep_is_silenced: bool = creep.is_silenced()

	if creep_is_silenced:
		return

	if !creep.calc_chance(0.30):
		return

	var active_buff: YtBuff = attacker.get_buff_of_type(unlucky_active)

	if active_buff != null:
		active_buff = unlucky_active.apply(creep, attacker, active_buff.get_level() + 10)
		active_buff.refresh_duration()
	else:
		active_buff = unlucky_active.apply(creep, attacker, 10)
