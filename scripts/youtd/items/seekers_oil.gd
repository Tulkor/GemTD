extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: this range is a hand-picked value which hits 3x3
# grid of towers around the main tower or 4+3+4 towers built
# in honeycomb pattern.
# 
# Distance to tower 2 tiles away = 128 * 2 = 256
# -RANGE_CHECK_BONUS_FOR_TOWERS(72) to account for YtIterate
# adding it during range checking.
# 256 - 72 = 184
# and then additional -4 so that the oil doesn't hit tower 2
# tiles away but hits a tower on the edge of honeycomb
# pattern.
static var SEEKER_OIL_RANGE: float = 2 * YtConstants.TILE_SIZE_WC3 - YtConstants.RANGE_CHECK_BONUS_FOR_TOWERS - 4
const SEEKER_OIL_ID: int = 1018


func on_pickup():
	seeker_oil_on_pickup(item, SEEKER_OIL_ID)


static func seeker_oil_on_pickup(original_oil: YtItem, oil_id: int):
# 	NOTE: hackfix alert! The _is_oil_and_was_applied_already
# 	flag is used to know when we are transferring oils from
# 	one tower to another, either when towers get upgraded or
# 	transformed. In such cases, we do not do the aoe effect
# 	of seeker oil again - we only transfer the oil from old
# 	tower to new tower.
	if original_oil._is_oil_and_was_applied_already:
		return

	var is_original_oil: bool = original_oil.user_int == 0

	if !is_original_oil:
		return

	var carrier: YtTower = original_oil.get_carrier()

	var towers_in_range: YtIterate = YtIterate.over_units_in_range_of_caster(carrier, YtTargetType.new(YtTargetType.TOWERS), SEEKER_OIL_RANGE)

	while towers_in_range.count() > 0:
		var neighbor: YtTower = towers_in_range.next()

		if neighbor == carrier:
			continue

		var oil_for_neighbor: YtItem = YtItem.create(original_oil.get_player(), oil_id, carrier.get_position_wc3())

#		NOTE: set user_int to 1 to mark this oil to stop recursion
		oil_for_neighbor.user_int = 1

		oil_for_neighbor.pickup(neighbor)
