# "Medieval Church" von Daniel74 (Blend Swap 75990, CC0, siehe assets/models/CREDITS.md) -> .glb für die eeveTD-Umgebung.
# Statue im Inneren (13 000 Flächen, von außen unsichtbar), Kamera und Licht fallen weg; Texturen verkleinert
# danach tools/modelle/umwandeln.py (pack_gltf). Aufruf (Blender als Python-Modul bpy, siehe README.md):
#   <python mit bpy> -I tools/modelle/kirche_umwandeln.py -- <Church1Upload.blend> assets/models/scenery/church.glb
import bpy, sys

argv = sys.argv[sys.argv.index('--') + 1:]
src, dst = argv[0], argv[1]
bpy.ops.wm.open_mainfile(filepath=src)
for o in list(bpy.data.objects):
	if o.type != 'MESH' or o.name == "Innansorra":
		bpy.data.objects.remove(o)
# Die Datei stammt aus Blender 2.5: Materialien ohne Knoten, Texturen nur als Bilder dabei. Jedes Material
# bekommt das Bild mit passendem Namen (GreyBrick2 -> GreyBricks2.jpg, LogEdgeWeathered -> TreeLogEdgeWeathered.jpg).
def norm(t):
	return "".join(c for c in t.lower().split(".jpg")[0] if c.isalnum()).replace("s", "")

for m in bpy.data.materials:
	img = next((i for i in bpy.data.images if i.size[0] and (norm(m.name) in norm(i.name) or norm(i.name) in norm(m.name))), None)
	col = tuple(m.diffuse_color)
	m.use_nodes = True
	nodes = m.node_tree.nodes
	nodes.clear()
	bsdf = nodes.new("ShaderNodeBsdfPrincipled")
	out = nodes.new("ShaderNodeOutputMaterial")
	m.node_tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
	bsdf.inputs["Base Color"].default_value = col
	bsdf.inputs["Roughness"].default_value = 0.9
	if img:
		tex = nodes.new("ShaderNodeTexImage")
		tex.image = img
		m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
	print("Material", m.name, "->", img.name if img else col)
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_apply=True, export_animations=False)
print("OK", dst)
