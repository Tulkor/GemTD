class_name YtCreep
extends YtUnit
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Werte eines Gegners (Leben, Rüstung, Tempo, Buffs). Laufen, Modell und Durchlaufen übernimmt der Körper
## (YoutdEnemy): er fragt hier jedes Bild das Tempo (get_current_movespeed) und ob der Gegner betäubt ist.
## Leben zählen nur hier und werden in body.hp gespiegelt. Punkte und Portalschaden rechnet youtd_game.gd.

signal moved(delta)

var _size: YtCreepSize.enm
var _category: YtCreepCategory.enm
var _armor_type: YtArmorType.enm
var _facing_angle: float = 0.0
var _spawn_level: int
var _special_list: Array[int] = []
var _target_height: float = 0.0
var _height_change_speed: float = 0.0
var _portal_damage_multiplier: float = 1.0


func _ready():
	super()

	YtGroupManager.add("creeps", self, get_uid())
	health_changed.connect(_on_health_changed)

	if _size == YtCreepSize.enm.AIR:
		var air_creep_z: float = 2 * YtConstants.TILE_SIZE_WC3
		set_z(air_creep_z)
		_target_height = air_creep_z

	_sprite_dimensions = Vector2(100, 120 if _size == YtCreepSize.enm.BOSS else 80)
	death.connect(_on_death)
	_on_health_changed()


func update(delta: float):
	super.update(delta)

	if !is_stunned():
		moved.emit(delta)

	var current_z: float = get_z()
	if current_z != _target_height:
		var height_change: float = _height_change_speed * delta
		var new_z: float
		if current_z < _target_height:
			new_z = min(_target_height, current_z + height_change)
		else:
			new_z = max(_target_height, current_z - height_change)
		set_z(new_z)


# NOTE: should be called once when creating the creep
func set_properties(player: YtPlayer, size: YtCreepSize.enm, armor_type: YtArmorType.enm, race, health: float, armor: float, level: int):
	set_player(player)
	_size = size
	_armor_type = armor_type
	_category = race
	set_base_health(health)
	set_health(health)
	set_base_armor(armor)
	_spawn_level = level


func set_portal_damage_multiplier(value: float):
	_portal_damage_multiplier = value


func get_portal_damage_multiplier() -> float:
	return _portal_damage_multiplier


# Creep moves to a point on path, which is closest to given point.
func move_to_point(point: Vector2):
	set_position_wc3_2d(point)


# NOTE: creep.adjustHeight() in JASS
func adjust_height(height: float, speed: float):
	if !is_inside_tree():
		return
	if get_size() == YtCreepSize.enm.AIR:
		return
	_target_height += height
	_height_change_speed = speed


# NOTE: creep.dropItem() in JASS
func drop_item(caster: YtTower, _use_creep_player: bool):
	if YtWorld.game != null:
		YtWorld.game.drop_item(self, caster.get_item_quality_ratio() if YtUtils.unit_is_valid(caster) else 1.0)


func drop_item_by_id(_caster: YtTower, _use_creep_player: bool, item_id: int):
	if YtWorld.game != null:
		YtWorld.game.drop_item_id(self, str(item_id))


func _on_health_changed():
	if body != null and is_instance_valid(body):
		body.max_hp = get_overall_health()
		body.hp = get_health()


func _on_death(_event: YtEvent):
	YtEffect.create_simple_at_unit("res://src/effects/death_explode.tscn", self)

	if _size != YtCreepSize.enm.AIR:
		var corpse: YtCreepCorpse = YtCreepCorpse.make(self)
		corpse.set_position_wc3(Vector3(get_x(), get_y(), 0))
		YtUtils.add_object_to_world(corpse)

	if body != null and is_instance_valid(body):
		body.yt_died()


# NOTE: creep.getBaseBountyValue() in JASS
func get_base_bounty_value() -> float:
	var creep_size: YtCreepSize.enm = get_size_including_challenge_sizes()
	var gold_multiplier: float = YtCreepSize.get_gold_multiplier(creep_size)
	var spawn_level: int = get_spawn_level()
	var bounty: float = gold_multiplier * (spawn_level / 8 + 1)

	return bounty


func get_log_name() -> String:
	return "%s-%d" % [YtCreepSize.get_display_string(_size), get_uid()]


# NOTE: creeps are always considered to be in combat for the purposes of their autocasts.
func is_in_combat() -> bool:
	return true


func get_current_movespeed() -> float:
	var base: float = get_base_movespeed()
	var mod: float = get_prop_move_speed()
	var mod_absolute: float = get_prop_move_speed_absolute()
	var unclamped: float = (base + mod_absolute) * mod
	return clampf(unclamped, YtConstants.MOVE_SPEED_MIN, YtConstants.MOVE_SPEED_MAX)


# Sets unit facing to an angle with respect to the positive X axis, in degrees (top down).
# NOTE: SetUnitFacing() in JASS
func set_unit_facing(angle: float):
	_facing_angle = int(angle + 360) % 360


# NOTE: GetUnitFacing() in JASS. Our body faces along rotation.y = atan2(-dir.x, -dir.y).
func get_unit_facing() -> float:
	if body != null and is_instance_valid(body):
		var r: float = body.rotation.y
		return fposmod(rad_to_deg(atan2(-cos(r), -sin(r))), 360.0)
	return _facing_angle


# NOTE: this special function forces CHALLENGE_MASS and CHALLENGE_BOSS to be treated as MASS and BOSS creeps.
func get_size() -> YtCreepSize.enm:
	if _size == YtCreepSize.enm.CHALLENGE_MASS:
		return YtCreepSize.enm.MASS
	elif _size == YtCreepSize.enm.CHALLENGE_BOSS:
		return YtCreepSize.enm.BOSS
	else:
		return _size


func get_size_including_challenge_sizes() -> YtCreepSize.enm:
	return _size


# NOTE: unit.getCategory() in JASS
func get_category() -> YtCreepCategory.enm:
	return _category


func get_armor_type() -> YtArmorType.enm:
	return _armor_type


func get_display_name() -> String:
	if body != null and is_instance_valid(body):
		return body.display_name()
	return YtCreepSize.get_display_string(_size)


func get_move_path():
	return body.path if body != null and is_instance_valid(body) else null


func get_spawn_level() -> int:
	return _spawn_level


func get_special_list() -> Array[int]:
	return _special_list


func set_special_list(special_list: Array[int]):
	_special_list = special_list


## Ein Kind dieses Gegners an seiner Stelle erzeugen (Brut, Nekromant, Trächtig). Lebt in derselben Welle.
func spawn_child(health: float, pos: Vector2, portal_mult: float, scale: float, size: YtCreepSize.enm = _size) -> YtCreep:
	if YtWorld.game == null or body == null or not is_instance_valid(body):
		return null
	var child: YtCreep = YtWorld.game.spawn_child_creep(body, size, health, pos / YtWorld.WC3)
	if child != null:
		child.set_portal_damage_multiplier(portal_mult)
		child.set_unit_scale(scale)
	return child
