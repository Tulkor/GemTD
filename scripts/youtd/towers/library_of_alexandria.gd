extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var aura_bt: YtBuffType
var teachings_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_periodic_event(periodic, 5.0)


func tower_init():
	aura_bt = YtBuffType.create_aura_effect_type("aura_bt", true, self)
	var library_aura_mod: YtModifier = YtModifier.new()
	library_aura_mod.add_modification(YtModificationType.enm.MOD_EXP_GRANTED, 0.30, 0.01)
	aura_bt.set_buff_modifier(library_aura_mod)
	aura_bt.set_buff_icon("res://resources/icons/generic_icons/spell_book.tres")
	aura_bt.set_buff_tooltip(YtUtils.text("OTAZ"))

	teachings_bt = YtBuffType.new("teachings_bt", 10, 0.2, true, self)
	var library_divine_teachings_mod: YtModifier = YtModifier.new()
	library_divine_teachings_mod.add_modification(YtModificationType.enm.MOD_EXP_RECEIVED, 1.0, 0.02)
	teachings_bt.set_buff_modifier(library_divine_teachings_mod)
	teachings_bt.set_buff_icon("res://resources/icons/generic_icons/spell_book.tres")
	teachings_bt.set_buff_tooltip(YtUtils.text("TL4V"))


func periodic(_event: YtEvent):
	var lvl: int = tower.get_level()
	var towers_in_range: YtIterate = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.TOWERS), 500)
	var random_tower: YtTower = towers_in_range.next_random()

	if random_tower == null:
		return

	random_tower.add_exp(2 + lvl * 0.2)
	YtEffect.create_simple_at_unit("res://src/effects/spell_alim.tscn", random_tower)


func on_autocast(event: YtEvent):
	var target: YtUnit = event.get_target()
	tower.add_exp(2)
	teachings_bt.apply(tower, target, tower.get_level())
