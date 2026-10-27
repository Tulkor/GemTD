class_name YtManualTimer
extends Node
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Timer, den YtWorld im Spieltakt weiterzählt (pausiert mit dem Spiel, schneller mit der Spielgeschwindigkeit).

signal timeout()

var time_left: float = 0.0
var wait_time: float = 1.0
var one_shot: bool = false
var autostart: bool = false
var paused: bool = false
var _stopped: bool = true


func _ready() -> void:
	add_to_group("yt_timers")
	if autostart:
		start()


func set_paused(value: bool) -> void:
	paused = value


func is_paused() -> bool:
	return paused


func start(new_wait_time: float = wait_time) -> void:
	wait_time = new_wait_time
	time_left = new_wait_time
	_stopped = false


func stop() -> void:
	time_left = wait_time
	_stopped = true


func update(delta: float) -> void:
	if _stopped or paused:
		return
	time_left -= delta
	if is_zero_approx(time_left):
		time_left = 0
	if time_left <= 0:
		if one_shot:
			_stopped = true
		else:
			time_left = maxf(time_left + wait_time, 0.0) if wait_time > 0.0 else wait_time
		timeout.emit()


func is_stopped() -> bool:
	return _stopped


func get_time_left() -> float:
	return time_left


func get_wait_time() -> float:
	return wait_time
