class_name CameraRig
extends Node3D
## Strategiekamera: WASD/Pfeiltasten verschieben, Mausrad zoomt,
## mittlere Maustaste ziehen oder Q/E dreht.

const PAN_SPEED := 18.0
const ROTATE_SPEED := 1.8
const MIN_DISTANCE := 6.0
const MAX_DISTANCE := 90.0

var camera: Camera3D
var target := Vector3.ZERO
var distance := 40.0
var yaw := 0.0
var pitch := deg_to_rad(-58.0)
var bounds := Rect2(0, 0, 40, 40)
var _rotating := false


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.far = 500.0
	add_child(camera)
	camera.make_current()
	_apply()


## Kamera auf die ganze Map ausrichten.
func frame_map(width: int, height: int) -> void:
	bounds = Rect2(0, 0, width, height)
	target = Vector3(width / 2.0, 0, height / 2.0 + height * 0.04)
	distance = clampf(maxf(width, height) * 1.05, MIN_DISTANCE, MAX_DISTANCE)
	_apply()


func _process(delta: float) -> void:
	# Echtzeit, damit die Kamera bei 4x Spieltempo nicht rast
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1
	var turn := 0.0
	if Input.is_key_pressed(KEY_Q):
		turn += 1
	if Input.is_key_pressed(KEY_E):
		turn -= 1
	if input == Vector2.ZERO and turn == 0.0:
		return
	yaw += turn * ROTATE_SPEED * real_delta
	var move := Vector3(input.x, 0, input.y).rotated(Vector3.UP, yaw) * PAN_SPEED * real_delta * (distance / 40.0)
	target += move
	target.x = clampf(target.x, bounds.position.x, bounds.end.x)
	target.z = clampf(target.z, bounds.position.y, bounds.end.y)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				distance = maxf(MIN_DISTANCE, distance * 0.9)
				_apply()
			MOUSE_BUTTON_WHEEL_DOWN:
				distance = minf(MAX_DISTANCE, distance * 1.1)
				_apply()
			MOUSE_BUTTON_MIDDLE:
				_rotating = event.pressed
	elif event is InputEventMouseMotion and _rotating:
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch - event.relative.y * 0.006, deg_to_rad(-85), deg_to_rad(-20))
		_apply()


func _apply() -> void:
	position = target
	rotation = Vector3(pitch, yaw, 0)
	if camera:
		camera.position = Vector3(0, 0, distance)
		# Bild nach links schieben, damit das Seitenpanel rechts nichts verdeckt
		camera.h_offset = distance * 0.12


## Licht und Himmel für eine 3D-Szene anlegen.
static func add_environment(parent: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("15171d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-35), 0)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	parent.add_child(sun)
