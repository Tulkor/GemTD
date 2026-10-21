# Gegner-Modelle aus "Animated Monster Pack" von Quaternius (CC0, siehe assets/models/CREDITS.md):
# FBX -> .glb mit Animationen walk, idle, hit, death (Namen wie beim Boss, enemy.gd spielt sie ab).
# Aufruf (Blender als Python-Modul bpy, siehe tools/modelle/README.md):
#   <python mit bpy> -I tools/modelle/monster_umwandeln.py -- <Ordner mit den FBX> assets/models/enemies
import bpy, sys, os

argv = sys.argv[sys.argv.index('--') + 1:]
src_dir, dst_dir = argv[0], argv[1]
# Modell -> {Zielname: Animation im Paket}; Flieger haben kein Stehen, dort fliegen sie weiter.
MONSTER = {
	"Skeleton": {"walk": "Running", "idle": "Idle", "death": "Death"},
	"Slime": {"walk": "Walk", "idle": "Idle", "death": "Death"},
	"Dragon": {"walk": "Flying", "idle": "Flying", "hit": "Hit", "death": "Death"},
	"Bat": {"walk": "Flying", "idle": "Flying", "hit": "Hit", "death": "Death"},
}

for name, anims in MONSTER.items():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.fbx(filepath=os.path.join(src_dir, name + ".fbx"))
	# Die Paket-Materialien haben Alpha 0 (im Spiel unsichtbar): deckend machen.
	for m in bpy.data.materials:
		bsdf = m.node_tree.nodes.get("Principled BSDF") if m.use_nodes else None
		if bsdf:
			bsdf.inputs["Alpha"].default_value = 1.0
		m.diffuse_color[3] = 1.0
		if hasattr(m, "surface_render_method"):
			m.surface_render_method = 'DITHERED'
	# Augen hängen an einem eigenen, unbewegten Skelett: starr an den Kopf hängen, damit nur ein Skelett übrig bleibt.
	main = max((o for o in bpy.data.objects if o.type == 'ARMATURE'), key=lambda o: len(o.data.bones))
	for arm in [o for o in bpy.data.objects if o.type == 'ARMATURE' and o != main]:
		for me in [o for o in bpy.data.objects if o.type == 'MESH' and o.parent == arm]:
			for mod in list(me.modifiers):
				if mod.type == 'ARMATURE':
					bpy.context.view_layer.objects.active = me
					bpy.ops.object.modifier_apply(modifier=mod.name)
			mw = me.matrix_world.copy()
			me.parent = main
			me.parent_type = 'BONE'
			me.parent_bone = "Head"
			me.matrix_world = mw
		bpy.data.objects.remove(arm)
	by_suffix = {a.name.rsplit("_", 1)[-1]: a for a in bpy.data.actions}
	keep = []
	for target, suffix in anims.items():
		a = by_suffix[suffix]
		if a in keep:
			a = a.copy()
		a.name = target
		a.use_fake_user = True
		keep.append(a)
	for a in list(bpy.data.actions):
		if a not in keep:
			bpy.data.actions.remove(a)
	dst = os.path.join(dst_dir, name.lower() + ".glb")
	bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_animations=True,
		export_animation_mode='ACTIONS', export_force_sampling=True, export_optimize_animation_size=True,
		export_apply=False)
	print("OK", dst, [a.name for a in keep])
