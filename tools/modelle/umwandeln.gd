extends SceneTree
## Wandelt FBX-Modelle in eigenständige .glb um: Texturen eingebettet und verkleinert,
## Normal- und Zusatzkarten weggelassen. Aufruf über tools/modelle/umwandeln.py (glTF/GLB rechnet das selbst).
## Argumente: <liste.json> mit [{"src": "/abs/quelle.fbx", "dst": "/abs/ziel.glb", "tex": 256}, …]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var list = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var fails := 0
	for e in list:
		if not _convert(str(e.src), str(e.dst), int(e.get("tex", 256)), str(e.get("textur", ""))):
			fails += 1
	print("FERTIG %d/%d" % [list.size() - fails, list.size()])
	quit(1 if fails else 0)


func _convert(src: String, dst: String, tex_max: int, textur := "") -> bool:
	var doc: GLTFDocument = FBXDocument.new() if src.get_extension().to_lower() == "fbx" else GLTFDocument.new()
	var state: GLTFState = FBXState.new() if doc is FBXDocument else GLTFState.new()
	var err := doc.append_from_file(src, state, 0, src.get_base_dir())
	if err != OK:
		printerr("FEHLER Laden %s: %s" % [src, error_string(err)])
		return false
	var scene := doc.generate_scene(state)
	if scene == null:
		printerr("FEHLER Szene %s" % src)
		return false
	_to_meshes(scene)
	if textur != "":
		var img := Image.load_from_file(textur)
		if img == null:
			printerr("FEHLER Textur %s" % textur)
			return false
		_set_texture(scene, ImageTexture.create_from_image(img))
	_shrink(scene, tex_max)
	var out := GLTFDocument.new()
	var st := GLTFState.new()
	err = out.append_from_scene(scene, st)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
		err = out.write_to_filesystem(st, dst)
	scene.free()
	if err != OK:
		printerr("FEHLER Schreiben %s: %s" % [dst, error_string(err)])
		return false
	print("OK %s" % dst)
	return true


## generate_scene liefert ImporterMeshInstance3D, die der glTF-Export nicht kennt.
func _to_meshes(node: Node) -> void:
	for c in node.get_children():
		_to_meshes(c)
		if c is ImporterMeshInstance3D:
			var mi := MeshInstance3D.new()
			mi.name = c.name
			mi.transform = c.transform
			mi.mesh = c.mesh.get_mesh()
			node.add_child(mi)
			node.move_child(mi, c.get_index())
			for k in c.get_children():
				k.reparent(mi, false)
			node.remove_child(c)
			c.free()
			mi.owner = node if node.owner == null else node.owner


## Eine Textur als Grundfarbe aller Flächen, durchsichtige Pixel ausgeschnitten (Pflanzen-Karten).
func _set_texture(node: Node, tex: Texture2D) -> void:
	if node is MeshInstance3D and node.mesh:
		for i in node.mesh.get_surface_count():
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = tex
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 0.5
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.roughness = 1.0
			node.mesh.surface_set_material(i, mat)
	for c in node.get_children():
		_set_texture(c, tex)


## Texturen auf höchstens tex_max Pixel verkleinern, nur Grundfarbe behalten.
func _shrink(node: Node, tex_max: int) -> void:
	if node is MeshInstance3D and node.mesh:
		for i in node.mesh.get_surface_count():
			var mat = node.mesh.surface_get_material(i)
			if mat is BaseMaterial3D:
				mat.normal_enabled = false
				mat.normal_texture = null
				mat.roughness_texture = null
				mat.metallic_texture = null
				mat.ao_texture = null
				mat.emission_texture = null
				var tex: Texture2D = mat.albedo_texture
				if tex:
					var img := tex.get_image()
					if img:
						if img.is_compressed():
							img.decompress()
						var big := maxi(img.get_width(), img.get_height())
						if big > tex_max:
							var f := float(tex_max) / big
							img.resize(maxi(1, int(img.get_width() * f)), maxi(1, int(img.get_height() * f)), Image.INTERPOLATE_LANCZOS)
						mat.albedo_texture = ImageTexture.create_from_image(img)
	for c in node.get_children():
		_shrink(c, tex_max)
