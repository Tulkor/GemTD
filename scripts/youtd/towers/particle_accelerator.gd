extends YtTowerBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var multiboard: YtMultiboardValues
var stun_bt: YtBuffType


func get_tier_stats() -> Dictionary:
	return {
		1: {mod_value = 0.02},
		2: {mod_value = 0.03},
		3: {mod_value = 0.04},
	}


const MOD_VALUE_ADD: float = 0.001
const STUN_DURATION: float = 2


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)
	triggers.add_event_on_kill(on_kill)


func update_effect_speed():
	var effect_id: int = tower.user_int2
	var new_speed: float = 0.5 + tower.user_real / 2
	YtEffect.set_animation_speed(effect_id, new_speed)


func tower_init():
	multiboard = YtMultiboardValues.new(1)
	var acceleration_label: String = YtUtils.text("GPF2")
	multiboard.set_key(0, acceleration_label)

	stun_bt = YtCbStun.new("particle_accelerator_stun", 0, 0, false, self)


func on_attack(_event: YtEvent):
	var lvl: int = tower.get_level()
	var modify_value: float = _stats.mod_value + MOD_VALUE_ADD * lvl
	tower.modify_property(YtModificationType.enm.MOD_DAMAGE_ADD_PERC, modify_value)
	tower.modify_property(YtModificationType.enm.MOD_ATTACKSPEED, modify_value)
	tower.user_real = tower.user_real + modify_value
	update_effect_speed()


func on_kill(event: YtEvent):
	var effect: int = YtEffect.create_simple_at_unit("res://src/effects/ancient_protector_missile.tscn", event.get_target())
	YtEffect.set_color(effect, Color.ORANGE)
	tower.modify_property(YtModificationType.enm.MOD_DAMAGE_ADD_PERC, -tower.user_real)
	tower.modify_property(YtModificationType.enm.MOD_ATTACKSPEED, -tower.user_real)
	stun_bt.apply_only_timed(tower, tower, STUN_DURATION)
	tower.user_real = 0
	update_effect_speed()


func on_create(_preceding: YtTower):
	var effect_pos: Vector3 = tower.get_position_wc3()
	effect_pos.z += 50
	var effect: int = YtEffect.create_animated_scaled("res://src/effects/spirit_link_target.tscn", effect_pos, 0, 1.5)
	YtEffect.set_auto_destroy_enabled(effect, false)
	tower.user_int2 = effect
	tower.user_real = 0
	update_effect_speed()


func on_destruct():
	YtEffect.destroy_effect(tower.user_int2)


func on_tower_details() -> YtMultiboardValues:
	multiboard.set_value(0, YtUtils.format_float(tower.user_real * 100, 1))

	return multiboard
