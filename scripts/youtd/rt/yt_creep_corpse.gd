class_name YtCreepCorpse
extends YtUnit
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Leiche eines Gegners am Boden, 10 Sekunden lang (z. B. für die Leichenexplosion der Gruft). Das sichtbare
## Modell legt YoutdEnemy selbst ab (Enemy._leave_corpse), hier nur Ort und Dauer.

const DURATION: float = 10

var _creep_uid: int = 0
var _expire_timer: YtManualTimer


func _ready():
	super()
	add_to_group("yt_corpses")
	_expire_timer = YtManualTimer.new()
	_expire_timer.one_shot = true
	_expire_timer.timeout.connect(remove_from_game)
	add_child(_expire_timer)
	_expire_timer.start(DURATION)


# NOTE: this uid is invalid because creep is removed from game before corpse is created
func get_creep_uid() -> int:
	return _creep_uid


static func make(creep: YtCreep) -> YtCreepCorpse:
	var corpse := YtCreepCorpse.new()
	corpse.set_player(creep.get_player())
	corpse._creep_uid = creep.get_uid()
	return corpse
