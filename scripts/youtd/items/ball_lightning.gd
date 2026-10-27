extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var lightning_pt: YtProjectileType


func load_triggers(triggers: YtBuffType):
	triggers.add_periodic_event(periodic, 3.0)


# NOTE: BallLightningJump() in original script
func lightning_pt_on_cleanup(ball: YtProjectile):
	var tower: YtTower = ball.get_caster()
	var towers_in_range: YtIterate 
	var ball_item: YtItem = YtGroupManager.get_by_uid("items", ball.user_int) as YtItem
	var target_tower: YtTower = YtGroupManager.get_by_uid("towers", ball.user_int2) as YtTower
	var tower_in_range: YtTower

	if ball_item == null:
		push_error("ball_item is null: ", ball_item, target_tower)
	
		return
	
#	NOTE: target tower may become invalid if target tower is
#	sold or transformed while Ball Lightning is flying to
#	it.
	var target_tower_is_valid: bool = target_tower != null && YtUtils.unit_is_valid(target_tower)
	if !target_tower_is_valid:
		ball_item.set_visible(true)
		ball_item.fly_to_stash(0.0)

		return

	if !ball_item.pickup(target_tower):
		towers_in_range = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.PLAYER_TOWERS), 1500.00)

		while true:
			tower_in_range = towers_in_range.next_random()

			if tower_in_range == null:
				break

			if tower_in_range != tower && tower_in_range != target_tower && tower_in_range.count_free_slots() > 0:
				break

		if tower_in_range != null:
			var ball_2 = YtProjectile.create_bezier_interpolation_from_unit_to_unit(lightning_pt, tower, 0, 0, target_tower, tower_in_range, 1.2, 0.0, 0.5, false)
			ball_2.user_int = ball_item.get_uid()
			ball_2.user_int2 = tower_in_range.get_uid()
		else:
			ball_item.set_visible(true)
			ball_item.fly_to_stash(0.0)


func item_init():
	lightning_pt = YtProjectileType.create_interpolate("res://src/projectiles/projectile_visuals/ball_lightning_projectile.tscn", 300, self)
	lightning_pt.set_event_on_cleanup(lightning_pt_on_cleanup)


func periodic(_event: YtEvent):
	var tower: YtTower = item.get_carrier()
	var ball: YtProjectile
	var towers_in_range: YtIterate = YtIterate.over_units_in_range_of_caster(tower, YtTargetType.new(YtTargetType.PLAYER_TOWERS), 1500.00)
	var tower_in_range: YtTower

	item.drop()

	var found_tower: bool = false

	if towers_in_range.count() == 0:
		item.fly_to_stash(0.0)

		return

	while true:
		tower_in_range = towers_in_range.next_random()

		if tower_in_range == null:
			break

		if tower_in_range != tower && tower_in_range.count_free_slots() > 0:
			item.set_visible(false)
			ball = YtProjectile.create_bezier_interpolation_from_unit_to_unit(lightning_pt, tower, 0, 0, tower, tower_in_range, 1.2, 0.0, 0.5, false)
			ball.user_int = item.get_uid()
			ball.user_int2 = tower_in_range.get_uid()

			found_tower = true

			break

	if !found_tower:
		item.fly_to_stash(0.0)
