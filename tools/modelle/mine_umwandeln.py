# "Free Mine Assets Pack" (OpenGameArt, CC0, siehe assets/models/CREDITS.md) -> einzelne .glb für die eeveTD-Umgebung.
# Jedes Objekt (bzw. jede Gruppe) aus mine_parts.blend wird für sich exportiert, Mitte unten auf den Ursprung,
# Texturen danach mit tools/modelle/umwandeln.py (pack_gltf) verkleinert, Normalmaps fallen dort weg.
# Aufruf (Blender als Python-Modul bpy, siehe README.md):
#   <python mit bpy> -I tools/modelle/mine_umwandeln.py -- <mine_parts.blend> <Zielordner> [name=Objekt+Objekt ...]
import bpy, sys, os, math
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index('--') + 1:]
src, dst_dir = argv[0], argv[1]
# Zielname -> Objekte aus der Datei
PARTS = dict(a.split("=", 1) for a in argv[2:]) if len(argv) > 2 else {
	"mine_cart": "minecart", "mine_rail": "Rail", "mine_rail_end": "Rail_end", "mine_lamp": "Lamp_01",
	"mine_lamp_hanging": "Lamp_02", "mine_chest": "chest+chest_top.001", "mine_coins": "coins_3",
	"mine_rocks_1": "rocks_1_mid", "mine_rocks_5": "rocks_5_mid", "mine_stalags_5": "stalags_5_low",
	"mine_stalag_3": "stalag_3_low", "mine_frame_1": "Wooden_01", "mine_frame_2": "Wooden_02",
}
# Die Datei stammt aus Blender 2.7 (Materialien für den alten Renderer): Grundfarbe neu aufbauen.
TEX = {"wood": "wood1.png", "metal": "iron_diffuse.png", "rock": "rock1.png", "stalags": "rock1.png"}
COL = {"gold_coins": (0.85, 0.62, 0.15, 1), "light": (1.0, 0.75, 0.35, 1), "cable": (0.05, 0.05, 0.05, 1)}
# Schienen liegen in der Datei hochkant
TURN = {"Rail", "Rail_end"}


def rebuild_materials():
	for m in bpy.data.materials:
		m.use_nodes = True
		nodes = m.node_tree.nodes
		nodes.clear()
		bsdf = nodes.new("ShaderNodeBsdfPrincipled")
		out = nodes.new("ShaderNodeOutputMaterial")
		m.node_tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
		bsdf.inputs["Roughness"].default_value = 0.85
		if m.name in TEX:
			tex = nodes.new("ShaderNodeTexImage")
			tex.image = bpy.data.images[TEX[m.name]]
			m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
		else:
			bsdf.inputs["Base Color"].default_value = COL.get(m.name, (0.5, 0.5, 0.5, 1))
		if m.name == "light":
			bsdf.inputs["Emission Color"].default_value = COL["light"]
			bsdf.inputs["Emission Strength"].default_value = 2.0


os.makedirs(dst_dir, exist_ok=True)
for name, objs in PARTS.items():
	bpy.ops.wm.open_mainfile(filepath=src)
	rebuild_materials()
	keep = [bpy.data.objects[o] for o in objs.split("+")]
	for o in list(bpy.data.objects):
		if o not in keep:
			bpy.data.objects.remove(o)
	for o in keep:
		if o.name in TURN:
			o.matrix_world = Matrix.Rotation(math.pi / 2, 4, 'Y') @ o.matrix_world
	bpy.context.view_layer.update()
	pts = [o.matrix_world @ Vector(c) for o in keep for c in o.bound_box]
	lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
	hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
	off = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
	for o in keep:
		if o.parent is None:
			o.location -= off
	dst = os.path.join(dst_dir, name + ".glb")
	bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_apply=True, export_animations=False)
	print("OK", dst)
