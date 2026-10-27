class_name YtTower
extends YtUnit
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Werte und Angriff eines Towers: Ziele suchen, Geschosse (YtProjectile) mit Krit, Flächenschaden und Abprallern,
## Modifikatoren (Level, Weisheit, Items, Buffs) und die Fähigkeiten aus dem Tower-Skript (YtTowerBehavior,
## scripts/youtd/towers/<script>.gd). Hängt als Kind an YoutdTower (body), Werte aus data/youtd/towers.json.


enum AttackStyle {
	NORMAL,
	SPLASH,
	BOUNCE,
}

const ELEMENT_TO_EXPLOSION_ART: Dictionary = {
	YtElement.enm.ICE: "projectile_explosion_ice",
	YtElement.enm.NATURE: "projectile_explosion_nature",
	YtElement.enm.FIRE: "projectile_explosion_fire",
	YtElement.enm.ASTRAL: "projectile_explosion_astral",
	YtElement.enm.DARKNESS: "projectile_explosion_darkness",
	YtElement.enm.IRON: "projectile_explosion_iron",
	YtElement.enm.STORM: "projectile_explosion_storm",
	YtElement.enm.NONE: "projectile_explosion_storm",
}

static var TARGET_TYPE_GROUND_ONLY: YtTargetType = YtTargetType.new(YtTargetType.CREEPS + YtTargetType.SIZE_MASS + YtTargetType.SIZE_NORMAL + YtTargetType.SIZE_CHAMPION + YtTargetType.SIZE_BOSS)
static var TARGET_TYPE_AIR_ONLY: YtTargetType = YtTargetType.new(YtTargetType.CREEPS + YtTargetType.SIZE_AIR)

var _id: int = 0
var _p: Dictionary = {}   ## Werte aus towers.json
var _splash_map: Dictionary = {}
var _bounce_count_max: int = 0
var _bounce_damage_multiplier: float = 0.0
var _attack_style: AttackStyle = AttackStyle.NORMAL
# NOTE: _target_list must be an untyped Array because it may
# contain invalid instances.
var _target_list: Array = []
var _target_count_from_tower: int = 1
var _target_count_from_item: int = 0
var _default_projectile_type: YtProjectileType
var _current_attack_cooldown: float = 0.0
var _was_ordered_to_stop_attack: bool = false
var _was_ordered_to_change_target: bool = false
var _new_target_from_order: YtUnit
# NOTE: preceding tower reference is used only during
# YtTower._ready() and YtTowerBehavior.init(). It becomes null
# forever after that and it is also always null for first
# tier towers.
var _temp_preceding_tower: YtTower = null
# This attack type determines which targets will be picked
# for attacking.
var _attack_target_type: YtTargetType = YtTargetType.new(YtTargetType.CREEPS)
var _tower_behavior: YtTowerBehavior = null
var _hide_attack_projectiles: bool = false
var _current_crit_count: int = 0
var _current_crit_damage: float = 0
var _transform_is_allowed: bool = true
var _is_in_combat: bool = false
var _item_modifier: YtModifier = null
## Ablage für 2D-Anzeigen der Skripte (Ladebalken in YouTD 2); hier ohne Bild, nur damit die Skripte laufen.
var _visual: Node = Node.new()


#########################
###     Built-in      ###
#########################

func _ready():
	add_child(_visual)
	super()

	add_to_group("yt_towers")
	_sprite_dimensions = Vector2(100, 120)

#	NOTE: set z to this value to position tower on 2nd floor
	var tower_z: float = YtConstants.TILE_SIZE_WC3
	set_z(tower_z)

	set_base_mana(float(_p.get("mana", 0)))
	set_mana(0)
	set_base_mana_regen(float(_p.get("mana_regen", 0)))

	YtGroupManager.add("towers", self, get_uid())

	var missile_speed: int = int(_p.get("missile_speed", 1000))
	_default_projectile_type = YtProjectileType.create_interpolate("", missile_speed, self)
	_default_projectile_type.set_event_on_interpolation_finished(_on_projectile_target_hit)
	var explosion_art: String = ELEMENT_TO_EXPLOSION_ART[get_element()]
	_default_projectile_type.set_explosion_art(explosion_art)

	if bool(_p.get("lightning", false)):
		_default_projectile_type.switch_to_lightning_visual()

# 	Carry over some properties from preceding tower
	if _temp_preceding_tower != null:
		set_level(_temp_preceding_tower._level)
		_experience_centi = _temp_preceding_tower._experience_centi
		_mana = _temp_preceding_tower._mana
		_kill_count = _temp_preceding_tower._kill_count
		_best_hit = _temp_preceding_tower._best_hit
		_damage_dealt_total = _temp_preceding_tower._damage_dealt_total
		_damage_dealt_to_wave_map = _temp_preceding_tower._damage_dealt_to_wave_map
		_attack_damage_dealt = _temp_preceding_tower._attack_damage_dealt
		_spell_damage_dealt = _temp_preceding_tower._spell_damage_dealt
		_attack_damage_dealt_to_wave_map = _temp_preceding_tower._attack_damage_dealt_to_wave_map
		_spell_damage_dealt_to_wave_map = _temp_preceding_tower._spell_damage_dealt_to_wave_map

#		Transition all buff groups from preceding tower
		_buff_groups = _temp_preceding_tower._buff_groups.duplicate()
	else:
#		NOTE: only apply tower exp and lvl bonus if tower is
#		"fresh". When tower is transformed or upgraded, it
#		inherits level of preceding tower
#		and these bonuses can't be applied.
		var exp_from_bonuses: float = _calculate_exp_from_bonuses()
		var lvl_from_bonuses: int = YtExperience.get_level_at_exp(exp_from_bonuses, get_player())
		set_level(mini(lvl_from_bonuses, get_player().get_max_tower_level()))
		_experience_centi = roundi(exp_from_bonuses * 100.0)

	var wisdom_modifier: YtModifier = get_player().get_wisdom_modifier()
	add_modifier(wisdom_modifier)

#	NOTE: some stats have an innate level-based modifier
	var innate_modifier: YtModifier = YtModifier.new()
	innate_modifier.add_modification(YtModificationType.enm.MOD_ATK_CRIT_CHANCE, 0, YtConstants.INNATE_MOD_ATK_CRIT_CHANCE_LEVEL_ADD)
	innate_modifier.add_modification(YtModificationType.enm.MOD_ATK_CRIT_DAMAGE, 0, YtConstants.INNATE_MOD_ATK_CRIT_DAMAGE_LEVEL_ADD)
	innate_modifier.add_modification(YtModificationType.enm.MOD_SPELL_CRIT_DAMAGE, 0, YtConstants.INNATE_MOD_SPELL_CRIT_CHANCE_LEVEL_ADD)
	innate_modifier.add_modification(YtModificationType.enm.MOD_SPELL_CRIT_DAMAGE, 0, YtConstants.INNATE_MOD_SPELL_CRIT_DAMAGE_LEVEL_ADD)
	innate_modifier.add_modification(YtModificationType.enm.MOD_DAMAGE_BASE_PERC, 0, YtConstants.INNATE_MOD_DAMAGE_BASE_PERC_LEVEL_ADD)
	innate_modifier.add_modification(YtModificationType.enm.MOD_ATTACKSPEED, 0, YtConstants.INNATE_MOD_ATTACKSPEED_LEVEL_ADD)
	add_modifier(innate_modifier)

	set_target_count(maxi(1, int(_p.get("multishot", 1))))

	var bounce: Array = _p.get("bounce", [])
	var splash: Array = _p.get("splash", [])
	if !bounce.is_empty():
		_attack_style = AttackStyle.BOUNCE
		_bounce_count_max = int(bounce[0])
		_bounce_damage_multiplier = float(bounce[1]) if bounce.size() > 1 else 0.0
	elif !splash.is_empty():
		_attack_style = AttackStyle.SPLASH
		for ring in splash:
			_splash_map[float(ring[0])] = float(ring[1])

	match str(_p.get("targets", "both")):
		"ground": _attack_target_type = TARGET_TYPE_GROUND_ONLY
		"air": _attack_target_type = TARGET_TYPE_AIR_ONLY
		_: _attack_target_type = YtTargetType.new(YtTargetType.CREEPS)

	var specials_modifier := YtModifier.new()
	for m in _p.get("mods", []):
		specials_modifier.add_modification(YtModificationType.from_string(str(m[0])), float(m[1]), float(m[2]))
	add_modifier(specials_modifier)

	_tower_behavior.init(self, _temp_preceding_tower)

#	Reset preceding tower var to avoid having dangling
#	reference
	_temp_preceding_tower = null


# NOTE: need to do attack timing without Timer because Timer
# doesn't handle short durations well (<0.5s)
func update(delta: float):
	super.update(delta)

	if is_stunned():
		return

#	NOTE: reduce current tracked cooldown to overall
#	cooldown if overall cooldown is smaller. This handles
#	cases where tower's attack speed was significantly
#	reduced and then returns to normal.
# 
#	For example, let's say tower's attack speed gets reduced
#	by some debuff so much that the attack cooldown becomes
#	100 seconds. The debuff expires after 10 seconds and
#	tower would be doing nothing for 90 seconds. Instead of
#	that, we recalculate the cooldown so that tower can
#	start attacking normally again.
	var attack_speed: float = get_current_attack_speed()
	if _current_attack_cooldown > attack_speed:
		_current_attack_cooldown = attack_speed

	if _current_attack_cooldown > 0.0:
		_current_attack_cooldown -= delta

	if _current_attack_cooldown <= 0.0:
#		NOTE: need to update target list even if tower is
#		not attacking, to have targets for offensive
#		abilities and items.
		_update_target_list()
		
		var attack_enabled: bool = get_attack_enabled()

		var should_reset_attack_cooldown: bool
		if attack_enabled:
			should_reset_attack_cooldown = _try_to_attack()
		else:
			should_reset_attack_cooldown = true

# 		NOTE: important to add, not set! So that if game is
# 		lagging, all of the attacks fire instead of skipping.
		if should_reset_attack_cooldown:
			_current_attack_cooldown += attack_speed


#########################
###       Public      ###
#########################

func set_transform_is_allowed(value: bool):
	_transform_is_allowed = value


func get_transform_is_allowed() -> bool:
	return _transform_is_allowed


# NOTE: resetAttackCrits() in JASS
func reset_attack_crits():
	_current_crit_count = 0
	_current_crit_damage = 0.0


func on_tower_details() -> YtMultiboardValues:
	return _tower_behavior.on_tower_details()


func remove_from_game():
	if _tower_behavior != null:
		_tower_behavior.on_destruct()

	super()


## Items und Öle des Körpers als ein Modifikator (Werte + Zuwachs je Level wie bei Towern).
func set_item_mods(mods: Array):
	if _item_modifier != null:
		remove_modifier(_item_modifier)
	_item_modifier = YtModifier.new()
	for m in mods:
		_item_modifier.add_modification(YtModificationType.from_string(str(m[0])), float(m[1]), float(m[2]))
	add_modifier(_item_modifier)


func force_attack_target(forced_target: YtCreep):
	var type_ok: bool = _attack_target_type.match(forced_target)
	if !type_ok:
		return

#	NOTE: if tower can attack 1 target, then we simply stop
#	attacking current target. If tower can attack multiple
#	targets, then we substitute one of the targets with the
#	forced target. Note that if the forced target is out of
#	range, we add it anyway and the tower will later
#	automatically remove out of range forced target find a
#	new valid target before next attack.
	if !_target_list.is_empty():
		_remove_target(_target_list[0])

	_add_target(forced_target)


# NOTE: tower.orderStop() in JASS
func order_stop():
	_was_ordered_to_stop_attack = true


# Forces tower to attack a particular target. Works only if
# called during ATTACK event callback.
# NOTE: tower.issueTargetOrder() in JASS
func issue_target_order(target: YtUnit):
	if !YtUtils.unit_is_valid(target):
		return

	_was_ordered_to_change_target = true
	_new_target_from_order = target


#########################
###      Private      ###
#########################

func _calculate_exp_from_bonuses() -> float:
	var player = get_player()
	var builder: YtBuilder = player.get_builder()
	
	var tower_lvl_bonus: int = builder.get_tower_lvl_bonus()
	var tower_exp_bonus: float = player.get_tower_exp_bonus()
	
	var current_lvl: int = YtExperience.get_level_at_exp(tower_exp_bonus, player)
	var experience_for_current_level: int = YtExperience.get_exp_for_level(current_lvl)
	var increased_lvl: int = min(current_lvl + tower_lvl_bonus, player.get_max_tower_level())
	var experience_for_increased_level: int = YtExperience.get_exp_for_level(increased_lvl)
	
	var added_exp: float = float(experience_for_increased_level - experience_for_current_level)
	
	return tower_exp_bonus + added_exp


func _do_damage_from_projectile(projectile: YtProjectile, target: YtUnit, damage: float, is_main_target: bool):
	if !YtUtils.unit_is_valid(target):
		return

	var crit_count: int = projectile.get_tower_crit_count()
	var crit_ratio: float = projectile.get_tower_crit_ratio()
	var emit_damage_event: bool = true

	do_attack_damage(target, damage, crit_ratio, crit_count, is_main_target, emit_damage_event)


# NOTE: this f-n does some unnecessary work in some cases
# but it's simpler this way.
# NOTE: arg needs to be untyped because it may be an invalid
# instance.
func _target_is_valid(target) -> bool:
#	NOTE: return early here, so that if unit instance is
#	invalid, we don't call f-ns on it - that would cause
#	errors
	var unit_is_valid: bool = YtUtils.unit_is_valid(target)
	if !unit_is_valid:
		return false

# 	NOTE: need to extend attack range by "tower radius".
# 	This is how it works in the original game.
	var attack_range: float = get_range() + YtConstants.RANGE_CHECK_BONUS_FOR_TOWERS
	attack_range = YtUtils.apply_unit_range_extension(attack_range, _attack_target_type)
	
	var in_range = YtVectorUtils.in_range(get_position_wc3_2d(), target.get_position_wc3_2d(), attack_range)

	var target_is_immune: bool = target.is_immune()
	var attack_type_is_arcane: bool = get_attack_type() == YtAttackType.enm.ARCANE
	var target_is_immune_to_attack_type: bool = target_is_immune && attack_type_is_arcane

	var target_is_valid: bool = in_range && !target_is_immune_to_attack_type

	return target_is_valid


func _make_projectile(from_pos_base: Vector3, target: YtUnit) -> YtProjectile:
	var z_arc: float = float(_p.get("arc", 0.0))
	var from_pos: Vector3 = from_pos_base + YtProjectile.UNIT_Z_OFFSET
	var projectile: YtProjectile = YtProjectile.create_linear_interpolation_from_point_to_unit(_default_projectile_type, self, 0, 0, from_pos, target, z_arc, true)

	if _hide_attack_projectiles:
		projectile.hide()

	projectile.modulate = YtElement.get_color(get_element())

	return projectile


func _try_to_attack() -> bool:
# 	NOTE: have to do this weird stuff instead of just
# 	iterating over target list because attacks can modify
# 	the target list by killing creeps (and not just the
# 	current target)
	var attack_count: int = 0
	var already_attacked_list: Array = []

	while attack_count < get_target_count():
		var target: YtCreep = null

		for the_target in _target_list:
#			NOTE: need to check for unit validy here because
#			targets during multishot attacks may become
#			invalid. For example, if a previously attacked
#			creep has a debuff which makes it explode and it
#			kills another target nearby.
			if !YtUtils.unit_is_valid(the_target):
				continue

			var already_attacked: bool = already_attacked_list.has(the_target)

			if !already_attacked:
				target = the_target

				break

		if !YtUtils.unit_is_valid(target):
			break

		var original_target: YtUnit = target

		var target_is_first: bool = attack_count == 0
		target = _attack_target(target, target_is_first)
		already_attacked_list.append(target)

#		NOTE: manually swap targets if target was changed
#		via issue_target_order() during _attack_target().
		var was_ordered_to_change_target: bool = original_target != target

		if was_ordered_to_change_target:
			var new_target_is_valid: bool = YtUtils.unit_is_valid(target)

			if new_target_is_valid:
				_remove_target(original_target)
				_add_target(target)

		attack_count += 1

#		NOTE: handlers for attack event (inside
#		_attack_target) may order the tower to stop
#		attacking or switch to a different target. Process
#		the orders here. This part is to stop attacking if
#		tower has multishot.
		if _was_ordered_to_stop_attack:
			_was_ordered_to_stop_attack = false

			break

	var attack_success: bool = attack_count > 0

	return attack_success


# NOTE: returns the target which was actually attacked. May
# be different from input target if tower was ordered to
# switch to new target.
func _attack_target(target: YtUnit, target_is_first: bool) -> YtUnit:
#	NOTE: need to generate crit number here early instead of
#	right before dealing damage, so that for attacks like
#	splash damage and bounce attacks all of the damage dealt
#	has the same crit values. Also so that attack and damage
#	event handlers have access to crit count.
# 
# 	NOTE: these variables need to be member vars instead of
# 	local vars because some ATTACK callbacks in tower
# 	scripts need to modify them.
	_current_crit_count = _generate_crit_count(0.0, 0.0)
	_current_crit_damage = _calc_attack_multicrit_from_crit_count(_current_crit_count, 0.0)

#	NOTE: emit attack event only for the "first" target so
#	that if the tower has multishot ability, the attack
#	event is emitted only once per series of attacks. This
#	is the way it works in original game.
	if target_is_first:
		var attack_event: YtEvent = YtEvent.new(target)
		attack_event._number_of_crits = _current_crit_count
		attack.emit(attack_event)

#	NOTE: process crit bonuses after attack event so that if
#	any attack event handlers added crit bonuses, we apply
#	these bonuses to current attack.
	_current_crit_count += _bonus_crit_count_for_next_attack
	_bonus_crit_count_for_next_attack = 0

	_current_crit_damage += _bonus_crit_ratio_for_next_attack
	_bonus_crit_ratio_for_next_attack = 0.0

#	NOTE: handlers for attack event may order the tower to
#	stop attacking or switch to a different target. Process
#	the orders here.
	if _was_ordered_to_stop_attack:
		return target

	if _was_ordered_to_change_target:
		_was_ordered_to_change_target = false

		var new_target_is_valid: bool = YtUtils.unit_is_valid(_new_target_from_order)
		if new_target_is_valid:
			target = _new_target_from_order

	var attacked_event: YtEvent = YtEvent.new(self)
	attacked_event._number_of_crits = _current_crit_count
	target.attacked.emit(attacked_event)

	var tower_pos: Vector3 = get_position_wc3()
	var projectile: YtProjectile = _make_projectile(tower_pos, target)
	projectile.set_tower_crit_count(_current_crit_count)
	projectile.set_tower_crit_ratio(_current_crit_damage)

#	NOTE: need to save some variables to be used later when
#	projectile reaches target
	if _attack_style == AttackStyle.BOUNCE:
		var randomize_damage: bool = true
		var damage: float = get_current_attack_damage_with_bonus(randomize_damage)
		var current_bounce_index: int = 0

		projectile.user_real = damage
		projectile.user_int = current_bounce_index
	elif _attack_style == AttackStyle.NORMAL:
		if target_is_first:
			projectile.user_int2 = 1
		else:
			projectile.user_int2 = 0

	if body != null and body.has_method("yt_attacked"):
		body.yt_attacked(target)

	return target


func _update_target_list():	
# 	NOTE: need to extend attack range by "tower radius".
# 	This is how it works in the original game.
	var attack_range: float = get_range() + YtConstants.RANGE_CHECK_BONUS_FOR_TOWERS

#	NOTE: get_units_in_range() is one of the most expensive
#	calls in the gameplay logic. Call it here once right
#	before attacking and no more.
	var creeps_in_range: Array = YtUtils.get_units_in_range(self, _attack_target_type, get_position_wc3_2d(), attack_range)

# 	NOTE: need to consider tower to be in combat if there
# 	are *any* creeps in attack range, even if the tower is
# 	not able to attack for whatever reason. This is so that
# 	towers use their offensive abilities and items as
# 	expected.
	_is_in_combat = !creeps_in_range.is_empty()

#	Remove targets that have become invalid. Targets can
#	become invalid for multiple reasons: moving out of
#	range, dying and other.
	var removed_target_list: Array = []

	for target in _target_list:
		var target_is_valid: bool = _target_is_valid(target)

		if !target_is_valid:
			removed_target_list.append(target)

	for target in removed_target_list:
		_remove_target(target)

# 	Remove targets if target list size is too large. For
# 	example, if a tower ability temporarily increased target
# 	count to 3 and then it went back down to 1.
	while _target_list.size() > get_target_count():
		var target = _target_list.back()
		_remove_target(target)

# 	Add new targets that have entered into range
	YtUtils.sort_creep_list_for_targeting(creeps_in_range, get_position_wc3_2d())

	for target in _target_list:
		creeps_in_range.erase(target)

	while creeps_in_range.size() > 0 && _target_list.size() < get_target_count():
		var new_target: YtCreep = creeps_in_range.pop_front()
		var target_is_valid: bool = _target_is_valid(new_target)

		if target_is_valid:
			_add_target(new_target)


func _add_target(target: YtCreep):
	if _target_list.has(target):
		return

	_target_list.append(target)
	target.tree_exited.connect(_on_target_tree_exited.bind(target))


# NOTE: arg needs to be untyped because it may be an invalid
# instance.
func _remove_target(target):
	if !_target_list.has(target):
		return

	if is_instance_valid(target):
		target.tree_exited.disconnect(_on_target_tree_exited)

	_target_list.erase(target)


func _get_next_bounce_target(bounce_pos: Vector3, visited_list: Array[YtUnit]) -> YtCreep:
	var bounce_pos_2d: Vector2 = Vector2(bounce_pos.x, bounce_pos.y)
	var creep_list: Array = YtUtils.get_units_in_range(self, _attack_target_type, bounce_pos_2d, YtConstants.BOUNCE_ATTACK_RANGE)

	for visited_creep in visited_list:
		if !YtUtils.unit_is_valid(visited_creep):
			continue

		creep_list.erase(visited_creep)

	YtUtils.sort_unit_list_by_distance(creep_list, bounce_pos_2d)

	if !creep_list.is_empty():
		var next_target = creep_list[0]

		return next_target
	else:
		return null


#########################
###     Callbacks     ###
#########################

func _on_target_tree_exited(target: YtCreep):
	_remove_target(target)


func _on_projectile_target_hit(projectile: YtProjectile, target: YtUnit):
	match _attack_style:
		AttackStyle.NORMAL:
			_on_projectile_target_hit_normal(projectile, target)
		AttackStyle.SPLASH:
			_on_projectile_target_hit_splash(projectile, target)
		AttackStyle.BOUNCE:
			_on_projectile_target_hit_bounce(projectile, target)


# NOTE: only the first target is considered to be the "main
# target" in case of multishot. This is how it works in
# original game.
func _on_projectile_target_hit_normal(projectile: YtProjectile, target: YtUnit):
	var randomize_damage: bool = true
	var damage: float = get_current_attack_damage_with_bonus(randomize_damage)
	var target_is_first: bool = projectile.user_int2 == 1
	var is_main_target: bool = target_is_first
	
	_do_damage_from_projectile(projectile, target, damage, is_main_target)


func _on_projectile_target_hit_splash(projectile: YtProjectile, main_target: YtUnit):
	if _splash_map.is_empty():
		return

	var randomize_damage: bool = true
	var damage: float = get_current_attack_damage_with_bonus(randomize_damage)
	var is_main_target: bool = true

	_do_damage_from_projectile(projectile, main_target, damage, is_main_target)

	var splash_pos: Vector2
	if main_target != null:
		splash_pos = main_target.get_position_wc3_2d()
	else:
		splash_pos = projectile.get_position_wc3_2d()

#	Process splash ranges from closest to furthers,
#	so that strongest damage is applied
	var splash_range_list: Array = _splash_map.keys()
	splash_range_list.sort()

	var splash_range_max: float = splash_range_list.back()

	var creep_list: Array = YtUtils.get_units_in_range(self, _attack_target_type, splash_pos, splash_range_max)

	if main_target != null:
		creep_list.erase(main_target)

	for neighbor in creep_list:
#		NOTE: need to check validity because splash attack
#		may trigger an exploding creep ability which will
#		kill other splash attack targets before they are
#		processed.
		if !YtUtils.unit_is_valid(neighbor):
			continue

		var neighbor_pos: Vector2 = neighbor.get_position_wc3_2d()
		var distance: float = splash_pos.distance_to(neighbor_pos)

		for splash_range in splash_range_list:
			var creep_is_in_range: bool = distance < splash_range

			if creep_is_in_range:
				var splash_damage_ratio: float = _splash_map[splash_range]
				var splash_damage: float = damage * splash_damage_ratio
				var splash_is_main_target: bool = false
				_do_damage_from_projectile(projectile, neighbor, splash_damage, splash_is_main_target)

				break


func _on_projectile_target_hit_bounce(projectile: YtProjectile, current_target: YtUnit):
	var current_damage: float = projectile.user_real
	var current_bounce_index: int = projectile.user_int
	var bounce_visited_list: Array[YtUnit] = projectile.get_tower_bounce_visited_list()
	if current_target != null:
		bounce_visited_list.append(current_target)

	var is_first_bounce: bool = current_bounce_index == 0
	var is_main_target: bool = is_first_bounce

	var bounce_pos: Vector3
	if current_target != null:
		bounce_pos = current_target.get_position_wc3()
	else:
		bounce_pos = projectile.get_position_wc3()

	_do_damage_from_projectile(projectile, current_target, current_damage, is_main_target)

# 	Launch projectile for next bounce, if bounce isn't over
	var bounce_end: bool = current_bounce_index == _bounce_count_max - 1

	if bounce_end:
		return

	var next_damage: float = current_damage * (1.0 - _bounce_damage_multiplier)

	var next_target: YtCreep = _get_next_bounce_target(bounce_pos, bounce_visited_list)

	if !YtUtils.unit_is_valid(next_target):
		return

	var next_projectile: YtProjectile = _make_projectile(bounce_pos, next_target)
	next_projectile.user_real = next_damage
	next_projectile.user_int = current_bounce_index + 1
	next_projectile._tower_bounce_visited_list = bounce_visited_list
#	NOTE: save crit count in projectile so that it can be
#	used when projectile reaches the target to calculate
#	damage
	next_projectile.set_tower_crit_count(projectile.get_tower_crit_count())
	next_projectile.set_tower_crit_ratio(projectile.get_tower_crit_ratio())


#########################
### Setters / Getters ###
#########################

# Makes all future attack projectiles invisible. Useful in
# rare cases.
func hide_attack_projectiles():
	_hide_attack_projectiles = true


# This f-n changes how many targets the tower can attack at
# the same time. Note that the default value of this
# property is loaded from tower properties CSV when tower is
# created. After that, if this f-n is called from tower
# script the original value is overwritten.
func set_target_count(count: int):
	_target_count_from_tower = count


func set_target_count_from_item(count: int):
	_target_count_from_item = count


func get_target_count_from_item() -> int:
	return _target_count_from_item


# NOTE: tower.getTargetCount() in JASS
func get_target_count() -> int:
	return _target_count_from_tower + _target_count_from_item


# YtTower is attacking while it has valid targets in range.
# NOTE: for towers which don't attack, the target list is
# always empty, so treat such towers as always attacking.
# This is to ensure that items with offensive autocasts
# still get triggered when equipped on such towers.
func is_in_combat() -> bool:
	return _is_in_combat


# NOTE: tower.countFreeSlots() in JASS
func count_free_slots() -> int:
	return get_inventory_capacity() - get_item_count()


# NOTE: tower.haveItemSpace() in JASS
func have_item_space() -> bool:
	return count_free_slots() > 0


func get_oils() -> Array:
	return []


func get_items() -> Array:
	return []


func get_item_count() -> int:
	return body.items.size() if body != null and "items" in body else 0


# NOTE: items carry no scripts yet (Etappe 3)
func get_held_item(_slot_number: int):
	return null


func get_log_name() -> String:
	return get_display_name()


func get_current_target() -> YtUnit:
	if !_target_list.is_empty():
		var target: YtUnit = _target_list.front()

#		NOTE: need to check validity here because target may
#		be in list but become invalid because it just died
		if YtUtils.unit_is_valid(target):
			return target
		else:
			return null
	else:
		return null


func set_id(id: int):
	_id = id
	_p = YoutdData.tower(str(id))


func get_id() -> int:
	return _id


func get_tier() -> int:
	return int(_p.get("tier", 1))


# NOTE: tower.getFamily() in JASS
func get_family() -> int:
	return int(_p.get("family", 0))


# NOTE: tower.getElement() in JASS
func get_element() -> YtElement.enm:
	return YtElement.from_string(str(_p.get("element", "")))


# This is the base time between tower attacks, before
# applying modifications. Do not confuse this value with
# MOD_ATTACKSPEED.
# NOTE: tower.getBaseAttackspeed() in JASS
func get_base_attack_speed() -> float:
	return float(_p.get("cooldown", 1.0))

# This is the actual time between tower attacks, after
# applying modifications.
# Example: If the base attack speed is 2.0 seconds and the
# tower has 1.25 attack speed, then the real attack cooldown
# will be 2.0/1.25 == 1.6 seconds.
# NOTE: tower.getCurrentAttackSpeed() in JASS
func get_current_attack_speed() -> float:
	var attack_speed: float = get_base_attack_speed()
	var attack_speed_mod: float = get_attack_speed_modifier()
	var current_attack_speed: float = attack_speed / attack_speed_mod

	return current_attack_speed


func get_remaining_cooldown() -> float:
	return max(0, _current_attack_cooldown)

func get_damage_min() -> int:
	return int(_p.get("damage", [0, 0])[0])

func get_damage_max() -> int:
	return int(_p.get("damage", [0, 0])[1])

# Returns the base damage, without bonuses to base damage
# NOTE: tower.getBaseDamage() in JASS
func get_base_damage() -> int:
	return floori((get_damage_min() + get_damage_max()) / 2.0)

# NOTE: this value is sum of MOD_DAMAGE_ADD and bonus
# derived from MOD_DPS_ADD. Doesn't include
# MOD_DAMAGE_ADD_PERC.
func get_damage_add_overall() -> float:
	var damage_add: float = get_damage_add()
	var dps_bonus: float = get_dps_bonus()
	var base_attack_speed: float = get_base_attack_speed()
	var dps_mod: float = dps_bonus * base_attack_speed
	var result: float = damage_add + dps_mod

	return result


# Returns base damage, including bonuses to base damage
# NOTE: tower.getCurrentAttackDamageBase() in JASS
func get_current_attack_damage_base() -> float:
	var base_damage: float = get_base_damage()
	var base_bonus: float = get_base_damage_bonus()
	var base_bonus_percent: float = get_base_damage_bonus_percent()
	var base_damage_with_bonus: float = (base_damage + base_bonus) * base_bonus_percent

	return base_damage_with_bonus


# NOTE: by default this value is based on the average of
# tower's min and max damage. When tower is calculating
# attack damage, the randomize_damage arg is set to true so
# that this f-n returns random value between min and max.
# NOTE: tower.getCurrentAttackDamageWithBonus() in JASS
func get_current_attack_damage_with_bonus(randomize_damage: bool = false) -> float:
	var base_damage: float
	var damage_min: float = get_damage_min()
	var damage_max: float = get_damage_max()
	if randomize_damage:
		base_damage = YtGlobals.synced_rng.randf_range(damage_min, damage_max)
	else:
		base_damage = floori((damage_min + damage_max) / 2)

	var base_bonus: float = get_base_damage_bonus()
	var base_bonus_percent: float = get_base_damage_bonus_percent()
	var damage_add_total: float = get_damage_add_overall()
	var damage_add_percent: float = get_damage_add_percent()

	var overall_base_damage: float = (base_damage + base_bonus) * base_bonus_percent
	var overall_damage: float = (overall_base_damage + damage_add_total) * damage_add_percent

	overall_damage = max(0, overall_damage)

	return overall_damage


# How much damage the tower deals with its attack per second on average (not counting in any crits). 
func get_overall_dps() -> float:
	var damage: float = get_current_attack_damage_with_bonus()
	var attack_speed: float = get_current_attack_speed()
	var dps: float = damage / attack_speed

	return dps


# How much damage the tower deals with its attack per second on average when 
# counting attack crits and multicrits.
func get_dps_with_crit() -> float:
	# Extra crit damage per successful crit:
	# if crit_damage = 1.5x, then extra = 0.5
	var extra_per_crit: float = get_prop_atk_crit_damage() - 1.0
	
	# Loop parameters
	var remaining_multicrits: int = get_prop_multicrit_count()      # M
	var current_crit_chance: float = get_prop_atk_crit_chance()     # initial p_1

	# Probability that the chain survives to stage k (P[crits ≥ k])
	var chain_prob_at_least_k: float = 1.0

	# Expected crit multiplier:
	# E[multiplier] = 1 + extra * Σ_{k=1..M} P(crits ≥ k)
	var expected_crit_multiplier: float = 1.0

	while remaining_multicrits > 0:
		# Compute effective crit probability for this stage, clamped to cap
		# and update chain -> probability of reaching at least this stage
		chain_prob_at_least_k *= clampf(current_crit_chance, 0.0, YtConstants.ATK_CRIT_CHANCE_CAP)

		# Add contribution of this stage
		expected_crit_multiplier += extra_per_crit * chain_prob_at_least_k

		# Prepare for next stage: diminish chance
		current_crit_chance *= YtConstants.ATK_MULTICRIT_DIMISHING
		remaining_multicrits -= 1

	var dps: float = get_overall_dps()
	var dps_with_crit: float = dps * expected_crit_multiplier
	
	return dps_with_crit


# How much damage the tower dealt in total
# NOTE: getOverallDamage() in JASS, renamed to avoid confusion
func get_total_damage() -> float:
	return _damage_dealt_total
	
# How much damage the tower dealt in total, during last 5 waves
func get_total_damage_recent() -> float:
	var total_damage_recent: float = 0
	var current_wave_level: int = _player.get_team().get_level()
	for i in range(current_wave_level, current_wave_level - 5, -1):
		total_damage_recent += _damage_dealt_to_wave_map.get(i, 0)
	return total_damage_recent

# How much kills the tower has in total
func get_kills() -> int:
	return _kill_count

# What was the max hit damage the tower dealt
func get_best_hit() -> float:
	return _best_hit

func get_base_range() -> float:
	return float(_p.get("range", 800))

# NOTE: tower.getRange() in JASS
func get_range() -> float:
	var original_range: float = get_base_range()
	var player: YtPlayer = get_player()
	var builder: YtBuilder = player.get_builder()
	var builder_range_bonus: float = builder.get_range_bonus()
	var attack_range_bonus: float = player.get_attack_range_bonus()
	var total_range: float = original_range + builder_range_bonus + attack_range_bonus

	return total_range


# NOTE: tower.getRarity() in JASS
func get_rarity() -> YtRarity.enm:
	return YtRarity.convert_from_string(str(_p.get("rarity", "common")))

func get_display_name() -> String:
	return str(_p.get("name", ""))

# NOTE: tower.getAttackType() in JASS
func get_attack_type() -> YtAttackType.enm:
	return YtAttackType.from_string(str(_p.get("attack_type", "physical")))

# NOTE: tower.getGoldCost() in JASS
func get_gold_cost() -> int:
	return int(_p.get("cost", 0))

func get_inventory_capacity() -> int:
	return clampi(YoutdData.item_slots(str(_id)), 1, YtConstants.INVENTORY_CAPACITY_MAX)

func get_attack_enabled() -> bool:
	return bool(_p.get("attack", true))


#########################
###       Static      ###
#########################

## Neuer Kern für Tower id; das Skript (Feld "script") liegt unter scripts/youtd/towers/.
static func make(id: int, player: YtPlayer, preceding_tower: YtTower = null) -> YtTower:
	var tower: YtTower = YtTower.new()
	tower.set_id(id)
	var script_name: String = str(tower._p.get("script", ""))
	var behavior: YtTowerBehavior = null
	var path := "res://scripts/youtd/towers/%s.gd" % script_name
	if script_name != "" and ResourceLoader.exists(path):
		behavior = load(path).new()
	else:
		behavior = YtTowerBehavior.new()
	tower._tower_behavior = behavior
	tower.add_child(behavior)
	tower._temp_preceding_tower = preceding_tower
	tower.set_player(player)

	return tower
