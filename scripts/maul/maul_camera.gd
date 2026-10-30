class_name MaulCamera
extends CameraRig
## Kamera für Shopping Maul: Q W E R A S D F Z X C sind dort Bau-Tasten (wie in WC3),
## deshalb bewegt sich die Kamera nur mit den Pfeiltasten, am Bildschirmrand und mit der Maus.
## Die Karte ist viel größer als eine GemTD-Map, darum darf weiter herausgezoomt werden.

const MAUL_MAX_DISTANCE := 140.0


func frame_map(width: float, height: float) -> void:
	super.frame_map(width, height)
	distance = clampf(maxf(width, height) * 1.05, MIN_DISTANCE, MAUL_MAX_DISTANCE)
	_apply()


## Kamera auf einen Punkt der Karte (in Einheiten) setzen.
func look_at_point(p: Vector2, dist := -1.0) -> void:
	target = Vector3(p.x, 0, p.y)
	if dist > 0.0:
		distance = clampf(dist, MIN_DISTANCE, MAUL_MAX_DISTANCE)
	_clamp_target()
	_apply()


func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	if _right_down and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_right_down = false
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_UP):
		input.y -= 1
	if Input.is_key_pressed(KEY_DOWN):
		input.y += 1
	if Input.is_key_pressed(KEY_LEFT):
		input.x -= 1
	if Input.is_key_pressed(KEY_RIGHT):
		input.x += 1
	input += _edge_input()
	input = input.limit_length(1.0)
	if input == Vector2.ZERO:
		return
	var move := Vector3(input.x, 0, input.y).rotated(Vector3.UP, yaw) * PAN_SPEED * real_delta * (distance / 40.0)
	target += move
	_clamp_target()
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	# Mausrad heraus: weiter als in GemTD
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN \
			and not UiUtil.mouse_over_ui(get_viewport()):
		distance = minf(distance * 1.1, MAUL_MAX_DISTANCE)
		_apply()
		return
	super._unhandled_input(event)
