extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var acid_bt: YtBuffType

# NOTE: values here are pre-multiplied by 1000, so 600 = 0.6
# as final value. That's how it is in original script and we
# stick to original to avoid introducting bugs.
func get_tier_stats() -> Dictionary:
	return {
		1: {armor_base = 0.6, armor_add = 0.024},
		2: {armor_base = 1.2, armor_add = 0.048},
		3: {armor_base = 2.4, armor_add = 0.096},
		4: {armor_base = 4.8, armor_add = 0.192},
		5: {armor_base = 9.6, armor_add = 0.384},
	}


const DEBUFF_DURATION: float = 3.0
const DEBUFF_DURATION_ADD: float = 0.12


func load_triggers(triggers_buff_type: YtBuffType):
	triggers_buff_type.add_event_on_damage(on_damage)


func tower_init():
	var m: YtModifier = YtModifier.new()
	m.add_modification(YtModificationType.enm.MOD_ARMOR, -_stats.armor_base, -_stats.armor_add)
	acid_bt = YtBuffType.new("acid_bt", DEBUFF_DURATION, DEBUFF_DURATION_ADD, false, self)
	acid_bt.set_buff_icon("res://resources/icons/generic_icons/open_wound.tres")
	acid_bt.set_buff_modifier(m)

	acid_bt.set_buff_tooltip(YtUtils.text("Y1IG"))


func on_damage(event: YtEvent):
	var target: YtUnit = event.get_target()
	var level: int = tower.get_level()

	acid_bt.apply(tower, target, level)
