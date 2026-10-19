class_name CameraRig
extends Node3D
## Strategiekamera: WASD/Pfeiltasten, Maus am Fensterrand oder rechte Maustaste ziehen verschiebt,
## Mausrad zoomt, mittlere Maustaste ziehen oder Q/E dreht.

const PAN_SPEED := 18.0
const ROTATE_SPEED := 1.8
const MIN_DISTANCE := 6.0
const MAX_DISTANCE := 90.0
## Abstand zum Fensterrand in Pixeln, ab dem die Kamera mitläuft.
const EDGE_MARGIN := 6.0
## Ab so vielen Pixeln Mausweg gilt ein Rechtsklick als Ziehen und nicht als Klick.
const DRAG_THRESHOLD := 6.0

var camera: Camera3D
var target := Vector3.ZERO
var distance := 40.0
var yaw := 0.0
var pitch := deg_to_rad(-58.0)
var bounds := Rect2(0, 0, 40, 40)
var _rotating := false
var _right_down := false
var _right_travel := 0.0
## true, wenn der letzte Rechtsklick die Kamera verschoben hat (dann kein Abwählen/Radieren).
var right_dragged := false


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.far = 500.0
	add_child(camera)
	camera.make_current()
	_apply()


## Kamera auf die ganze Map ausrichten (Größe in Einheiten, nicht in Feldern).
func frame_map(width: float, height: float) -> void:
	bounds = Rect2(0, 0, width, height)
	target = Vector3(width / 2.0, 0, height / 2.0 + height * 0.04)
	distance = clampf(maxf(width, height) * 1.05, MIN_DISTANCE, MAX_DISTANCE)
	_apply()


func _process(delta: float) -> void:
	# Echtzeit, damit die Kamera bei 4x Spieltempo nicht rast
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	if _right_down and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_right_down = false  # losgelassen über dem Seitenpanel
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1
	input += _edge_input()
	input = input.limit_length(1.0)
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
	_clamp_target()
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
			MOUSE_BUTTON_RIGHT:
				_right_down = event.pressed
				if event.pressed:
					_right_travel = 0.0
					right_dragged = false
	elif event is InputEventMouseMotion and _rotating:
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch - event.relative.y * 0.006, deg_to_rad(-85), deg_to_rad(-20))
		_apply()
	elif event is InputEventMouseMotion and _right_down:
		_right_travel += event.relative.length()
		if _right_travel >= DRAG_THRESHOLD:
			right_dragged = true
			_drag_pan(event.relative)


## Karte mit der Maus „greifen“: der Boden folgt dem Mauszeiger.
func _drag_pan(relative: Vector2) -> void:
	if camera == null:
		return
	var view_h := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var per_pixel := 2.0 * distance * tan(deg_to_rad(camera.fov) / 2.0) / view_h
	var along := Vector3(-relative.x, 0, -relative.y / maxf(sin(-pitch), 0.2))
	target += along.rotated(Vector3.UP, yaw) * per_pixel
	_clamp_target()
	_apply()


## Richtung, wenn die Maus am Fensterrand steht (nur bei aktivem Fenster).
func _edge_input() -> Vector2:
	if not DisplayServer.window_is_focused() or _right_down or _rotating:
		return Vector2.ZERO
	var rect := get_viewport().get_visible_rect()
	var mp := get_viewport().get_mouse_position()
	if not rect.grow(1.0).has_point(mp):
		return Vector2.ZERO
	var dir := Vector2.ZERO
	if mp.x <= rect.position.x + EDGE_MARGIN:
		dir.x -= 1
	elif mp.x >= rect.end.x - EDGE_MARGIN:
		dir.x += 1
	if mp.y <= rect.position.y + EDGE_MARGIN:
		dir.y -= 1
	elif mp.y >= rect.end.y - EDGE_MARGIN:
		dir.y += 1
	return dir


func _clamp_target() -> void:
	target.x = clampf(target.x, bounds.position.x, bounds.end.x)
	target.z = clampf(target.z, bounds.position.y, bounds.end.y)


func _apply() -> void:
	position = target
	rotation = Vector3(pitch, yaw, 0)
	if camera:
		camera.position = Vector3(0, 0, distance)
		# Bild nach links schieben, damit das Seitenpanel rechts nichts verdeckt
		camera.h_offset = distance * 0.12


## Skybox: sechs Bilder in der Reihenfolge +X, -X, +Y, -Y, +Z, -Z.
const SKY_FACES := ["right", "left", "top", "bottom", "front", "back"]
const SKY_DIR := "res://assets/textures/sky/"
static var _sky_cube: Cubemap


static func _sky() -> Sky:
	if _sky_cube == null:
		var images: Array[Image] = []
		for face in SKY_FACES:
			var tex := load(SKY_DIR + face + ".png") as Texture2D
			if tex == null:
				return null
			var img := tex.get_image()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGB8)
			images.append(img)
		_sky_cube = Cubemap.new()
		_sky_cube.create_from_images(images)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/skybox.gdshader")
	mat.set_shader_parameter("cube", _sky_cube)
	var sky := Sky.new()
	sky.sky_material = mat
	return sky


## Licht und Himmel für eine 3D-Szene anlegen.
static func add_environment(parent: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("05030c")
	var sky := _sky()
	if sky != null:
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	# Leuchten für helle (HDR) Flächen, z. B. die Neon-Wegpunkte
	env.glow_enabled = true
	env.glow_intensity = 1.1
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# dunkle Szene: schwaches kühles Umgebungslicht und eine schwache, flach stehende Sonne,
	# damit Neon, Sockel und Gems hervorstechen
	env.ambient_light_color = Color(0.62, 0.7, 0.85)
	env.ambient_light_energy = 0.1
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-38), deg_to_rad(-35), 0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	# Schatten nur so weit wie das Spielfeld reicht: feinere Schattenkanten ohne Treppen
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	# eeveTD und Shopping Maul: eigener Himmel und eigenes Licht (FieldStyle)
	var look: Dictionary = FieldStyle.current().get("env", {})
	if not look.is_empty():
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = look.sky_top
		sky_mat.sky_horizon_color = look.sky_horizon
		sky_mat.ground_horizon_color = look.sky_horizon
		sky_mat.ground_bottom_color = look.ground_bottom
		sky_mat.sun_angle_max = 0.0
		var plain_sky := Sky.new()
		plain_sky.sky_material = sky_mat
		env.background_mode = Environment.BG_SKY
		env.sky = plain_sky
		env.ambient_light_color = look.ambient
		env.ambient_light_energy = look.ambient_energy
		env.glow_hdr_threshold = look.glow_threshold
		env.glow_intensity = look.glow_intensity
		env.tonemap_exposure = look.exposure
		sun.light_color = look.sun
		sun.light_energy = look.sun_energy
		sun.rotation.x = deg_to_rad(look.sun_pitch)
		if look.has("fog"):
			# leichter Dunst in der Ferne, damit Boden und Tower räumlicher wirken
			env.fog_enabled = true
			env.fog_light_color = look.fog
			env.fog_density = look.fog_density
			env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	parent.add_child(sun)
