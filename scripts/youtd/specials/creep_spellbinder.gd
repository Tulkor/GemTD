extends YtBuffType
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.

# NOTE: this special is not affected by silence, on purpose.
# This is how it was in the original game.


var silence_bt: YtBuffType


func _init(parent: Node):
	super("creep_spellbinder", 0, 0, true, parent)

	silence_bt = YtCbSilence.new("silence_bt", 0, 0, false, self)

	add_periodic_event(on_periodic, 5.0)


func on_periodic(event: YtEvent):
	var buff: YtBuff = event.get_buff()
	var creep: YtUnit = buff.get_buffed_unit()

	var I: YtIterate = YtIterate.over_units_in_range_of_caster(creep, YtTargetType.new(YtTargetType.TOWERS), 1100.0)

	var zap_count: int = 0

	while true:
		var tower: YtUnit = I.next_random()

		if tower == null:
			break

		if zap_count >= 3:
			break

		if creep.get_mana() < 50:
			break

		creep.subtract_mana(50, true)

		var stolen_mana: float = tower.get_overall_mana() * 0.3
		creep.add_mana(stolen_mana)
		tower.subtract_mana(stolen_mana, true)

		silence_bt.apply_only_timed(creep, tower, 5.0) 

		var lightning: YtInterpolatedSprite = YtInterpolatedSprite.create_from_unit_to_unit(YtInterpolatedSprite.LIGHTNING, creep, tower)
		lightning.modulate = Color.PURPLE
		lightning.set_lifetime(0.2)

		zap_count += 1
