extends SceneTree
## Rendert YouTD-Icons: je Paar <key> <modell> ein PNG mit durchsichtigem Hintergrund nach <ordner>/<key>.png.
## Aufruf über tools/youtd/icons.py. Modell "paket/name", "res://…glb" oder "kristall:<farbe>[:crystal_XX]".

const SIZE := 128

var _cam: Camera3D
var _holder: Node3D


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	root.transparent_bg = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment.ambient_light_energy = 1.2
	root.add_child(env)
	for rot in [Vector3(-50, -35, 0), Vector3(-20, 140, 0)]:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = rot
		sun.light_energy = 1.3 if rot.y < 0 else 0.6
		root.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 30
	root.add_child(_cam)
	_run.call_deferred(args[0], args.slice(1))


func _run(out: String, pairs: Array) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	for i in range(0, pairs.size() - 1, 2):
		var key: String = pairs[i]
		var ref: String = pairs[i + 1]
		var tint := Color(0, 0, 0, 0)
		var path := ref
		if ref.begins_with("kristall:"):
			var p := ref.split(":")
			tint = Color("#" + p[1])
			path = "res://assets/models/crystals/%s.glb" % (p[2] if p.size() > 2 else "crystal_13")
		elif not ref.begins_with("res://"):
			path = "res://assets/models/pakete/%s.glb" % ref
		# Importierte Szene bevorzugen (mit Texturen wie im Spiel), sonst die .glb direkt lesen
		var model: Node = null
		if ResourceLoader.exists(path):
			var ps = load(path)
			if ps is PackedScene:
				model = ps.instantiate()
		if model == null:
			var doc := GLTFDocument.new()
			var st := GLTFState.new()
			if doc.append_from_file(ProjectSettings.globalize_path(path), st) != OK:
				print("FEHLER ", key, " ", path)
				continue
			model = doc.generate_scene(st)
		if _holder:
			_holder.queue_free()
		_holder = Node3D.new()
		root.add_child(_holder)
		_holder.add_child(model)
		_fix_materials(model)
		if tint.a > 0.0:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = tint
			mat.metallic = 0.3
			mat.roughness = 0.25
			mat.emission_enabled = true
			mat.emission = tint * 0.25
			for m in model.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).material_override = mat
		var box := _aabb(model, Transform3D())
		var c := box.get_center()
		var r := maxf(box.size.length() * 0.5, 0.01)
		_cam.position = c + Vector3(1.0, 0.75, 1.3).normalized() * r / tan(deg_to_rad(_cam.fov * 0.5)) * 1.02
		_cam.look_at(c)
		for k in 4:
			await process_frame
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var used := img.get_used_rect()
		if used.size.x > 0:
			var side := maxi(used.size.x, used.size.y)
			var sq := Image.create(side, side, false, Image.FORMAT_RGBA8)
			sq.blit_rect(img, used, Vector2i((side - used.size.x) / 2, (side - used.size.y) / 2))
			img = sq
		img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		img.save_png(out.path_join(key + ".png"))
		print("BILD ", key)
	quit()


## Manche Pakete (Quaternius Fantasy Props) haben schwarze Vertexfarben neben einer Textur: dann nur die Textur.
func _fix_materials(model: Node) -> void:
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (m as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i) as StandardMaterial3D
			if mat != null and mat.albedo_texture != null and mat.vertex_color_use_as_albedo:
				var copy := mat.duplicate() as StandardMaterial3D
				copy.vertex_color_use_as_albedo = false
				(m as MeshInstance3D).set_surface_override_material(i, copy)


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	var t: Transform3D = xf * (n.transform if n is Node3D else Transform3D())
	if n is MeshInstance3D and n.mesh:
		box = t * n.mesh.get_aabb()
		first = false
	for c in n.get_children():
		var b := _aabb(c, t)
		if b.size != Vector3.ZERO:
			box = b if first else box.merge(b)
			first = false
	return box
