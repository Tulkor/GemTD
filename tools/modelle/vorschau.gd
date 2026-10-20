extends SceneTree
## Kontaktbogen von .glb-Dateien: jedes Modell einzeln schräg von oben, als PNG pro Modell.
## Aufruf über tools/modelle/vorschau.sh <ausgabeordner> <a.glb> <b.glb> …
## Mit --animationen: bei Modellen mit Animationen je Animation vier Bilder (Name_Animation_Bild).

var _cam: Camera3D
var _holder: Node3D


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("2a2a36")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	root.add_child(sun)
	_cam = Camera3D.new()
	root.add_child(_cam)
	_run.call_deferred(out, args.slice(1))


func _run(out: String, files: Array) -> void:
	var anims := files.has("--animationen")
	files.erase("--animationen")
	for f in files:
		if _holder:
			_holder.queue_free()
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(str(f), st) != OK:
			print("FEHLER ", f)
			continue
		_holder = Node3D.new()
		root.add_child(_holder)
		var model := doc.generate_scene(st)
		_holder.add_child(model)
		var box := _aabb(model, Transform3D())
		var r := box.size.length() * 0.5
		var c := box.get_center()
		_cam.position = c + Vector3(1.0, 0.8, 1.2).normalized() * r * 2.6
		_cam.look_at(c)
		_cam.fov = 40
		var name: String = str(f).get_file().get_basename()
		var players := model.find_children("*", "AnimationPlayer", true, false)
		if anims and not players.is_empty():
			var ap: AnimationPlayer = players[0]
			for a in ap.get_animation_list():
				var length := ap.get_animation(a).length
				for k in 4:
					ap.play(a)
					ap.seek(length * k / 3.0, true)
					ap.pause()
					for i in 3:
						await process_frame
					root.get_texture().get_image().save_png(out.path_join("%s_%s_%d.png" % [name, a, k]))
			print("BILD ", name, " Animationen: ", ", ".join(ap.get_animation_list()))
			continue
		for i in 4:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png(out.path_join(name + ".png"))
		print("BILD ", name, "  %.2f x %.2f x %.2f" % [box.size.x, box.size.y, box.size.z])
	quit()


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	var t: Transform3D = xf * (n.transform if n is Node3D else Transform3D())
	if n is MeshInstance3D and n.mesh:
		box = t * n.mesh.get_aabb()
		first = false
	elif n is ImporterMeshInstance3D and n.mesh:
		box = t * n.mesh.get_mesh().get_aabb()
		first = false
	for c in n.get_children():
		var b := _aabb(c, t)
		if b.size != Vector3.ZERO:
			box = b if first else box.merge(b)
			first = false
	return box
