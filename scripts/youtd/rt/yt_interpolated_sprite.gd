class_name YtInterpolatedSprite
extends Node
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Strahl zwischen zwei Einheiten oder Punkten (Lightning in JASS). Gezeichnet als Blitz-Schuss im FxPlayer,
## der bis zum Ende der Lebensdauer immer wieder neu zwischen den aktuellen Positionen aufflackert.

const LIGHTNING: String = "lightning"
const REDRAW: float = 0.15

var _kind: String
var _start_unit: YtUnit
var _end_unit: YtUnit
var _last_start_pos: Vector3 = Vector3.ZERO
var _last_end_pos: Vector3 = Vector3.ZERO
var _lifetime_timer: YtManualTimer
var _redraw_timer: YtManualTimer
var modulate: Color = Color.WHITE


func _ready():
	_lifetime_timer = YtManualTimer.new()
	_lifetime_timer.one_shot = true
	_lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)
	add_child(_lifetime_timer)
	_redraw_timer = YtManualTimer.new()
	_redraw_timer.wait_time = REDRAW
	_redraw_timer.timeout.connect(_draw)
	add_child(_redraw_timer)
	_redraw_timer.start()
	_draw()


func _pos(unit: YtUnit, last: Vector3) -> Vector3:
	if is_instance_valid(unit):
		return unit.get_position_wc3() + YtProjectile.UNIT_Z_OFFSET
	return last


func _draw():
	_last_start_pos = _pos(_start_unit, _last_start_pos)
	_last_end_pos = _pos(_end_unit, _last_end_pos)
	if DisplayServer.get_name() == "headless" or YtWorld.node == null:
		return
	YtWorld.node.fx.play_shot({"id": "lightning_arc"}, YtWorld.to_3d(_last_start_pos), YtWorld.to_3d(_last_end_pos))


func _on_lifetime_timer_timeout():
	queue_free()


func set_lifetime(lifetime: float):
	_lifetime_timer.start(lifetime)


static func create_from_unit_to_unit(kind: String, start_unit: YtUnit, end_unit: YtUnit) -> YtInterpolatedSprite:
	return YtInterpolatedSprite._create_internal(kind, start_unit, end_unit, Vector3.ZERO, Vector3.ZERO)


static func create_from_point_to_point(kind: String, start_pos: Vector3, end_pos: Vector3) -> YtInterpolatedSprite:
	return YtInterpolatedSprite._create_internal(kind, null, null, start_pos, end_pos)


static func create_from_unit_to_point(kind: String, start_unit: YtUnit, end_pos: Vector3) -> YtInterpolatedSprite:
	return YtInterpolatedSprite._create_internal(kind, start_unit, null, Vector3.ZERO, end_pos)


static func create_from_point_to_unit(kind: String, start_pos: Vector3, end_unit: YtUnit) -> YtInterpolatedSprite:
	return YtInterpolatedSprite._create_internal(kind, null, end_unit, start_pos, Vector3.ZERO)


static func _create_internal(kind: String, start_unit: YtUnit, end_unit: YtUnit, start_pos: Vector3, end_pos: Vector3) -> YtInterpolatedSprite:
	var s: YtInterpolatedSprite = YtInterpolatedSprite.new()
	s._kind = kind
	s._start_unit = start_unit
	s._end_unit = end_unit
	s._last_start_pos = start_pos
	s._last_end_pos = end_pos
	YtUtils.add_object_to_world(s)
	return s
