extends YtBuffType
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func _init(parent: Node):
	super("creep_meaty", 0, 0, true, parent)

	add_event_on_death(on_death)


func on_death(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var unit: YtUnit = buff.get_buffed_unit()
	var caster: YtUnit = event.get_target()

	var creep: YtCreep = unit as YtCreep

	if creep == null:
		return

#	NOTE: this condition is a bit confusing. The way it
#	works is that if creep is below max level, it will
#	always drop food. If it's above max level, it has 10%
#	chance to drop food. Currently, creeps can't go above
#	max level so this only applies to a potential future
#	"neverending" game length.
	if creep.get_spawn_level() < YtUtils.get_max_level() || creep.calc_bad_chance(0.1):
		creep.drop_item_by_id(caster, false, 2003)
