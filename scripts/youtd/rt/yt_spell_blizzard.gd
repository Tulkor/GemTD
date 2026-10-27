extends YtSpellDummy
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.

const WAVE_INTERVAL: float = 1.0

var _damage: float = 0.0
var _radius: float = 0.0
var _wave_count: int = 0

var _completed_wave_count: int = 0

var _wave_timer: YtManualTimer


# Called when the node enters the scene tree for the first time.
func _ready():
	super()

	_wave_timer = YtManualTimer.new()
	_wave_timer.timeout.connect(_on_wave_timer_timeout)
	add_child(_wave_timer)
	_wave_timer.start(WAVE_INTERVAL)

#	NOTE: do first wave on creation
	_on_wave_timer_timeout()


func _on_wave_timer_timeout():
	do_spell_damage_aoe(_target_position, _radius, _damage, 0.0)
	var effect: int = YtEffect.create_simple("frost_blizzard", _target_position)
	YtEffect.set_scale(effect, _radius / 150.0)

	_completed_wave_count += 1

	var all_waves_done: bool = _completed_wave_count >= _wave_count
	if all_waves_done:
		_wave_timer.stop()


# NOTE: subclasses override this to save data that is useful
# for them
func _set_subclass_data(data: YtSpellType.SpellData):
	_damage = data.blizzard.damage
	_radius = data.blizzard.radius
	_wave_count = data.blizzard.wave_count
