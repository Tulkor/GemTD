extends YtBuffType
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: this doesn't 100% match original code logic but end
# result is the same. Used autocast so that channeling is
# affected by silence.


const PROTECTOR_RANGE: int = 1000


var aura_bt: YtBuffType
var channel_bt: YtBuffType
var curse_bt: YtBuffType


func _init(parent: Node):
	super("creep_protector", 0, 0, true, parent)

	add_event_on_create(on_create)
	
	channel_bt = YtBuffType.new("channel_bt", 0, 0, true, self)
	channel_bt.set_buff_icon("res://resources/icons/generic_icons/alien_skull.tres")
	channel_bt.set_buff_icon_color(Color.DARK_RED)
	channel_bt.set_buff_tooltip(YtUtils.text("LT32"))
	
	curse_bt = YtBuffType.new("curse_bt", 1.5, 0, false, self
		)
	var modifier: YtModifier = YtModifier.new()
	modifier.add_modification(YtModificationType.enm.MOD_DAMAGE_ADD_PERC, -1.3, 0.0)
	modifier.add_modification(YtModificationType.enm.MOD_MULTICRIT_COUNT, -2, 0.0)
	curse_bt.set_buff_icon("res://resources/icons/generic_icons/alien_skull.tres")
	curse_bt.set_buff_icon_color(Color.DARK_RED)
	curse_bt.set_buff_tooltip(YtUtils.text("M3QZ"))
	curse_bt.set_buff_modifier(modifier)

	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", true, self)
	aura_bt.add_event_on_death(aura_bt_on_death)
	aura_bt.set_hidden()

	add_aura(107, self)


func on_create(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var protector: YtUnit = buff.get_buffed_unit()

	var autocast: YtAutocast = YtAutocast.make(172, self)
	protector.add_autocast(autocast)


func aura_bt_on_death(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var protector: YtUnit = buff.get_caster()

	var channel_buff: YtBuff = protector.get_buff_of_type(channel_bt)

	var protector_is_channeling: bool = channel_buff != null

	if protector_is_channeling:
		var it: YtIterate = YtIterate.over_units_in_range_of_caster(protector, YtTargetType.new(YtTargetType.CREEPS + YtTargetType.SIZE_MASS + YtTargetType.SIZE_NORMAL + YtTargetType.SIZE_BOSS + YtTargetType.SIZE_AIR), PROTECTOR_RANGE)
		var non_champion_count: int = it.count()
		var stop_channel: bool = non_champion_count == 0

		if stop_channel:
			channel_buff.remove_buff()
	else:
		var attacker: YtUnit = event.get_target()
		var new_channel_buff: YtBuff = channel_bt.apply_to_unit_permanent(protector, protector, 0)
		new_channel_buff.user_int = attacker.get_uid()


func on_autocast(event: YtEvent):
	var autocast: YtAutocast = event.get_autocast_type()
	var protector: YtUnit = autocast.get_caster()
	var channel_buff: YtBuff = protector.get_buff_of_type(channel_bt)
	var protector_is_channeling: bool = channel_buff != null

	if !protector_is_channeling:
		return
	
	var cursed_tower_instance_uid: int = channel_buff.user_int
	var cursed_tower_object: Object = YtGroupManager.get_by_uid("towers", cursed_tower_instance_uid)

	if cursed_tower_object == null || !YtUtils.unit_is_valid(cursed_tower_object):
		return

	var cursed_tower: YtUnit = cursed_tower_object as YtUnit

	var tower_pos: Vector2 = cursed_tower.get_position_wc3_2d()
	var protector_pos: Vector2 = protector.get_position_wc3_2d()
	var cursed_tower_is_in_range: bool = YtVectorUtils.in_range(tower_pos, protector_pos, PROTECTOR_RANGE)

	if !cursed_tower_is_in_range:
		channel_buff.remove_buff()

		return

	curse_bt.apply(protector, cursed_tower, 0)

	var lightning: YtInterpolatedSprite = YtInterpolatedSprite.create_from_unit_to_unit(YtInterpolatedSprite.LIGHTNING, protector, cursed_tower)
	lightning.modulate = Color.DARK_OLIVE_GREEN
	lightning.set_lifetime(1.0)
