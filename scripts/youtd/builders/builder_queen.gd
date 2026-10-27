extends YtBuilder
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func _get_tower_modifier() -> YtModifier:
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 0.10, 0.0)
	mod.add_modification(YtModificationType.enm.MOD_DMG_TO_AIR, 0.30, 0.02)

	return mod


func _get_creep_buff() -> YtBuffType:
	var queen_bt: YtBuffType = YtBuffType.new("queen_bt", 0, 0, false, self)
	queen_bt.add_event_on_create(_creep_bt_on_create)

	return queen_bt


func _creep_bt_on_create(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var buffed_unit: YtUnit = buff.get_buffed_unit()
	var creep: YtCreep = buffed_unit as YtCreep

	if creep == null:
		return

	var creep_size: YtCreepSize.enm = creep.get_size()

	if creep_size == YtCreepSize.enm.AIR:
		creep.modify_property(YtModificationType.enm.MOD_MOVESPEED_ABSOLUTE, -60)
