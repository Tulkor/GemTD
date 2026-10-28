extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var enraged_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_kill(on_kill)


func item_init():
	enraged_bt = YtBuffType.new("enraged_bt", 0, 0, true, self)
	enraged_bt.set_buff_icon("res://resources/icons/generic_icons/mighty_force.tres")
	enraged_bt.set_buff_tooltip(YtUtils.text("JE2F"))
	var mod: YtModifier = YtModifier.new()
	mod.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 0.20, 0.004)
	enraged_bt.set_buff_modifier(mod)


func on_kill(event: YtEvent):
	var tower: YtTower = item.get_carrier()

	if tower.get_buff_of_type(enraged_bt) == null:
		YtSFX.sfx_at_unit(YtSfxPaths.TELEPORT_BASS, event.get_target())
		YtEffect.create_simple_at_unit("res://src/effects/stampede_missile_death.tscn", event.get_target())
		enraged_bt.apply_custom_timed(tower, tower, tower.get_level(), 3.0)
